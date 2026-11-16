//! =============================================================================
//! P³ ENGINE CLI & REPL — TERMINAL INTERACTIVE INTERPRETER
//! =============================================================================
//!
//! Direct terminal interface for projective geometry, entity manipulation,
//! collision checks, and AI agent interaction via stdin/stdout.
//!

const std = @import("std");
const p3_kernel = @import("p3_kernel.zig");
const p3_pga = @import("p3_pga.zig");
const p3_dual_quat = @import("p3_dual_quat.zig");

pub const HomVec4 = p3_kernel.HomVec4;
pub const PGL4 = p3_kernel.PGL4;

pub const ObjectType = enum {
    cube,
    sphere,
    point,
    npc,
    player,
};

pub const WorldEntity = struct {
    id: u32,
    name: [32]u8,
    name_len: usize,
    obj_type: ObjectType,
    pos: HomVec4, // [X : Y : Z : W]
    radius: f64 = 1.0,
    active: bool = true,

    pub fn getName(self: *const WorldEntity) []const u8 {
        return self.name[0..self.name_len];
    }
};

pub const World = struct {
    entities: [256]WorldEntity = undefined,
    count: usize = 0,
    next_id: u32 = 1,

    pub fn spawn(self: *World, obj_type: ObjectType, name: []const u8, x: f64, y: f64, z: f64, w: f64, r: f64) ?*WorldEntity {
        if (self.count >= self.entities.len) return null;
        const id = self.next_id;
        self.next_id += 1;

        var ent_name: [32]u8 = undefined;
        const copy_len = @min(name.len, ent_name.len);
        @memcpy(ent_name[0..copy_len], name[0..copy_len]);

        self.entities[self.count] = .{
            .id = id,
            .name = ent_name,
            .name_len = copy_len,
            .obj_type = obj_type,
            .pos = HomVec4.init(x, y, z, w),
            .radius = r,
            .active = true,
        };
        const ptr = &self.entities[self.count];
        self.count += 1;
        return ptr;
    }

    pub fn findById(self: *World, id: u32) ?*WorldEntity {
        for (self.entities[0..self.count]) |*ent| {
            if (ent.id == id and ent.active) return ent;
        }
        return null;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    try stdout.print(
        \\=============================================================================
        \\ P³ REPL ENGINE v1.0 [Zig 0.14.0 — Projective Geometry Engine]
        \\=============================================================================
        \\ Commands:
        \\   spawn <type> <name> <x> <y> <z> <w> [radius]  - Spawn entity (type: sphere, cube, npc, player, point)
        \\   move <id> <dx> <dy> <dz> [dw]                 - Move entity in P³
        \\   scale_w <id> <w>                              - Change W coordinate (LOD / weight)
        \\   dist <id1> <id2>                              - Fubini-Study / Projective distance
        \\   intersect <id1> <id2>                         - Check collision in projective space
        \\   status                                        - List all active entities
        \\   ascii                                         - Simple 2D ASCII world projection
        \\   help                                          - Print this menu
        \\   exit / quit                                   - Exit REPL
        \\=============================================================================
        \\
    , .{});

    var world = World{};

    // Default world initialization: Player and an NPC
    _ = world.spawn(.player, "Hero", 0.0, 0.0, 0.0, 1.0, 0.5);
    _ = world.spawn(.npc, "Goblin", 3.0, 4.0, 0.0, 1.0, 0.5);

    try stdout.print("[P3] Default scene created (Hero @ [0:0:0:1], Goblin @ [3:4:0:1])\n", .{});

    var buf: [1024]u8 = undefined;

    while (true) {
        try stdout.print("\np3> ", .{});
        const line_opt = try stdin.readUntilDelimiterOrEof(&buf, '\n');
        if (line_opt == null) break;

        const line = std.mem.trim(u8, line_opt.?, " \r\t");
        if (line.len == 0) continue;

        var tokens = std.mem.tokenizeAny(u8, line, " \t");
        const cmd = tokens.next() orelse continue;

        if (std.mem.eql(u8, cmd, "exit") or std.mem.eql(u8, cmd, "quit")) {
            try stdout.print("[P3] Engine shutdown.\n", .{});
            break;
        } else if (std.mem.eql(u8, cmd, "help")) {
            try stdout.print(
                \\Commands:
                \\  spawn <type> <name> <x> <y> <z> <w> [radius]
                \\  move <id> <dx> <dy> <dz> [dw]
                \\  scale_w <id> <w>
                \\  dist <id1> <id2>
                \\  intersect <id1> <id2>
                \\  status
                \\  ascii
                \\  exit
                \\
            , .{});
        } else if (std.mem.eql(u8, cmd, "status")) {
            try stdout.print("Entities ({d}):\n", .{world.count});
            try stdout.print("ID  | TYPE    | NAME            | POS [X : Y : Z : W]                     | R3 (Dehomog)\n", .{});
            try stdout.print("----+---------+-----------------+-----------------------------------------+-------------------\n", .{});
            for (world.entities[0..world.count]) |*ent| {
                if (!ent.active) continue;
                const c = ent.pos.cartesian3();
                try stdout.print("{d:<3} | {s:<7} | {s:<15} | [{d:>6.2} : {d:>6.2} : {d:>6.2} : {d:>6.2}] | ({d:>5.2}, {d:>5.2}, {d:>5.2})\n", .{
                    ent.id,
                    @tagName(ent.obj_type),
                    ent.getName(),
                    ent.pos.x,
                    ent.pos.y,
                    ent.pos.z,
                    ent.pos.w,
                    c[0],
                    c[1],
                    c[2],
                });
            }
        } else if (std.mem.eql(u8, cmd, "spawn")) {
            const type_str = tokens.next() orelse {
                try stdout.print("ERR: missing type. (sphere, cube, npc, player, point)\n", .{});
                continue;
            };
            const name_str = tokens.next() orelse "obj";
            const x_str = tokens.next() orelse "0";
            const y_str = tokens.next() orelse "0";
            const z_str = tokens.next() orelse "0";
            const w_str = tokens.next() orelse "1";
            const r_str = tokens.next() orelse "1";

            const x = std.fmt.parseFloat(f64, x_str) catch 0.0;
            const y = std.fmt.parseFloat(f64, y_str) catch 0.0;
            const z = std.fmt.parseFloat(f64, z_str) catch 0.0;
            const w = std.fmt.parseFloat(f64, w_str) catch 1.0;
            const r = std.fmt.parseFloat(f64, r_str) catch 1.0;

            var obj_type: ObjectType = .cube;
            if (std.mem.eql(u8, type_str, "sphere")) obj_type = .sphere;
            if (std.mem.eql(u8, type_str, "npc")) obj_type = .npc;
            if (std.mem.eql(u8, type_str, "player")) obj_type = .player;
            if (std.mem.eql(u8, type_str, "point")) obj_type = .point;

            if (world.spawn(obj_type, name_str, x, y, z, w, r)) |spawned| {
                try stdout.print("[OK] Spawned id={d} ({s}) at [{d}:{d}:{d}:{d}]\n", .{
                    spawned.id,
                    spawned.getName(),
                    spawned.pos.x,
                    spawned.pos.y,
                    spawned.pos.z,
                    spawned.pos.w,
                });
            } else {
                try stdout.print("ERR: World entity pool full\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "move")) {
            const id_str = tokens.next() orelse {
                try stdout.print("ERR: missing id\n", .{});
                continue;
            };
            const id = std.fmt.parseInt(u32, id_str, 10) catch {
                try stdout.print("ERR: invalid id\n", .{});
                continue;
            };
            const dx = if (tokens.next()) |s| std.fmt.parseFloat(f64, s) catch 0.0 else 0.0;
            const dy = if (tokens.next()) |s| std.fmt.parseFloat(f64, s) catch 0.0 else 0.0;
            const dz = if (tokens.next()) |s| std.fmt.parseFloat(f64, s) catch 0.0 else 0.0;
            const dw = if (tokens.next()) |s| std.fmt.parseFloat(f64, s) catch 0.0 else 0.0;

            if (world.findById(id)) |ent| {
                ent.pos.x += dx;
                ent.pos.y += dy;
                ent.pos.z += dz;
                ent.pos.w += dw;
                const c = ent.pos.cartesian3();
                try stdout.print("[OK] Moved id={d}: new pos=[{d:.2}:{d:.2}:{d:.2}:{d:.2}], R3=({d:.2},{d:.2},{d:.2})\n", .{
                    ent.id,
                    ent.pos.x,
                    ent.pos.y,
                    ent.pos.z,
                    ent.pos.w,
                    c[0],
                    c[1],
                    c[2],
                });
            } else {
                try stdout.print("ERR: Entity {d} not found\n", .{id});
            }
        } else if (std.mem.eql(u8, cmd, "scale_w")) {
            const id_str = tokens.next() orelse {
                try stdout.print("ERR: missing id\n", .{});
                continue;
            };
            const id = std.fmt.parseInt(u32, id_str, 10) catch {
                try stdout.print("ERR: invalid id\n", .{});
                continue;
            };
            const w_val = if (tokens.next()) |s| std.fmt.parseFloat(f64, s) catch 1.0 else 1.0;

            if (world.findById(id)) |ent| {
                ent.pos.w = w_val;
                const c = ent.pos.cartesian3();
                try stdout.print("[OK] Entity {d} W set to {d:.2} (R3 pos: {d:.2}, {d:.2}, {d:.2})\n", .{
                    ent.id,
                    ent.pos.w,
                    c[0],
                    c[1],
                    c[2],
                });
            } else {
                try stdout.print("ERR: Entity {d} not found\n", .{id});
            }
        } else if (std.mem.eql(u8, cmd, "dist")) {
            const id1_str = tokens.next() orelse continue;
            const id2_str = tokens.next() orelse continue;
            const id1 = std.fmt.parseInt(u32, id1_str, 10) catch continue;
            const id2 = std.fmt.parseInt(u32, id2_str, 10) catch continue;

            const e1 = world.findById(id1);
            const e2 = world.findById(id2);

            if (e1 != null and e2 != null) {
                const c1 = e1.?.pos.cartesian3();
                const c2 = e2.?.pos.cartesian3();
                const dx = c1[0] - c2[0];
                const dy = c1[1] - c2[1];
                const dz = c1[2] - c2[2];
                const euclid_dist = @sqrt(dx * dx + dy * dy + dz * dz);

                // Fubini-Study / Projective inner product metric
                const dot_val = HomVec4.dot(e1.?.pos.normalize(), e2.?.pos.normalize());
                const clamped_dot = std.math.clamp(@abs(dot_val), 0.0, 1.0);
                const fubini_dist = std.math.acos(clamped_dot);

                try stdout.print("[METRICS] Between {s} and {s}:\n", .{ e1.?.getName(), e2.?.getName() });
                try stdout.print("  - Euclidean R3 Distance:      {d:.4}\n", .{euclid_dist});
                try stdout.print("  - Projective P3 (Fubini-Study): {d:.4} rad\n", .{fubini_dist});
                try stdout.print("  - Inner Product <P1, P2>:     {d:.4}\n", .{dot_val});
            } else {
                try stdout.print("ERR: One or both entities not found\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "intersect")) {
            const id1_str = tokens.next() orelse continue;
            const id2_str = tokens.next() orelse continue;
            const id1 = std.fmt.parseInt(u32, id1_str, 10) catch continue;
            const id2 = std.fmt.parseInt(u32, id2_str, 10) catch continue;

            const e1 = world.findById(id1);
            const e2 = world.findById(id2);

            if (e1 != null and e2 != null) {
                const c1 = e1.?.pos.cartesian3();
                const c2 = e2.?.pos.cartesian3();
                const dx = c1[0] - c2[0];
                const dy = c1[1] - c2[1];
                const dz = c1[2] - c2[2];
                const dist = @sqrt(dx * dx + dy * dy + dz * dz);
                const sum_radii = e1.?.radius + e2.?.radius;

                if (dist <= sum_radii) {
                    try stdout.print("[COLLISION HIT!] {s} (id={d}) intersects with {s} (id={d})! dist={d:.2} <= {d:.2}\n", .{
                        e1.?.getName(),
                        e1.?.id,
                        e2.?.getName(),
                        e2.?.id,
                        dist,
                        sum_radii,
                    });
                } else {
                    try stdout.print("[NO COLLISION] {s} and {s} clear. dist={d:.2} > {d:.2}\n", .{
                        e1.?.getName(),
                        e2.?.getName(),
                        dist,
                        sum_radii,
                    });
                }
            } else {
                try stdout.print("ERR: Entity not found\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "ascii")) {
            try stdout.print("2D Top-Down View (X: -10..10, Y: -10..10):\n", .{});
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

            for (world.entities[0..world.count]) |*ent| {
                if (!ent.active) continue;
                const c = ent.pos.cartesian3();
                const gx_f = (c[0] + 10.0) * 2.0;
                const gy_f = 10.0 - c[1];
                const gx: isize = @intFromFloat(@round(gx_f));
                const gy: isize = @intFromFloat(@round(gy_f));

                if (gx >= 0 and gx < 41 and gy >= 0 and gy < 21) {
                    const ch: u8 = switch (ent.obj_type) {
                        .player => '@',
                        .npc => 'G',
                        .sphere => 'O',
                        .cube => '#',
                        .point => '*',
                    };
                    grid[@intCast(gy)][@intCast(gx)] = ch;
                }
            }

            for (0..21) |r| {
                try stdout.print("{s}\n", .{grid[r][0..41]});
            }
            try stdout.print("Legend: @=Player, G=NPC, #=Cube, O=Sphere, +=Origin(0,0)\n", .{});
        } else {
            try stdout.print("Unknown command: '{s}'. Type 'help' for available commands.\n", .{cmd});
        }
    }
}
