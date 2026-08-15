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
    };

    // --- Phase 6 modules (need stubs for testing without GPU) ---
    const rt_modules = .{
        .{ "gpu_rt", "src/p3_gpu_rt.zig" },
        .{ "input",  "src/p3_input.zig" },
        .{ "app",    "src/p3_app.zig" },
    };

    // ========================================================
    // STUB MODULES (для тестов без GPU)
    // ========================================================
    const zglfw_stub = b.addModule("zglfw", .{
        .root_source_file = b.path("src/stubs/zglfw_stub.zig"),
    });
    const zgpu_stub = b.addModule("zgpu", .{
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
    // EXECUTABLE TARGET — P³ Engine (с реальным GPU)
    // ========================================================
    // Для сборки executable нужно добавить зависимости в build.zig.zon:
    //
    //   zig fetch --save=zgpu      https://github.com/zig-gamedev/zgpu/archive/96f3ce2229e4836daec714a3f0b8c3c3218a6b2c.tar.gz
    //   zig fetch --save=zglfw     https://github.com/zig-gamedev/zglfw/archive/82da052ccacec5f9b11b1f9ce4c9edc2ea0bb2a7.tar.gz
    //   zig fetch --save=zmath     https://github.com/zig-gamedev/zmath/archive/666efb32f8bf06e46c19e0c8e6c18d37e26a462b.tar.gz
    //   zig fetch --save=zpool     https://github.com/zig-gamedev/zpool/archive/7829cf02f78e8c39e19b802ccb47ed44037299c2.tar.gz
    //   zig fetch --save=system_sdk https://github.com/zig-gamedev/system_sdk/archive/c0dbf11cdc17da5904ea8a17eadc54dee26567ec.tar.gz
    //   zig build --fetch
    //
    // После этого раскомментировать блок GPU BUILD ниже и запустить:
    //   zig build p3    — собрать бинарник
    //   zig build run   — запустить движок
    //
    // ========================================================
    // GPU BUILD (uncomment after fetching dependencies)
    // ========================================================
    //
    // const zgpu_dep = b.dependency("zgpu", .{
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const zglfw_dep = b.dependency("zglfw", .{
    //     .target = target,
    //     .optimize = optimize,
    // });
    //
    // const exe = b.addExecutable(.{
    //     .name = "p3-engine",
    //     .root_source_file = b.path("src/p3_app.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // exe.root_module.addImport("zgpu", zgpu_dep.module("root"));
    // exe.root_module.addImport("zglfw", zglfw_dep.module("root"));
    // exe.linkLibrary(zgpu_dep.artifact("zdawn"));
    // exe.linkLibrary(zglfw_dep.artifact("glfw"));
    // b.installArtifact(exe);
    //
    // const run_cmd = b.addRunArtifact(exe);
    // if (b.args) |args| run_cmd.addArgs(args);
    // const run_step = b.step("run", "Run P³ Engine");
    // run_step.dependOn(&run_cmd.step);
}
