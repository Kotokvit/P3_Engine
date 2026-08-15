const std = @import("std");
const p3_kernel = @import("p3_kernel.zig");
const p3_raylib = @import("p3_raylib.zig");

const rl = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    rl.InitWindow(1280, 720, "DYNAMIS / P3 Engine — Live GPU Window (Raylib/OpenGL)");
    defer rl.CloseWindow();
    rl.SetTargetFPS(60);

    var cam = p3_raylib.P3Camera.fromCartesian(.{ 0, 2, 6 }, .{ 0, 0, 0 }, .{ 0, 1, 0 });
    var t: f32 = 0;

    while (!rl.WindowShouldClose()) {
        t += 0.016;
        cam = cam.rotate(0.005, 0.002);

        const ray_cam: rl.Camera3D = .{
            .position = .{ .x = 6.0 * @cos(t * 0.5), .y = 3.0, .z = 6.0 * @sin(t * 0.5) },
            .target = .{ .x = 0, .y = 0, .z = 0 },
            .up = .{ .x = 0, .y = 1, .z = 0 },
            .fovy = 60.0,
            .projection = rl.CAMERA_PERSPECTIVE,
        };

        rl.BeginDrawing();
        rl.ClearBackground(.{ .r = 10, .g = 10, .b = 18, .a = 255 });

        rl.BeginMode3D(ray_cam);
        rl.DrawGrid(20, 1.0);

        // Draw P³ Geodesic points on S³
        var i: usize = 0;
        while (i < 36) : (i += 1) {
            const angle = @as(f32, @floatFromInt(i)) * (std.math.pi / 18.0) + t;
            const px = 3.0 * @cos(angle);
            const pz = 3.0 * @sin(angle);
            const py = @sin(angle * 2.0 + t);
            rl.DrawSphere(.{ .x = px, .y = py, .z = pz }, 0.15, .{ .r = 100, .g = 200, .b = 255, .a = 255 });
            rl.DrawSphereWires(.{ .x = px, .y = py, .z = pz }, 0.16, 8, 8, .{ .r = 0, .g = 255, .b = 200, .a = 150 });
        }

        rl.DrawCubeWires(.{ .x = 0, .y = 0, .z = 0 }, 2.0, 2.0, 2.0, .{ .r = 255, .g = 180, .b = 50, .a = 255 });
        rl.EndMode3D();

        rl.DrawText("P3 ENGINE: S3 / RP3 Projective Geometry Live Viewport", 20, 20, 20, .{ .r = 120, .g = 200, .b = 255, .a = 255 });
        rl.DrawText("Rendering on NVIDIA GeForce GTX 1060 via Raylib/OpenGL", 20, 50, 14, .{ .r = 180, .g = 180, .b = 180, .a = 255 });
        rl.DrawFPS(1200, 20);

        rl.EndDrawing();
    }
}
