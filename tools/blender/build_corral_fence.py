"""Rebuild the corral perimeter with modular fence (Lib_Fence) on the ground.

Run via the in-Blender MCP socket. Replaces the deleted floating Corral_Wall
slabs with a ground-snapped modular fence around the corral footprint, leaving
a gate opening on the west side. Idempotent: clears COL_Corral first.
"""
import bpy
import math
import random
import mathutils

scn = bpy.context.scene
dg = bpy.context.evaluated_depsgraph_get()
TERRAIN = {"Terrain_Main", "Mtn_Main"}

# corral footprint (from the removed walls)
X0, X1 = 103.0, 162.0
Y0, Y1 = 103.0, 147.0
# gate opening on the west edge (X0), between these Y values
GATE_Y0, GATE_Y1 = 120.0, 130.0

SEG_LEN = 2.4          # spacing (m); panels are ~3.1 m wide so this overlaps
FENCE_SCALE = 2.6      # scale up the ~1.2 m library fence
SEED = 7


def gt(x, y):
    z = 300.0
    for _ in range(12):
        hit, loc, nrm, idx, obj, mat = scn.ray_cast(
            dg, mathutils.Vector((x, y, z)), mathutils.Vector((0, 0, -1)))
        if not hit:
            return None
        if obj and obj.name in TERRAIN:
            return loc.z
        z = loc.z - 0.05
    return None


def get_coll(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        scn.collection.children.link(c)
    return c


def run():
    rng = random.Random(SEED)
    lib = bpy.data.collections.get("COL_PropLibrary")
    if lib is None:
        return {"error": "COL_PropLibrary missing"}
    # use upright fence variants only (Z is the tall axis)
    variants = []
    for o in lib.objects:
        if not o.name.startswith("Lib_Fence"):
            continue
        zs = [v.co.z for v in o.data.vertices]
        xs = [v.co.x for v in o.data.vertices]
        if (max(zs) - min(zs)) >= (max(xs) - min(xs)) * 0.6:
            variants.append(o)
    if not variants:
        variants = [o for o in lib.objects if o.name.startswith("Lib_Fence")]

    corral = get_coll("COL_Corral")
    for o in list(corral.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    placed = 0

    def post(x, y, yaw):
        nonlocal placed
        gz = gt(x, y)
        if gz is None:
            return
        var = rng.choice(variants)
        inst = var.copy()
        corral.objects.link(inst)
        inst.location = (x, y, gz)
        inst.rotation_euler = (0, 0, yaw)
        inst.scale = (FENCE_SCALE, FENCE_SCALE, FENCE_SCALE)
        inst.name = f"Corral_Fence_{placed:03d}"
        placed += 1

    # walk the 4 edges. fence faces along the edge (yaw aligns its long X axis).
    # include both endpoints so corners meet (covers X0..X1 / Y0..Y1 fully).
    def span(lo, hi):
        vals = []
        v = lo
        while v < hi:
            vals.append(v)
            v += SEG_LEN
        vals.append(hi)   # always cap the far end -> corner closes
        return vals

    # South edge (Y0): run in X, yaw 0
    for x in span(X0, X1):
        post(x, Y0, 0.0)
    # North edge (Y1): run in X, yaw 0
    for x in span(X0, X1):
        post(x, Y1, 0.0)
    # East edge (X1): run in Y, yaw 90deg
    for y in span(Y0, Y1):
        post(X1, y, math.radians(90))
    # West edge (X0): run in Y, yaw 90deg, skip the gate opening
    for y in span(Y0, Y1):
        if not (GATE_Y0 <= y <= GATE_Y1):
            post(X0, y, math.radians(90))

    # two gate posts flanking the opening (slightly larger)
    for gy in (GATE_Y0, GATE_Y1):
        gz = gt(X0, gy)
        if gz is not None:
            var = rng.choice(variants)
            inst = var.copy()
            corral.objects.link(inst)
            inst.location = (X0, gy, gz)
            inst.rotation_euler = (0, 0, math.radians(90))
            inst.scale = (FENCE_SCALE * 1.15, FENCE_SCALE * 1.15, FENCE_SCALE * 1.25)
            inst.name = f"Corral_GatePost_{int(gy)}"
            placed += 1

    return {"fence_segments": placed, "variants_used": len(variants),
            "gate_opening_y": [GATE_Y0, GATE_Y1]}


result = run()
