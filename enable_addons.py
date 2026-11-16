import bpy

# Core professional modeling toolkits inside Blender
addons = [
    "mesh_looptools",          # Circle/bridge/relax mesh topology
    "add_mesh_extra_objects",  # Gears, mechanical pipes, complex math solids
    "add_curve_extra_objects", # Bevel roads, profiles, wires
    "node_wrangler",           # PBR shaders quick setup
]

for addon in addons:
    try:
        bpy.ops.preferences.addon_enable(module=addon)
        print(f"[OK] Enabled addon: {addon}")
    except Exception as e:
        print(f"[WARN] Addon {addon}: {e}")

try:
    bpy.ops.wm.save_userpref()
    print("[P3] Preferences saved successfully!")
except Exception as e:
    print(f"[P3] {e}")
