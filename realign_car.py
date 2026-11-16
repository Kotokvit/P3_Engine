import bpy
import bmesh
import math
import os

# Align quit.blend car to standard OpenGL/Raylib ground orientation
def align_car_mesh():
    export_obj_path = os.path.join(os.getcwd(), "car_custom.obj")
    
    # Select all car mesh parts
    bpy.ops.object.select_all(action='SELECT')
    floor = bpy.data.objects.get("Studio_Floor")
    if floor:
        floor.select_set(False)
    
    # Export with Y Forward, Z Up
    bpy.ops.wm.obj_export(
        filepath=export_obj_path,
        export_selected_objects=True,
        forward_axis='Y',
        up_axis='Z',
        apply_modifiers=True
    )
    print(f"[P3] Re-exported oriented model to {export_obj_path}")

if __name__ == "__main__":
    align_car_mesh()
