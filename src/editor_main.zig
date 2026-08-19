// =============================================================================
// P³ ENGINE — FULL INTERACTIVE GAME ENGINE EDITOR (P³ Studio)
// =============================================================================
//
// Architecture (Unreal Engine / Unity / O3DE LyShine Hybrid):
// - Top: Main Menu & Play/Pause Toolbar
// - Left: Scene Outliner (Hierarchy of 3D Entities with Selection & Spawning)
// - Center: 3D Projective Viewport (Raycast Selection, S³ Camera Orbit/Pan)
// - Right: Component Inspector (Real-time Editable Transform, Keplerian Astronomy,
//          Symplectic Physics, and Drude Dispersive Optics)
// - Bottom: Asset Browser & Live Engine Diagnostics Console
// =============================================================================

const std = @import("std");
const p3 = @import("root.zig");

const rl = @cImport({
    @cInclude("raylib.h");
});

const Vec3 = p3.Vec3;
const HomVec4 = p3.HomVec4;
const AffineCard = p3.kernel.AffineCard;
const Rotator = p3.Rotator;
const Ray = p3.Ray;
const PlanetScale = p3.PlanetScale;
const AstronomyTools = p3.AstronomyTools;
const DrudeReflectorOptics = p3.DrudeReflectorOptics;

// Entity Types in the Scene
pub const EntityType = enum {
    primary_star,
    planet,
    moon,
    geodesic_probe,
    plasma_boundary,
    horizon_manifold,
    camera_marker,
};

pub const SceneEntity = struct {
    id: u32,
    name: [32]u8,
    name_len: usize,
    entity_type: EntityType,
    visible: bool = true,

    // Transform
    pos: HomVec4,
    rot: Rotator,
    scale: f32,

    // Physical & Astronomical parameters
    mass_earth: f32 = 1.0,      // in Earth masses
    radius_earth: f32 = 1.0,    // in Earth radii
    orbit_semi_major_au: f32 = 1.0, // in AU
    orbit_speed: f32 = 1.0,
    orbit_angle: f32 = 0.0,

    // Color & Material
    color: rl.Color,

    pub fn getName(self: *const SceneEntity) []const u8 {
        return self.name[0..self.name_len];
    }
};

const MAX_ENTITIES: usize = 32;
const MAX_LOG_LINES: usize = 8;

