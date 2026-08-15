// =============================================================================
// P³ ENGINE — GPU-OPTIMIZED LIVE VIEWPORT (Instanced Rendering)
// =============================================================================
//
// ПРОБЛЕМА: оригинальный демо делал 720 draw calls/кадр:
//   360 × DrawSphere + 360 × DrawSphereWires
// Каждый DrawSphere генерировал геометрию на CPU → загрузка на GPU → отрисовка.
// Результат: CPU 42%, GPU 26% — GPU почти не работает.
//
// РЕШЕНИЕ: Instanced Rendering (Raylib 4.5+)
//   1. Создаём mesh сферы ОДИН раз (GPU-resident VAO/VBO)
//   2. Каждый кадр: вычисляем 360 Matrix трансформаций (batch)
//   3. DrawMeshInstanced — ОДИН draw call для ВСЕХ 360 сфер
//   4. GPU делает ВСЮ растеризацию через instancing
//
// Результат: 720 draw calls → 2 draw calls
//   GPU берёт на себя instancing, CPU только вычисляет позиции.
//
// Требования: Raylib 4.5+ (DrawMeshInstanced)
//   Raylib 5.0+: MATERIAL_MAP_ALBEDO (вместо MATERIAL_MAP_DIFFUSE)
//   Raylib 6.0+: полная поддержка
//
// Принцип: убивать и жрать и рождать новое.
// =============================================================================

const std = @import("std");
const p3_kernel = @import("p3_kernel.zig");
const p3_raylib = @import("p3_raylib.zig");

const rl = @cImport({
    @cInclude("raylib.h");
});

// =============================================================================
// КОНФИГУРАЦИЯ ДЕМО
// =============================================================================
const TOTAL_POINTS: c_int = 360;
const TOTAL_POINTS_USIZE: usize = 360;
const SPHERE_RADIUS: f32 = 0.08;
const SPHERE_RINGS: c_int = 8;
const SPHERE_SLICES: c_int = 8;
const WIRE_RADIUS: f32 = 0.09;
const WIRE_RINGS: c_int = 6;
const WIRE_SLICES: c_int = 6;

// Material map index: 0 = ALBEDO (Raylib 5.0+) / DIFFUSE (older)
// Оба имени указывают на один и тот же индекс.
const MAP_COLOR: c_int = 0;

// =============================================================================
// HELPERS: Raymath functions not in @cImport (raymath.h vs raylib.h)
// =============================================================================

/// Translation matrix: T(x, y, z)
/// Raylib Matrix layout (row-major):
///   m0  m4  m8  m12     1  0  0  tx
///   m1  m5  m9  m13  =  0  1  0  ty
///   m2  m6  m10 m14     0  0  1  tz
///   m3  m7  m11 m15     0  0  0  1
fn matrixTranslate(x: f32, y: f32, z: f32) rl.Matrix {
    return .{
        .m0 = 1,
        .m4 = 0,
        .m8 = 0,
        .m12 = x,
        .m1 = 0,
        .m5 = 1,
        .m9 = 0,
        .m13 = y,
        .m2 = 0,
        .m6 = 0,
        .m10 = 1,
        .m14 = z,
        .m3 = 0,
        .m7 = 0,
        .m11 = 0,
        .m15 = 1,
    };
}

