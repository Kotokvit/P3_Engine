#!/usr/bin/env python3
"""
P³ Remote Control Server v2.0 — KDE Plasma 6 Wayland edition.
Запуск:  python3 p3_remote_v2.py
Порт:   8080

КРИТИЧЕСКИЕ ИСПРАВЛЕНИЯ для KDE Plasma 6 Wayland:
  - spectacle как ПЕРВИЧНЫЙ метод (нативный KDE инструмент)
  - БЕЗ capture_output для spectacle (убивает D-Bus дочерний процесс!)
  - Уникальный путь temp-файла /tmp/p3_shot_{uid}.png (не root-owned)
  - _clean_tmp() для удаления root-owned файлов перед захватом
  - Ожидание файла — spectacle пишет асинхронно через D-Bus

Endpoints:
  GET  /              — файловый браузер
  GET  /screenshot     — скриншот монитора → PNG/JPEG
  GET  /screenshot?format=jpg  — JPEG (меньше размер, быстрее по сети)
  GET  /processes      — список процессов
  GET  /status         — статус системы (CPU, RAM, GPU)
  POST /cmd            — выполнить команду → {stdout, stderr, returncode}
  GET  /cmd?q=command  — то же через GET
"""

import http.server
import subprocess
import json
import os
import sys
import time
import urllib.parse
from pathlib import Path

BASE_DIR = Path.cwd()

# Уникальный temp-путь per-UID — избегаем конфликтов с root-owned файлами
_UID = os.getuid()
TEMP_PNG = f"/tmp/p3_shot_{_UID}.png"
TEMP_JPG = f"/tmp/p3_shot_{_UID}.jpg"

VERSION = "2.0"


def _clean_tmp(path):
    """Удалить temp-файл, даже если он принадлежит root."""
    try:
        if os.path.exists(path):
            os.unlink(path)
    except PermissionError:
        try:
            subprocess.run(['sudo', '-n', 'rm', '-f', path], timeout=3,
                           capture_output=True)
        except Exception:
            pass


