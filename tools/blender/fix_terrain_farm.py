"""
fix_terrain_farm.py
Corrects Terreno_Finca.blend for Godot 4 export.
Run: blender --background --python tools/blender/fix_terrain_farm.py
"""

import bpy
from mathutils import Vector
import os, sys

BLEND_IN  = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.blend"
BLEND_OUT = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca_FIXED.blend"
GLB_OUT   = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca_FIXED.glb"

# ── helpers ──────────────────────────────────────────────────────────────────

def world_bbox(obj):
    verts = [obj.matrix_world @ Vector(v) for v in obj.bound_box]
    xs=[v.x for v in verts]; ys=[v.y for v in verts]; zs=[v.z for v in verts]
    return min(xs),max(xs),min(ys),max(ys),min(zs),max(zs)

def log(msg):
    print(f"[FIX] {msg}", flush=True)

# ── open ─────────────────────────────────────────────────────────────────────

log("Opening blend...")
bpy.ops.wm.open_mainfile(filepath=BLEND_IN)

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 1 — Safe corrections
# ═══════════════════════════════════════════════════════════════════════════

log("=== PHASE 1: Safe corrections ===")

# ── 1A. Rename / merge non-standard materials ─────────────────────────────

LAKE_AREA_X = (-210, -90)
LAKE_AREA_Y = (108, 182)

def ensure_mat(name, base_color, roughness=0.8, metallic=0.0, alpha=1.0):
    """Get or create a simple Principled BSDF material."""
    mat = bpy.data.materials.get(name)
    if not mat:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out  = nt.nodes.new('ShaderNodeOutputMaterial')
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    bsdf.inputs['Base Color'].default_value = (*base_color, 1.0)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value  = metallic
    if alpha < 1.0:
        bsdf.inputs['Alpha'].default_value = alpha
        mat.blend_method = 'BLEND'
    return mat

# Create/ensure canonical materials
mat_water = ensure_mat('MAT_Water',   (0.05, 0.25, 0.50), roughness=0.1, alpha=0.75)
mat_wood  = ensure_mat('MAT_Wood',    (0.35, 0.20, 0.08), roughness=0.85)
mat_fog   = ensure_mat('MAT_Fog',     (0.80, 0.85, 0.90), roughness=1.0,  alpha=0.3)

# Remap non-standard material names to canonical ones
REMAP = {
    'River Water':    'MAT_Water',
    'Water for river':'MAT_Water',
    'Tree wood':      'MAT_Wood',
    'Mat_Neblina':    'MAT_Fog',
}

replaced_count = 0
for obj in bpy.data.objects:
    if obj.type != 'MESH': continue
    for slot in obj.material_slots:
        if slot.material and slot.material.name in REMAP:
            target_name = REMAP[slot.material.name]
            target_mat  = bpy.data.materials.get(target_name)
            if target_mat:
                slot.material = target_mat
                replaced_count += 1

# Remove orphaned non-standard materials
for old_name in REMAP.keys():
    old_mat = bpy.data.materials.get(old_name)
    if old_mat and old_mat.users == 0:
        bpy.data.materials.remove(old_mat)
        log(f"  Removed orphan mat: {old_name}")

log(f"  Material slots remapped: {replaced_count}")

# ── 1B. Delete duplicate Borde_Alto_Norte.001 ────────────────────────────

dup = bpy.data.objects.get('Borde_Alto_Norte.001')
if dup:
    bpy.data.objects.remove(dup, do_unlink=True)
    log("  Removed Borde_Alto_Norte.001")

# ── 1C. Rename long _20ha_ objects ───────────────────────────────────────

RENAME_MAP = {}
for obj in bpy.data.objects:
    n = obj.name
    if '_20ha_' in n:
        new_name = n.replace('_20ha_', '_')
        RENAME_MAP[n] = new_name
    elif n.startswith('Bebedero_Animal_'):
        new_name = 'Bebed_An_' + n[len('Bebedero_Animal_'):]
        RENAME_MAP[n] = new_name
    elif n.startswith('Monticulo_20ha_'):
        new_name = 'Monti_' + n[len('Monticulo_20ha_'):]
        RENAME_MAP[n] = new_name
    elif n.startswith('Monticulo_Tierra_'):
        new_name = 'Monti_' + n[len('Monticulo_Tierra_'):]
        RENAME_MAP[n] = new_name

for old, new in RENAME_MAP.items():
    obj = bpy.data.objects.get(old)
    if obj:
        obj.name = new
        log(f"  Renamed: {old} → {new}")

log(f"  Total renames: {len(RENAME_MAP)}")

# ── 1D. Fix sinking trees/bushes NOT in lake area ────────────────────────

# Lake basin area approx
LX0, LX1 = -215, -85
LY0, LY1 = 105, 185

terrain = bpy.data.objects.get('Terrain_Main')
fixed_sink = 0

if terrain:
    # Build terrain vertex Z lookup by proximity (sample closest vert)
    t_verts = [terrain.matrix_world @ Vector(v.co) for v in terrain.data.vertices]

    def terrain_z_at(x, y, radius=15.0):
        best_z = None
        best_d = float('inf')
        for tv in t_verts:
            d = (tv.x - x)**2 + (tv.y - y)**2
            if d < radius*radius and d < best_d:
                best_d = d
                best_z = tv.z
        return best_z

    SINK_PREFIXES = ('Bush_Old_', 'Tree_Old_', 'Cerca_Borde_', 'Bush_F')
    for obj in bpy.data.objects:
        if obj.type != 'MESH': continue
        if obj.location.z > -5: continue
        # Skip if in lake area
        lx, ly = obj.location.x, obj.location.y
        if LX0 <= lx <= LX1 and LY0 <= ly <= LY1: continue
        # Only fix known vegetation/fence prefixes
        if not any(obj.name.startswith(p) for p in SINK_PREFIXES): continue

        tz = terrain_z_at(lx, ly)
        if tz is not None and tz > obj.location.z:
            old_z = obj.location.z
            obj.location.z = tz + 0.1
            log(f"  Lifted {obj.name}: z={old_z:.1f} → {obj.location.z:.1f}")
            fixed_sink += 1

log(f"  Sinking objects fixed: {fixed_sink}")

log("=== PHASE 1 DONE ===")

# ── Save intermediate ─────────────────────────────────────────────────────
bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)
log(f"Saved phase1 → {BLEND_OUT}")

print("PHASE1_OK")
