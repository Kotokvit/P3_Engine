import bpy
import os

def apply_cyberpunk_materials_and_export():
    # 1. Helper function for creating PBR materials
    def create_pbr_mat(name, base_color, roughness=0.1, metallic=0.0, emission_color=None, emission_strength=0.0, alpha=1.0):
        mat = bpy.data.materials.get(name) or bpy.data.materials.new(name=name)
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        bsdf = nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs['Base Color'].default_value = base_color
            bsdf.inputs['Roughness'].default_value = roughness
            bsdf.inputs['Metallic'].default_value = metallic
            if 'Alpha' in bsdf.inputs:
                bsdf.inputs['Alpha'].default_value = alpha
            if 'Emission Color' in bsdf.inputs:
                if emission_color:
                    bsdf.inputs['Emission Color'].default_value = emission_color
                    bsdf.inputs['Emission Strength'].default_value = emission_strength
            elif 'Emission' in bsdf.inputs and emission_color:
                bsdf.inputs['Emission'].default_value = emission_color
                if 'Emission Strength' in bsdf.inputs:
                    bsdf.inputs['Emission Strength'].default_value = emission_strength
        return mat

    # Materials definition
    graphite_metallic = create_pbr_mat("Cyber_Graphite", (0.04, 0.04, 0.05, 1.0), roughness=0.15, metallic=0.92)
    cyan_neon = create_pbr_mat("Neon_Cyan_LED", (0.0, 0.9, 1.0, 1.0), roughness=0.0, emission_color=(0.0, 0.9, 1.0, 1.0), emission_strength=8.0)
    red_neon = create_pbr_mat("Neon_Red_Taillight", (1.0, 0.02, 0.05, 1.0), roughness=0.0, emission_color=(1.0, 0.02, 0.05, 1.0), emission_strength=8.0)
    carbon_fiber = create_pbr_mat("Carbon_Aero", (0.02, 0.02, 0.02, 1.0), roughness=0.25, metallic=0.3)
    tinted_glass = create_pbr_mat("Tinted_Cockpit_Glass", (0.01, 0.02, 0.03, 0.4), roughness=0.05, metallic=0.1, alpha=0.35)
    tire_rubber = create_pbr_mat("Tire_Grip_Rubber", (0.02, 0.02, 0.02, 1.0), roughness=0.65, metallic=0.0)
    alloy_spokes = create_pbr_mat("Alloy_Silver_Spokes", (0.85, 0.85, 0.9, 1.0), roughness=0.1, metallic=0.98)

    # 2. Assign materials to matching object names
    for obj in bpy.data.objects:
        if obj.type != 'MESH':
            continue
        obj.data.materials.clear()
        name = obj.name
        
        if "Headlight" in name:
            obj.data.materials.append(cyan_neon)
        elif "Rear_Light" in name:
            obj.data.materials.append(red_neon)
        elif "Windshield" in name or "SideWindow" in name:
            obj.data.materials.append(tinted_glass)
        elif "Tire" in name or "Wheel_Arch" in name:
            obj.data.materials.append(tire_rubber)
        elif "Spoke" in name or "Wheel_Hub" in name:
            obj.data.materials.append(alloy_spokes)
        elif "Wing" in name or "Diffuser" in name or "Splitter" in name or "Air_Intake" in name:
            obj.data.materials.append(carbon_fiber)
        else: # Supercar_Body, Mirrors, etc.
            obj.data.materials.append(graphite_metallic)

    # 3. Enhance Studio Scene for Rendering
    dark_floor = create_pbr_mat("Wet_Asphalt_Floor", (0.03, 0.03, 0.035, 1.0), roughness=0.12, metallic=0.05)
    floor = bpy.data.objects.get("Studio_Floor")
    if floor:
        floor.data.materials.clear()
        floor.data.materials.append(dark_floor)

    # 4. Render High-Quality Preview
    bpy.context.scene.render.engine = 'CYCLES'
    bpy.context.scene.cycles.samples = 64
    bpy.context.scene.render.resolution_x = 1280
    bpy.context.scene.render.resolution_y = 720
    output_png = os.path.join(os.getcwd(), "cyber_supercar_render.png")
    bpy.context.scene.render.filepath = output_png
    bpy.ops.render.render(write_still=True)
    print(f"[P3-Blender] Cyberpunk render saved to {output_png}")

    # 5. Export clean .OBJ for P³ Engine
    export_obj_path = os.path.join(os.getcwd(), "car_custom.obj")
    # Deselect floor before export
    bpy.ops.object.select_all(action='SELECT')
    if floor:
        floor.select_set(False)
    
    bpy.ops.wm.obj_export(filepath=export_obj_path, export_selected_objects=True)
    print(f"[P3-Blender] Exported game-ready model to {export_obj_path}")

if __name__ == "__main__":
    apply_cyberpunk_materials_and_export()
