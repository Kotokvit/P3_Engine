#!/bin/bash
# =============================================================================
# P³ Engine — Launcher (прямой запуск O3DE лаунчера)
# =============================================================================
# Phase 1: ИСПОЛЬЗУЕМ оригинальный O3DE лаунчер напрямую.
# Phase 2: Постепенно заменяем C++ модули на Zig.
# Phase 3: Полный перевод на Zig.
#
# Запуск: ./launch_p3.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Путь к O3DE SDK (настрой под себя)
O3DE_DIR="${O3DE_DIR:-/opt/O3DE/26.05}"

# Путь к P3 Engine (этот репозиторий)
P3_ENGINE_DIR="${SCRIPT_DIR}"

# Бинарники лаунчера
LAUNCHER_BIN="${P3_ENGINE_DIR}/bin/o3de_launcher"
GAMELAUNCHER="${LAUNCHER_BIN}/O3DE.GameLauncher"
EDITOR="${LAUNCHER_BIN}/Editor"
O3DE_PM="${LAUNCHER_BIN}/o3de"
ASSET_PROC="${LAUNCHER_BIN}/AssetProcessor"

# Проверка что O3DE SDK установлен
if [ ! -d "${O3DE_DIR}" ]; then
    echo "❌ O3DE SDK не найден: ${O3DE_DIR}"
    echo "   Установите O3DE или задайте O3DE_DIR:"
    echo "   export O3DE_DIR=/path/to/o3de"
    exit 1
fi

# Проверка бинарников
if [ ! -f "${GAMELAUNCHER}" ]; then
    echo "❌ GameLauncher не найден: ${GAMELAUNCHER}"
    exit 1
fi

# Настройка окружения
export LD_LIBRARY_PATH="${P3_ENGINE_DIR}/zig-out/lib:${O3DE_DIR}/bin/Linux/profile/Default:${LD_LIBRARY_PATH}"
export LD_PRELOAD="${P3_ENGINE_DIR}/zig-out/lib/libP3_O3DE_Bridge.so:${LD_PRELOAD}"
export AZ_GEM_PATH="${O3DE_DIR}/Gems"
export AZ_ENGINE_PATH="${O3DE_DIR}"
export QT_PLUGIN_PATH="${O3DE_DIR}/bin/Linux/profile/Default:${QT_PLUGIN_PATH}"
export QT_QPA_PLATFORM_PLUGIN_PATH="${O3DE_DIR}/bin/Linux/profile/Default/platforms"
export QT_QPA_PLATFORM="xcb"
export XCURSOR_SIZE="24"
export XCURSOR_THEME="Adwaita"

# Выбор режима запуска
case "${1:-menu}" in
    game|play)
        echo "🎮 Запуск P³ Engine — Game Launcher"
        exec "${GAMELAUNCHER}" \
            --engine-path="${O3DE_DIR}" \
            --project-path="${P3_ENGINE_DIR}" \
            "${@:2}"
        ;;
    editor|edit)
        echo "✏️  Запуск P³ Engine — Editor"
        exec "${EDITOR}" \
            --engine-path="${O3DE_DIR}" \
            --project-path="${P3_ENGINE_DIR}" \
            "${@:2}"
        ;;
    manager|pm)
        echo "📁 Запуск P³ Engine — Project Manager"
        exec "${O3DE_PM}" \
            --engine-path="${O3DE_DIR}" \
            "${@:2}"
        ;;
    assets|ap)
        echo "📦 Запуск P³ Engine — Asset Processor"
        exec "${ASSET_PROC}" \
            --engine-path="${O3DE_DIR}" \
            --project-path="${P3_ENGINE_DIR}" \
            "${@:2}"
        ;;
    menu|"")
        echo "╔══════════════════════════════════════════╗"
        echo "║      P³ ENGINE — ЗАПУСК ДВИЖКА           ║"
        echo "╠══════════════════════════════════════════╣"
        echo "║  1. game     — Игровой режим             ║"
        echo "║  2. editor   — Редактор сцен            ║"
        echo "║  3. manager  — Менеджер проектов        ║"
        echo "║  4. assets   — Обработчик ассетов       ║"
        echo "║  5. zig      — Zig лаунчер (raylib)      ║"
        echo "╠══════════════════════════════════════════╣"
        echo "║  O3DE SDK: ${O3DE_DIR:0:25}...          ║"
        echo "║  P³ Engine: ${P3_ENGINE_DIR:0:25}...    ║"
        echo "╚══════════════════════════════════════════╝"
        echo ""
        echo "Использование: $0 <режим>"
        echo "  $0 game      → запустить игру"
        echo "  $0 editor    → открыть редактор"
        echo "  $0 manager   → менеджер проектов"
        echo "  $0 assets    → обработчик ассетов"
        echo "  $0 zig       → Zig+raylib лаунчер (zig build run-launcher)"
        echo ""
        read -p "Выберите режим [1-5]: " choice
        case "$choice" in
            1) exec "$0" game "${@:2}" ;;
            2) exec "$0" editor "${@:2}" ;;
            3) exec "$0" manager "${@:2}" ;;
            4) exec "$0" assets "${@:2}" ;;
            5) exec "$0" zig "${@:2}" ;;
            *) echo "Неверный выбор"; exit 1 ;;
        esac
        ;;
    zig)
        echo "⚡ Запуск P³ Engine — Zig+raylib лаунчер"
        cd "${P3_ENGINE_DIR}"
        zig build launcher && exec ./zig-out/bin/p3-launcher "${@:2}"
        ;;
    *)
        echo "Неизвестный режим: $1"
        echo "Использование: $0 [game|editor|manager|assets|zig|menu]"
        exit 1
        ;;
esac
