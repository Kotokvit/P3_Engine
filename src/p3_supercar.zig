//! =============================================================================
//! P³ CYBERPUNK / SUPERCAR DETAILED 3D MESH GENERATOR
//! =============================================================================

const std = @import("std");
const math = std.math;

pub fn exportSupercarObj(file_path: []const u8) !void {
    const file = try std.fs.cwd().createFile(file_path, .{ .truncate = true });
    defer file.close();
    const writer = file.writer();

    try writer.writeAll("# P3 Engine - High-Detail Sports Racecar\n");
    try writer.writeAll("o SportsCar\n\n");

    var vert_offset: usize = 1;

    // 1. Sleek Aerodynamic Bodywork (Hood, Fenders, Side-Skirts, Diffuser, Roof, Spoiler)
    try writer.writeAll("# Main_Bodywork\n");
    const body_verts = [20][3]f64{
        // Nose Splitter (Ground level)
        .{ -0.85, 2.4, 0.12 }, // 1 Front-Left splitter
        .{ 0.85, 2.4, 0.12 }, // 2 Front-Right splitter
        .{ 0.95, 1.4, 0.18 }, // 3 Mid-front arch right
        .{ -0.95, 1.4, 0.18 }, // 4 Mid-front arch left
        .{ -0.95, -1.5, 0.18 }, // 5 Mid-rear arch left
        .{ 0.95, -1.5, 0.18 }, // 6 Mid-rear arch right
        .{ 0.90, -2.4, 0.20 }, // 7 Rear-Right diffuser
        .{ -0.90, -2.4, 0.20 }, // 8 Rear-Left diffuser

        // Hood / Waistline / Shoulder
        .{ -0.75, 2.2, 0.55 }, // 9 Hood tip left
        .{ 0.75, 2.2, 0.55 }, // 10 Hood tip right
        .{ 0.80, 0.6, 0.70 }, // 11 Windshield base right
        .{ -0.80, 0.6, 0.70 }, // 12 Windshield base left
        .{ -0.85, -1.4, 0.78 }, // 13 Rear shoulder left
        .{ 0.85, -1.4, 0.78 }, // 14 Rear shoulder right
        .{ 0.80, -2.3, 0.72 }, // 15 Trunk lip right
        .{ -0.80, -2.3, 0.72 }, // 16 Trunk lip left

        // Low-Profile Aerodynamic Canopy Roof
        .{ -0.55, 0.4, 1.05 }, // 17 A-pillar top left
        .{ 0.55, 0.4, 1.05 }, // 18 A-pillar top right
        .{ 0.50, -0.9, 1.00 }, // 19 C-pillar top right
        .{ -0.50, -0.9, 1.00 }, // 20 C-pillar top left
    };

    for (body_verts) |v| {
        try writer.print("v {d:.4} {d:.4} {d:.4}\n", .{ v[0], v[1], v[2] });
    }

    // Connect panels
    const body_faces = [15][4]usize{
        .{ 1, 2, 10, 9 }, // Front bumper nose
        .{ 9, 10, 11, 12 }, // Sloped Hood
        .{ 1, 9, 12, 4 }, // Left front fender
        .{ 2, 3, 11, 10 }, // Right front fender
        .{ 4, 12, 13, 5 }, // Left door panel
        .{ 3, 6, 14, 11 }, // Right door panel
        .{ 5, 13, 16, 8 }, // Left rear fender
        .{ 6, 7, 15, 14 }, // Right rear fender
        .{ 7, 8, 16, 15 }, // Rear bumper / Exhaust area
        .{ 13, 14, 15, 16 }, // Rear engine deck lid

        // Cockpit Glass & Roof
        .{ 12, 11, 18, 17 }, // Raked Windshield
        .{ 17, 18, 19, 20 }, // Carbon Roof
        .{ 20, 19, 14, 13 }, // Rear Fastback Glass
        .{ 12, 17, 20, 13 }, // Left Side Window
        .{ 11, 14, 19, 18 }, // Right Side Window
    };
    for (body_faces) |f| {
        try writer.print("f {d} {d} {d} {d}\n", .{ f[0], f[1], f[2], f[3] });
    }
    vert_offset += 20;

    // 2. GT-Style Rear Wing / Spoiler
    try writer.writeAll("\n# GT_Spoiler\n");
    const s_start = vert_offset;
    const spoiler_verts = [8][3]f64{
        // Stanchions (mounts)
        .{ -0.45, -2.1, 0.75 },
        .{ -0.40, -2.1, 0.75 },
        .{ 0.40, -2.1, 0.75 },
        .{ 0.45, -2.1, 0.75 },
        // Wing Blade
        .{ -0.88, -2.2, 1.15 },
        .{ 0.88, -2.2, 1.15 },
        .{ 0.88, -2.4, 1.20 },
        .{ -0.88, -2.4, 1.20 },
    };
    for (spoiler_verts) |v| {
        try writer.print("v {d:.4} {d:.4} {d:.4}\n", .{ v[0], v[1], v[2] });
    }
    try writer.print("f {d} {d} {d} {d}\n", .{ s_start + 4, s_start + 5, s_start + 6, s_start + 7 }); // Wing airfoil blade
    try writer.print("f {d} {d} {d} {d}\n", .{ s_start + 0, s_start + 1, s_start + 6, s_start + 4 }); // Left mount
    try writer.print("f {d} {d} {d} {d}\n", .{ s_start + 2, s_start + 3, s_start + 7, s_start + 5 }); // Right mount
    vert_offset += 8;

    // 3. Four Detailed Wheels with Rim Inset and Hubcaps
    const wheel_positions = [4][3]f64{
        .{ -0.92, 1.45, 0.33 }, // FL
        .{ 0.92, 1.45, 0.33 }, // FR
        .{ -0.95, -1.45, 0.35 }, // RL (Wider stance)
        .{ 0.95, -1.45, 0.35 }, // RR
    };

    for (wheel_positions, 0..) |wp, w_idx| {
        try writer.print("\n# SportWheel_{d}\n", .{w_idx + 1});
        const w_start = vert_offset;
        const segments = 16;
        const radius: f64 = if (w_idx >= 2) 0.36 else 0.33; // Staggered rear wheels
        const width = 0.28;
        const sign: f64 = if (wp[0] < 0) -1.0 else 1.0;

        for (0..segments) |seg| {
            const angle = (@as(f64, @floatFromInt(seg)) / @as(f64, @floatFromInt(segments))) * 2.0 * math.pi;
            const y = @sin(angle) * radius;
            const z = @cos(angle) * radius;

            // Outer tire tread
            try writer.print("v {d:.4} {d:.4} {d:.4}\n", .{ wp[0], wp[1] + y, wp[2] + z });
            try writer.print("v {d:.4} {d:.4} {d:.4}\n", .{ wp[0] + (sign * width), wp[1] + y, wp[2] + z });
            // Rim Inset hub
            try writer.print("v {d:.4} {d:.4} {d:.4}\n", .{ wp[0] + (sign * (width * 0.4)), wp[1] + (y * 0.65), wp[2] + (z * 0.65) });
        }

        for (0..segments) |seg| {
            const next_seg = (seg + 1) % segments;
            const v0 = w_start + (seg * 3);
            const v1 = v0 + 1;
            const v2 = w_start + (next_seg * 3) + 1;
            const v3 = w_start + (next_seg * 3);
            const rim0 = v0 + 2;
            const rim1 = w_start + (next_seg * 3) + 2;

            // Tire tread face
            try writer.print("f {d} {d} {d} {d}\n", .{ v0, v1, v2, v3 });
            // Deep dish rim spoke face
            try writer.print("f {d} {d} {d} {d}\n", .{ v1, rim0, rim1, v2 });
        }
        vert_offset += segments * 3;
    }
}
