import bpy

GLB = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.glb"

bpy.ops.import_scene.gltf(filepath=GLB)
from mathutils import Vector

terrain = bpy.data.objects["Terrain_Main"]
matrix = terrain.matrix_world
all_z = [(matrix @ vert.co).z for vert in terrain.data.vertices]
forest_z = []
for vert in terrain.data.vertices:
    world = matrix @ vert.co
    if (world.x - 92.7) ** 2 + (world.y + 60.3) ** 2 <= 900.0:
        forest_z.append(world.z)

machete = bpy.data.objects.get("Machete")
print("GLB minZ=%.2f maxZ=%.2f" % (min(all_z), max(all_z)))
print("GLB forest_min=%.2f" % min(forest_z))
if machete:
    bounds = [machete.matrix_world @ Vector(corner) for corner in machete.bound_box]
    avg_z = sum(point.z for point in bounds) / len(bounds)
    print(
        "GLB Machete loc=%s scale=%s max_dim=%.3f avgZ=%.2f"
        % (
            tuple(round(value, 2) for value in machete.location),
            tuple(round(value, 2) for value in machete.scale),
            max(machete.dimensions),
            avg_z,
        )
    )
else:
    print("GLB Machete missing")