pub fn main() !void {
    rl.InitWindow(1280, 720, "DYNAMIS / P3 Engine — Live GPU Window (Raylib/OpenGL)");
    rl.SetTargetFPS(0); // Uncapped FPS for benchmark
    rl.SetWindowState(rl.FLAG_WINDOW_RESIZABLE);

    // ========================================================================
    // GPU RESIDENT MESHES — создаются ОДИН раз, живут в VRAM
    // ========================================================================
    //
    // GenMeshSphere: генерирует вершины на CPU (один раз)
    // UploadMesh:    загружает VAO/VBO на GPU (один раз)
    // DrawMeshInstanced: использует GPU VAO, рисует N экземпляров
    //
    // В отличие от DrawSphere(), который КАЖДЫЙ вызов:
    //   1. Генерирует вершины сферы (CPU)
    //   2. Загружает на GPU (GPU upload)
    //   3. Рисует (GPU rasterize)
    //   4. Удаляет (GPU cleanup)
    //
    // Instanced: шаги 1-2 делаются ОДИН раз, шаг 3 делает GPU N раз.

    var solid_mesh = rl.GenMeshSphere(SPHERE_RADIUS, SPHERE_RINGS, SPHERE_SLICES);
    rl.UploadMesh(&solid_mesh, false); // false = static upload (not dynamic)

    var wire_mesh = rl.GenMeshSphere(WIRE_RADIUS, WIRE_RINGS, WIRE_SLICES);
    rl.UploadMesh(&wire_mesh, false);

    // --- Materials ---
    var solid_mat = rl.LoadMaterialDefault();
    solid_mat.maps[MAP_COLOR].color = .{ .r = 80, .g = 180, .b = 255, .a = 255 };

    var wire_mat = rl.LoadMaterialDefault();
    wire_mat.maps[MAP_COLOR].color = .{ .r = 0, .g = 255, .b = 180, .a = 100 };

    // --- Transform arrays (pre-allocated, stack) ---
    var solid_transforms: [TOTAL_POINTS_USIZE]rl.Matrix = undefined;
    var wire_transforms: [TOTAL_POINTS_USIZE]rl.Matrix = undefined;

    // --- P³ Camera ---
    var cam = p3_raylib.P3Camera.fromCartesian(.{ 0, 2, 6 }, .{ 0, 0, 0 }, .{ 0, 1, 0 });
    var t: f32 = 0;

    // --- Stats ---
    var fps_accum: f32 = 0;
    var fps_count: u32 = 0;
    var avg_fps: f32 = 0;

    // ========================================================================
    // MAIN LOOP
    // ========================================================================
    while (!rl.WindowShouldClose()) {
        const dt = rl.GetFrameTime();
        t += dt;
        cam = cam.rotate(0.005, 0.002);

        // FPS tracking
        fps_accum += if (dt > 0) 1.0 / dt else 0;
        fps_count += 1;
        if (fps_count >= 30) {
            avg_fps = fps_accum / @as(f32, @floatFromInt(fps_count));
            fps_accum = 0;
            fps_count = 0;
        }

        // Camera: orbit around origin
        const ray_cam: rl.Camera3D = .{
            .position = .{ .x = 8.0 * @cos(t * 0.3), .y = 4.0, .z = 8.0 * @sin(t * 0.3) },
            .target = .{ .x = 0, .y = 0, .z = 0 },
            .up = .{ .x = 0, .y = 1, .z = 0 },
            .fovy = 60.0,
            .projection = rl.CAMERA_PERSPECTIVE,
        };

        // ====================================================================
        // BATCH COMPUTE: все 360 трансформаций за один проход (cache-friendly)
        // ====================================================================
        //
        // Это ЕДИНСТВЕННАЯ CPU работа для геодезических точек.
        // 360 × MatrixTranslate() — тривиально для современного CPU.
        // Вся тяжёлая работа (vertex transform + rasterization) — на GPU.
        {
            var i: usize = 0;
            while (i < TOTAL_POINTS_USIZE) : (i += 1) {
                const fi = @as(f32, @floatFromInt(i));
                const angle = fi * (std.math.pi / 18.0) + t;
                const r = 4.0 + @sin(fi * 0.1 + t * 2.0);
                const px = r * @cos(angle);
                const pz = r * @sin(angle);
                const py = 1.5 * @sin(angle * 3.0 + t);

                const transform = matrixTranslate(px, py, pz);
                solid_transforms[i] = transform;
                wire_transforms[i] = transform;
            }
        }

        // ====================================================================
        // RENDER — 2 draw calls вместо 720!
        // ====================================================================
        rl.BeginDrawing();
        rl.ClearBackground(.{ .r = 8, .g = 8, .b = 14, .a = 255 });

        rl.BeginMode3D(ray_cam);
        rl.DrawGrid(100, 1.0);

        // --- Instanced solid spheres: 1 draw call, 360 instances ---
        rl.DrawMeshInstanced(solid_mesh, solid_mat, &solid_transforms, TOTAL_POINTS);

        // --- Instanced wire spheres: 1 draw call, 360 instances ---
        // Wireframe overlay (slightly larger, semi-transparent)
        rl.DrawMeshInstanced(wire_mesh, wire_mat, &wire_transforms, TOTAL_POINTS);

        // Reference cube
        rl.DrawCubeWires(.{ .x = 0, .y = 0, .z = 0 }, 2.0, 2.0, 2.0, .{ .r = 255, .g = 180, .b = 50, .a = 255 });

        rl.EndMode3D();

        // ====================================================================
        // HUD
        // ====================================================================
        rl.DrawText("P3 ENGINE: S3 / RP3 Projective Geometry Live Viewport", 20, 20, 20, .{ .r = 120, .g = 200, .b = 255, .a = 255 });
        rl.DrawText("GPU: NVIDIA GeForce GTX 1060 6GB | Backend: Raylib / OpenGL 3.3 + GPU Instancing", 20, 48, 14, .{ .r = 180, .g = 180, .b = 180, .a = 255 });

        var buf0: [128]u8 = undefined;
        const stats = std.fmt.bufPrintZ(&buf0, "Geodesic Points: {d} | Grid: 100x100 | Frame: {d:.2} ms | Draw Calls: 2 (instanced)", .{ TOTAL_POINTS_USIZE, dt * 1000.0 }) catch "";
        rl.DrawText(stats, 20, 70, 14, .{ .r = 100, .g = 255, .b = 150, .a = 255 });

        var buf1: [128]u8 = undefined;
        const gpu_stats = std.fmt.bufPrintZ(&buf1, "Avg FPS: {d:.0} | GPU Mode: Instanced (360 instances/call) | CPU: batch transforms only", .{avg_fps}) catch "";
        rl.DrawText(gpu_stats, 20, 90, 14, .{ .r = 200, .g = 200, .b = 100, .a = 255 });

        rl.DrawFPS(1180, 20);

        rl.EndDrawing();
    }

    // ========================================================================
    // CLEANUP — освобождаем GPU ресурсы
    // ========================================================================
    rl.UnloadMesh(&solid_mesh);
    rl.UnloadMaterial(solid_mat);
    rl.UnloadMesh(&wire_mesh);
    rl.UnloadMaterial(wire_mat);
    rl.CloseWindow();
}
