//! =============================================================================
//! P³ VEHICLE & ROAD 3D OBJ EXPORTER FOR BLENDER
//! =============================================================================

const std = @import("std");
const math = std.math;
const p3_road = @import("p3_road.zig");
const p3_supercar = @import("p3_supercar.zig");

pub fn exportCarObj(file_path: []const u8) !void {
    return p3_supercar.exportSupercarObj(file_path);
}

pub fn exportRoadObj(file_path: []const u8) !void {
    const file = try std.fs.cwd().createFile(file_path, .{ .truncate = true });
    defer file.close();
    const writer = file.writer();

    try writer.writeAll("# P3 Engine - Generated 3D Racing Track for Blender\n");
    try writer.writeAll("o RacingTrack\n\n");

    var track = p3_road.Track{};
    track.generateOval(35.0, 70.0);

    for (track.points[0..track.count]) |pt| {
        // Left edge & Right edge
        const half_w = pt.width * 0.5;
        const normal_x = -pt.tangent[1];
        const normal_y = pt.tangent[0];

        const lx = pt.pos.x + normal_x * half_w;
        const ly = pt.pos.y + normal_y * half_w;
        const lz = pt.pos.z + @sin(pt.banking_rad) * half_w;

        const rx = pt.pos.x - normal_x * half_w;
        const ry = pt.pos.y - normal_y * half_w;
        const rz = pt.pos.z - @sin(pt.banking_rad) * half_w;

        try writer.print("v {d:.4} {d:.4} {d:.4}\n", .{ lx, ly, lz });
        try writer.print("v {d:.4} {d:.4} {d:.4}\n", .{ rx, ry, rz });
    }

    for (0..track.count) |i| {
        const next_i = (i + 1) % track.count;
        const v0 = (i * 2) + 1;
        const v1 = v0 + 1;
        const v2 = (next_i * 2) + 2;
        const v3 = (next_i * 2) + 1;
        try writer.print("f {d} {d} {d} {d}\n", .{ v0, v1, v2, v3 });
    }
}
