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
    // Зависимости уже добавлены в build.zig.zon:
    //   zglfw (commit d9c06187e8b2) — Zig 0.14.0 compatible
    //   zgpu  (commit 96f3ce2229e4) — Zig 0.14.0 compatible (NOT main!)
    //   dawn_x86_64_linux_gnu (lazy) — Dawn prebuilt binary
    //
    // zig build p3   — собрать бинарник
    // zig build run  — запустить движок
    // ========================================================

    // --- zglfw (GLFW bindings for window/input) ---
    const zglfw_dep = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });

    // --- zgpu (WebGPU/Dawn) ---
    // CRITICAL: addLibraryPathsTo must be called BEFORE linkLibrary(zdawn)
    // It adds the Dawn prebuilt library paths so the linker can find libdawn
    const zgpu_dep = b.dependency("zgpu", .{
        .target = target,
        .optimize = optimize,
    });

    // --- P³ Engine executable ---
    const exe = b.addExecutable(.{
        .name = "p3-engine",
        .root_source_file = b.path("src/p3_app.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add all P³ library modules as imports for the executable
    inline for (lib_modules) |mod| {
        const mod_name = mod.@"0";
        const mod_path = mod.@"1";
        exe.root_module.addImport(
            b.fmt("p3_{s}", .{mod_name}),
            b.addModule(b.fmt("p3_{s}", .{mod_name}), .{
                .root_source_file = b.path(mod_path),
            }),
        );
    }
    inline for (rt_modules) |mod| {
        const mod_name = mod.@"0";
        const mod_path = mod.@"1";
        exe.root_module.addImport(
            b.fmt("p3_{s}", .{mod_name}),
            b.addModule(b.fmt("p3_{s}", .{mod_name}), .{
                .root_source_file = b.path(mod_path),
            }),
        );
    }

    // zgpu/zglfw imports — real GPU bindings
    exe.root_module.addImport("zgpu", zgpu_dep.module("root"));
    exe.root_module.addImport("zglfw", zglfw_dep.module("root"));

    // Link Dawn WebGPU C++ library (MUST call addLibraryPathsTo first)
    @import("zgpu").addLibraryPathsTo(exe);
    exe.linkLibrary(zgpu_dep.artifact("zdawn"));

    // Link GLFW C library
    exe.linkLibrary(zglfw_dep.artifact("glfw"));

    // Platform-specific system SDK paths (for Dawn linking)
    // system_sdk is a transitive dep of zgpu/zglfw, resolved automatically
    if (target.result.os.tag == .macos) {
        // macOS needs framework paths — handled by zglfw/zgpu internally
    }

    b.installArtifact(exe);

    // --- Build step: zig build p3 ---
    const p3_step = b.step("p3", "Build P³ Engine executable");
    p3_step.dependOn(&exe.step);

    // --- Run step: zig build run ---
    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run P³ Engine");
    run_step.dependOn(&run_cmd.step);
}