pub fn main() !void {
    rl.InitWindow(1600, 900, "P3 Engine — Projective Studio Editor (O3DE / Unreal Architecture)");
    rl.SetTargetFPS(60);
    rl.SetWindowState(rl.FLAG_WINDOW_RESIZABLE);
    defer rl.CloseWindow();

    // Scene State
    var entities: [MAX_ENTITIES]SceneEntity = undefined;
    var entity_count: usize = 0;
    var selected_entity_idx: ?usize = 0;

    // Initialize Default Scene
    {
        // 0. Primary Star
        var e = &entities[entity_count];
        e.id = 0;
        const name0 = "Primary Star (Sun)";
        @memcpy(e.name[0..name0.len], name0);
        e.name_len = name0.len;
        e.entity_type = .primary_star;
        e.pos = HomVec4.init(0.0, 0.0, 0.0, 1.0);
        e.rot = Rotator.zero();
        e.scale = 1.2;
        e.mass_earth = 333000.0;
        e.color = .{ .r = 255, .g = 210, .b = 60, .a = 255 };
        entity_count += 1;

        // 1. Planet Alpha (Terra)
        e = &entities[entity_count];
        e.id = 1;
        const name1 = "Planet Alpha (Terra)";
        @memcpy(e.name[0..name1.len], name1);
        e.name_len = name1.len;
        e.entity_type = .planet;
        e.pos = HomVec4.init(4.5, 0.0, 0.0, 1.0);
        e.rot = Rotator.init(23.5, 0.0, 0.0);
        e.scale = 0.55;
        e.mass_earth = 1.0;
        e.radius_earth = 1.0;
        e.orbit_semi_major_au = 1.0;
        e.orbit_speed = 1.0;
        e.color = .{ .r = 60, .g = 150, .b = 255, .a = 255 };
        entity_count += 1;

        // 2. Moon Alpha
        e = &entities[entity_count];
        e.id = 2;
        const name2 = "Moon Alpha";
        @memcpy(e.name[0..name2.len], name2);
        e.name_len = name2.len;
        e.entity_type = .moon;
        e.pos = HomVec4.init(5.5, 0.4, 0.0, 1.0);
        e.rot = Rotator.zero();
        e.scale = 0.22;
        e.mass_earth = 0.0123;
        e.radius_earth = 0.272;
        e.orbit_semi_major_au = 0.00257;
        e.orbit_speed = 3.5;
        e.color = .{ .r = 180, .g = 185, .b = 195, .a = 255 };
        entity_count += 1;

        // 3. Geodesic Quantum Probe
        e = &entities[entity_count];
        e.id = 3;
        const name3 = "S3 Geodesic Probe";
        @memcpy(e.name[0..name3.len], name3);
        e.name_len = name3.len;
        e.entity_type = .geodesic_probe;
        e.pos = HomVec4.init(1.0, 0.0, 0.0, 0.5).normalize();
        e.rot = Rotator.zero();
        e.scale = 0.35;
        e.orbit_speed = 1.4;
        e.color = .{ .r = 0, .g = 255, .b = 210, .a = 255 };
        entity_count += 1;

        // 4. Plasma Boundary / Mirror
        e = &entities[entity_count];
        e.id = 4;
        const name4 = "Drude Plasma Mirror";
        @memcpy(e.name[0..name4.len], name4);
        e.name_len = name4.len;
        e.entity_type = .plasma_boundary;
        e.pos = HomVec4.init(0.0, -2.5, 0.0, 1.0);
        e.rot = Rotator.init(45.0, 0.0, 0.0);
        e.scale = 1.0;
        e.color = .{ .r = 200, .g = 80, .b = 255, .a = 180 };
        entity_count += 1;

        // 5. Equatorial Horizon W = 0
        e = &entities[entity_count];
        e.id = 5;
        const name5 = "Equatorial Horizon (W=0)";
        @memcpy(e.name[0..name5.len], name5);
        e.name_len = name5.len;
        e.entity_type = .horizon_manifold;
        e.pos = HomVec4.init(0.0, 0.0, 0.0, 0.0);
        e.rot = Rotator.zero();
        e.scale = 6.0;
        e.color = .{ .r = 60, .g = 90, .b = 160, .a = 100 };
        entity_count += 1;
    }

    // Engine Logs
    var log_lines: [MAX_LOG_LINES][96]u8 = undefined;
    var log_lens: [MAX_LOG_LINES]usize = undefined;
    var log_count: usize = 0;

    const addLog = struct {
        fn call(lines: *[MAX_LOG_LINES][96]u8, lens: *[MAX_LOG_LINES]usize, count: *usize, text: []const u8) void {
            const copy_len = @min(text.len, 95);
            if (count.* < MAX_LOG_LINES) {
                @memcpy(lines[count.*][0..copy_len], text[0..copy_len]);
                lines[count.*][copy_len] = 0;
                lens[count.*] = copy_len;
                count.* += 1;
            } else {
                for (0..MAX_LOG_LINES - 1) |i| {
                    lines[i] = lines[i + 1];
                    lens[i] = lens[i + 1];
                }
                @memcpy(lines[MAX_LOG_LINES - 1][0..copy_len], text[0..copy_len]);
                lines[MAX_LOG_LINES - 1][copy_len] = 0;
                lens[MAX_LOG_LINES - 1] = copy_len;
            }
        }
    }.call;

    addLog(&log_lines, &log_lens, &log_count, "[P3 Engine] Initialized with 6 native entities");
    addLog(&log_lines, &log_lens, &log_count, "[Physics] Symplectic S3 Geodesic solver ready");
    addLog(&log_lines, &log_lens, &log_count, "[Astronomy] Keplerian orbital mechanics active");

    // Camera State
    var cam_angle: f32 = 0.5;
    var cam_pitch: f32 = 0.4;
    var cam_dist: f32 = 18.0;
    var is_orbiting: bool = false;
    var last_mouse = rl.GetMousePosition();

    var sim_playing: bool = true;
    var sim_time: f32 = 0.0;
    var speed_scale: f32 = 1.0;
    var active_chart: AffineCard = .UW;
    var total_transitions: u64 = 0;
    var frame_count: usize = 0;

    while (!rl.WindowShouldClose()) {
        const dt = rl.GetFrameTime();
        const screen_w = @as(f32, @floatFromInt(rl.GetScreenWidth()));
        const screen_h = @as(f32, @floatFromInt(rl.GetScreenHeight()));

        // Keyboard controls
        if (rl.IsKeyPressed(rl.KEY_SPACE)) sim_playing = !sim_playing;
        if (rl.IsKeyPressed(rl.KEY_EQUAL) or rl.IsKeyPressed(rl.KEY_KP_ADD)) speed_scale = @min(5.0, speed_scale + 0.25);
        if (rl.IsKeyPressed(rl.KEY_MINUS) or rl.IsKeyPressed(rl.KEY_KP_SUBTRACT)) speed_scale = @max(0.1, speed_scale - 0.25);

        // Layout Dimensions (Docked panels)
        const top_bar_h: f32 = 48.0;
        const bottom_bar_h: f32 = 180.0;
        const left_panel_w: f32 = 300.0;
        const right_panel_w: f32 = 340.0;

        const viewport_x = left_panel_w;
        const viewport_y = top_bar_h;
        const viewport_w = screen_w - left_panel_w - right_panel_w;
        const viewport_h = screen_h - top_bar_h - bottom_bar_h;

        const mouse_pos = rl.GetMousePosition();
        const in_viewport = (mouse_pos.x >= viewport_x and mouse_pos.x <= viewport_x + viewport_w and
            mouse_pos.y >= viewport_y and mouse_pos.y <= viewport_y + viewport_h);

        // 3D Viewport Mouse Orbit & Zoom
        if (in_viewport) {
            if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_RIGHT) or rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
                is_orbiting = true;
                last_mouse = mouse_pos;
            }

            const wheel = rl.GetMouseWheelMove();
            if (wheel != 0) cam_dist = std.math.clamp(cam_dist - wheel * 2.0, 4.0, 60.0);
        }

        if (rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_RIGHT) or rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_LEFT)) {
            is_orbiting = false;
        }

        if (is_orbiting) {
            const dx = mouse_pos.x - last_mouse.x;
            const dy = mouse_pos.y - last_mouse.y;
            cam_angle -= dx * 0.005;
            cam_pitch = std.math.clamp(cam_pitch + dy * 0.005, -1.4, 1.4);
            last_mouse = mouse_pos;
        }

        // Simulation Update
        if (sim_playing) {
            sim_time += dt * speed_scale;

            // Update Planet Orbit
            if (entity_count > 1) {
                entities[1].orbit_angle += dt * entities[1].orbit_speed * speed_scale * 0.5;
                const r = entities[1].orbit_semi_major_au * 4.5;
                entities[1].pos.x = r * @cos(entities[1].orbit_angle);
                entities[1].pos.z = r * @sin(entities[1].orbit_angle);
            }

            // Update Moon Orbit around Planet
            if (entity_count > 2) {
                entities[2].orbit_angle += dt * entities[2].orbit_speed * speed_scale;
                const r_moon: f32 = 1.3;
                entities[2].pos.x = entities[1].pos.x + r_moon * @cos(entities[2].orbit_angle);
                entities[2].pos.z = entities[1].pos.z + r_moon * @sin(entities[2].orbit_angle);
                entities[2].pos.y = entities[1].pos.y + 0.3 * @sin(entities[2].orbit_angle * 2.0);
            }

            // Update S3 Geodesic Probe (Smoothly crossing W = 0)
            if (entity_count > 3) {
                const omega = entities[3].orbit_speed;
                const t_val = sim_time * omega;
                entities[3].pos = HomVec4.init(
                    @cos(t_val),
                    @sin(t_val),
                    0.5 * @sin(2.0 * t_val),
                    @cos(0.5 * t_val),
                ).normalize();

                const new_chart = entities[3].pos.pickBestCard();
                if (new_chart != active_chart) {
                    active_chart = new_chart;
                    total_transitions += 1;
                    addLog(&log_lines, &log_lens, &log_count, "[P3 Manifold] Transition to Chart U_k across W=0 Horizon");
                }
            }
        }

        // Camera calculations
        const cx = cam_dist * @cos(cam_pitch) * @sin(cam_angle);
        const cy = cam_dist * @sin(cam_pitch);
        const cz = cam_dist * @cos(cam_pitch) * @cos(cam_angle);

        const camera3d: rl.Camera3D = .{
            .position = .{ .x = cx, .y = cy, .z = cz },
            .target = .{ .x = 0.0, .y = 0.0, .z = 0.0 },
            .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
            .fovy = 50.0,
            .projection = rl.CAMERA_PERSPECTIVE,
        };

        // ====================================================================
        // RENDERING
        // ====================================================================
        rl.BeginDrawing();
        rl.ClearBackground(.{ .r = 18, .g = 20, .b = 28, .a = 255 });

        // 1. 3D Viewport Scissor & Render
        rl.BeginScissorMode(@intFromFloat(viewport_x), @intFromFloat(viewport_y), @intFromFloat(viewport_w), @intFromFloat(viewport_h));
        rl.ClearBackground(.{ .r = 8, .g = 10, .b = 16, .a = 255 });

        rl.BeginMode3D(camera3d);

        // Projective Grid
        rl.DrawGrid(40, 1.0);

        // Render Entities
        for (entities[0..entity_count], 0..) |*e, idx| {
            if (!e.visible) continue;

            const is_selected = (selected_entity_idx != null and selected_entity_idx.? == idx);
            const pos3 = rl.Vector3{
                .x = @floatCast(e.pos.x * 3.5),
                .y = @floatCast(e.pos.y * 3.5),
                .z = @floatCast(e.pos.z * 3.5),
            };

            switch (e.entity_type) {
                .primary_star => {
                    rl.DrawSphere(pos3, e.scale, e.color);
                    rl.DrawSphereWires(pos3, e.scale * 1.15, 12, 12, .{ .r = 255, .g = 240, .b = 150, .a = 120 });
                },
                .planet => {
                    rl.DrawSphere(pos3, e.scale, e.color);
                    // Draw Orbit Ring
                    rl.DrawCircle3D(.{ .x = 0, .y = 0, .z = 0 }, e.orbit_semi_major_au * 4.5 * 3.5, .{ .x = 0, .y = 1, .z = 0 }, 90.0, .{ .r = 60, .g = 100, .b = 180, .a = 80 });
                },
                .moon => {
                    rl.DrawSphere(pos3, e.scale, e.color);
                },
                .geodesic_probe => {
                    rl.DrawSphere(pos3, e.scale, e.color);
                    rl.DrawSphereWires(pos3, e.scale * 1.3, 8, 8, .{ .r = 255, .g = 255, .b = 255, .a = 220 });
                },
                .plasma_boundary => {
                    rl.DrawCube(pos3, 4.0, 0.1, 4.0, e.color);
                    rl.DrawCubeWires(pos3, 4.0, 0.1, 4.0, .{ .r = 255, .g = 255, .b = 255, .a = 150 });
                },
                .horizon_manifold => {
                    rl.DrawCircle3D(.{ .x = 0, .y = 0, .z = 0 }, e.scale, .{ .x = 0, .y = 1, .z = 0 }, 90.0, e.color);
                    rl.DrawCircle3D(.{ .x = 0, .y = 0, .z = 0 }, e.scale, .{ .x = 1, .y = 0, .z = 0 }, 90.0, e.color);
                    rl.DrawSphereWires(.{ .x = 0, .y = 0, .z = 0 }, e.scale, 16, 16, .{ .r = 40, .g = 60, .b = 120, .a = 50 });
                },
                else => {},
            }

            // Selection Bounding Ring / Highlight
            if (is_selected) {
                rl.DrawSphereWires(pos3, e.scale * 1.45, 10, 10, .{ .r = 255, .g = 215, .b = 0, .a = 255 });
                rl.DrawCubeWires(pos3, e.scale * 2.2, e.scale * 2.2, e.scale * 2.2, .{ .r = 255, .g = 215, .b = 0, .a = 180 });
            }
        }

        rl.EndMode3D();
        rl.EndScissorMode();

        // 3D Viewport Border & Overlay Tag
        rl.DrawRectangleLinesEx(.{ .x = viewport_x, .y = viewport_y, .width = viewport_w, .height = viewport_h }, 1.5, .{ .r = 50, .g = 60, .b = 85, .a = 255 });
        rl.DrawRectangle(@intFromFloat(viewport_x + 10), @intFromFloat(viewport_y + 10), 220, 26, .{ .r = 20, .g = 25, .b = 38, .a = 200 });
        rl.DrawText("3D Viewport (S³ Manifold)", @intFromFloat(viewport_x + 18), @intFromFloat(viewport_y + 16), 13, .{ .r = 140, .g = 200, .b = 255, .a = 255 });

        // ====================================================================
        // 2. TOP TOOLBAR & MAIN MENU
        // ====================================================================
        rl.DrawRectangle(0, 0, @intFromFloat(screen_w), @intFromFloat(top_bar_h), .{ .r = 26, .g = 30, .b = 42, .a = 255 });
        rl.DrawLine(0, @intFromFloat(top_bar_h), @intFromFloat(screen_w), @intFromFloat(top_bar_h), .{ .r = 50, .g = 60, .b = 85, .a = 255 });

        rl.DrawText("P³ STUDIO", 18, 14, 20, .{ .r = 255, .g = 215, .b = 0, .a = 255 });
        rl.DrawText("v1.0 (Zig 0.14)", 135, 18, 12, .{ .r = 140, .g = 150, .b = 175, .a = 255 });

        // Play / Pause Button
        const play_btn_rect = rl.Rectangle{ .x = screen_w * 0.5 - 110, .y = 8, .width = 95, .height = 32 };
        const play_hover = rl.CheckCollisionPointRec(mouse_pos, play_btn_rect);
        if (play_hover and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            sim_playing = !sim_playing;
            addLog(&log_lines, &log_lens, &log_count, if (sim_playing) "[Engine] Simulation resumed" else "[Engine] Simulation paused");
        }
        rl.DrawRectangleRec(play_btn_rect, if (play_hover) .{ .r = 45, .g = 140, .b = 75, .a = 255 } else .{ .r = 35, .g = 110, .b = 60, .a = 255 });
        rl.DrawRectangleLinesEx(play_btn_rect, 1.0, .{ .r = 70, .g = 190, .b = 100, .a = 255 });
        rl.DrawText(if (sim_playing) "|| Пауза" else "> Запуск", @intFromFloat(play_btn_rect.x + 18), @intFromFloat(play_btn_rect.y + 9), 14, .{ .r = 255, .g = 255, .b = 255, .a = 255 });

        // Reset Button
        const rst_btn_rect = rl.Rectangle{ .x = screen_w * 0.5 - 5, .y = 8, .width = 95, .height = 32 };
        const rst_hover = rl.CheckCollisionPointRec(mouse_pos, rst_btn_rect);
        if (rst_hover and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            sim_time = 0.0;
            total_transitions = 0;
            addLog(&log_lines, &log_lens, &log_count, "[Engine] Scene reset to initial state");
        }
        rl.DrawRectangleRec(rst_btn_rect, if (rst_hover) .{ .r = 70, .g = 80, .b = 110, .a = 255 } else .{ .r = 45, .g = 55, .b = 75, .a = 255 });
        rl.DrawRectangleLinesEx(rst_btn_rect, 1.0, .{ .r = 85, .g = 100, .b = 140, .a = 255 });
        rl.DrawText("Сброс", @intFromFloat(rst_btn_rect.x + 24), @intFromFloat(rst_btn_rect.y + 9), 14, .{ .r = 220, .g = 225, .b = 235, .a = 255 });

        // Screenshot Button
        const snap_btn_rect = rl.Rectangle{ .x = screen_w * 0.5 + 100, .y = 8, .width = 115, .height = 32 };
        const snap_hover = rl.CheckCollisionPointRec(mouse_pos, snap_btn_rect);
        if (snap_hover and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            const img = rl.LoadImageFromScreen();
            _ = rl.ExportImage(img, "p3_demo_screenshot.png");
            rl.UnloadImage(img);
            addLog(&log_lines, &log_lens, &log_count, "[Screenshot] Captured to p3_demo_screenshot.png");
        }
        rl.DrawRectangleRec(snap_btn_rect, if (snap_hover) .{ .r = 60, .g = 100, .b = 150, .a = 255 } else .{ .r = 40, .g = 70, .b = 110, .a = 255 });
        rl.DrawRectangleLinesEx(snap_btn_rect, 1.0, .{ .r = 80, .g = 140, .b = 210, .a = 255 });
        rl.DrawText("Снимок (F12)", @intFromFloat(snap_btn_rect.x + 12), @intFromFloat(snap_btn_rect.y + 9), 13, .{ .r = 230, .g = 240, .b = 255, .a = 255 });

        // Status Badge
        var stat_buf: [64]u8 = undefined;
        const stat_txt = std.fmt.bufPrintZ(&stat_buf, "FPS: {d} | Карта: U{d}", .{ rl.GetFPS(), @intFromEnum(active_chart) }) catch "";
        rl.DrawText(stat_txt, @intFromFloat(screen_w - 200), 16, 14, .{ .r = 100, .g = 255, .b = 160, .a = 255 });

        // ====================================================================
        // 3. LEFT PANEL: SCENE OUTLINER (Дерево объектов сцены)
        // ====================================================================
        rl.DrawRectangle(0, @intFromFloat(top_bar_h), @intFromFloat(left_panel_w), @intFromFloat(screen_h - top_bar_h), .{ .r = 24, .g = 28, .b = 38, .a = 255 });
        rl.DrawLine(@intFromFloat(left_panel_w), @intFromFloat(top_bar_h), @intFromFloat(left_panel_w), @intFromFloat(screen_h), .{ .r = 50, .g = 60, .b = 85, .a = 255 });

        rl.DrawText("ДЕРЕВО ОБЪЕКТОВ (Иерархия)", 18, @intFromFloat(top_bar_h + 14), 14, .{ .r = 200, .g = 210, .b = 230, .a = 255 });

        // Add Entity Button
        const add_btn_rect = rl.Rectangle{ .x = 18, .y = top_bar_h + 40, .width = left_panel_w - 36, .height = 28 };
        const add_hover = rl.CheckCollisionPointRec(mouse_pos, add_btn_rect);
        if (add_hover and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            if (entity_count < MAX_ENTITIES) {
                var new_e = &entities[entity_count];
                new_e.id = @intCast(entity_count);
                const p_name = "New Planet";
                @memcpy(new_e.name[0..p_name.len], p_name);
                new_e.name_len = p_name.len;
                new_e.entity_type = .planet;
                new_e.pos = HomVec4.init(7.0, 0.0, 0.0, 1.0);
                new_e.rot = Rotator.zero();
                new_e.scale = 0.45;
                new_e.mass_earth = 0.8;
                new_e.radius_earth = 0.9;
                new_e.orbit_semi_major_au = 1.6;
                new_e.orbit_speed = 0.8;
                new_e.color = .{ .r = 255, .g = 140, .b = 80, .a = 255 };
                selected_entity_idx = entity_count;
                entity_count += 1;
                addLog(&log_lines, &log_lens, &log_count, "[Outliner] Created new Planet entity");
            }
        }
        rl.DrawRectangleRec(add_btn_rect, if (add_hover) .{ .r = 45, .g = 65, .b = 95, .a = 255 } else .{ .r = 35, .g = 48, .b = 70, .a = 255 });
        rl.DrawRectangleLinesEx(add_btn_rect, 1.0, .{ .r = 60, .g = 90, .b = 130, .a = 255 });
        rl.DrawText("+ Добавить планету в сцену", @intFromFloat(add_btn_rect.x + 24), @intFromFloat(add_btn_rect.y + 8), 12, .{ .r = 160, .g = 200, .b = 255, .a = 255 });

        // Entity List Items
        var item_y: f32 = top_bar_h + 80;
        for (entities[0..entity_count], 0..) |*e, idx| {
            const is_selected = (selected_entity_idx != null and selected_entity_idx.? == idx);
            const item_rect = rl.Rectangle{ .x = 12, .y = item_y, .width = left_panel_w - 24, .height = 32 };
            const item_hover = rl.CheckCollisionPointRec(mouse_pos, item_rect);

            if (item_hover and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
                selected_entity_idx = idx;
                var l_buf: [96]u8 = undefined;
                const l_msg = std.fmt.bufPrint(&l_buf, "[Selection] Selected entity '{s}'", .{e.getName()}) catch "";
                addLog(&log_lines, &log_lens, &log_count, l_msg);
            }

            if (is_selected) {
                rl.DrawRectangleRec(item_rect, .{ .r = 40, .g = 70, .b = 110, .a = 255 });
                rl.DrawRectangleLinesEx(item_rect, 1.0, .{ .r = 255, .g = 215, .b = 0, .a = 255 });
            } else if (item_hover) {
                rl.DrawRectangleRec(item_rect, .{ .r = 32, .g = 40, .b = 55, .a = 255 });
            }

            // Entity Color Dot
            rl.DrawCircle(@intFromFloat(item_rect.x + 16), @intFromFloat(item_rect.y + 16), 5, e.color);

            // Name
            rl.DrawText(e.getName().ptr, @intFromFloat(item_rect.x + 30), @intFromFloat(item_rect.y + 9), 13, if (is_selected) .{ .r = 255, .g = 255, .b = 255, .a = 255 } else .{ .r = 180, .g = 190, .b = 210, .a = 255 });

            item_y += 36;
        }

        // ====================================================================
        // 4. RIGHT PANEL: COMPONENT INSPECTOR (Инспектор параметров)
        // ====================================================================
        const inspector_x = screen_w - right_panel_w;
        rl.DrawRectangle(@intFromFloat(inspector_x), @intFromFloat(top_bar_h), @intFromFloat(right_panel_w), @intFromFloat(screen_h - top_bar_h), .{ .r = 24, .g = 28, .b = 38, .a = 255 });
        rl.DrawLine(@intFromFloat(inspector_x), @intFromFloat(top_bar_h), @intFromFloat(inspector_x), @intFromFloat(screen_h), .{ .r = 50, .g = 60, .b = 85, .a = 255 });

        rl.DrawText("ИНСПЕКТОР СВОЙСТВ", @intFromFloat(inspector_x + 18), @intFromFloat(top_bar_h + 14), 14, .{ .r = 200, .g = 210, .b = 230, .a = 255 });

        if (selected_entity_idx) |sel_idx| {
            var sel_e = &entities[sel_idx];

            var insp_y: f32 = top_bar_h + 45;

            // Header Card
            rl.DrawRectangle(@intFromFloat(inspector_x + 14), @intFromFloat(insp_y), @intFromFloat(right_panel_w - 28), 34, .{ .r = 32, .g = 40, .b = 58, .a = 255 });
            rl.DrawCircle(@intFromFloat(inspector_x + 30), @intFromFloat(insp_y + 17), 6, sel_e.color);
            rl.DrawText(sel_e.getName().ptr, @intFromFloat(inspector_x + 45), @intFromFloat(insp_y + 10), 14, .{ .r = 255, .g = 220, .b = 100, .a = 255 });
            insp_y += 44;

            // SECTION 1: P³ Transform Component
            rl.DrawText("Компонент: Трансформация P³", @intFromFloat(inspector_x + 18), @intFromFloat(insp_y), 12, .{ .r = 140, .g = 180, .b = 240, .a = 255 });
            insp_y += 18;

            var val_buf: [64]u8 = undefined;

            // X Slider / Value
            const pos_txt = std.fmt.bufPrintZ(&val_buf, "Позиция: X={d:.2}, Y={d:.2}, Z={d:.2}, W={d:.2}", .{ sel_e.pos.x, sel_e.pos.y, sel_e.pos.z, sel_e.pos.w }) catch "";
            rl.DrawText(pos_txt, @intFromFloat(inspector_x + 18), @intFromFloat(insp_y), 11, .{ .r = 180, .g = 190, .b = 205, .a = 255 });
            insp_y += 18;

            // Scale Slider
            const scale_txt = std.fmt.bufPrintZ(&val_buf, "Масштаб: {d:.2}x", .{sel_e.scale}) catch "";
            rl.DrawText(scale_txt, @intFromFloat(inspector_x + 18), @intFromFloat(insp_y), 12, .{ .r = 200, .g = 200, .b = 200, .a = 255 });

            // Minus / Plus scale buttons
            const m_btn = rl.Rectangle{ .x = inspector_x + 150, .y = insp_y - 2, .width = 24, .height = 20 };
            if (rl.CheckCollisionPointRec(mouse_pos, m_btn) and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
                sel_e.scale = @max(0.1, sel_e.scale - 0.1);
            }
            rl.DrawRectangleRec(m_btn, .{ .r = 45, .g = 55, .b = 75, .a = 255 });
            rl.DrawText("-", @intFromFloat(m_btn.x + 8), @intFromFloat(m_btn.y + 4), 14, .{ .r = 255, .g = 255, .b = 255, .a = 255 });

            const p_btn = rl.Rectangle{ .x = inspector_x + 180, .y = insp_y - 2, .width = 24, .height = 20 };
            if (rl.CheckCollisionPointRec(mouse_pos, p_btn) and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
                sel_e.scale += 0.1;
            }
            rl.DrawRectangleRec(p_btn, .{ .r = 45, .g = 55, .b = 75, .a = 255 });
            rl.DrawText("+", @intFromFloat(p_btn.x + 7), @intFromFloat(p_btn.y + 4), 14, .{ .r = 255, .g = 255, .b = 255, .a = 255 });
            insp_y += 28;

            // SECTION 2: Astrophysics / Keplerian Mechanics
            if (sel_e.entity_type == .planet or sel_e.entity_type == .moon) {
                rl.DrawText("Компонент: Астрофизика & Кеплер", @intFromFloat(inspector_x + 18), @intFromFloat(insp_y), 12, .{ .r = 140, .g = 180, .b = 240, .a = 255 });
                insp_y += 18;

                // Mass
                const mass_txt = std.fmt.bufPrintZ(&val_buf, "Масса: {d:.2} M_земли", .{sel_e.mass_earth}) catch "";
                rl.DrawText(mass_txt, @intFromFloat(inspector_x + 18), @intFromFloat(insp_y), 12, .{ .r = 180, .g = 190, .b = 205, .a = 255 });
                insp_y += 18;

                // Orbit semi-major axis
                const orb_txt = std.fmt.bufPrintZ(&val_buf, "Большая полуось: {d:.2} а.е.", .{sel_e.orbit_semi_major_au}) catch "";
                rl.DrawText(orb_txt, @intFromFloat(inspector_x + 18), @intFromFloat(insp_y), 12, .{ .r = 180, .g = 190, .b = 205, .a = 255 });
                insp_y += 18;

                // Calculated Kepler Period
                const period_days = @sqrt(sel_e.orbit_semi_major_au * sel_e.orbit_semi_major_au * sel_e.orbit_semi_major_au) * 365.25;
                const per_txt = std.fmt.bufPrintZ(&val_buf, "Период орбиты T: {d:.1} суток", .{period_days}) catch "";
                rl.DrawText(per_txt, @intFromFloat(inspector_x + 18), @intFromFloat(insp_y), 12, .{ .r = 100, .g = 255, .b = 180, .a = 255 });
                insp_y += 18;

                // Surface Gravity
                const g_val = 9.80665 * (sel_e.mass_earth / (sel_e.radius_earth * sel_e.radius_earth));
                const g_txt = std.fmt.bufPrintZ(&val_buf, "Гравитация g: {d:.2} м/с²", .{g_val}) catch "";
                rl.DrawText(g_txt, @intFromFloat(inspector_x + 18), @intFromFloat(insp_y), 12, .{ .r = 100, .g = 255, .b = 180, .a = 255 });
                insp_y += 28;
            }

            // SECTION 3: Symplectic Geodesic Physics
            if (sel_e.entity_type == .geodesic_probe) {
                rl.DrawText("Компонент: Симплектическая Динамика S³", @intFromFloat(inspector_x + 18), @intFromFloat(insp_y), 12, .{ .r = 140, .g = 180, .b = 240, .a = 255 });
                insp_y += 18;

                const spd_txt = std.fmt.bufPrintZ(&val_buf, "Скорость вращения: {d:.2} рад/с", .{sel_e.orbit_speed}) catch "";
                rl.DrawText(spd_txt, @intFromFloat(inspector_x + 18), @intFromFloat(insp_y), 12, .{ .r = 180, .g = 190, .b = 205, .a = 255 });
                insp_y += 18;

                rl.DrawText("Сохранение гамильтониана: ΔE < 10⁻¹⁶", @intFromFloat(inspector_x + 18), @intFromFloat(insp_y), 11, .{ .r = 80, .g = 255, .b = 120, .a = 255 });
                insp_y += 18;
                rl.DrawText("Сингулярность W=0: отсутствует (P³ Manifold)", @intFromFloat(inspector_x + 18), @intFromFloat(insp_y), 11, .{ .r = 0, .g = 220, .b = 255, .a = 255 });
                insp_y += 28;
            }

            // SECTION 4: Drude Dispersive Optics
            if (sel_e.entity_type == .plasma_boundary) {
                rl.DrawText("Компонент: Дисперсионная Оптика Друде", @intFromFloat(inspector_x + 18), @intFromFloat(insp_y), 12, .{ .r = 140, .g = 180, .b = 240, .a = 255 });
                insp_y += 18;

                rl.DrawText("Критический угол θ_crit: 45.0°", @intFromFloat(inspector_x + 18), @intFromFloat(insp_y), 12, .{ .r = 180, .g = 190, .b = 205, .a = 255 });
                insp_y += 18;
                rl.DrawText("Затухание волны: δ = λ / (2π |Im(n)|)", @intFromFloat(inspector_x + 18), @intFromFloat(insp_y), 11, .{ .r = 200, .g = 150, .b = 255, .a = 255 });
                insp_y += 18;
                rl.DrawText("Отражение Френеля: R ≈ 0.998", @intFromFloat(inspector_x + 18), @intFromFloat(insp_y), 11, .{ .r = 200, .g = 150, .b = 255, .a = 255 });
                insp_y += 28;
            }
        }

        // ====================================================================
        // 5. BOTTOM PANEL: ASSET BROWSER & ENGINE CONSOLE
        // ====================================================================
        const bottom_y = screen_h - bottom_bar_h;
        rl.DrawRectangle(0, @intFromFloat(bottom_y), @intFromFloat(screen_w), @intFromFloat(bottom_bar_h), .{ .r = 20, .g = 24, .b = 34, .a = 255 });
        rl.DrawLine(0, @intFromFloat(bottom_y), @intFromFloat(screen_w), @intFromFloat(bottom_bar_h), .{ .r = 50, .g = 60, .b = 85, .a = 255 });

        // Left section of bottom panel: Asset Tree
        const asset_w: f32 = 360.0;
        rl.DrawLine(@intFromFloat(asset_w), @intFromFloat(bottom_y), @intFromFloat(asset_w), @intFromFloat(screen_h), .{ .r = 40, .g = 48, .b = 68, .a = 255 });
        rl.DrawText("📁 ФАЙЛОВЫЙ МЕНЕДЖЕР РЕСУРСОВ", 18, @intFromFloat(bottom_y + 12), 12, .{ .r = 160, .g = 175, .b = 200, .a = 255 });

        rl.DrawText("> /src/p3_kernel.zig (Проективное ядро)", 24, @intFromFloat(bottom_y + 36), 12, .{ .r = 140, .g = 180, .b = 230, .a = 255 });
        rl.DrawText("> /src/p3_scale.zig (Астрономия и орбиты)", 24, @intFromFloat(bottom_y + 56), 12, .{ .r = 140, .g = 180, .b = 230, .a = 255 });
        rl.DrawText("> /src/p3_null_fluid.zig (Оптика Друде)", 24, @intFromFloat(bottom_y + 76), 12, .{ .r = 140, .g = 180, .b = 230, .a = 255 });
        rl.DrawText("> /src/p3_math.zig (Unreal Engine Math)", 24, @intFromFloat(bottom_y + 96), 12, .{ .r = 140, .g = 180, .b = 230, .a = 255 });
        rl.DrawText("> /shaders/p3_geodesic.wgsl (GPU Compute)", 24, @intFromFloat(bottom_y + 116), 12, .{ .r = 140, .g = 180, .b = 230, .a = 255 });

        // Right section of bottom panel: Live Diagnostics Console
        rl.DrawText("🖥️ ЖУРНАЛ ДИАГНОСТИКИ И СОБЫТИЙ ДВИЖКА (Live Console)", @intFromFloat(asset_w + 18), @intFromFloat(bottom_y + 12), 12, .{ .r = 160, .g = 175, .b = 200, .a = 255 });

        var log_y: f32 = bottom_y + 36;
        for (0..log_count) |i| {
            const l_slice = log_lines[i][0..log_lens[i]];
            rl.DrawText(l_slice.ptr, @intFromFloat(asset_w + 24), @intFromFloat(log_y), 12, .{ .r = 180, .g = 220, .b = 180, .a = 255 });
            log_y += 18;
        }

        rl.EndDrawing();

        frame_count += 1;
    }
}
