#!/usr/bin/env bash
PROJECT_DIR="/home/vitalij/o3de_game_project"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Поиск исполняемых файлов лаунчера (в репозитории или в системе)
if [ -f "$REPO_DIR/bin/o3de_launcher/Editor" ] && [ -d "/opt/O3DE/26.05/bin/Linux/profile/Default" ]; then
    O3DE_BIN="/opt/O3DE/26.05/bin/Linux/profile/Default"
elif [ -d "/opt/O3DE/26.05/bin/Linux/profile/Default" ]; then
    O3DE_BIN="/opt/O3DE/26.05/bin/Linux/profile/Default"
else
    O3DE_BIN="$REPO_DIR/bin/o3de_launcher"
fi

echo "=== Запуск O3DE Launcher / Editor ==="
echo "Бинарники: $O3DE_BIN"
echo "Проект:    $PROJECT_DIR"

# 1. Запуск Asset Processor в фоне (если еще не запущен)
if ! pgrep -f "AssetProcessor $PROJECT_DIR" > /dev/null; then
    echo "Запуск Asset Processor..."
    "$O3DE_BIN/AssetProcessor" "$PROJECT_DIR" > /dev/null 2>&1 &
    sleep 1
fi

# 2. Запуск Editor
echo "Открытие O3DE Editor..."
exec "$O3DE_BIN/Editor" --project-path "$PROJECT_DIR" "$@"
