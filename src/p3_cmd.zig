//! =============================================================================
//! P³ LINUX CLI TOOL — EXTENDED FOR VEHICLE DYNAMICS & RACING TRACKS
//! =============================================================================

const std = @import("std");
const p3_kernel = @import("p3_kernel.zig");
const p3_vehicle = @import("p3_vehicle.zig");
const p3_road = @import("p3_road.zig");
const p3_exporter = @import("p3_exporter.zig");

pub const HomVec4 = p3_kernel.HomVec4;
pub const Vehicle = p3_vehicle.Vehicle;
pub const Track = p3_road.Track;

pub const ObjectType = enum {
    cube,
    sphere,
    point,
    npc,
    player,
    car,
};

pub const WorldEntity = extern struct {
    id: u32,
    name: [32]u8,
    name_len: u32,
    obj_type: u32,
    x: f64,
    y: f64,
    z: f64,
    w: f64,
    radius: f64,
    active: bool,
};

pub const StateHeader = extern struct {
    magic: [4]u8 = .{ 'P', '3', 'S', 'T' },
    version: u32 = 2,
    count: u32 = 0,
    next_id: u32 = 1,
    car_speed_kmh: f64 = 0.0,
    car_rpm: f64 = 800.0,
    car_throttle: f64 = 0.0,
    car_steering: f64 = 0.0,
    car_gear: i32 = 1,
    left_door_open: f64 = 0.0,
    right_door_open: f64 = 0.0,
};

pub const MAX_ENTITIES = 256;
const STATE_FILE_PATH = "/tmp/p3_engine_state.bin";

fn loadState(header: *StateHeader, entities: []WorldEntity) !void {
    const file = std.fs.openFileAbsolute(STATE_FILE_PATH, .{}) catch |err| {
        if (err == error.FileNotFound) {
            header.count = 0;
            header.next_id = 1;
            return;
        }
        return err;
    };
    defer file.close();

    const reader = file.reader();
    _ = try reader.readNoEof(std.mem.asBytes(header));
    const to_read = @min(header.count, MAX_ENTITIES);
    if (to_read > 0) {
        _ = try reader.readNoEof(std.mem.sliceAsBytes(entities[0..to_read]));
    }
}

