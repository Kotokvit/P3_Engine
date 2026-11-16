#!/bin/bash
# Запуск окремого вікна Chromium з відкритим портом відладки для ШІ
mkdir -p /home/vitalij/.config/chromium-ai-profile
/usr/bin/chromium \
  --user-data-dir="/home/vitalij/.config/chromium-ai-profile" \
  --remote-debugging-port=9222 \
  --no-first-run \
  --no-default-browser-check \
  "https://notebooklm.google.com/notebook/08109264-caad-4605-b369-11f543c1ff62?authuser=1" > /dev/null 2>&1 &

echo "Browser launched on debug port 9222."
