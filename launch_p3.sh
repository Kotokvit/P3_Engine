#!/bin/bash
# =============================================================================
# P³ Engine — Pure Source Build Launcher (Без предсобранных бинарников)
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

O3DE_DIR="${O3DE_DIR:-/opt/O3DE/26.05}"
P3_ENGINE_DIR="${SCRIPT_DIR}"

# Build first — so LD_PRELOAD path actually exists when we export it.
# (Before this change, LD_PRELOAD pointed to a not-yet-existing .so and
#  ld.so printed "cannot be preloaded: ignored" — harmless but noisy.)
MODE="${1:-zig}"
case "${MODE}" in
    cpp)
        echo "⚡ Сборка C++ Лаунчера из исходников (launcher-src)..."
        zig build launcher-cpp o3de-bridge
        ;;
    zig|*)
        echo "⚡ Сборка Нативного P³ Studio Launcher (с 3D Вьюпортом)..."
        zig build launcher
        ;;
esac

# Now that the build is done, .so exists — safe to set LD paths.
export LD_LIBRARY_PATH="${P3_ENGINE_DIR}/zig-out/lib:${O3DE_DIR}/bin/Linux/profile/Default:${LD_LIBRARY_PATH}"
# NOTE: LD_PRELOAD is intentionally NOT set. libP3_O3DE_Bridge.so is linked
# dynamically into p3-launcher-cpp via build.zig (linkLibrary), so it loads
# through normal LD_LIBRARY_PATH resolution. LD_PRELOAD would only be
# needed if we wanted to override an existing libAzFramework.so that
# O3DE shipped — but we don't ship O3DE binaries at all.
export AZ_GEM_PATH="${O3DE_DIR}/Gems"
export AZ_ENGINE_PATH="${O3DE_DIR}"
export QT_QPA_PLATFORM="xcb"
export XCURSOR_SIZE="24"
export XCURSOR_THEME="Adwaita"

case "${MODE}" in
    cpp)
        echo "🚀 Запуск C++ Лаунчера (source build)..."
        exec ./zig-out/bin/p3-launcher-cpp \
            --project-path "${P3_PROJECT_PATH:-/home/vitalij/o3de_game_project}" \
            --engine-path "${O3DE_DIR}" \
            "${@:2}"
        ;;
    zig|*)
        echo "🚀 Запуск Нативного P³ Studio Launcher..."
        exec ./zig-out/bin/p3-launcher "${@:2}"
        ;;
esac
