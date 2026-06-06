"""Snap/remove lake-zone props and export GLB. Use via mcp_send.py."""
import bpy
import math
from mathutils import Vector
from mathutils.bvhtree import BVHTree

BLEND_PATH = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.blend"
GLB_PATH = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.glb"

LAKE_CX, LAKE_CY = -150.347, 144.866
LAKE_RX, LAKE_RY = 60.0, 44.0
WATER_Z = -3.2
DEEP_Z = -5.0


def log(msg: str) -> None:
    print(f"[fix_lake] {msg}", flush=True)


def ensure_open() -> None:
    if bpy.data.filepath != BLEND_PATH:
        bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)


def build_bvh():
    terrain = bpy.data.objects.get("Terrain_Main")
    if terrain is None:
        return None
    return BVHTree.FromObject(terrain, bpy.context.evaluated_depsgraph_get())


def ground_z(bvh, x: float, y: float):
    if bvh is None:
        return None
    hit = bvh.ray_cast(Vector((x, y, 400.0)), Vector((0.0, 0.0, -1.0)), 800.0)
    return hit[0].z if hit[0] else None


def in_lake_ellipse(x: float, y: float) -> bool:
    dx = (x - LAKE_CX) / LAKE_RX
    dy = (y - LAKE_CY) / LAKE_RY
    return dx * dx + dy * dy <= 1.0


def snap_bottom(obj, bvh) -> bool:
    if obj.type != "MESH" or not obj.data.vertices:
        return False
    ws = [obj.matrix_world @ v.co for v in obj.data.vertices]
    cx = sum(p.x for p in ws) / len(ws)
    cy = sum(p.y for p in ws) / len(ws)
    bz = min(p.z for p in ws)
    gz = ground_z(bvh, cx, cy)
    if gz is None:
        return False
    obj.location.z += (gz - bz) + 0.04
    return True


def upright_tree(obj) -> None:
    euler = obj.matrix_world.to_euler()
    obj.rotation_euler = (0.0, 0.0, euler.z)


def main() -> dict:
    ensure_open()
    bvh = build_bvh()
    removed_dup = 0
    removed_underwater = 0
    removed_island = 0
    snapped = 0
    upright = 0

    # Duplicate monticulos from old naming pass.
    for obj in list(bpy.data.objects):
        if obj.type != "MESH":
            continue
        if "_20ha_" in obj.name and obj.name.startswith("Monticulo"):
            bpy.data.objects.remove(obj, do_unlink=True)
            removed_dup += 1

    to_remove: list[str] = []
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        loc = obj.matrix_world.translation
        if not in_lake_ellipse(loc.x, loc.y):
            continue
        gz = ground_z(bvh, loc.x, loc.y)
        if gz is None:
            continue

        name = obj.name
        is_prop = any(
            k in name
            for k in ("Tree", "Pine", "Rock", "Reed", "Monticulo", "Monti_", "Dock", "Bush")
        )
        if not is_prop:
            continue

        if gz < DEEP_Z:
            to_remove.append(name)
            continue

        if gz > WATER_Z + 0.35:
            if "Monticulo" in name or "Monti_" in name:
                to_remove.append(name)
                continue

        if "Tree" in name or name.startswith("Pine"):
            upright_tree(obj)
            upright += 1
        if snap_bottom(obj, bvh):
            snapped += 1

    for name in to_remove:
        obj = bpy.data.objects.get(name)
        if obj is None:
            continue
        gz = ground_z(bvh, obj.matrix_world.translation.x, obj.matrix_world.translation.y)
        bpy.data.objects.remove(obj, do_unlink=True)
        if gz is not None and gz < DEEP_Z:
            removed_underwater += 1
        else:
            removed_island += 1

    # Global tree upright + snap for tilted trees outside lake too.
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        if "Tree" not in obj.name and not obj.name.startswith("Pine"):
            continue
        euler = obj.matrix_world.to_euler()
        if abs(euler.x) > 0.2 or abs(euler.y) > 0.2:
            upright_tree(obj)
            upright += 1
            snap_bottom(obj, bvh)

    bpy.ops.wm.save_mainfile()
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
    )
    log(f"dup={removed_dup} underwater={removed_underwater} island={removed_island} snap={snapped} upright={upright}")

    return {
        "removed_dup_monticulos": removed_dup,
        "removed_underwater": removed_underwater,
        "removed_island_monticulos": removed_island,
        "snapped": snapped,
        "upright_trees": upright,
        "glb": GLB_PATH,
    }


result = main()
