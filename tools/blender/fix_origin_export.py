"""
Fix Terreno_Finca.blend via Blender MCP or CLI:
- remove duplicate structure meshes stuck at origin (baked world verts)
- remove opaque water meshes (Godot boujie water)
- snap reeds/small props to terrain
- reposition Bridge_01 origin to geometry center
- export GLB

Run:
  python3 tools/blender/mcp_send.py < tools/blender/fix_origin_export.py
  blender --background Terreno_Finca.blend --python tools/blender/fix_origin_export.py
"""
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

BLEND_PATH = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.blend"
GLB_PATH = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.glb"

DELETE_NAMES = {
    "Lake_Water_Surface",
    "River_Water_Surface",
    "Barn_01",
    "Corral_01",
    "Ranch_01",
    "Plain_Farm_Area",
    "Bridge_Ramp_South",
}

NEVER_DELETE = {
    "Terrain_Main",
    "Mtn_Main",
}

SNAP_PREFIXES = (
    "Lake_Reed_",
    "RiverReed_",
    "Reed_",
)

STRUCTURE_PREFIXES = (
    "Granero_",
    "Corral_Wall",
    "Corral_Gate",
    "Bridge_",
    "Cave_Lip",
    "Dock_",
)


def log(msg: str) -> None:
    print(f"[fix_origin] {msg}", flush=True)


def ensure_open() -> None:
    if bpy.data.filepath != BLEND_PATH:
        bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)


def world_aabb(obj):
    if obj.type != "MESH" or not obj.data.vertices:
        return None
    ws = [obj.matrix_world @ v.co for v in obj.data.vertices]
    xs = [p.x for p in ws]
    ys = [p.y for p in ws]
    zs = [p.z for p in ws]
    return min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)


def build_terrain_bvh():
    terrain = bpy.data.objects.get("Terrain_Main")
    if terrain is None:
        return None, None
    deps = bpy.context.evaluated_depsgraph_get()
    return BVHTree.FromObject(terrain, deps), terrain


def ground_z(bvh, x: float, y: float):
    if bvh is None:
        return None
    hit = bvh.ray_cast(Vector((x, y, 400.0)), Vector((0.0, 0.0, -1.0)), 800.0)
    if hit[0] is None:
        return None
    return hit[0].z


def delete_junk() -> int:
    removed = 0
    for name in list(DELETE_NAMES):
        obj = bpy.data.objects.get(name)
        if obj is None:
            continue
        bpy.data.objects.remove(obj, do_unlink=True)
        removed += 1
        log(f"deleted {name}")
    return removed


def delete_origin_baked_duplicates() -> int:
    """Objects at origin whose mesh center is far away are export bugs."""
    to_remove: list[str] = []
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        if obj.name in DELETE_NAMES or obj.name in NEVER_DELETE:
            continue
        loc = obj.matrix_world.translation
        if loc.length > 1.0:
            continue
        aabb = world_aabb(obj)
        if aabb is None:
            continue
        cx = (aabb[0] + aabb[1]) * 0.5
        cy = (aabb[2] + aabb[3]) * 0.5
        if Vector((cx, cy, 0.0)).length < 25.0:
            continue
        to_remove.append(obj.name)

    removed = 0
    for name in to_remove:
        obj = bpy.data.objects.get(name)
        if obj is None:
            continue
        bpy.data.objects.remove(obj, do_unlink=True)
        removed += 1
        log(f"deleted origin-baked {name}")
    return removed


def fix_bridge_origin() -> None:
    obj = bpy.data.objects.get("Bridge_01")
    if obj is None:
        return
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    obj.select_set(False)
    log(f"Bridge_01 origin -> {tuple(round(v, 2) for v in obj.matrix_world.translation)}")


def snap_props_to_ground(bvh) -> int:
    if bvh is None:
        return 0
    snapped = 0
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        if obj.name.startswith(("Cam_", "Sp_")):
            continue
        if any(obj.name.startswith(p) for p in STRUCTURE_PREFIXES):
            continue
        if not any(obj.name.startswith(p) for p in SNAP_PREFIXES):
            continue
        ws = [obj.matrix_world @ v.co for v in obj.data.vertices]
        cx = sum(p.x for p in ws) / len(ws)
        cy = sum(p.y for p in ws) / len(ws)
        bz = min(p.z for p in ws)
        gz = ground_z(bvh, cx, cy)
        if gz is None:
            continue
        gap = bz - gz
        if gap < 0.15 or gap > 25.0:
            continue
        obj.location.z -= gap - 0.05
        snapped += 1
    return snapped


def export_glb() -> None:
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
    )
    log(f"exported {GLB_PATH}")


def main() -> None:
    ensure_open()
    bvh, _terrain = build_terrain_bvh()
    deleted = delete_junk()
    deleted += delete_origin_baked_duplicates()
    fix_bridge_origin()
    snapped = snap_props_to_ground(bvh)
    bpy.ops.wm.save_mainfile()
    export_glb()
    return {
        "deleted": deleted,
        "snapped_reeds": snapped,
        "blend": BLEND_PATH,
        "glb": GLB_PATH,
        "origin_left": [
            o.name
            for o in bpy.data.objects
            if o.type == "MESH" and o.matrix_world.translation.length < 0.5
        ],
    }


result = main()
