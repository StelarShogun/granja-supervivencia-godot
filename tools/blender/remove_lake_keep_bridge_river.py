"""Remove lake props, fill lake basin in Terrain_Main, trim river decor, export GLB."""
import bpy
import math
from mathutils import Vector

BLEND_PATH = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.blend"
GLB_PATH = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.glb"

LAKE_CX, LAKE_CY = -150.347, 144.866
LAKE_RX, LAKE_RY = 62.0, 48.0
SHORE_Z = -2.8


def log(msg: str) -> None:
    print(f"[no_lake] {msg}", flush=True)


def in_lake(x: float, y: float) -> bool:
    dx = (x - LAKE_CX) / LAKE_RX
    dy = (y - LAKE_CY) / LAKE_RY
    return dx * dx + dy * dy <= 1.0


def near_bridge_river(x: float, y: float) -> bool:
    # Godot bridge ~(27.6, -10) -> blender y=10
    return abs(x - 27.6) < 35.0 and abs(y - 10.0) < 22.0


def main() -> dict:
    if bpy.data.filepath != BLEND_PATH:
        bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)

    removed = 0
    for obj in list(bpy.data.objects):
        name = obj.name
        if name in {
            "Cam_Lake",
            "Lake_Center_Marker",
            "Lake_Deep_Marker",
            "Zn_Lake",
        } or name.startswith("RiverPath_Point_"):
            bpy.data.objects.remove(obj, do_unlink=True)
            removed += 1
            continue
        if obj.type != "MESH":
            continue
        if name.startswith("Lake_Reed") or name.startswith("Lake_"):
            bpy.data.objects.remove(obj, do_unlink=True)
            removed += 1
            continue
        if name == "Dock_01":
            bpy.data.objects.remove(obj, do_unlink=True)
            removed += 1
            continue
        loc = obj.matrix_world.translation
        if in_lake(loc.x, loc.y) and any(
            k in name for k in ("Reed", "Rock", "Bush", "Monticulo", "Monti_", "Tree")
        ):
            bpy.data.objects.remove(obj, do_unlink=True)
            removed += 1
            continue
        if name.startswith("River") and not near_bridge_river(loc.x, loc.y):
            bpy.data.objects.remove(obj, do_unlink=True)
            removed += 1

    terrain = bpy.data.objects.get("Terrain_Main")
    filled = 0
    if terrain and terrain.type == "MESH":
        mesh = terrain.data
        mw = terrain.matrix_world
        imw = mw.inverted()
        for vert in mesh.vertices:
            w = mw @ vert.co
            if not in_lake(w.x, w.y):
                continue
            dist = math.sqrt(
                ((w.x - LAKE_CX) / LAKE_RX) ** 2 + ((w.y - LAKE_CY) / LAKE_RY) ** 2
            )
            t = min(1.0, dist)
            target_z = SHORE_Z + t * 2.0
            if w.z < target_z:
                w.z = target_z
            vert.co = imw @ w
            filled += 1
        mesh.update()
        terrain.data.update()

    bpy.ops.wm.save_mainfile()
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
    )
    log(f"removed={removed} filled_verts={filled}")
    return {"removed": removed, "filled_verts": filled, "glb": GLB_PATH}


result = main()
