import bpy

print("=== CHECKING OBJECT PARENTING & LOCATIONS ===")
for obj in bpy.data.objects:
    if obj.type == 'MESH':
        print(f"Name: {obj.name:<25} Loc: ({obj.location.x:5.2f}, {obj.location.y:5.2f}, {obj.location.z:5.2f}) Parent: {obj.parent.name if obj.parent else 'None'}")
