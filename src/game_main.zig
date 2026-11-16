//! =============================================================================
//! P³ SUPERCAR RACING GAME — FIXED ORIENTATION & ROAD ALIGNMENT
//! =============================================================================

const std = @import("std");
const math = std.math;

// Import Raylib via C ABI
const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const p3_kernel = @import("p3_kernel.zig");
const p3_vehicle = @import("p3_vehicle.zig");
const p3_road = @import("p3_road.zig");

pub fn main() !void {
    const screen_width = 1280;
    const screen_height = 720;

    rl.SetConfigFlags(rl.FLAG_MSAA_4X_HINT | rl.FLAG_VSYNC_HINT);
    rl.InitWindow(screen_width, screen_height, "P3 Engine — Cyber Supercar Racing");
    defer rl.CloseWindow();

    rl.SetTargetFPS(60);

    // 1. Load User's Custom 3D Car Model
    var car_model = rl.LoadModel("car_custom.obj");
    defer rl.UnloadModel(car_model);

    // 2. Generate Racing Track (Oval with radius=35m, straights=70m)
    var track = p3_road.Track{};
    track.generateOval(35.0, 70.0);

    // 3. Initialize P3 Vehicle directly in the middle of Straight 1 (X=35, Y=20)
    var veh = p3_vehicle.Vehicle.init();
    veh.pos = p3_kernel.HomVec4.init(35.0, 20.0, 0.0, 1.0);
    veh.yaw = 0.0; // Heading forward along +Y

    // 4. Setup 3D Chase Camera
    var camera = rl.Camera3D{
        .position = .{ .x = 35.0, .y = 12.0, .z = 4.0 },
        .target = .{ .x = 35.0, .y = 20.0, .z = 0.6 },
        .up = .{ .x = 0.0, .y = 0.0, .z = 1.0 },
        .fovy = 55.0,
        .projection = rl.CAMERA_PERSPECTIVE,
    };

    // 5. Main Game Loop
    while (!rl.WindowShouldClose()) {
        const dt = rl.GetFrameTime();

        // --- INPUT CONTROLS ---
        veh.throttle = 0.0;
        veh.brake = 0.0;
        veh.steering = 0.0;

        if (rl.IsKeyDown(rl.KEY_W) or rl.IsKeyDown(rl.KEY_UP)) {
            veh.throttle = 1.0;
        }
        if (rl.IsKeyDown(rl.KEY_S) or rl.IsKeyDown(rl.KEY_DOWN)) {
            veh.brake = 1.0;
        }
        if (rl.IsKeyDown(rl.KEY_A) or rl.IsKeyDown(rl.KEY_LEFT)) {
            veh.steering = -1.0;
        }
        if (rl.IsKeyDown(rl.KEY_D) or rl.IsKeyDown(rl.KEY_RIGHT)) {
            veh.steering = 1.0;
        }
        if (rl.IsKeyPressed(rl.KEY_R)) {
            veh.pos = p3_kernel.HomVec4.init(35.0, 20.0, 0.0, 1.0);
            veh.velocity = .{ 0, 0, 0 };
            veh.yaw = 0.0;
        }

        // --- UPDATE P3 PHYSICS ---
        veh.update(dt);

        // --- SMOOTH CHASE CAMERA (Z-Up Coordinate System) ---
        const car_x: f32 = @floatCast(veh.pos.x);
        const car_y: f32 = @floatCast(veh.pos.y);
        const car_z: f32 = @floatCast(veh.pos.z);
        const yaw_f: f32 = @floatCast(veh.yaw);

        const cam_dist: f32 = 8.0;
        const cam_height: f32 = 3.2;
        const target_cam_x = car_x - @sin(yaw_f) * cam_dist;
        const target_cam_y = car_y - @cos(yaw_f) * cam_dist;
        const target_cam_z = car_z + cam_height;

        camera.position.x += (target_cam_x - camera.position.x) * 6.0 * dt;
        camera.position.y += (target_cam_y - camera.position.y) * 6.0 * dt;
        camera.position.z += (target_cam_z - camera.position.z) * 6.0 * dt;
        camera.target = .{ .x = car_x, .y = car_y, .z = car_z + 0.6 };

        // --- RENDER 3D SCENE ---
        rl.BeginDrawing();
        rl.ClearBackground(.{ .r = 14, .g = 18, .b = 26, .a = 255 });

        rl.BeginMode3D(camera);

        // Ground Grid
        rl.DrawGrid(100, 2.0);

        // 3D Racing Track Surface & Curbs
        for (0..track.count) |i| {
            const next_i = (i + 1) % track.count;
            const p1 = track.points[i];
            const p2 = track.points[next_i];

            const half_w1: f32 = @floatCast(p1.width * 0.5);
            const half_w2: f32 = @floatCast(p2.width * 0.5);

            // Left & Right road vertices
            const v1_l = rl.Vector3{ .x = @floatCast(p1.pos.x - p1.tangent[1] * half_w1), .y = @floatCast(p1.pos.y + p1.tangent[0] * half_w1), .z = 0.05 };
            const v1_r = rl.Vector3{ .x = @floatCast(p1.pos.x + p1.tangent[1] * half_w1), .y = @floatCast(p1.pos.y - p1.tangent[0] * half_w1), .z = 0.05 };
            const v2_l = rl.Vector3{ .x = @floatCast(p2.pos.x - p2.tangent[1] * half_w2), .y = @floatCast(p2.pos.y + p2.tangent[0] * half_w2), .z = 0.05 };
            const v2_r = rl.Vector3{ .x = @floatCast(p2.pos.x + p2.tangent[1] * half_w2), .y = @floatCast(p2.pos.y - p2.tangent[0] * half_w2), .z = 0.05 };

            // Road asphalt
            rl.DrawTriangle3D(v1_l, v2_l, v1_r, .{ .r = 40, .g = 44, .b = 52, .a = 255 });
            rl.DrawTriangle3D(v2_l, v2_r, v1_r, .{ .r = 40, .g = 44, .b = 52, .a = 255 });

            // Glowing Curbs
            const curb_color = if (i % 2 == 0) rl.Color{ .r = 0, .g = 220, .b = 255, .a = 255 } else rl.Color{ .r = 255, .g = 30, .b = 90, .a = 255 };
            rl.DrawLine3D(v1_l, v2_l, curb_color);
            rl.DrawLine3D(v1_r, v2_r, curb_color);
        }

        // Draw User Custom Car (Corrected: Rotated 90 deg around X to fix Blender vertical orientation, then Yaw)
        const rot_x = rl.MatrixRotateX(90.0 * (std.math.pi / 180.0));
        const rot_z = rl.MatrixRotateZ(-yaw_f);
        const transform_mat = rl.MatrixMultiply(rot_x, rot_z);

        car_model.transform = transform_mat;
        rl.DrawModel(
            car_model,
            .{ .x = car_x, .y = car_y, .z = car_z + 0.35 },
            1.0,
            .{ .r = 240, .g = 245, .b = 255, .a = 255 },
        );

        rl.EndMode3D();

        // --- 2D DASHBOARD & TELEMETRY ---
        rl.DrawRectangle(20, 20, 340, 165, .{ .r = 10, .g = 12, .b = 18, .a = 225 });
        rl.DrawRectangleLines(20, 20, 340, 165, .{ .r = 0, .g = 200, .b = 255, .a = 255 });

        rl.DrawText("P3 ENGINE — CYBER RACING", 35, 32, 16, .{ .r = 0, .g = 220, .b = 255, .a = 255 });

        var speed_buf: [64]u8 = undefined;
        const speed_str = std.fmt.bufPrintZ(&speed_buf, "SPEED: {d:.0} KM/H", .{veh.speedKmh()}) catch "SPEED: 0";
        rl.DrawText(speed_str, 35, 58, 26, .{ .r = 255, .g = 255, .b = 255, .a = 255 });

        var rpm_buf: [64]u8 = undefined;
        const rpm_str = std.fmt.bufPrintZ(&rpm_buf, "RPM:   {d:.0} / 7500", .{veh.engine.rpm}) catch "RPM: 0";
        rl.DrawText(rpm_str, 35, 90, 18, .{ .r = 255, .g = 180, .b = 0, .a = 255 });

        // Tachometer Bar
        const rpm_frac: f32 = @floatCast(veh.engine.rpm / 7500.0);
        rl.DrawRectangle(35, 116, 300, 12, .{ .r = 40, .g = 45, .b = 55, .a = 255 });
        rl.DrawRectangle(35, 116, @intFromFloat(300.0 * rpm_frac), 12, .{ .r = 255, .g = 50, .b = 50, .a = 255 });

        rl.DrawText("CONTROLS: [W/S] Throttle/Brake | [A/D] Steer | [R] Reset", 35, 140, 10, .{ .r = 180, .g = 190, .b = 200, .a = 255 });

        rl.EndDrawing();
    }
}
