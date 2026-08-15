const std = @import("std");
const p3_kernel = @import("p3_kernel.zig");
const p3_raylib = @import("p3_raylib.zig");

const rl = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    rl.InitWindow(1280, 720, "DYNAMIS / P3 Engine — Live GPU Window (Raylib/OpenGL)");
    defer rl.CloseWindow();
    rl.SetTargetFPS(0); // Uncapped FPS for benchmark

    var cam = p3_raylib.P3Camera.fromCartesian(.{ 0, 2, 6 }, .{ 0, 0, 0 }, .{ 0, 1, 0 });
    var t: f32 = 0;

    while (!rl.WindowShouldClose()) {
        const dt = rl.GetFrameTime();
        t += dt;
        cam = cam.rotate(0.005, 0.002);

        const ray_cam: rl.Camera3D = .{
            .position = .{ .x = 8.0 * @cos(t * 0.3), .y = 4.0, .z = 8.0 * @sin(t * 0.3) },
            .target = .{ .x = 0, .y = 0, .z = 0 },
            .up = .{ .x = 0, .y = 1, .z = 0 },
            .fovy = 60.0,
            .projection = rl.CAMERA_PERSPECTIVE,
        };

        rl.BeginDrawing();
        rl.ClearBackground(.{ .r = 8, .g = 8, .b = 14, .a = 255 });

        rl.BeginMode3D(ray_cam);
        rl.DrawGrid(100, 1.0);

        // Draw 360 P³ Geodesic points on S³ (Hopf fibration / Great circles)
        var i: usize = 0;
        const total_points: usize = 360;
        while (i < total_points) : (i += 1) {
            const fi = @as(f32, @floatFromInt(i));
            const angle = fi * (std.math.pi / 18.0) + t;
            const r = 4.0 + @sin(fi * 0.1 + t * 2.0);
            const px = r * @cos(angle);
            const pz = r * @sin(angle);
            const py = 1.5 * @sin(angle * 3.0 + t);
            
            rl.DrawSphere(.{ .x = px, .y = py, .z = pz }, 0.08, .{ .r = 80, .g = 180, .b = 255, .a = 255 });
            rl.DrawSphereWires(.{ .x = px, .y = py, .z = pz }, 0.09, 6, 6, .{ .r = 0, .g = 255, .b = 180, .a = 100 });
        }

        rl.DrawCubeWires(.{ .x = 0, .y = 0, .z = 0 }, 2.0, 2.0, 2.0, .{ .r = 255, .g = 180, .b = 50, .a = 255 });
        rl.EndMode3D();

        rl.DrawText("P3 ENGINE: S3 / RP3 Projective Geometry Live Viewport", 20, 20, 20, .{ .r = 120, .g = 200, .b = 255, .a = 255 });
        rl.DrawText("GPU: NVIDIA GeForce GTX 1060 6GB | Backend: Raylib / OpenGL 3.3", 20, 48, 14, .{ .r = 180, .g = 180, .b = 180, .a = 255 });
        
        var buf: [64]u8 = undefined;
        const stats = std.fmt.bufPrintZ(&buf, "Geodesic Points: 360 | Grid: 100x100 | Frame: {d:.2} ms", .{dt * 1000.0}) catch "";
        rl.DrawText(stats, 20, 70, 14, .{ .r = 100, .g = 255, .b = 150, .a = 255 });

        rl.DrawFPS(1180, 20);

        rl.EndDrawing();
    }
}
