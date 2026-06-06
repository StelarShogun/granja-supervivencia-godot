import bpy, math
BLEND = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.blend"
CX, CY, RX, RY = -150.347, 144.866, 62.0, 48.0
if bpy.data.filepath != BLEND:
    bpy.ops.wm.open_mainfile(filepath=BLEND)
t = bpy.data.objects.get("Terrain_Main")
mw = t.matrix_world
zs = []
for v in t.data.vertices:
    w = mw @ v.co
    dx, dy = (w.x - CX) / RX, (w.y - CY) / RY
    if dx * dx + dy * dy <= 1.0:
        zs.append(w.z)
print(f"verts_in_lake={len(zs)} z_min={min(zs) if zs else 'n/a'} z_max={max(zs) if zs else 'n/a'} below_-2={sum(1 for z in zs if z < -2)}")
