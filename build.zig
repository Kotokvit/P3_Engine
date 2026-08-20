const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ========================================================
    // P³ Engine — Projective Geometry Engine
    // Zig 0.14.0 — zgpu (Dawn/WebGPU) + zglfw (Window)
    // ========================================================
    // Фаза 1: Ядро + Идемпотенты + Геодезические + Мост
    //         + Cross-ratio + Safety (type-level guarantees)
    // Фаза 2: GPU (WGSL) + raylib мост + Инварианты
    //         + Алгебра (Грассман/Клиффорд/Плюккер)
    // Фаза 3: ECS (из O3DE) + Scene Graph + Physics
    // Фаза 4: Serial (@typeInfo) + IO (VFS) + Jobs (parallel batch)
    //         + Differential Geometry (Christoffel, Riemann, Ricci)
    // Фаза 5: Renderer (Forward+/Deferred P³ pipeline)
    //         + P³ Camera + Frustum culling on S³ + FS-depth
    // Фаза 6: Реальный GPU (zgpu/Dawn), pub fn main,
    //         Input, P³ Camera на S³, запускаемый бинарник
    // Фаза 7: zgpu (WebGPU/Dawn) + zglfw — рабочий GPU binary
    //         + Raylib demo (S³/RP³ live viewport)
    // ========================================================
    //
    // BUILD TARGETS:
    //   zig build p3      — engine (stubs, headless)
    //   zig build p3-gpu  — engine (real zgpu/zglfw, needs GPU)
    //   zig build demo    — Raylib 3D live viewport demo
    //   zig build test    — all 773 tests
    // ========================================================

    // --- All P³ library modules (no external deps) ---
    const lib_modules = .{
        .{ "kernel",      "src/p3_kernel.zig" },
        .{ "idempotent",  "src/p3_idempotent.zig" },
        .{ "geodesic",    "src/p3_geodesic.zig" },
        .{ "bridge",      "src/p3_bridge.zig" },
        .{ "crossratio",  "src/p3_crossratio.zig" },
        .{ "safety",      "src/p3_safety.zig" },
        .{ "gpu",         "src/p3_gpu.zig" },
        .{ "raylib",      "src/p3_raylib.zig" },
        .{ "quaternion",  "src/p3_quaternion.zig" },
        .{ "scale",       "src/p3_scale.zig" },
        .{ "invariant",   "src/p3_invariant.zig" },
        .{ "algebra",     "src/p3_algebra.zig" },
        .{ "ecs",         "src/p3_ecs.zig" },
        .{ "scene",       "src/p3_scene.zig" },
        .{ "physics",     "src/p3_physics.zig" },
        .{ "serial",      "src/p3_serial.zig" },
        .{ "io",          "src/p3_io.zig" },
        .{ "jobs",        "src/p3_jobs.zig" },
        .{ "rhi",         "src/p3_rhi.zig" },
        .{ "renderer",    "src/p3_renderer.zig" },
        // Phase 9: Full O3DE math port (Vec2/3/4, Mat3x3/4x4, Quat, Transform, Aabb, Plane, Frustum, Color, Uuid, Random)
        .{ "math",        "src/p3_math.zig" },
        // Phase 8A: Projective & Field Dynamics (causal spacetime, poler operators, dispersive boundary optics, PGA)
        .{ "causal",      "src/p3_causal.zig" },
        .{ "poler",       "src/p3_poler.zig" },
        .{ "null_fluid",  "src/p3_null_fluid.zig" },
        .{ "pga",         "src/p3_pga.zig" },
        // Phase 8B: GUI from O3DE LyShine (transform, layout, canvas, draw)
        .{ "ui_transform", "src/p3_ui_transform.zig" },
        .{ "ui_layout",   "src/p3_ui_layout.zig" },
        .{ "ui_canvas",   "src/p3_ui_canvas.zig" },
        .{ "ui_draw",     "src/p3_ui_draw.zig" },
        // Phase 8C: GUI Interactables from O3DE LyShine (full port)
        .{ "ui_interactable", "src/p3_ui_interactable.zig" },
        .{ "ui_button",       "src/p3_ui_button.zig" },
        .{ "ui_image",        "src/p3_ui_image.zig" },
        .{ "ui_text",         "src/p3_ui_text.zig" },
        .{ "ui_scroll",       "src/p3_ui_scroll.zig" },
        .{ "ui_dragdrop",     "src/p3_ui_dragdrop.zig" },
        .{ "ui_animation",    "src/p3_ui_animation.zig" },
        .{ "ui_navigation",   "src/p3_ui_navigation.zig" },
        .{ "ui_render",       "src/p3_ui_render.zig" },
        .{ "ui_raylib",       "src/p3_ui_raylib.zig" },
        // Phase 8D: CORDIC + Tensor (math foundation for P³)
        .{ "cordic",       "src/p3_cordic.zig" },
        .{ "tensor",       "src/p3_tensor.zig" },
        // Phase 10: UE Math port (DualQuat, SH, PolyRoot, Sobol/Halton, Archetype)
        .{ "dual_quat",      "src/p3_dual_quat.zig" },
        .{ "sh",             "src/p3_sh.zig" },
        .{ "polyroot",       "src/p3_polyroot.zig" },
        .{ "quasirandom",    "src/p3_quasirandom.zig" },
        .{ "archetype",      "src/p3_archetype.zig" },
        .{ "procedural_mesh","src/p3_procedural_mesh.zig" },
        .{ "vision",         "src/p3_vision.zig" },
        .{ "obj_loader",     "src/p3_obj_loader.zig" },
        .{ "vehicle_physics","src/p3_vehicle_physics.zig" },
    };

    // --- Phase 6 modules (need stubs for testing without GPU) ---
    const rt_modules = .{
        .{ "gpu_rt", "src/p3_gpu_rt.zig" },
        .{ "input",  "src/p3_input.zig" },
        .{ "app",    "src/p3_app.zig" },
        .{ "root",   "src/root.zig" },
    };

    // ========================================================
    // STUB MODULES (для тестов без GPU)
    // ========================================================
    const zglfw_stub = b.addModule("zglfw_stub", .{
        .root_source_file = b.path("src/stubs/zglfw_stub.zig"),
    });
    const zgpu_stub = b.addModule("zgpu_stub", .{
        .root_source_file = b.path("src/stubs/zgpu_stub.zig"),
    });

    // ========================================================
    // TEST TARGETS — все модули, без GPU
    // ========================================================
    const test_step = b.step("test", "Run all P³ engine tests");

    // --- Library module tests (no stubs needed) ---
    inline for (lib_modules) |mod| {
        const mod_name = mod.@"0";
        const mod_path = mod.@"1";

        const mod_tests = b.addTest(.{
            .root_source_file = b.path(mod_path),
            .target = target,
            .optimize = optimize,
        });
        const run_mod_tests = b.addRunArtifact(mod_tests);
        test_step.dependOn(&run_mod_tests.step);

        const individual_step = b.step(
            b.fmt("test-{s}", .{mod_name}),
            b.fmt("Run p3_{s} tests only", .{mod_name}),
        );
        individual_step.dependOn(&run_mod_tests.step);
    }

    // --- Phase 6 module tests (with stub imports for GPU/window) ---
    inline for (rt_modules) |mod| {
        const mod_name = mod.@"0";
        const mod_path = mod.@"1";

        const mod_tests = b.addTest(.{
            .root_source_file = b.path(mod_path),
            .target = target,
            .optimize = optimize,
        });
        // Stub imports: zgpu/zglfw replaced with empty types
        mod_tests.root_module.addImport("zgpu", zgpu_stub);
        mod_tests.root_module.addImport("zglfw", zglfw_stub);

        const run_mod_tests = b.addRunArtifact(mod_tests);
        test_step.dependOn(&run_mod_tests.step);

        const individual_step = b.step(
            b.fmt("test-{s}", .{mod_name}),
            b.fmt("Run p3_{s} tests only", .{mod_name}),
        );
        individual_step.dependOn(&run_mod_tests.step);
    }

    // ========================================================
    // HELPER: Add all P³ module imports to an executable
    // ========================================================
    const addP3Imports = struct {
        fn call(
            b_: *std.Build,
            exe_: *std.Build.Step.Compile,
            lib_mods: @TypeOf(lib_modules),
            rt_mods: @TypeOf(rt_modules),
        ) void {
            inline for (lib_mods) |mod| {
                const mod_name = mod.@"0";
                const mod_path = mod.@"1";
                exe_.root_module.addImport(
                    b_.fmt("p3_{s}", .{mod_name}),
                    b_.addModule(b_.fmt("p3_{s}", .{mod_name}), .{
                        .root_source_file = b_.path(mod_path),
                    }),
                );
            }
            inline for (rt_mods) |mod| {
                const mod_name = mod.@"0";
                const mod_path = mod.@"1";
                exe_.root_module.addImport(
                    b_.fmt("p3_{s}", .{mod_name}),
                    b_.addModule(b_.fmt("p3_{s}", .{mod_name}), .{
                        .root_source_file = b_.path(mod_path),
                    }),
                );
            }
        }
    }.call;

    // ========================================================
    // TARGET 1: p3-engine (stubs — headless, works everywhere)
    // ========================================================
    // zig build p3   — собрать бинарник (stubs)
    // zig build run  — запустить движок (stubs)
    {
        const exe = b.addExecutable(.{
            .name = "p3-engine",
            .root_source_file = b.path("src/p3_app.zig"),
            .target = target,
            .optimize = optimize,
        });
        addP3Imports(b, exe, lib_modules, rt_modules);
        exe.root_module.addImport("zgpu", zgpu_stub);
        exe.root_module.addImport("zglfw", zglfw_stub);
        b.installArtifact(exe);

        const p3_step = b.step("p3", "Build P³ Engine (headless stubs)");
        p3_step.dependOn(&exe.step);

        const run_cmd = b.addRunArtifact(exe);
        if (b.args) |args| run_cmd.addArgs(args);
        const run_step = b.step("run", "Run P³ Engine (stubs)");
        run_step.dependOn(&run_cmd.step);
    }

    // ========================================================
    // TARGET 2: p3-engine-gpu (real zgpu/zglfw — needs GPU)
    // ========================================================
    // zig build p3-gpu   — собрать бинарник (real GPU)
    // zig build run-gpu  — запустить движок (real GPU)
    //
    // Dependencies in build.zig.zon (Zig 0.14.0):
    //   zglfw (commit d9c06187e8b2)
    //   zgpu  (commit 96f3ce2229e4)
    //   dawn_x86_64_linux_gnu (lazy)
    //
    // CRITICAL: @import("zgpu").addLibraryPathsTo() ДО linkLibrary(zdawn)
    // ========================================================
    {
        const zglfw_dep = b.dependency("zglfw", .{
            .target = target,
            .optimize = optimize,
        });
        const zgpu_dep = b.dependency("zgpu", .{
            .target = target,
            .optimize = optimize,
        });

        const exe_gpu = b.addExecutable(.{
            .name = "p3-engine-gpu",
            .root_source_file = b.path("src/p3_app.zig"),
            .target = target,
            .optimize = optimize,
        });
        addP3Imports(b, exe_gpu, lib_modules, rt_modules);

        // Real zgpu/zglfw imports
        exe_gpu.root_module.addImport("zgpu", zgpu_dep.module("root"));
        exe_gpu.root_module.addImport("zglfw", zglfw_dep.module("root"));

        // CRITICAL: addLibraryPathsTo ДО linkLibrary(zdawn)
        @import("zgpu").addLibraryPathsTo(exe_gpu);
        exe_gpu.linkLibrary(zgpu_dep.artifact("zdawn"));
        exe_gpu.linkLibrary(zglfw_dep.artifact("glfw"));

        b.installArtifact(exe_gpu);

        const p3_gpu_step = b.step("p3-gpu", "Build P³ Engine with real GPU (zgpu/Dawn + zglfw)");
        p3_gpu_step.dependOn(&exe_gpu.step);

        const run_gpu_cmd = b.addRunArtifact(exe_gpu);
        if (b.args) |args| run_gpu_cmd.addArgs(args);
        const run_gpu_step = b.step("run-gpu", "Run P³ Engine with real GPU");
        run_gpu_step.dependOn(&run_gpu_cmd.step);
    }

    // ========================================================
    // TARGET 3: p3-demo-window (Raylib 3D live viewport)
    // ========================================================
    // zig build demo      — собрать демо
    // zig build run-demo  — запустить демо (needs raylib + display)
    //
    // Uses @cImport("raylib.h") directly — C99, no Zig wrapper.
    // Renders geodesic orbits + projective grid at 60 FPS.
    // ========================================================
    {
        const demo_exe = b.addExecutable(.{
            .name = "p3-demo-window",
            .root_source_file = b.path("src/demo_window.zig"),
            .target = target,
            .optimize = optimize,
        });
        inline for (lib_modules) |mod| {
            const mod_name = mod.@"0";
            const mod_path = mod.@"1";
            demo_exe.root_module.addImport(
                b.fmt("p3_{s}", .{mod_name}),
                b.addModule(b.fmt("p3_{s}", .{mod_name}), .{
                    .root_source_file = b.path(mod_path),
                }),
            );
        }
        demo_exe.linkLibC();
        demo_exe.linkSystemLibrary("raylib");
        demo_exe.linkSystemLibrary("GL");
        demo_exe.linkSystemLibrary("m");
        demo_exe.linkSystemLibrary("pthread");
        demo_exe.linkSystemLibrary("dl");
        demo_exe.linkSystemLibrary("rt");
        demo_exe.linkSystemLibrary("X11");
        b.installArtifact(demo_exe);

        const demo_step = b.step("demo", "Build P³ Engine Raylib live viewport demo");
        demo_step.dependOn(&demo_exe.step);

        const run_demo = b.addRunArtifact(demo_exe);
        const run_demo_step = b.step("run-demo", "Run P³ Engine live viewport demo");
        run_demo_step.dependOn(&run_demo.step);
    }

    // ========================================================
    // TARGET 4: p3-gui-demo (Raylib 2D GUI components demo)
    // ========================================================
    // zig build gui-demo      — собрать GUI демо
    // zig build run-gui-demo  — запустить GUI демо (needs raylib + display)
    //
    // Demonstrates all O3DE LyShine UI components live:
    //   Button, Checkbox, RadioButton, Slider, ScrollBar,
    //   Text, TextInput, DragDrop, Animation, Navigation
    // ========================================================
    {
        const gui_exe = b.addExecutable(.{
            .name = "p3-gui-demo",
            .root_source_file = b.path("src/gui_demo.zig"),
            .target = target,
            .optimize = optimize,
        });
        inline for (lib_modules) |mod| {
            const mod_name = mod.@"0";
            const mod_path = mod.@"1";
            gui_exe.root_module.addImport(
                b.fmt("p3_{s}", .{mod_name}),
                b.addModule(b.fmt("p3_{s}", .{mod_name}), .{
                    .root_source_file = b.path(mod_path),
                }),
            );
        }
        gui_exe.linkLibC();
        gui_exe.linkSystemLibrary("raylib");
        gui_exe.linkSystemLibrary("GL");
        gui_exe.linkSystemLibrary("m");
        gui_exe.linkSystemLibrary("pthread");
        gui_exe.linkSystemLibrary("dl");
        gui_exe.linkSystemLibrary("rt");
        gui_exe.linkSystemLibrary("X11");
        b.installArtifact(gui_exe);

        const gui_demo_step = b.step("gui-demo", "Build P³ Engine Raylib GUI components demo");
        gui_demo_step.dependOn(&gui_exe.step);

        const run_gui_demo = b.addRunArtifact(gui_exe);
        const run_gui_demo_step = b.step("run-gui-demo", "Run P³ Engine GUI components demo");
        run_gui_demo_step.dependOn(&run_gui_demo.step);
    }

    // ========================================================
    // TARGET 5: p3-editor (Full Interactive Game Engine Studio)
    // ========================================================
    // zig build editor      — собрать редактор
    // zig build run-editor  — запустить редактор
    //
    // Complete Unreal / Unity / O3DE LyShine Hybrid Studio:
    //   3D Viewport, Scene Outliner, Component Inspector,
    //   Keplerian Astronomy, Symplectic Physics, Asset Browser
    // ========================================================
    {
        const editor_exe = b.addExecutable(.{
            .name = "p3-editor",
            .root_source_file = b.path("src/editor_main.zig"),
            .target = target,
            .optimize = optimize,
        });
        inline for (lib_modules) |mod| {
            const mod_name = mod.@"0";
            const mod_path = mod.@"1";
            editor_exe.root_module.addImport(
                b.fmt("p3_{s}", .{mod_name}),
                b.addModule(b.fmt("p3_{s}", .{mod_name}), .{
                    .root_source_file = b.path(mod_path),
                }),
            );
        }
        editor_exe.root_module.addImport(
            "root.zig",
            b.addModule("root.zig", .{
                .root_source_file = b.path("src/root.zig"),
            }),
        );
        editor_exe.linkLibC();
        editor_exe.linkSystemLibrary("raylib");
        editor_exe.linkSystemLibrary("GL");
        editor_exe.linkSystemLibrary("m");
        editor_exe.linkSystemLibrary("pthread");
        editor_exe.linkSystemLibrary("dl");
        editor_exe.linkSystemLibrary("rt");
        editor_exe.linkSystemLibrary("X11");
        b.installArtifact(editor_exe);

        const editor_step = b.step("editor", "Build P³ Engine Full Interactive Studio Editor");
        editor_step.dependOn(&editor_exe.step);

        const run_editor = b.addRunArtifact(editor_exe);
        const run_editor_step = b.step("run-editor", "Run P³ Engine Full Interactive Studio Editor");
        run_editor_step.dependOn(&run_editor.step);
    }

    // ========================================================
    // TARGET 6: p3-game (Playable Projective Space Game)
    // ========================================================
    // zig build game      — собрать игру
    // zig build run-game  — запустить игру
    // ========================================================
    {
        const game_exe = b.addExecutable(.{
            .name = "p3-game",
            .root_source_file = b.path("src/game_main.zig"),
            .target = target,
            .optimize = optimize,
        });
        inline for (lib_modules) |mod| {
            const mod_name = mod.@"0";
            const mod_path = mod.@"1";
            game_exe.root_module.addImport(
                b.fmt("p3_{s}", .{mod_name}),
                b.addModule(b.fmt("p3_{s}", .{mod_name}), .{
                    .root_source_file = b.path(mod_path),
                }),
            );
        }
        game_exe.root_module.addImport(
            "root.zig",
            b.addModule("root.zig", .{
                .root_source_file = b.path("src/root.zig"),
            }),
        );
        game_exe.linkLibC();
        game_exe.linkSystemLibrary("raylib");
        game_exe.linkSystemLibrary("GL");
        game_exe.linkSystemLibrary("m");
        game_exe.linkSystemLibrary("pthread");
        game_exe.linkSystemLibrary("dl");
        game_exe.linkSystemLibrary("rt");
        game_exe.linkSystemLibrary("X11");
        const install_game = b.addInstallArtifact(game_exe, .{});
        b.getInstallStep().dependOn(&install_game.step);

        const game_step = b.step("game", "Build P³ Void Voyager Game");
        game_step.dependOn(&install_game.step);

        const run_game = b.addRunArtifact(game_exe);
        const run_game_step = b.step("run-game", "Run P³ Void Voyager Game");
        run_game_step.dependOn(&run_game.step);
    }

    // ========================================================
    // TARGET 7: p3-tank-arena (Orbital Hover-Tank Arena)
    // ========================================================
    {
        const tank_exe = b.addExecutable(.{
            .name = "p3-tank-arena",
            .root_source_file = b.path("src/tank_arena_main.zig"),
            .target = target,
            .optimize = optimize,
        });
        inline for (lib_modules) |mod| {
            const mod_name = mod.@"0";
            const mod_path = mod.@"1";
            tank_exe.root_module.addImport(
                b.fmt("p3_{s}", .{mod_name}),
                b.addModule(b.fmt("p3_{s}", .{mod_name}), .{
                    .root_source_file = b.path(mod_path),
                }),
            );
        }
        tank_exe.root_module.addImport(
            "root.zig",
            b.addModule("root.zig", .{
                .root_source_file = b.path("src/root.zig"),
            }),
        );
        tank_exe.linkLibC();
        tank_exe.linkSystemLibrary("raylib");
        tank_exe.linkSystemLibrary("GL");
        tank_exe.linkSystemLibrary("m");
        tank_exe.linkSystemLibrary("pthread");
        tank_exe.linkSystemLibrary("dl");
        tank_exe.linkSystemLibrary("rt");
        tank_exe.linkSystemLibrary("X11");
        const install_tank = b.addInstallArtifact(tank_exe, .{});
        b.getInstallStep().dependOn(&install_tank.step);

        const tank_step = b.step("tank-arena", "Build P³ Orbital Hover-Tank Arena");
        tank_step.dependOn(&install_tank.step);

        const run_tank = b.addRunArtifact(tank_exe);
        const run_tank_step = b.step("run-tank-arena", "Run P³ Orbital Hover-Tank Arena");
        run_tank_step.dependOn(&run_tank.step);
    }

    // ========================================================
    // TARGET 8: p3-arena-bench (HEADLESS Asteroid Field benchmark)
    //   Pure software rasterizer, no GPU, no raylib.
    //   Produces PPM + raw depth + segmentation + JSON sidecar.
    // ========================================================
    {
        const bench_exe = b.addExecutable(.{
            .name = "p3-arena-bench",
            .root_source_file = b.path("src/p3_arena_bench.zig"),
            .target = target,
            .optimize = optimize,
        });
        inline for (lib_modules) |mod| {
            const mod_name = mod.@"0";
            const mod_path = mod.@"1";
            bench_exe.root_module.addImport(
                b.fmt("p3_{s}", .{mod_name}),
                b.addModule(b.fmt("p3_{s}", .{mod_name}), .{
                    .root_source_file = b.path(mod_path),
                }),
            );
        }
        bench_exe.root_module.addImport(
            "root.zig",
            b.addModule("root.zig", .{
                .root_source_file = b.path("src/root.zig"),
            }),
        );
        const install_bench = b.addInstallArtifact(bench_exe, .{});
        b.getInstallStep().dependOn(&install_bench.step);

        const bench_step = b.step("arena-bench", "Build P3 Headless Arena Benchmark (no GPU)");
        bench_step.dependOn(&install_bench.step);

        const run_bench = b.addRunArtifact(bench_exe);
        const run_bench_step = b.step("run-arena-bench", "Run P3 Headless Arena Benchmark");
        run_bench_step.dependOn(&run_bench.step);
    }

    // ========================================================
    // TARGET 9: p3-closed-loop (LLM Vision Closed-Loop Demo)
    //   Reads /home/z/renders/actions.json, applies actions
    //   one-by-one, renders each frame to disk with PNG + depth
    //   + segmentation + meta JSON. Demonstrates the engine's
    //   real-time visual access for an LLM agent.
    // ========================================================
    {
        const loop_exe = b.addExecutable(.{
            .name = "p3-closed-loop",
            .root_source_file = b.path("src/p3_closed_loop.zig"),
            .target = target,
            .optimize = optimize,
        });
        inline for (lib_modules) |mod| {
            const mod_name = mod.@"0";
            const mod_path = mod.@"1";
            loop_exe.root_module.addImport(
                b.fmt("p3_{s}", .{mod_name}),
                b.addModule(b.fmt("p3_{s}", .{mod_name}), .{
                    .root_source_file = b.path(mod_path),
                }),
            );
        }
        loop_exe.root_module.addImport(
            "root.zig",
            b.addModule("root.zig", .{
                .root_source_file = b.path("src/root.zig"),
            }),
        );
        const install_loop = b.addInstallArtifact(loop_exe, .{});
        b.getInstallStep().dependOn(&install_loop.step);

        const loop_step = b.step("closed-loop", "Build P3 LLM Vision Closed-Loop Demo (no GPU)");
        loop_step.dependOn(&install_loop.step);

        const run_loop = b.addRunArtifact(loop_exe);
        const run_loop_step = b.step("run-closed-loop", "Run P3 LLM Vision Closed-Loop Demo");
        run_loop_step.dependOn(&run_loop.step);
    }

    // ========================================================
    // TARGET 10: p3-race (P³ Neon Vector Grand Prix)
    // ========================================================
    {
        const race_exe = b.addExecutable(.{
            .name = "p3-race",
            .root_source_file = b.path("src/race_main.zig"),
            .target = target,
            .optimize = optimize,
        });
        inline for (lib_modules) |mod| {
            const mod_name = mod.@"0";
            const mod_path = mod.@"1";
            race_exe.root_module.addImport(
                b.fmt("p3_{s}", .{mod_name}),
                b.addModule(b.fmt("p3_{s}", .{mod_name}), .{
                    .root_source_file = b.path(mod_path),
                }),
            );
        }
        race_exe.root_module.addImport(
            "root.zig",
            b.addModule("root.zig", .{
                .root_source_file = b.path("src/root.zig"),
            }),
        );
        race_exe.linkLibC();
        race_exe.linkSystemLibrary("raylib");
        race_exe.linkSystemLibrary("GL");
        race_exe.linkSystemLibrary("m");
        race_exe.linkSystemLibrary("pthread");
        race_exe.linkSystemLibrary("dl");
        race_exe.linkSystemLibrary("rt");
        race_exe.linkSystemLibrary("X11");
        const install_race = b.addInstallArtifact(race_exe, .{});
        b.getInstallStep().dependOn(&install_race.step);

        const race_step = b.step("race", "Build P³ Neon Vector Grand Prix Game");
        race_step.dependOn(&install_race.step);

        const run_race = b.addRunArtifact(race_exe);
        const run_race_step = b.step("run-race", "Run P³ Neon Vector Grand Prix Game");
        run_race_step.dependOn(&run_race.step);
    }

    // ========================================================
    // TARGET 10: p3-race-bench (HEADLESS race benchmark, no raylib)
    //   Same trefoil-knot circuit as race_main.zig but rendered
    //   through our VisualFrameBuffer (CPU rasterizer + CV analyzer).
    //   No GPU/X11/raylib — pure headless, for LLM agent loop.
    // ========================================================
    {
        const bench_exe = b.addExecutable(.{
            .name = "p3-race-bench",
            .root_source_file = b.path("src/p3_race_bench.zig"),
            .target = target,
            .optimize = optimize,
        });
        inline for (lib_modules) |mod| {
            const mod_name = mod.@"0";
            const mod_path = mod.@"1";
            bench_exe.root_module.addImport(
                b.fmt("p3_{s}", .{mod_name}),
                b.addModule(b.fmt("p3_{s}", .{mod_name}), .{
                    .root_source_file = b.path(mod_path),
                }),
            );
        }
        bench_exe.root_module.addImport(
            "root.zig",
            b.addModule("root.zig", .{
                .root_source_file = b.path("src/root.zig"),
            }),
        );
        const install_bench = b.addInstallArtifact(bench_exe, .{});
        b.getInstallStep().dependOn(&install_bench.step);

        const bench_step = b.step("race-bench", "Build P3 Headless Race Benchmark (no GPU)");
        bench_step.dependOn(&install_bench.step);

        const run_bench = b.addRunArtifact(bench_exe);
        const run_bench_step = b.step("run-race-bench", "Run P3 Headless Race Benchmark");
        run_bench_step.dependOn(&run_bench.step);
    }

    // ========================================================
    // TARGET 11: p3-obj-demo (load .obj file, render it headless)
    //   Demonstrates Blender integration: parse .obj, rasterize to
    //   VisualFrameBuffer. Works with any Wavefront OBJ exported
    //   from Blender, Maya, 3ds Max, etc.
    // ========================================================
    {
        const obj_exe = b.addExecutable(.{
            .name = "p3-obj-demo",
            .root_source_file = b.path("src/p3_obj_demo.zig"),
            .target = target,
            .optimize = optimize,
        });
        inline for (lib_modules) |mod| {
            const mod_name = mod.@"0";
            const mod_path = mod.@"1";
            obj_exe.root_module.addImport(
                b.fmt("p3_{s}", .{mod_name}),
                b.addModule(b.fmt("p3_{s}", .{mod_name}), .{
                    .root_source_file = b.path(mod_path),
                }),
            );
        }
        obj_exe.root_module.addImport(
            "root.zig",
            b.addModule("root.zig", .{
                .root_source_file = b.path("src/root.zig"),
            }),
        );
        const install_obj = b.addInstallArtifact(obj_exe, .{});
        b.getInstallStep().dependOn(&install_obj.step);

        const obj_step = b.step("obj-demo", "Build P3 OBJ Loader Demo (Blender integration)");
        obj_step.dependOn(&install_obj.step);

        const run_obj = b.addRunArtifact(obj_exe);
        const run_obj_step = b.step("run-obj-demo", "Run P3 OBJ Loader Demo");
        run_obj_step.dependOn(&run_obj.step);
    }
}
