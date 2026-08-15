#!/usr/bin/env python3
"""
P³ Remote Control Server — даёт AI полный доступ к твоему ПК.
Запуск: python3 p3_remote.py
Порт: 8080 (заменяет http.server)

Endpoints:
  GET  /              — файловый браузер (как http.server)
  GET  /src/foo.zig   — чтение файлов
  POST /cmd           — выполнить команду → {stdout, stderr, returncode}
  GET  /screenshot     — скриншот монитора → PNG
  GET  /processes      — список процессов
  GET  /status         — статус системы (CPU, RAM, GPU)
"""

import http.server
import subprocess
import json
import os
import sys
import signal
import urllib.parse
from pathlib import Path

BASE_DIR = Path.cwd()

class P3RemoteHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(BASE_DIR), **kwargs)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == '/screenshot':
            self.handle_screenshot()
        elif path == '/processes':
            self.handle_processes()
        elif path == '/status':
            self.handle_status()
        else:
            # Default: serve files
            super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == '/cmd':
            self.handle_cmd()
        else:
            self.send_error(404, f"POST {path} not found")

    def handle_cmd(self):
        """Выполнить shell команду и вернуть результат."""
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
            cmd = data.get('cmd', '')
            cwd = data.get('cwd', str(BASE_DIR))
            timeout = data.get('timeout', 30)

            if not cmd:
                self.send_json({"error": "no cmd provided"}, 400)
                return

            result = subprocess.run(
                cmd, shell=True, capture_output=True, text=True,
                cwd=cwd, timeout=timeout
            )

            self.send_json({
                "stdout": result.stdout[-10000:],  # Trim large output
                "stderr": result.stderr[-10000:],
                "returncode": result.returncode,
                "cmd": cmd,
            })

        except subprocess.TimeoutExpired:
            self.send_json({"error": f"timeout ({timeout}s)", "cmd": cmd}, 408)
        except Exception as e:
            self.send_json({"error": str(e)}, 500)

    def handle_screenshot(self):
        """Сделать скриншот и вернуть PNG."""
        try:
            # Попробуем разные инструменты
            screenshot_tools = [
                # Wayland (cachyos likely uses Hyprland/Sway)
                ["grim", "-", ],  # grim outputs to stdout
                # X11
                ["scrot", "-"],  # scrot to stdout
                # GNOME
                ["gnome-screenshot", "-f", "/tmp/p3_screenshot.png"],
                # ImageMagick
                ["import", "-window", "root", "/tmp/p3_screenshot.png"],
            ]

            png_data = None

            # Try grim first (Wayland) — reads from stdout
            try:
                result = subprocess.run(["grim", "-"], capture_output=True, timeout=5)
                if result.returncode == 0 and len(result.stdout) > 100:
                    png_data = result.stdout
            except (FileNotFoundError, subprocess.TimeoutExpired):
                pass

            # Try scrot (X11)
            if not png_data:
                try:
                    tmp = "/tmp/p3_screenshot.png"
                    result = subprocess.run(["scrot", tmp], capture_output=True, timeout=5)
                    if result.returncode == 0:
                        with open(tmp, 'rb') as f:
                            png_data = f.read()
                        os.unlink(tmp)
                except (FileNotFoundError, subprocess.TimeoutExpired):
                    pass

            # Try gnome-screenshot
            if not png_data:
                try:
                    tmp = "/tmp/p3_screenshot.png"
                    result = subprocess.run(["gnome-screenshot", "-f", tmp], capture_output=True, timeout=5)
                    if result.returncode == 0:
                        with open(tmp, 'rb') as f:
                            png_data = f.read()
                        os.unlink(tmp)
                except (FileNotFoundError, subprocess.TimeoutExpired):
                    pass

            # Try xdg-desktop-portal (Wayland Screenshot portal)
            if not png_data:
                try:
                    # Use dbus-send for portal screenshot
                    tmp = "/tmp/p3_screenshot.png"
                    result = subprocess.run(
                        ["dbus-send", "--session", "--print-reply",
                         "--type=method_call",
                         "/org/freedesktop/portal/desktop",
                         "org.freedesktop.portal.Screenshot.Screenshot",
                         "string:org.freedesktop.portal.Screenshot",
                         "dict:string:string:interactive,b"],
                        capture_output=True, timeout=5
                    )
                except (FileNotFoundError, subprocess.TimeoutExpired):
                    pass

            if png_data:
                self.send_response(200)
                self.send_header('Content-Type', 'image/png')
                self.send_header('Content-Length', str(len(png_data)))
                self.end_headers()
                self.wfile.write(png_data)
            else:
                self.send_json({"error": "no screenshot tool found. Install: grim (wayland) or scrot (x11)"}, 500)

        except Exception as e:
            self.send_json({"error": str(e)}, 500)

    def handle_processes(self):
        """Список процессов."""
        try:
            result = subprocess.run(["ps", "aux"], capture_output=True, text=True, timeout=5)
            lines = result.stdout.split('\n')[:100]  # Top 100
            self.send_json({"processes": lines})
        except Exception as e:
            self.send_json({"error": str(e)}, 500)

    def handle_status(self):
        """Статус системы."""
        try:
            status = {}

            # CPU
            try:
                r = subprocess.run(["nproc"], capture_output=True, text=True, timeout=2)
                status["cpu_cores"] = r.stdout.strip()
            except:
                pass

            # RAM
            try:
                r = subprocess.run(["free", "-h"], capture_output=True, text=True, timeout=2)
                status["memory"] = r.stdout.strip()
            except:
                pass

            # GPU
            try:
                r = subprocess.run(["nvidia-smi", "--query-gpu=name,memory.used,memory.total,utilization.gpu",
                                   "--format=csv,noheader"],
                                  capture_output=True, text=True, timeout=5)
                status["gpu"] = r.stdout.strip()
            except:
                status["gpu"] = "nvidia-smi not found"

            # Disk
            try:
                r = subprocess.run(["df", "-h", "/"], capture_output=True, text=True, timeout=2)
                status["disk"] = r.stdout.strip()
            except:
                pass

            # Uptime
            try:
                r = subprocess.run(["uptime"], capture_output=True, text=True, timeout=2)
                status["uptime"] = r.stdout.strip()
            except:
                pass

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
        # Quiet logging
        pass


def main():
    port = 8080
    os.chdir(str(BASE_DIR))
    server = http.server.HTTPServer(('0.0.0.0', port), P3RemoteHandler)
    print(f"P³ Remote Control Server on http://0.0.0.0:{port}")
    print(f"  GET  /            — file browser")
    print(f"  GET  /screenshot   — monitor screenshot (PNG)")
    print(f"  GET  /processes    — process list")
    print(f"  GET  /status       — system status (CPU/RAM/GPU)")
    print(f"  POST /cmd          — run command {{\"cmd\": \"...\"}}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()


if __name__ == '__main__':
    main()