def _wait_for_file(path, min_size=5000, timeout=12, poll=0.3):
    """Ждём пока файл появится и достигнет минимального размера."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if os.path.exists(path) and os.path.getsize(path) >= min_size:
                return True
        except OSError:
            pass
        time.sleep(poll)
    return False


def _capture_spectacle():
    """
    Spectacle — ПЕРВИЧНЫЙ метод для KDE Plasma 6 Wayland.

    КРИТИЧЕСКИЕ нюансы:
    1. capture_output=True УБИВАЕТ D-Bus дочерний процесс → файл НЕ создаётся!
    2. Spectale форкается через D-Bus и пишет АСИНХРОННО — надо ждать файл.
    3. Нужны правильные KDE env vars (XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS).
    """
    tmp = TEMP_PNG
    _clean_tmp(tmp)

    # Подготовка окружения KDE/D-Bus
    env = os.environ.copy()
    if 'DBUS_SESSION_BUS_ADDRESS' not in env:
        bus_path = f"/run/user/{_UID}/bus"
        if os.path.exists(bus_path):
            env['DBUS_SESSION_BUS_ADDRESS'] = f'unix:path={bus_path}'
    if 'XDG_RUNTIME_DIR' not in env:
        env['XDG_RUNTIME_DIR'] = f'/run/user/{_UID}'

    cmd = ['spectacle', '-b', '-n', '-o', tmp]

    # ⚠️ CRITICAL: NO capture_output! Spectacle forks via D-Bus
    # and piping stdout/stderr kills the background child process.
    try:
        r = subprocess.run(cmd, timeout=15, env=env)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None

    if r.returncode != 0:
        return None

    # Spectacle пишет асинхронно — ждём файл
    if _wait_for_file(tmp, min_size=5000, timeout=12):
        try:
            with open(tmp, 'rb') as f:
                data = f.read()
            _clean_tmp(tmp)
            return data
        except Exception:
            return None

    return None


def _capture_kmsgrab():
    """
    kmsgrab — fallback для Wayland когда spectacle не работает.
    Требует sudo. Использует ffmpeg для конвертации.
    """
    tmp = TEMP_PNG
    _clean_tmp(tmp)

    # kmsgrab → ffmpeg → PNG
    # -i '' (пустая строка, НЕ '-i -' который читает stdin и висит!)
    cmd = (
        'sudo kmsgrab -i "" - '
        '| ffmpeg -y -f image_pipe -i - '
        f'-f image2 -update 1 {tmp}'
    )
    try:
        r = subprocess.run(cmd, shell=True, timeout=20,
                           capture_output=True)
        if r.returncode == 0 and _wait_for_file(tmp, min_size=5000, timeout=3):
            with open(tmp, 'rb') as f:
                data = f.read()
            _clean_tmp(tmp)
            return data
    except Exception:
        pass
    _clean_tmp(tmp)
    return None


def _capture_grim():
    """grim — для Sway/Hyprland Wayland. Читает в stdout."""
    try:
        result = subprocess.run(["grim", "-"], capture_output=True, timeout=10)
        if result.returncode == 0 and len(result.stdout) > 5000:
            return result.stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return None


def _convert_to_jpg(png_data, quality=85):
    """Конвертировать PNG → JPEG для меньшего размера по сети."""
    try:
        tmp_png = TEMP_PNG
        tmp_jpg = TEMP_JPG
        with open(tmp_png, 'wb') as f:
            f.write(png_data)

        r = subprocess.run(
            ['ffmpeg', '-y', '-i', tmp_png,
             '-q:v', str(quality // 10), tmp_jpg],
            capture_output=True, timeout=10
        )
        if r.returncode == 0 and os.path.exists(tmp_jpg):
            with open(tmp_jpg, 'rb') as f:
                jpg_data = f.read()
            _clean_tmp(tmp_jpg)
            _clean_tmp(tmp_png)
            return jpg_data
    except Exception:
        pass
    _clean_tmp(TEMP_PNG)
    _clean_tmp(TEMP_JPG)
    return None


# Порядок попыток: spectacle (KDE native) → kmsgrab (sudo) → grim (Sway)
CAPTURE_METHODS = [
    ("spectacle",  _capture_spectacle),
    ("kmsgrab",    _capture_kmsgrab),
    ("grim",       _capture_grim),
]


class P3RemoteHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(BASE_DIR), **kwargs)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        params = urllib.parse.parse_qs(parsed.query)

        if path == '/screenshot':
            fmt = params.get('format', ['png'])[0].lower()
            self.handle_screenshot(fmt)
        elif path == '/processes':
            self.handle_processes()
        elif path == '/status':
            self.handle_status()
        elif path == '/cmd':
            cmd = params.get('q', [''])[0]
            if cmd:
                self.handle_cmd_raw(cmd)
            else:
                self.send_json({"error": "use /cmd?q=your+command"}, 400)
        else:
            super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == '/cmd':
            self.handle_cmd()
        else:
            self.send_error(404, f"POST {path} not found")

    def handle_cmd(self):
        """Выполнить shell команду (POST) и вернуть результат."""
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
            cmd = data.get('cmd', '')
            cwd = data.get('cwd', str(BASE_DIR))
            timeout = data.get('timeout', 30)
            self.handle_cmd_raw(cmd, cwd, timeout)
        except Exception as e:
            self.send_json({"error": str(e)}, 500)

    def handle_cmd_raw(self, cmd, cwd=None, timeout=30):
        """Выполнить shell команду и вернуть результат."""
        try:
            if not cmd:
                self.send_json({"error": "no cmd provided"}, 400)
                return

            if cwd is None:
                cwd = str(BASE_DIR)

            result = subprocess.run(
                cmd, shell=True, capture_output=True, text=True,
                cwd=cwd, timeout=timeout
            )

            self.send_json({
                "stdout": result.stdout[-10000:],
                "stderr": result.stderr[-10000:],
                "returncode": result.returncode,
                "cmd": cmd,
            })

        except subprocess.TimeoutExpired:
            self.send_json({"error": f"timeout ({timeout}s)", "cmd": cmd}, 408)
        except Exception as e:
            self.send_json({"error": str(e)}, 500)

    def handle_screenshot(self, fmt='png'):
        """Сделать скриншот монитора. Возвращает PNG или JPEG."""
        png_data = None
        method_used = None
        errors = {}

        for name, func in CAPTURE_METHODS:
            try:
                data = func()
                if data and len(data) > 5000:
                    png_data = data
                    method_used = name
                    break
                else:
                    errors[name] = "no data or too small"
            except Exception as e:
                errors[name] = str(e)

        if not png_data:
            self.send_json({
                "error": "all screenshot methods failed",
                "methods_tried": errors,
                "hint": "For KDE Plasma Wayland, ensure spectacle is installed "
                        "and DBUS_SESSION_BUS_ADDRESS is set correctly"
            }, 500)
            return

        # Конвертируем формат если нужно
        if fmt in ('jpg', 'jpeg'):
            img_data = _convert_to_jpg(png_data)
            content_type = 'image/jpeg'
            if not img_data:
                img_data = png_data
                content_type = 'image/png'
                fmt = 'png'
        else:
            img_data = png_data
            content_type = 'image/png'

        size_kb = len(img_data) / 1024
        self.send_response(200)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(img_data)))
        self.send_header('X-Capture-Method', method_used)
        self.send_header('X-Image-Format', fmt)
        self.send_header('X-Image-Size-KB', f'{size_kb:.1f}')
        self.end_headers()
        self.wfile.write(img_data)

    def handle_processes(self):
        """Список процессов."""
        try:
            result = subprocess.run(["ps", "aux"], capture_output=True,
                                    text=True, timeout=5)
            lines = result.stdout.split('\n')[:100]
            self.send_json({"processes": lines})
        except Exception as e:
            self.send_json({"error": str(e)}, 500)

    def handle_status(self):
        """Статус системы."""
        try:
            status = {}
            try:
                r = subprocess.run(["nproc"], capture_output=True,
                                   text=True, timeout=2)
                status["cpu_cores"] = r.stdout.strip()
            except Exception:
                pass
            try:
                r = subprocess.run(["free", "-h"], capture_output=True,
                                   text=True, timeout=2)
                status["memory"] = r.stdout.strip()
            except Exception:
                pass
            try:
                r = subprocess.run(
                    ["nvidia-smi",
                     "--query-gpu=name,memory.used,memory.total,utilization.gpu",
                     "--format=csv,noheader"],
                    capture_output=True, text=True, timeout=5
                )
                status["gpu"] = r.stdout.strip()
            except Exception:
                status["gpu"] = "nvidia-smi not found"
            try:
                r = subprocess.run(["df", "-h", "/"], capture_output=True,
                                   text=True, timeout=2)
                status["disk"] = r.stdout.strip()
            except Exception:
                pass
            try:
                r = subprocess.run(["uptime"], capture_output=True,
                                   text=True, timeout=2)
                status["uptime"] = r.stdout.strip()
            except Exception:
                pass
            status["session_type"] = os.environ.get('XDG_SESSION_TYPE', 'unknown')
            self.send_json(status)
        except Exception as e:
            self.send_json({"error": str(e)}, 500)

    def send_json(self, data, code=200):
        body = json.dumps(data, ensure_ascii=False, indent=2).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        msg = format % args if args else format
        if any(k in msg for k in ['/screenshot', '/cmd', '/processes', '/status']):
            sys.stderr.write(f"[P3] {msg}\n")
            sys.stderr.flush()


def main():
    port = 8080
    os.chdir(str(BASE_DIR))

    print(f"P3 Remote Control Server v{VERSION} — KDE Plasma 6 Wayland")
    print(f"=" * 50)

    # Pre-flight
    has_spectacle = os.path.exists('/usr/bin/spectacle')
    has_grim = os.path.exists('/usr/bin/grim')
    has_kmsgrab = os.path.exists('/usr/bin/kmsgrab')
    has_ffmpeg = os.path.exists('/usr/bin/ffmpeg')
    session = os.environ.get('XDG_SESSION_TYPE', 'unknown')
    bus = os.environ.get('DBUS_SESSION_BUS_ADDRESS', 'not set')

    print(f"  spectacle:  {'YES' if has_spectacle else 'NO'}")
    print(f"  grim:       {'YES' if has_grim else 'NO'}")
    print(f"  kmsgrab:    {'YES' if has_kmsgrab else 'NO'}")
    print(f"  ffmpeg:     {'YES' if has_ffmpeg else 'NO'}")
    print(f"  session:    {session}")
    print(f"  D-Bus:      {'OK' if 'unix:' in bus else 'WARN'} {bus[:50]}")

    # Clean stale root-owned temp files
    for p in [TEMP_PNG, TEMP_JPG,
              '/tmp/p3_screenshot.png', '/tmp/p3_frame.png', '/tmp/p3_frame.jpg']:
        _clean_tmp(p)

    print(f"=" * 50)
    print(f"  GET  /              — file browser")
    print(f"  GET  /screenshot    — screenshot (PNG)")
    print(f"  GET  /screenshot?format=jpg — JPEG")
    print(f"  GET  /processes     — process list")
    print(f"  GET  /status        — system status")
    print(f"  POST /cmd           — run command")
    print(f"=" * 50)

    server = http.server.HTTPServer(('0.0.0.0', port), P3RemoteHandler)
    print(f"\nListening on http://0.0.0.0:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()


if __name__ == '__main__':
    main()
