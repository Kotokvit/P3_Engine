import bpy
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import os

PORT = 8081

class BlenderCommandHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)
        
        try:
            req = json.loads(post_data.decode('utf-8'))
            cmd = req.get('cmd', '')
            
            # Execute on main thread queue
            result = {"status": "ok", "message": f"Executed: {cmd}"}
            
            if cmd == "reload":
                cwd = "/home/vitalij/Стільниця/P3_Engine_repo"
                car_path = os.path.join(cwd, "car.obj")
                # Remove old meshes
                for obj in list(bpy.data.objects):
                    if obj.type == 'MESH':
                        bpy.data.objects.remove(obj, do_unlink=True)
                if os.path.exists(car_path):
                    bpy.ops.wm.obj_import(filepath=car_path)
                    result["details"] = "Reloaded car.obj into live viewport"
            elif cmd == "get_info":
                objs = [obj.name for obj in bpy.data.objects]
                result["objects"] = objs
                act = bpy.context.view_layer.objects.active
                result["active_object"] = act.name if act else None
                result["mode"] = bpy.context.mode
                
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(result).encode('utf-8'))
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(e).encode('utf-8'))
            
    def log_message(self, format, *args):
        return  # Suppress default server logs

def start_server():
    server = HTTPServer(('localhost', PORT), BlenderCommandHandler)
    print(f"[P3-AI] Live Blender Bridge running on http://localhost:{PORT}")
    server.serve_forever()

# Run server in daemon background thread inside Blender
thread = threading.Thread(target=start_server, daemon=True)
thread.start()
print("[P3-AI] Background Bridge listener active!")
