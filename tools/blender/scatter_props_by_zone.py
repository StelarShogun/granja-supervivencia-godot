"""Scatter normalized prop-library instances across the farm by biome.

Run via the in-Blender MCP socket (tools/blender/mcp_send.py) AFTER
import_prop_packs.py has built COL_PropLibrary.

Pipeline:
  1. Build exclusion list from spawns / structures / bridge (world XY + radius).
  2. (Forest) delete existing cone "Tree_*" inside the forest rect so the pack
     trees replace them (user decision: replace forest cones).
  3. Per zone: pseudo-random candidate points (fixed SEED), reject by
     - exclusion radius, - slope, - Poisson min-distance to accepted points.
  4. Instantiate = duplicate a library variant (linked mesh, new object),
     snap Z to terrain, random Z-rotation, +/-15% uniform scale.
  5. File into COL_Props subcollections per zone.
  6. Add fixed POIs (wood pile, broken fence, cave rocks, forest clearing).

Idempotent: removes COL_Props (and its children) before scattering.
"""
import bpy
import math
import random
import mathutils

SEED = 42

LIB_NAME = "COL_PropLibrary"
PROPS_NAME = "COL_Props"

scn = bpy.context.scene
dg = bpy.context.evaluated_depsgraph_get()


def ground(x, y):
    """Return (z, normal) of terrain at x,y or (None, None)."""
    # ray_cast -> (hit, location, normal, index, object, matrix)
    hit, loc, nrm, idx, obj, mat = scn.ray_cast(
        dg, mathutils.Vector((x, y, 200.0)), mathutils.Vector((0, 0, -1)))
    if hit:
        return loc.z, nrm
    return None, None


def slope_deg(normal):
    if normal is None:
        return 90.0
    up = mathutils.Vector((0, 0, 1))
    return math.degrees(up.angle(normal))


# --- exclusion anchors (world XY, radius m) -------------------------------
def build_exclusions():
    ex = []
    ex.append((98.8, 66.1, 12.0))   # Sp_Player
    for o in bpy.data.objects:
        n = o.name
        w = o.matrix_world.translation
        if n.startswith("Sp_An"):
            ex.append((w.x, w.y, 6.0))
        elif n.startswith(("Corral_", "Granero_")):
            ex.append((w.x, w.y, 8.0))
        elif n == "Bridge_01":
            ex.append((w.x, w.y, 6.0))
    return ex


def blocked(x, y, ex):
    for ex_x, ex_y, r in ex:
        if (x - ex_x) ** 2 + (y - ex_y) ** 2 < r * r:
            return True
    return False


# --- zone definitions ------------------------------------------------------
# kind weights pick which library prefixes a zone draws from.
ZONES = {
    "Forest": {
        "rect": (-90, 40, 20, 90),
        "count": 40,
        "kinds": {"Lib_Tree": 0.75, "Lib_Shrub": 0.15, "Lib_Rock": 0.10},
        "min_dist": 4.0, "max_slope": 38.0,
    },
    "ExLake": {
        "ellipse": (-150, 145, 62, 48),
        "count": 45,
        "kinds": {"Lib_Rock": 0.45, "Lib_Shrub": 0.35, "Lib_Tree": 0.20},
        "min_dist": 3.5, "max_slope": 30.0,
    },
    "Rural": {
        "rect": (100, 165, 100, 150),
        "count": 22,
        "kinds": {"Lib_Fence": 0.45, "Lib_Shrub": 0.30, "Lib_Rock": 0.25},
        "min_dist": 3.0, "max_slope": 25.0,
    },
    "MtnCave": {
        "rect": (86, 200, -200, -90),
        "count": 20,
        "kinds": {"Lib_Rock": 0.60, "Lib_Tree": 0.25, "Lib_Shrub": 0.15},
        "min_dist": 5.0, "max_slope": 50.0,
    },
}


