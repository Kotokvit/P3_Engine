#!/usr/bin/env bash
PROJECT_DIR="/home/vitalij/o3de_game_project"
O3DE_BIN="/opt/O3DE/26.05/bin/Linux/profile/Default"

echo "=== Запуск O3DE Launcher / Editor ==="
echo "Проект: $PROJECT_DIR"

# 1. Запуск Asset Processor в фоне (если еще не запущен)
if ! pgrep -f "AssetProcessor $PROJECT_DIR" > /dev/null; then
    echo "Запуск Asset Processor..."
    "$O3DE_BIN/AssetProcessor" "$PROJECT_DIR" > /dev/null 2>&1 &
    sleep 1
fi

# 2. Запуск Editor
echo "Открытие O3DE Editor..."
exec "$O3DE_BIN/Editor" --project-path "$PROJECT_DIR" "$@"
