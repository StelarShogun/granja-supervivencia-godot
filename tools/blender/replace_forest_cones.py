"""Replace existing single-style cone trees with varied prop-pack trees.

Run via the in-Blender MCP socket AFTER import_prop_packs.py + scatter.

For every existing "Tree*" cone (excluding new Lib_/POI_ instances):
  - record world XY, original height, Z rotation;
  - delete the cone;
  - instance a random Lib_Tree variant at the same XY, snapped to ground,
    uniformly scaled so its height matches the original (clamped 2-14 m),
    with a random Z rotation.

Instances go into COL_Props/COL_ForestTrees (instanced mesh data).
Idempotent: clears COL_ForestTrees before running; safe to re-run only if
cones still exist (after a full run there are none, so re-running is a no-op).
"""
import bpy
import math
import random
import mathutils

SEED = 73
LIB_BASE_H = 8.5      # Lib_Tree normalized height (m)
H_CLAMP = (2.0, 14.0)

scn = bpy.context.scene
dg = bpy.context.evaluated_depsgraph_get()


def ground(x, y):
    hit, loc, nrm, idx, obj, mat = scn.ray_cast(
        dg, mathutils.Vector((x, y, 200.0)), mathutils.Vector((0, 0, -1)))
    return loc.z if hit else None


def vheight(o):
    zs = [(o.matrix_world @ v.co).z for v in o.data.vertices]
    return max(zs) - min(zs)


def get_coll(parent, name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        parent.children.link(c)
    return c


def run():
    rng = random.Random(SEED)

    lib = bpy.data.collections.get("COL_PropLibrary")
    if lib is None:
        return {"error": "COL_PropLibrary missing"}
    tree_variants = [o for o in lib.objects if o.name.startswith("Lib_Tree")]
    if not tree_variants:
        return {"error": "no Lib_Tree variants"}

    # collect cones
    cones = []
    for o in bpy.data.objects:
        if o.type != 'MESH':
            continue
        if not o.name.startswith("Tree"):
            continue
        if o.name.startswith(("Lib_", "POI_")):
            continue
        w = o.matrix_world.translation
        cones.append((w.x, w.y, vheight(o), o.rotation_euler[2]))

    # delete cones
    for o in list(bpy.data.objects):
        if (o.type == 'MESH' and o.name.startswith("Tree")
                and not o.name.startswith(("Lib_", "POI_"))):
            bpy.data.objects.remove(o, do_unlink=True)

    props_root = get_coll(scn.collection, "COL_Props")
    ftcoll = get_coll(props_root, "COL_ForestTrees")
    # clear any previous forest-tree instances
    for o in list(ftcoll.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    placed = 0
    skipped = 0
    for (x, y, h, rz) in cones:
        gz = ground(x, y)
        if gz is None:
            skipped += 1
            continue
        var = rng.choice(tree_variants)
        inst = var.copy()
        ftcoll.objects.link(inst)
        target_h = max(H_CLAMP[0], min(H_CLAMP[1], h))
        s = target_h / LIB_BASE_H
        # +/-8% variety on top
        s *= rng.uniform(0.92, 1.08)
        inst.location = (x, y, gz)
        inst.rotation_euler = (0, 0, rng.uniform(0, math.tau))
        inst.scale = (s, s, s)
        placed += 1

    return {
        "cones_found": len(cones),
        "replaced": placed,
        "skipped_no_ground": skipped,
        "variants_used": len(tree_variants),
    }


result = run()
