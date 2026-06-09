"""Audit prop/structure alignment against terrain. Read-only: writes CSV report.

Usage: blender --background Terreno_Finca.blend --python this_file
   or via MCP execute_blender_code_for_cli (code must assign `result`).

CSV: reports/audit_terrain_alignment.csv
Columns: object_name, collection, zone, cx, cy, bottom_z, ground_z, gap_m, action
"""
import bpy
import csv
import math
import os

from mathutils import Vector
from mathutils.bvhtree import BVHTree

REPO = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot"
BLEND_PATH = os.path.join(REPO, "assets/models/environment/Terreno_Finca.blend")
CSV_PATH = os.path.join(REPO, "reports/audit_terrain_alignment.csv")

LAKE_CX, LAKE_CY, LAKE_RX, LAKE_RY = -150.347, 144.866, 60.0, 44.0
FOREST_C, FOREST_R = (92.7, -60.3), 30.0
RURAL_C, RURAL_R = (145.0, 135.0), 45.0
BRIDGE_R = 15.0
RIVER_PATH = [
    (150.0, -132.0), (120.0, -95.0), (82.0, -48.0), (34.0, 18.0),
    (-28.0, 58.0), (-78.0, 90.0), (-112.0, 118.0), (-150.0, 145.0),
]
RIVER_R = 25.0

TERRAIN_NAMES = {"Terrain_Main", "Mtn_Main"}
SKIP_EXACT = {"Machete", "Rope_Descent", "Cave_Main", "Cave_Mouth_Visible"}
SKIP_SUBSTR = ("Water",)

FAIL = 0.15
CRIT = 0.5
WALL_SUSPECT = 2.0


def ensure_open():
    if bpy.data.filepath != BLEND_PATH and os.path.exists(BLEND_PATH):
        bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)


def dist_to_polyline(x, y, pts):
    best = float("inf")
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        dx, dy = x2 - x1, y2 - y1
        L2 = dx * dx + dy * dy
        t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / L2))
        px, py = x1 + t * dx, y1 + t * dy
        best = min(best, math.hypot(x - px, y - py))
    return best


def classify_zone(x, y, bridge_xy):
    dxe = (x - LAKE_CX) / LAKE_RX
    dye = (y - LAKE_CY) / LAKE_RY
    if dxe * dxe + dye * dye <= 1.0:
        return "A_crater"
    if bridge_xy and math.hypot(x - bridge_xy[0], y - bridge_xy[1]) <= BRIDGE_R:
        return "E_bridge"
    if math.hypot(x - RURAL_C[0], y - RURAL_C[1]) <= RURAL_R:
        return "C_rural"
    if math.hypot(x - FOREST_C[0], y - FOREST_C[1]) <= FOREST_R:
        return "D_forest"
    if dist_to_polyline(x, y, RIVER_PATH) <= RIVER_R:
        return "B_gorge"
    return "other"


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
            if p.z < bz:
                bz = p.z
        return sx / n, sy / n, bz
    corners = [mw @ Vector(c) for c in obj.bound_box]
    return (
        sum(c.x for c in corners) / 8.0,
        sum(c.y for c in corners) / 8.0,
        min(c.z for c in corners),
    )


def suggest(name, zone, gap, is_structure):
    if gap is None:
        return "no_ground_hit_manual"
    if zone in ("A_crater", "B_gorge") and gap > WALL_SUSPECT:
        return "manual_review_wall"
    if gap > FAIL:
        return "snap_bottom"
    if gap < -CRIT and is_structure:
        return "raise_to_ground"
    if gap < -0.3 and is_structure:
        return "raise_to_ground"
    if gap < -FAIL:
        return "snap_bottom"
    return "ok"


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
                z = hit[0].z
                best = z if best is None else max(best, z)
        return best

    bridge = bpy.data.objects.get("Bridge_Part_01") or bpy.data.objects.get("Bridge_01")
    bridge_xy = None
    if bridge:
        t = bridge.matrix_world.translation
        bridge_xy = (t.x, t.y)

    rows = []
    counts = {"total": 0, "fail": 0, "crit": 0, "no_hit": 0}
    structure_pref = ("Granero_", "Corral_", "Bridge_", "Cave_Lip", "Barn", "Ranch", "Shed", "POI_")
    for obj in bpy.data.objects:
        if obj.type != "MESH" or obj.name in TERRAIN_NAMES or obj.name in SKIP_EXACT:
            continue
        if any(s in obj.name for s in SKIP_SUBSTR) or obj.name.startswith("Sp_"):
            continue
        st = world_stats(obj)
        if st is None:
            continue
        cx, cy, bottom = st
        gz = ground_z(cx, cy)
        gap = None if gz is None else bottom - gz
        zone = classify_zone(cx, cy, bridge_xy)
        is_structure = obj.name.startswith(structure_pref)
        action = suggest(obj.name, zone, gap, is_structure)
        coll = obj.users_collection[0].name if obj.users_collection else ""
        counts["total"] += 1
        if gap is None:
            counts["no_hit"] += 1
        else:
            if abs(gap) > FAIL:
                counts["fail"] += 1
            if abs(gap) > CRIT:
                counts["crit"] += 1
        rows.append([
            obj.name, coll, zone,
            round(cx, 2), round(cy, 2),
            round(bottom, 3),
            None if gz is None else round(gz, 3),
            None if gap is None else round(gap, 3),
            action,
        ])

    rows.sort(key=lambda r: -(abs(r[7]) if r[7] is not None else 999))
    os.makedirs(os.path.dirname(CSV_PATH), exist_ok=True)
    with open(CSV_PATH, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["object_name", "collection", "zone", "cx", "cy",
                    "bottom_z", "ground_z", "gap_m", "action"])
        w.writerows(rows)

    zone_fail = {}
    for r in rows:
        if r[8] not in ("ok",):
            zone_fail[r[2]] = zone_fail.get(r[2], 0) + 1
    return {
        "csv": CSV_PATH,
        "counts": counts,
        "fails_by_zone": zone_fail,
        "top20": [
            {"name": r[0], "zone": r[2], "gap": r[7], "action": r[8]}
            for r in rows[:20]
        ],
    }


result = main()
print(result["counts"], result["fails_by_zone"])
