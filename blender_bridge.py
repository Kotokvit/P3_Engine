import bpy
import os
import time

# P3 Engine - Blender AI Bridge Server
PORT = 9999
HOST = "localhost"

def setup_scene():
    # Clear existing mesh objects
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    
    # 3/4 Isometric Perspective Camera
    bpy.ops.object.camera_add(location=(6.0, -8.0, 5.0), rotation=(1.05, 0.0, 0.65))
    bpy.context.scene.camera = bpy.context.object
    
    # Sun and Fill Light
    bpy.ops.object.light_add(type='SUN', location=(10, -10, 15))
    sun = bpy.context.object
    sun.data.energy = 3.5
    
    bpy.ops.object.light_add(type='POINT', location=(-5, 5, 8))
    point = bpy.context.object
    point.data.energy = 500.0
    
    print("[P3-Blender] Bridge Scene Ready!")

def reload_p3_models(car_path="car.obj", track_path="track.obj"):
    cwd = os.getcwd()
    car_full = os.path.join(cwd, car_path)
    track_full = os.path.join(cwd, track_path)
    
    # Remove previous imported meshes
    for obj in list(bpy.data.objects):
        if obj.type == 'MESH':
            bpy.data.objects.remove(obj, do_unlink=True)
            
    if os.path.exists(car_full):
        bpy.ops.wm.obj_import(filepath=car_full)
        print(f"[P3-Blender] Imported {car_full}")
        
    if os.path.exists(track_full):
        bpy.ops.wm.obj_import(filepath=track_full)
        print(f"[P3-Blender] Imported {track_full}")

def capture_viewport(output_path="render_preview.png"):
    bpy.context.scene.render.engine = 'CYCLES'  # Works perfectly in background / CPU / headless mode
    bpy.context.scene.cycles.samples = 16       # Ultra fast preview render
    bpy.context.scene.render.filepath = os.path.join(os.getcwd(), output_path)
    bpy.context.scene.render.resolution_x = 1280
    bpy.context.scene.render.resolution_y = 720
    bpy.ops.render.render(write_still=True)
    print(f"[P3-Blender] Render snapshot saved to {output_path}")

if __name__ == "__main__":
    setup_scene()
    reload_p3_models()
    capture_viewport()
