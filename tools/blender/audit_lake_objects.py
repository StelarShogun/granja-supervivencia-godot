import bpy
BLEND = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.blend"
if bpy.data.filepath != BLEND:
    bpy.ops.wm.open_mainfile(filepath=BLEND)
lake = [o.name for o in bpy.data.objects if "Lake" in o.name or o.name.startswith("Dock")]
river_far = [o.name for o in bpy.data.objects if o.name.startswith("River") and abs(o.matrix_world.translation.x - 27.6) > 35]
print(f"lake_dock={len(lake)} sample={lake[:8]}")
print(f"river_far={len(river_far)} sample={river_far[:8]}")
