#!/bin/bash
# =============================================================================
# P³ Engine — Pure Source Build Launcher (Без предсобранных бинарников)
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

O3DE_DIR="${O3DE_DIR:-/opt/O3DE/26.05}"
P3_ENGINE_DIR="${SCRIPT_DIR}"

export LD_LIBRARY_PATH="${P3_ENGINE_DIR}/zig-out/lib:${O3DE_DIR}/bin/Linux/profile/Default:${LD_LIBRARY_PATH}"
export LD_PRELOAD="${P3_ENGINE_DIR}/zig-out/lib/libP3_O3DE_Bridge.so:${LD_PRELOAD}"
export AZ_GEM_PATH="${O3DE_DIR}/Gems"
export AZ_ENGINE_PATH="${O3DE_DIR}"
export QT_QPA_PLATFORM="xcb"
export XCURSOR_SIZE="24"
export XCURSOR_THEME="Adwaita"

MODE="${1:-zig}"

case "${MODE}" in
    cpp)
        echo "⚡ Сборка и запуск C++ Лаунчера из исходников (launcher-src)..."
        zig build launcher-cpp
        exec ./zig-out/bin/p3-launcher-cpp --project-path /home/vitalij/o3de_game_project "${@:2}"
        ;;
    zig|*)
        echo "⚡ Сборка и запуск Нативного P³ Studio Launcher (с 3D Вьюпортом)..."
        zig build launcher
        exec ./zig-out/bin/p3-launcher "${@:2}"
        ;;
esac