fn saveState(header: *const StateHeader, entities: []const WorldEntity) !void {
    const file = try std.fs.createFileAbsolute(STATE_FILE_PATH, .{ .truncate = true });
    defer file.close();

    const writer = file.writer();
    try writer.writeAll(std.mem.asBytes(header));
    if (header.count > 0) {
        try writer.writeAll(std.mem.sliceAsBytes(entities[0..header.count]));
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    var args = try std.process.argsWithAllocator(gpa.allocator());
    defer args.deinit();

    _ = args.next(); // Skip binary name

    const cmd = args.next() orelse {
        try stdout.print(
            \\=============================================================================
            \\ P³ Engine Racing & Vehicle Dynamics CLI Tool
            \\=============================================================================
            \\
            \\ Usage:
            \\   p3 init                                      - Reset world (Player, Goblin, RaceCar)
            \\   p3 status                                    - Print state table of entities
            \\   p3 car status                                - Inspect Car telemetry & mechanical parts
            \\   p3 car drive <throttle 0..1> <steer -1..1>   - Drive car (throttle & steer)
            \\   p3 car door <left|right> <open|close>        - Hinge open/close car doors
            \\   p3 step <dt> [ticks]                         - Simulate vehicle physics ticks
            \\   p3 ascii                                     - 2D Top-Down radar map
            \\   p3 json                                      - Output state as JSON (for AI / bash)
            \\   p3 spawn <type> <name> <x> <y> <z> <w> [r]   - Spawn entity
            \\   p3 move <id> <dx> <dy> <dz> [dw]             - Move entity
            \\   p3 dist <id1> <id2>                          - Projective & Euclidean distance
            \\=============================================================================
            \\
        , .{});
        return;
    };

    var header = StateHeader{};
    var entities: [MAX_ENTITIES]WorldEntity = undefined;
    loadState(&header, &entities) catch {
        header.count = 0;
        header.next_id = 1;
    };

    if (std.mem.eql(u8, cmd, "init")) {
        header.count = 0;
        header.next_id = 1;
        header.car_speed_kmh = 0.0;
        header.car_rpm = 800.0;
        header.car_throttle = 0.0;
        header.car_steering = 0.0;
        header.car_gear = 1;
        header.left_door_open = 0.0;
        header.right_door_open = 0.0;

        // 1. Player
        var p_name: [32]u8 = undefined;
        @memcpy(p_name[0..4], "Hero");
        entities[0] = .{
            .id = 1,
            .name = p_name,
            .name_len = 4,
            .obj_type = @intFromEnum(ObjectType.player),
            .x = 0,
            .y = 0,
            .z = 0,
            .w = 1,
            .radius = 0.5,
            .active = true,
        };

        // 2. Goblin
        var g_name: [32]u8 = undefined;
        @memcpy(g_name[0..6], "Goblin");
        entities[1] = .{
            .id = 2,
            .name = g_name,
            .name_len = 6,
            .obj_type = @intFromEnum(ObjectType.npc),
            .x = 3,
            .y = 4,
            .z = 0,
            .w = 1,
            .radius = 0.5,
            .active = true,
        };

        // 3. RaceCar
        var c_name: [32]u8 = undefined;
        @memcpy(c_name[0..7], "RaceCar");
        entities[2] = .{
            .id = 3,
            .name = c_name,
            .name_len = 7,
            .obj_type = @intFromEnum(ObjectType.car),
            .x = 0,
            .y = 5,
            .z = 0.35,
            .w = 1,
            .radius = 1.8,
            .active = true,
        };

        header.count = 3;
        header.next_id = 4;
        try saveState(&header, &entities);
        try stdout.print("[P3] World initialized with Hero, Goblin, and RaceCar (id=3).\n", .{});
    } else if (std.mem.eql(u8, cmd, "car")) {
        const sub_cmd = args.next() orelse "status";

        if (std.mem.eql(u8, sub_cmd, "status")) {
            var car_ent: ?*WorldEntity = null;
            for (entities[0..header.count]) |*ent| {
                if (ent.obj_type == @intFromEnum(ObjectType.car) and ent.active) {
                    car_ent = ent;
                    break;
                }
            }

            try stdout.print(
                \\=============================================================================
                \\ P³ VEHICLE TELEMETRY & COMPONENT STATUS
                \\=============================================================================
                \\ Chassis Position:  [{d:.2} : {d:.2} : {d:.2} : {d:.2}]
                \\ Speed:             {d:.1} km/h
                \\ Engine RPM:        {d:.0} RPM (Idle: 800, Redline: 7500)
                \\ Throttle / Steer:  {d:.0}% / {d:.2}
                \\ Gear:              {d} (Manual RWD)
                \\ Left / Right Door: {s} ({d:.1} deg) / {s} ({d:.1} deg)
                \\ Pistons (4-cyl):   P1: [Active], P2: [Comp], P3: [Exh], P4: [Intake]
                \\ Tires:             4x Pacejka Slip-Grip Enabled (330mm)
                \\=============================================================================
                \\
            , .{
                if (car_ent) |c| c.x else 0.0,
                if (car_ent) |c| c.y else 0.0,
                if (car_ent) |c| c.z else 0.0,
                if (car_ent) |c| c.w else 1.0,
                header.car_speed_kmh,
                header.car_rpm,
                header.car_throttle * 100.0,
                header.car_steering,
                header.car_gear,
                if (header.left_door_open > 0.1) "OPEN" else "CLOSED",
                header.left_door_open * (180.0 / std.math.pi),
                if (header.right_door_open > 0.1) "OPEN" else "CLOSED",
                header.right_door_open * (180.0 / std.math.pi),
            });
        } else if (std.mem.eql(u8, sub_cmd, "drive")) {
            const thr_str = args.next() orelse "1.0";
            const str_str = args.next() orelse "0.0";
            header.car_throttle = std.fmt.parseFloat(f64, thr_str) catch 1.0;
            header.car_steering = std.fmt.parseFloat(f64, str_str) catch 0.0;
            try saveState(&header, &entities);
            try stdout.print("OK: Set Throttle={d:.0}%, Steering={d:.2}\n", .{ header.car_throttle * 100.0, header.car_steering });
        } else if (std.mem.eql(u8, sub_cmd, "door")) {
            const side = args.next() orelse "left";
            const state = args.next() orelse "open";
            const angle: f64 = if (std.mem.eql(u8, state, "open")) 1.1 else 0.0;

            if (std.mem.eql(u8, side, "left")) {
                header.left_door_open = angle;
            } else {
                header.right_door_open = angle;
            }
            try saveState(&header, &entities);
            try stdout.print("OK: {s} door set to {s}\n", .{ side, state });
        }
    } else if (std.mem.eql(u8, cmd, "step")) {
        const dt_str = args.next() orelse "0.1";
        const ticks_str = args.next() orelse "1";
        const dt = std.fmt.parseFloat(f64, dt_str) catch 0.1;
        const ticks = std.fmt.parseInt(usize, ticks_str, 10) catch 1;

        var veh = Vehicle.init();
        veh.throttle = header.car_throttle;
        veh.steering = header.car_steering;
        veh.gear = @intCast(header.car_gear);

        // Link existing position if car entity exists
        var car_ent_idx: ?usize = null;
        for (entities[0..header.count], 0..) |*ent, idx| {
            if (ent.obj_type == @intFromEnum(ObjectType.car) and ent.active) {
                veh.pos = HomVec4.init(ent.x, ent.y, ent.z, ent.w);
                veh.velocity[1] = header.car_speed_kmh / 3.6;
                veh.engine.rpm = header.car_rpm;
                car_ent_idx = idx;
                break;
            }
        }

        for (0..ticks) |_| {
            veh.update(dt);
        }

        header.car_speed_kmh = veh.speedKmh();
        header.car_rpm = veh.engine.rpm;

        if (car_ent_idx) |idx| {
            entities[idx].x = veh.pos.x;
            entities[idx].y = veh.pos.y;
            entities[idx].z = veh.pos.z;
            entities[idx].w = veh.pos.w;
        }

        try saveState(&header, &entities);
        try stdout.print("OK: Simulated {d} ticks (dt={d:.3}s). Speed: {d:.1} km/h, RPM: {d:.0}, Pos: [{d:.2}:{d:.2}:{d:.2}:{d:.2}]\n", .{
            ticks,
            dt,
            header.car_speed_kmh,
            header.car_rpm,
            veh.pos.x,
            veh.pos.y,
            veh.pos.z,
            veh.pos.w,
        });
    } else if (std.mem.eql(u8, cmd, "export")) {
        const target = args.next() orelse "car";
        if (std.mem.eql(u8, target, "road") or std.mem.eql(u8, target, "track")) {
            p3_exporter.exportRoadObj("track.obj") catch |err| {
                try stderr.print("ERR exporting road: {}\n", .{err});
                return;
            };
            try stdout.print("OK: Exported 3D Racing Track to 'track.obj'\n", .{});
        } else {
            p3_exporter.exportCarObj("car.obj") catch |err| {
                try stderr.print("ERR exporting car: {}\n", .{err});
                return;
            };
            try stdout.print("OK: Exported 3D RaceCar to 'car.obj' (Chassis, Cockpit, 4x Wheels)\n", .{});
        }
    } else if (std.mem.eql(u8, cmd, "status")) {
        try stdout.print("Entities ({d}):\n", .{header.count});
        try stdout.print("ID  | TYPE    | NAME            | POS [X : Y : Z : W]                     | R3 (Dehomog)\n", .{});
        try stdout.print("----+---------+-----------------+-----------------------------------------+-------------------\n", .{});
        for (entities[0..header.count]) |*ent| {
            if (!ent.active) continue;
            const w_div = if (@abs(ent.w) < 1e-6) 1.0 else ent.w;
            const type_tag: ObjectType = @enumFromInt(ent.obj_type);

            try stdout.print("{d:<3} | {s:<7} | {s:<15} | [{d:>6.2} : {d:>6.2} : {d:>6.2} : {d:>6.2}] | ({d:>5.2}, {d:>5.2}, {d:>5.2})\n", .{
                ent.id,
                @tagName(type_tag),
                ent.name[0..ent.name_len],
                ent.x,
                ent.y,
                ent.z,
                ent.w,
                ent.x / w_div,
                ent.y / w_div,
                ent.z / w_div,
            });
        }
    } else if (std.mem.eql(u8, cmd, "ascii")) {
        var grid: [21][41]u8 = undefined;
        for (0..21) |r| {
            for (0..41) |c| {
                if (r == 10 and c == 20) {
                    grid[r][c] = '+';
                } else if (r == 10) {
                    grid[r][c] = '-';
                } else if (c == 20) {
                    grid[r][c] = '|';
                } else {
                    grid[r][c] = '.';
                }
            }
        }

        for (entities[0..header.count]) |*ent| {
            if (!ent.active) continue;
            const w_div = if (@abs(ent.w) < 1e-6) 1.0 else ent.w;
            const rx = ent.x / w_div;
            const ry = ent.y / w_div;
            const gx_f = (rx + 10.0) * 2.0;
            const gy_f = 10.0 - ry;
            const gx: isize = @intFromFloat(@round(gx_f));
            const gy: isize = @intFromFloat(@round(gy_f));

            if (gx >= 0 and gx < 41 and gy >= 0 and gy < 21) {
                const type_tag: ObjectType = @enumFromInt(ent.obj_type);
                const ch: u8 = switch (type_tag) {
                    .player => '@',
                    .npc => 'G',
                    .sphere => 'O',
                    .cube => '#',
                    .point => '*',
                    .car => 'C',
                };
                grid[@intCast(gy)][@intCast(gx)] = ch;
            }
        }

        for (0..21) |r| {
            try stdout.print("{s}\n", .{grid[r][0..41]});
        }
        try stdout.print("Legend: @=Hero, G=Goblin, C=RaceCar, O=Sphere, +=Origin(0,0)\n", .{});
    } else if (std.mem.eql(u8, cmd, "dist")) {
        const id1_str = args.next() orelse return;
        const id2_str = args.next() orelse return;
        const id1 = try std.fmt.parseInt(u32, id1_str, 10);
        const id2 = try std.fmt.parseInt(u32, id2_str, 10);

        var e1: ?*WorldEntity = null;
        var e2: ?*WorldEntity = null;
        for (entities[0..header.count]) |*ent| {
            if (ent.id == id1 and ent.active) e1 = ent;
            if (ent.id == id2 and ent.active) e2 = ent;
        }

        if (e1 != null and e2 != null) {
            const w1 = if (@abs(e1.?.w) < 1e-6) 1.0 else e1.?.w;
            const w2 = if (@abs(e2.?.w) < 1e-6) 1.0 else e2.?.w;
            const dx = (e1.?.x / w1) - (e2.?.x / w2);
            const dy = (e1.?.y / w1) - (e2.?.y / w2);
            const dz = (e1.?.z / w1) - (e2.?.z / w2);
            const euclid = @sqrt(dx * dx + dy * dy + dz * dz);

            const v1 = HomVec4.init(e1.?.x, e1.?.y, e1.?.z, e1.?.w).normalize();
            const v2 = HomVec4.init(e2.?.x, e2.?.y, e2.?.z, e2.?.w).normalize();
            const dot_val = HomVec4.dot(v1, v2);
            const fubini = std.math.acos(std.math.clamp(@abs(dot_val), 0.0, 1.0));

            try stdout.print("Euclidean R3: {d:.4} | Fubini-Study P3: {d:.4} rad | <P1,P2>: {d:.4}\n", .{ euclid, fubini, dot_val });
        }
    } else {
        try stderr.print("Unknown command: '{s}'. Run 'p3' without arguments for help.\n", .{cmd});
    }
}
