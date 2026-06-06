"""Import and normalize downloaded prop packs into Terreno_Finca.blend.

Run via the in-Blender MCP socket (tools/blender/mcp_send.py).

Responsibilities:
  1. Import the useful GLB packs into collection COL_PropLibrary (kept as a
     non-exported library; the scatter step duplicates from here).
  2. Drop junk meshes (giant ground planes shipped inside the simple-tree pack).
  3. Normalize scale so every variant fits the project's tree/prop range
     (~5-12 m trees, ~0.3-1.2 m small props).
  4. Remap plain (texture-less) pack materials to the existing MAT_* palette.
     Packs whose materials carry packed textures (forest tree atlas, fence)
     keep their own embedded material - they are Godot-safe.
  5. Apply transforms and give short, indexed names (Lib_Tree_##, Lib_Fence_##).

Idempotent: re-running first clears COL_PropLibrary and its meshes.

This script defines run() and (when imported by the MCP wrapper) assigns the
summary dict to `result`.
"""
import bpy
import mathutils

PROP_BASE = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/props"

# Packs to import. wooden_bridge is intentionally excluded (24 MB, duplicates Bridge_01).
PACKS = {
    "forest": f"{PROP_BASE}/nature/trees/low_poly_forest_tree_pack.glb",
    "simple": f"{PROP_BASE}/nature/trees/low_poly_trees.glb",
    "fence":  f"{PROP_BASE}/structure/modular_fence_system.glb",
}

LIB_NAME = "COL_PropLibrary"

# Target height ranges (Z, metres) per category. Variants are uniformly scaled
# so their bbox height lands inside the range (clamped to its midpoint when out).
TARGET_H = {
    "tree":  (5.0, 12.0),
    "fence": (0.9, 1.3),
    "rock":  (0.6, 2.5),
    "shrub": (1.0, 3.0),
}

# Plain pack materials (no embedded texture) -> existing MAT_* palette.
MAT_REMAP = {
    "Material.001": "MAT_Forest",   # foliage
    "Material.002": "MAT_Bark",     # trunk
    "Material.003": "MAT_Forest",
    "Material.004": "MAT_Forest",
}

# Junk meshes inside the simple pack: two oversized ground discs (>30 m wide).
JUNK_MAX_FLAT = 25.0   # if bbox X or Y > this and height < 16 m -> ground plane junk


def _dims(obj):
    cs = [obj.matrix_world @ mathutils.Vector(c) for c in obj.bound_box]
    xs = [c.x for c in cs]; ys = [c.y for c in cs]; zs = [c.z for c in cs]
    return (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))


def _clear_library():
    lib = bpy.data.collections.get(LIB_NAME)
    if lib is None:
        return 0
    n = 0
    for o in list(lib.objects):
        bpy.data.objects.remove(o, do_unlink=True)
        n += 1
    return n


def _get_library():
    lib = bpy.data.collections.get(LIB_NAME)
    if lib is None:
        lib = bpy.data.collections.new(LIB_NAME)
        bpy.context.scene.collection.children.link(lib)
    return lib


def _move_to(obj, coll):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)


def _apply_transform(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)


def _normalize_height(obj, lo, hi):
    _, _, h = _dims(obj)
    if h <= 0:
        return 1.0
    target = (lo + hi) / 2.0
    if h < lo:
        f = target / h
    elif h > hi:
        f = target / h
    else:
        return 1.0
    obj.scale = (obj.scale[0] * f, obj.scale[1] * f, obj.scale[2] * f)
    return f


def _remap_materials(obj):
    for slot in obj.material_slots:
        m = slot.material
        if not m:
            continue
        # keep packed-texture materials (atlas foliage, fence); only remap plain ones
        has_tex = False
        if m.use_nodes:
            for n in m.node_tree.nodes:
                if n.type == 'TEX_IMAGE' and n.image:
                    has_tex = True
                    break
        if has_tex:
            continue
        repl = MAT_REMAP.get(m.name)
        if repl:
            tgt = bpy.data.materials.get(repl)
            if tgt:
                slot.material = tgt


def _categorize(name, dims):
    n = name.lower()
    x, y, z = dims
    if "fence" in n:
        return "fence"
    if "rock" in n:
        return "rock"
    if "trunk" in n or "branch" in n:
        return "tree"
    if z >= 4.0 and z >= max(x, y) * 0.6:
        return "tree"
    if z >= 1.0:
        return "shrub"
    return "rock"


def run():
    import os
    cleared = _clear_library()
    lib = _get_library()

    counters = {"tree": 0, "fence": 0, "rock": 0, "shrub": 0}
    dropped = []
    kept = []

    for tag, path in PACKS.items():
        if not os.path.exists(path):
            dropped.append(f"MISSING:{path}")
            continue
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=path)
        new = [o for o in bpy.data.objects if o not in before]

        for o in new:
            if o.type != 'MESH':
                bpy.data.objects.remove(o, do_unlink=True)
                continue
            dx, dy, dz = _dims(o)
            # drop junk ground planes from the simple pack
            if tag == "simple" and (dx > JUNK_MAX_FLAT or dy > JUNK_MAX_FLAT) and dz < 16.0:
                dropped.append(o.name)
                bpy.data.objects.remove(o, do_unlink=True)
                continue
            cat = _categorize(o.name, (dx, dy, dz))
            lo, hi = TARGET_H[cat]
            _normalize_height(o, lo, hi)
            _apply_transform(o)
            _remap_materials(o)
            counters[cat] += 1
            idx = counters[cat]
            short = {"tree": "Lib_Tree", "fence": "Lib_Fence",
                     "rock": "Lib_Rock", "shrub": "Lib_Shrub"}[cat]
            o.name = f"{short}_{idx:02d}"
            o.data.name = o.name + "_mesh"
            _move_to(o, lib)
            kept.append((o.name, [round(v, 2) for v in _dims(o)]))

    # any leftover empties / root nodes from import -> remove
    for o in list(bpy.data.objects):
        if o.type == 'EMPTY' and (o.name.startswith(("GLTF_SceneRoot", "glTF", "Sketchfab"))):
            bpy.data.objects.remove(o, do_unlink=True)

    return {
        "cleared_prev": cleared,
        "counters": counters,
        "library_total": len(lib.objects),
        "dropped": dropped,
        "kept_sample": kept[:20],
    }


result = run()