def in_ellipse(x, y, cx, cy, rx, ry):
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def get_collection(parent, name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        parent.children.link(c)
    return c


def clear_props():
    root = bpy.data.collections.get(PROPS_NAME)
    if root is None:
        return 0
    n = 0
    for o in list(_all_objects_recursive(root)):
        bpy.data.objects.remove(o, do_unlink=True)
        n += 1
    return n


def _all_objects_recursive(coll):
    for o in coll.objects:
        yield o
    for c in coll.children:
        yield from _all_objects_recursive(c)


def delete_forest_cones(rect):
    """Remove existing single-style cone trees inside the forest rect."""
    x0, x1, y0, y1 = rect
    removed = 0
    for o in list(bpy.data.objects):
        if o.type != 'MESH':
            continue
        if not o.name.startswith("Tree"):
            continue
        w = o.matrix_world.translation
        if x0 <= w.x <= x1 and y0 <= w.y <= y1:
            bpy.data.objects.remove(o, do_unlink=True)
            removed += 1
    return removed


def pick_variant(kinds, lib_by_prefix, rng):
    prefixes = list(kinds.keys())
    weights = list(kinds.values())
    pre = rng.choices(prefixes, weights=weights, k=1)[0]
    pool = lib_by_prefix.get(pre, [])
    if not pool:
        # fall back to any available
        for p in lib_by_prefix.values():
            if p:
                return rng.choice(p)
        return None
    return rng.choice(pool)


def place(variant, x, y, z, rng, coll):
    inst = variant.copy()           # new object, shares mesh data (instanced)
    coll.objects.link(inst)
    inst.location = (x, y, z)
    inst.rotation_euler = (0, 0, rng.uniform(0, math.tau))
    s = rng.uniform(0.85, 1.15)
    inst.scale = (s, s, s)
    return inst


def scatter():
    rng = random.Random(SEED)
    lib = bpy.data.collections.get(LIB_NAME)
    if lib is None:
        return {"error": "COL_PropLibrary missing - run import_prop_packs first"}

    lib_by_prefix = {}
    for o in lib.objects:
        pre = o.name.rsplit("_", 1)[0]
        lib_by_prefix.setdefault(pre, []).append(o)

    cleared = clear_props()
    props_root = get_collection(scn.collection, PROPS_NAME)

    ex = build_exclusions()
    cones_removed = delete_forest_cones(ZONES["Forest"]["rect"])

    placed_by_zone = {}
    accepted_pts = []   # global, for cross-zone spacing sanity

    for zname, z in ZONES.items():
        zcoll = get_collection(props_root, f"COL_{zname}")
        cnt = z["count"]
        min_d = z["min_dist"]
        max_slope = z["max_slope"]
        kinds = z["kinds"]

        if "rect" in z:
            x0, x1, y0, y1 = z["rect"]
        else:
            cx, cy, rx, ry = z["ellipse"]
            x0, x1, y0, y1 = cx - rx, cx + rx, cy - ry, cy + ry

        local_pts = []
        attempts = 0
        placed = 0
        max_attempts = cnt * 60
        while placed < cnt and attempts < max_attempts:
            attempts += 1
            x = rng.uniform(x0, x1)
            y = rng.uniform(y0, y1)
            if "ellipse" in z and not in_ellipse(x, y, *z["ellipse"]):
                continue
            if blocked(x, y, ex):
                continue
            # poisson within zone
            ok = True
            for px, py in local_pts:
                if (x - px) ** 2 + (y - py) ** 2 < min_d * min_d:
                    ok = False
                    break
            if not ok:
                continue
            gz, gn = ground(x, y)
            if gz is None:
                continue
            if slope_deg(gn) > max_slope:
                continue
            var = pick_variant(kinds, lib_by_prefix, rng)
            if var is None:
                continue
            place(var, x, y, gz, rng, zcoll)
            local_pts.append((x, y))
            accepted_pts.append((x, y))
            placed += 1
        placed_by_zone[zname] = placed

    # --- fixed POIs ---------------------------------------------------------
    poi_coll = get_collection(props_root, "COL_POI")
    pois = []

    def poi(prefix_pool, x, y, label, rot_z=0.0, scale=1.0):
        pool = lib_by_prefix.get(prefix_pool, [])
        if not pool:
            return
        var = pool[0]
        gz, _ = ground(x, y)
        if gz is None:
            return
        inst = var.copy()
        poi_coll.objects.link(inst)
        inst.location = (x, y, gz)
        inst.rotation_euler = (0, 0, rot_z)
        inst.scale = (scale, scale, scale)
        inst.name = f"POI_{label}"
        pois.append(inst.name)

    # wood pile at forest edge, broken fence on rural path, cave-entrance rocks,
    # forest clearing marker.
    poi("Lib_Rock", 40, 55, "ForestEdgeRock")
    poi("Lib_Fence", 115, 118, "BrokenFenceA", rot_z=math.radians(20))
    poi("Lib_Fence", 118, 121, "BrokenFenceB", rot_z=math.radians(-35), scale=0.9)
    poi("Lib_Rock", 165, 178, "CaveRockA", scale=1.3)
    poi("Lib_Rock", 170, 175, "CaveRockB", scale=1.0)
    poi("Lib_Shrub", -45, 62, "ClearingShrub")

    total_new = sum(placed_by_zone.values()) + len(pois)
    return {
        "cleared_prev": cleared,
        "cones_removed_forest": cones_removed,
        "placed_by_zone": placed_by_zone,
        "pois": pois,
        "total_new_instances": total_new,
    }


result = scatter()
