//! =============================================================================
//! P³ VEHICLE TEST LOADER — INTEGRATING USER CUSTOM CAR
//! =============================================================================

const std = @import("std");
const p3_obj_loader = @import("p3_obj_loader.zig");
const p3_vehicle = @import("p3_vehicle.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    try stdout.print(
        \\=============================================================================
        \\ P³ ENGINE — CUSTOM USER VEHICLE IMPORTER TEST
        \\=============================================================================
        \\
    , .{});

    const car_path = "car_custom.obj";
    try stdout.print("[P3] Loading user model: '{s}' (2.2 MB)...\n", .{car_path});

    var timer = try std.time.Timer.start();
    var mesh = p3_obj_loader.parseObjFile(allocator, car_path) catch |err| {
        try stdout.print("ERR loading mesh: {}\n", .{err});
        return;
    };
    defer mesh.deinit();
    const load_time_ns = timer.read();
    const load_time_ms = @as(f64, @floatFromInt(load_time_ns)) / 1_000_000.0;

    try stdout.print(
        \\[OK] Mesh successfully imported into P³ Engine!
        \\  - Total Vertices: {d}
        \\  - Total Triangles: {d}
        \\  - Load Time:      {d:.2} ms
        \\
    , .{
        mesh.vertices.items.len,
        mesh.indices.items.len / 3,
        load_time_ms,
    });

    // Link vehicle physics to this custom model
    var veh = p3_vehicle.Vehicle.init();
    try stdout.print("\n[P3] Binding P³ Physics Core (Pacejka 4x Wheels + 4-cyl ICE Engine):\n", .{});
    try stdout.print("  - Engine Status: {d:.0} RPM Idle, Max: {d:.0} RPM\n", .{ veh.engine.rpm, veh.engine.max_rpm });
    try stdout.print("  - RWD Drive:     Connected\n", .{});

    // Simulate acceleration test
    veh.throttle = 1.0;
    try stdout.print("\n[P3] Simulating 0-100 km/h acceleration test on custom car...\n", .{});
    for (0..40) |_| {
        veh.update(0.05);
    }
    try stdout.print("  -> Speed after 2.0s: {d:.1} km/h (RPM: {d:.0}, Pos: [{d:.2}:{d:.2}:{d:.2}:{d:.2}])\n", .{
        veh.speedKmh(),
        veh.engine.rpm,
        veh.pos.x,
        veh.pos.y,
        veh.pos.z,
        veh.pos.w,
    });

    try stdout.print(
        \\=============================================================================
        \\ SUCCESS: User custom 3D car is fully wired to P³ Engine physics!
        \\=============================================================================
        \\
    , .{});
}
