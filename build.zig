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
        // Phase 8D: CORDIC + Tensor (math foundation for P³)
        .{ "cordic",       "src/p3_cordic.zig" },
        .{ "tensor",       "src/p3_tensor.zig" },
        // Phase 10: UE Math port (DualQuat, SH, PolyRoot, Sobol/Halton, Archetype)
        .{ "dual_quat",      "src/p3_dual_quat.zig" },
        .{ "sh",             "src/p3_sh.zig" },
        .{ "polyroot",       "src/p3_polyroot.zig" },
        .{ "quasirandom",    "src/p3_quasirandom.zig" },
        .{ "archetype",      "src/p3_archetype.zig" },
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
}
