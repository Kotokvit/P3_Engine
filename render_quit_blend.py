import bpy
import os

# Inspect scene contents
print("=== INSPECTING QUIT.BLEND SCENE ===")
for obj in bpy.data.objects:
    print(f"Object: {obj.name}, Type: {obj.type}, Location: {obj.location}")
    if obj.type == 'MESH':
        print(f"  - Vertices: {len(obj.data.vertices)}, Faces: {len(obj.data.polygons)}")

# Ensure a camera exists to frame all objects
if not bpy.context.scene.camera:
    bpy.ops.object.camera_add(location=(5, -7, 4), rotation=(1.1, 0, 0.65))
    bpy.context.scene.camera = bpy.context.object

# Add a light if not present
if not any(o.type == 'LIGHT' for o in bpy.data.objects):
    bpy.ops.object.light_add(type='SUN', location=(5, -5, 10))

# Frame all objects in view
bpy.ops.object.select_all(action='SELECT')
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        for region in area.regions:
            if region.type == 'WINDOW':
                override = {'area': area, 'region': region, 'scene': bpy.context.scene}
                try:
                    bpy.ops.view3d.camera_to_view_selected(override)
                except Exception:
                    pass

# Render preview image
bpy.context.scene.render.engine = 'CYCLES'
bpy.context.scene.cycles.samples = 32
bpy.context.scene.render.resolution_x = 1280
bpy.context.scene.render.resolution_y = 720
output_png = os.path.join(os.getcwd(), "quit_blend_render.png")
bpy.context.scene.render.filepath = output_png
bpy.ops.render.render(write_still=True)
print(f"Rendered snapshot saved to {output_png}")
