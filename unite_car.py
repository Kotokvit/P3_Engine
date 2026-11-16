import bpy
import os

def unite_car_and_add_glass():
    # 1. Select all car parts except Floor/Lights/Camera
    bpy.ops.object.select_all(action='DESELECT')
    
    car_parts = []
    for obj in bpy.data.objects:
        if obj.type == 'MESH' and obj.name != "Studio_Floor":
            obj.select_set(True)
            car_parts.append(obj)
            
    # Set Supercar_Body as the active object
    body = bpy.data.objects.get("Supercar_Body")
    if body:
        bpy.context.view_layer.objects.active = body
    else:
        bpy.context.view_layer.objects.active = car_parts[0]

    # Apply all visual transforms (Position, Rotation, Scale) so parts freeze in their correct places
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    print("[P3-Blender] Applied transforms to all vehicle parts.")

    # Export unified car OBJ with all modifiers applied
    export_obj_path = os.path.join(os.getcwd(), "car_custom.obj")
    bpy.ops.wm.obj_export(
        filepath=export_obj_path,
        export_selected_objects=True,
        forward_axis='Y',
        up_axis='Z',
        apply_modifiers=True
    )
    print(f"[P3-Blender] Exported solid vehicle model to {export_obj_path}")

if __name__ == "__main__":
    unite_car_and_add_glass()
