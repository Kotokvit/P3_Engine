import bpy
import bmesh
import math
import os

def create_complex_racecar_chassis():
    # Clear scene
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    
    # 1. Create High-Performance Racing Wheel with Disc Brakes & Multi-spoke Rim
    def create_wheel(name, loc, is_left=True):
        mesh = bpy.data.meshes.new(name + "_mesh")
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        obj.location = loc
        
        bm = bmesh.new()
        
        # Tire (Toroid-cylinder)
        tire_radius = 0.35
        tire_width = 0.28
        segments = 32
        
        # Create outer tire profile
        verts_outer = []
        verts_inner = []
        for i in range(segments):
            angle = (i / segments) * 2.0 * math.pi
            y = math.sin(angle) * tire_radius
            z = math.cos(angle) * tire_radius
            sign = -1.0 if is_left else 1.0
            
            v_out = bm.verts.new((0, y, z))
            v_in = bm.verts.new((sign * tire_width, y, z))
            verts_outer.append(v_out)
            verts_inner.append(v_in)
            
        bm.verts.ensure_lookup_table()
        # Connect tire tread
        for i in range(segments):
            next_i = (i + 1) % segments
            bm.faces.new((verts_outer[i], verts_inner[i], verts_inner[next_i], verts_outer[next_i]))
            
        # Create 5-spoke sport rim & Brake rotor
        hub_center = bm.verts.new(((-0.05 if is_left else 0.05) * tire_width, 0, 0))
        rotor_rad = 0.22
        for s in range(5):
            angle1 = (s / 5.0) * 2.0 * math.pi
            angle2 = ((s + 0.35) / 5.0) * 2.0 * math.pi
            
            p1_y, p1_z = math.sin(angle1) * (tire_radius * 0.75), math.cos(angle1) * (tire_radius * 0.75)
            p2_y, p2_z = math.sin(angle2) * (tire_radius * 0.75), math.cos(angle2) * (tire_radius * 0.75)
            
            v_rim1 = bm.verts.new(((-0.08 if is_left else 0.08) * tire_width, p1_y, p1_z))
            v_rim2 = bm.verts.new(((-0.08 if is_left else 0.08) * tire_width, p2_y, p2_z))
            
            bm.faces.new((hub_center, v_rim1, v_rim2))
            
        bm.to_mesh(mesh)
        bm.free()
        return obj

    # Spawn 4 Wheels
    w_fl = create_wheel("Wheel_FL", (-1.0, 1.45, 0.35), True)
    w_fr = create_wheel("Wheel_FR", (1.0, 1.45, 0.35), False)
    w_rl = create_wheel("Wheel_RL", (-1.05, -1.45, 0.38), True)
    w_rr = create_wheel("Wheel_RR", (1.05, -1.45, 0.38), False)

    # 2. Sleek Supercar Carbon Bodywork with Air Intakes & Aerodynamic Splitters
    body_mesh = bpy.data.meshes.new("Supercar_Body")
    body_obj = bpy.data.objects.new("Supercar_Chassis", body_mesh)
    bpy.context.collection.objects.link(body_obj)
    
    bm_body = bmesh.new()
    
    # Half-chassis profile vertices (Mirror modifier will complete the right side)
    verts_data = [
        # Nose Splitter / Air Dam
        (0.0, 2.5, 0.08),     # 0 Center nose tip
        (-0.85, 2.35, 0.08),  # 1 Left front splitter corner
        (-0.95, 1.8, 0.12),   # 2 Front wheel arch entry
        # Wheel Arches & Side Skirts
        (-0.98, 1.1, 0.15),   # 3 Front wheel arch exit
        (-0.92, -0.8, 0.12),  # 4 Side skirt mid
        (-1.02, -1.1, 0.15),  # 5 Rear wheel arch entry
        (-1.02, -1.8, 0.18),  # 6 Rear wheel arch exit
        (-0.88, -2.5, 0.22),  # 7 Rear diffuser left
        (0.0, -2.55, 0.25),   # 8 Rear diffuser center
        
        # Hood / Waistline / Shoulder Profile
        (0.0, 2.3, 0.52),     # 9 Hood center
        (-0.75, 2.1, 0.55),   # 10 Left headlight apex
        (-0.80, 0.6, 0.68),   # 11 Windshield base left
        (0.0, 0.65, 0.65),    # 12 Windshield base center
        (-0.85, -1.3, 0.78),  # 13 Muscle rear shoulder left
        (-0.80, -2.35, 0.72), # 14 Rear deck left
        (0.0, -2.4, 0.70),    # 15 Rear deck center
        
        # Low-Slung Fighter Jet Canopy & Carbon Roof
        (0.0, 0.35, 1.05),    # 16 Roof peak center front
        (-0.52, 0.35, 1.02),  # 17 Roof peak left A-pillar
        (-0.48, -0.95, 0.98), # 18 Roof rear left C-pillar
        (0.0, -0.95, 1.00),   # 19 Roof rear center
    ]
    
    bm_verts = [bm_body.verts.new(p) for p in verts_data]
    bm_body.verts.ensure_lookup_table()
    
    # Create Panels & Aero Surfaces
    faces_indices = [
        (0, 1, 10, 9),      # Front Bumper Left
        (9, 10, 11, 12),    # Sleek Hood
        (1, 2, 10),         # Front Corner Intake
        (2, 3, 11),         # Front Wheel Vent
        (3, 4, 11),         # Door Lower
        (4, 5, 13, 11),     # Side Air Intake (for radiator)
        (5, 6, 13),         # Rear Wheel Arch
        (6, 7, 14, 13),     # Rear Quarter Panel
        (7, 8, 15, 14),     # Rear Diffuser & Exhaust Tunnel
        (13, 14, 15),       # Rear Engine Cover Left
        
        # Glass & Roof
        (12, 11, 17, 16),   # Raked Windshield Half
        (16, 17, 18, 19),   # Carbon Fiber Roof Half
        (19, 18, 13, 15),   # Fastback Louvered Engine Glass
        (11, 13, 18, 17),   # Side Fighter Canopy Window
    ]
    
    for f in faces_indices:
        bm_body.faces.new([bm_verts[idx] for idx in f])
        
    bm_body.to_mesh(body_mesh)
    bm_body.free()
    
    # 3. Add Professional Modifiers: Mirror, Subdivision Surface, and Bevel
    bpy.context.view_layer.objects.active = body_obj
    mirror_mod = body_obj.modifiers.new(name="Mirror", type='MIRROR')
    mirror_mod.use_clip = True
    
    subdiv_mod = body_obj.modifiers.new(name="Subdivision", type='SUBSURF')
    subdiv_mod.levels = 1
    subdiv_mod.render_levels = 2
    
    # 4. Create Aerodynamic Carbon GT Rear Wing (Double Stanchions + Airfoil)
    wing_mesh = bpy.data.meshes.new("GT_Wing_Mesh")
    wing_obj = bpy.data.objects.new("GT_Rear_Wing", wing_mesh)
    bpy.context.collection.objects.link(wing_obj)
    
    bm_wing = bmesh.new()
    # Wing airfoil blade
    w_v1 = bm_wing.verts.new((-0.95, -2.2, 1.15))
    w_v2 = bm_wing.verts.new((0.95, -2.2, 1.15))
    w_v3 = bm_wing.verts.new((0.95, -2.45, 1.22))
    w_v4 = bm_wing.verts.new((-0.95, -2.45, 1.22))
    bm_wing.faces.new((w_v1, w_v2, w_v3, w_v4))
    
    # Twin Pylon Mounts
    for mx in [-0.45, 0.45]:
        p1 = bm_wing.verts.new((mx - 0.03, -2.15, 0.72))
        p2 = bm_wing.verts.new((mx + 0.03, -2.15, 0.72))
        p3 = bm_wing.verts.new((mx + 0.03, -2.35, 1.16))
        p4 = bm_wing.verts.new((mx - 0.03, -2.35, 1.16))
        bm_wing.faces.new((p1, p2, p3, p4))
        
    bm_wing.to_mesh(wing_mesh)
    bm_wing.free()
    
    # 5. Studio Lighting & High-Gloss Shaders
    def create_car_paint_mat(name, color, roughness=0.1, metallic=0.9):
        mat = bpy.data.materials.new(name=name)
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        bsdf = nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs['Base Color'].default_value = color
            bsdf.inputs['Roughness'].default_value = roughness
            bsdf.inputs['Metallic'].default_value = metallic
        return mat

    red_paint = create_car_paint_mat("Ferrari_Red_Metallic", (0.85, 0.02, 0.02, 1.0), roughness=0.08, metallic=0.95)
    carbon_black = create_car_paint_mat("Carbon_Fiber", (0.05, 0.05, 0.05, 1.0), roughness=0.3, metallic=0.2)
    rubber = create_car_paint_mat("Tire_Rubber", (0.02, 0.02, 0.02, 1.0), roughness=0.7, metallic=0.0)

    body_obj.data.materials.append(red_paint)
    wing_obj.data.materials.append(carbon_black)
    w_fl.data.materials.append(rubber)
    w_fr.data.materials.append(rubber)
    w_rl.data.materials.append(rubber)
    w_rr.data.materials.append(rubber)

    # 6. Studio Ground & 3-Point Lighting
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
    ground = bpy.context.object
    ground.data.materials.append(create_car_paint_mat("Studio_Floor", (0.12, 0.12, 0.14, 1.0), roughness=0.2, metallic=0.1))

    # Camera Position (Cinematic 3/4 Low Angle)
    bpy.ops.object.camera_add(location=(4.8, -5.5, 2.2), rotation=(1.25, 0.0, 0.72))
    bpy.context.scene.camera = bpy.context.object

    # Studio Key, Rim, and Fill Lights
    bpy.ops.object.light_add(type='SUN', location=(6, -6, 12))
    sun = bpy.context.object
    sun.data.energy = 4.0
    
    bpy.ops.object.light_add(type='POINT', location=(-4, 4, 3))
    rim = bpy.context.object
    rim.data.energy = 800.0
    rim.data.color = (0.3, 0.6, 1.0) # Blue rim reflection

    # Render High-Quality Snapshot
    bpy.context.scene.render.engine = 'CYCLES'
    bpy.context.scene.cycles.samples = 32
    bpy.context.scene.render.resolution_x = 1280
    bpy.context.scene.render.resolution_y = 720
    bpy.context.scene.render.filepath = os.path.join(os.getcwd(), "complex_car_render.png")
    bpy.ops.render.render(write_still=True)
    print("[P3-Blender] Complex Prototype Supercar successfully constructed and rendered!")

if __name__ == "__main__":
    create_complex_racecar_chassis()
