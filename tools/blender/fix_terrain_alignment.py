"""Fix prop/structure alignment found by audit_terrain_alignment.py.

Rules (approved 2026-06-09):
- Skip: terrain, cave interior meshes, Machete, Rope_Descent, Sp_*, water,
  COL_PropLibrary members (source variants, never shipped).
- Floating > 2 m inside crater (A) or gorge (B):
    vegetation -> delete (was suspended over carved terrain);
    rocks/other -> snap to ground below.
- Any other |gap| > 0.15 m -> snap bottom onto ground (+0.04 m).
- Tilted trees are made Z-up before snapping.

Saves the .blend and exports the GLB (COL_PropLibrary excluded).
"""
import bpy
import math
import os

from mathutils import Vector
from mathutils.bvhtree import BVHTree

REPO = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot"
BLEND_PATH = os.path.join(REPO, "assets/models/environment/Terreno_Finca.blend")
GLB_PATH = os.path.join(REPO, "assets/models/environment/Terreno_Finca.glb")

LAKE_CX, LAKE_CY, LAKE_RX, LAKE_RY = -150.347, 144.866, 60.0, 44.0
RIVER_PATH = [
    (150.0, -132.0), (120.0, -95.0), (82.0, -48.0), (34.0, 18.0),
    (-28.0, 58.0), (-78.0, 90.0), (-112.0, 118.0), (-150.0, 145.0),
]
RIVER_R = 25.0
FAIL = 0.15
WALL = 2.0
LIFT = 0.04

TERRAIN_NAMES = {"Terrain_Main", "Mtn_Main"}
SKIP_EXACT = {"Machete", "Rope_Descent"}
VEG = ("Tree", "Bush", "Shrub", "Flor", "Tallo", "Pasto", "Reed", "Ribera",
       "Log", "Tocon", "Monti", "WetLog", "Planicie")


def ensure_open():
    if bpy.data.filepath != BLEND_PATH and os.path.exists(BLEND_PATH):
        bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)


def lib_members():
    col = bpy.data.collections.get("COL_PropLibrary")
    if col is None:
        return set()
    return {o.name for o in col.all_objects}


def dist_to_polyline(x, y, pts):
    best = float("inf")
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        dx, dy = x2 - x1, y2 - y1
        L2 = dx * dx + dy * dy
        t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / L2))
        best = min(best, math.hypot(x - (x1 + t * dx), y - (y1 + t * dy)))
    return best


def in_ab(x, y):
    dx, dy = (x - LAKE_CX) / LAKE_RX, (y - LAKE_CY) / LAKE_RY
    if dx * dx + dy * dy <= 1.0:
        return True
    return dist_to_polyline(x, y, RIVER_PATH) <= RIVER_R


def world_stats(obj):
    me = obj.data
    n = len(me.vertices)
    if n == 0:
        return None
    mw = obj.matrix_world
    if n <= 4000:
        sx = sy = 0.0
        bz = float("inf")
        for v in me.vertices:
            p = mw @ v.co
            sx += p.x
            sy += p.y
            bz = min(bz, p.z)
        return sx / n, sy / n, bz
    cs = [mw @ Vector(c) for c in obj.bound_box]
    return (sum(c.x for c in cs) / 8.0, sum(c.y for c in cs) / 8.0,
            min(c.z for c in cs))


def main():
    ensure_open()
    deps = bpy.context.evaluated_depsgraph_get()
    bvhs = []
    for nm in TERRAIN_NAMES:
        o = bpy.data.objects.get(nm)
        if o:
            bvhs.append(BVHTree.FromObject(o, deps))

    def ground_z(x, y):
        best = None
        for bvh in bvhs:
            hit = bvh.ray_cast(Vector((x, y, 400.0)), Vector((0, 0, -1.0)), 800.0)
            if hit[0] is not None:
                best = hit[0].z if best is None else max(best, hit[0].z)
        return best

    lib = lib_members()
    deleted, snapped_down, snapped_up, upright, skipped = [], 0, 0, 0, 0

    for obj in list(bpy.data.objects):
        n = obj.name
        if (obj.type != "MESH" or n in TERRAIN_NAMES or n in SKIP_EXACT
                or n.startswith(("Cave_", "Sp_")) or "Water" in n or n in lib):
            continue
        st = world_stats(obj)
        if st is None:
            continue
        cx, cy, bottom = st
        gz = ground_z(cx, cy)
        if gz is None:
            skipped += 1
            continue
        gap = bottom - gz
        if abs(gap) <= FAIL:
            continue

        if gap > WALL and in_ab(cx, cy) and any(v in n for v in VEG):
            bpy.data.objects.remove(obj, do_unlink=True)
            deleted.append(n)
            continue

        if ("Tree" in n or n.startswith("Pine")):
            e = obj.matrix_world.to_euler()
            if abs(e.x) > 0.2 or abs(e.y) > 0.2:
                obj.rotation_euler = (0.0, 0.0, e.z)
                bpy.context.view_layer.update()
                st = world_stats(obj)
                cx, cy, bottom = st
                gz = ground_z(cx, cy) or gz
                gap = bottom - gz
                upright += 1

        obj.location.z += (gz - bottom) + LIFT
        if gap > 0:
            snapped_down += 1
        else:
            snapped_up += 1

    bpy.ops.wm.save_mainfile()

    # export excluding prop library (same as export_terreno_glb.py)
    def find_lc(lc, name):
        if lc.collection.name == name:
            return lc
        for ch in lc.children:
            r = find_lc(ch, name)
            if r:
                return r
        return None

    vl = bpy.context.view_layer
    lib_lc = find_lc(vl.layer_collection, "COL_PropLibrary")
    prev = None
    if lib_lc:
        prev = lib_lc.exclude
        lib_lc.exclude = True
    bpy.context.view_layer.update()
    try:
        import addon_utils
        addon_utils.enable("io_scene_gltf2", default_set=False)
    except Exception:
        pass
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        use_visible=True,
    )
    if lib_lc and prev is not None:
        lib_lc.exclude = prev

    return {
        "deleted": len(deleted),
        "deleted_names_sample": deleted[:15],
        "snapped_down": snapped_down,
        "snapped_up": snapped_up,
        "upright_trees": upright,
        "skipped_no_ground": skipped,
        "lib_excluded": len(lib),
        "glb": GLB_PATH,
    }


result = main()
print(result)
