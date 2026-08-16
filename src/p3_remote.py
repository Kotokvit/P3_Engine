#!/usr/bin/env python3
"""
P³ Remote Control Server v2 — даёт AI полный доступ к твоему ПК.
Запуск: python3 p3_remote.py
Порт: 8080

Endpoints:
  GET  /              — файловый браузер
  GET  /screenshot     — скриншот монитора → PNG (spectacle на KDE!)
  GET  /processes      — список процессов
  GET  /status         — статус системы (CPU, RAM, GPU)
  POST /cmd            — выполнить команду → {stdout, stderr, returncode}
  GET  /cmd?q=command  — то же через GET (для ngrok/funnel)
"""

import http.server
import subprocess
import json
import os
import sys
import time
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
        params = urllib.parse.parse_qs(parsed.query)

        if path == '/screenshot':
            self.handle_screenshot()
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

    def handle_screenshot(self):
        """Сделать скриншот и вернуть PNG."""
        try:
            env = {**os.environ, 'XDG_RUNTIME_DIR': f'/run/user/{os.getuid()}'}
            png_data = None
            tmp = "/tmp/p3_screenshot.png"

            def _clean(path):
                try:
                    if os.path.exists(path): os.unlink(path)
                except PermissionError:
                    subprocess.run(['sudo', '-n', 'rm', '-f', path], timeout=3)

            # Method 1: spectacle (KDE Plasma 5/6 Wayland)
            # CRITICAL: NO capture_output! Spectacle forks D-Bus process,
            # and piping stdout/stderr kills the child before it writes the file.
            _clean(tmp)
            try:
                subprocess.run(['spectacle', '-b', '-n', '-o', tmp], timeout=10, env=env)
                for _ in range(10):  # wait up to 2s
                    if os.path.exists(tmp) and os.path.getsize(tmp) > 5000:
                        break
                    time.sleep(0.2)
                if os.path.exists(tmp) and os.path.getsize(tmp) > 5000:
                    with open(tmp, 'rb') as f:
                        png_data = f.read()
                    _clean(tmp)
            except (FileNotFoundError, subprocess.TimeoutExpired):
                pass

            # Method 2: grim (wlroots - Sway/Hyprland)
            if not png_data:
                try:
                    result = subprocess.run(["grim", "-"], capture_output=True, timeout=5)
                    if result.returncode == 0 and len(result.stdout) > 5000:
                        png_data = result.stdout
                except (FileNotFoundError, subprocess.TimeoutExpired):
                    pass

            if png_data:
                self.send_response(200)
                self.send_header('Content-Type', 'image/png')
                self.send_header('Content-Length', str(len(png_data)))
                self.end_headers()
                self.wfile.write(png_data)
            else:
                self.send_json({"error": "screenshot failed (tried: spectacle, grim)"}, 500)
        except Exception as e:
            self.send_json({"error": str(e)}, 500)

    def handle_processes(self):
        try:
            result = subprocess.run(["ps", "aux"], capture_output=True, text=True, timeout=5)
            lines = result.stdout.split('\n')[:100]
            self.send_json({"processes": lines})
        except Exception as e:
            self.send_json({"error": str(e)}, 500)

    def handle_status(self):
        try:
            status = {}
            try:
                r = subprocess.run(["nproc"], capture_output=True, text=True, timeout=2)
                status["cpu_cores"] = r.stdout.strip()
            except: pass
            try:
                r = subprocess.run(["free", "-h"], capture_output=True, text=True, timeout=2)
                status["memory"] = r.stdout.strip()
            except: pass
            try:
                r = subprocess.run(["nvidia-smi", "--query-gpu=name,memory.used,memory.total,utilization.gpu",
                                   "--format=csv,noheader"],
                                  capture_output=True, text=True, timeout=5)
                status["gpu"] = r.stdout.strip()
            except:
                status["gpu"] = "nvidia-smi not found"
            try:
                r = subprocess.run(["df", "-h", "/"], capture_output=True, text=True, timeout=2)
                status["disk"] = r.stdout.strip()
            except: pass
            try:
                r = subprocess.run(["uptime"], capture_output=True, text=True, timeout=2)
                status["uptime"] = r.stdout.strip()
            except: pass
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
        pass


def main():
    port = 8080
    os.chdir(str(BASE_DIR))
    server = http.server.HTTPServer(('0.0.0.0', port), P3RemoteHandler)
    print(f"P³ Remote Control Server v2 on http://0.0.0.0:{port}")
    print(f"  GET  /            — file browser")
    print(f"  GET  /screenshot   — monitor screenshot (PNG via spectacle)")
    print(f"  GET  /processes    — process list")
    print(f"  GET  /status       — system status (CPU/RAM/GPU)")
    print(f"  POST /cmd          — run command")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()


if __name__ == '__main__':
    main()
