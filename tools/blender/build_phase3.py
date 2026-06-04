import bpy, bmesh
from mathutils import Vector, Matrix

scn = bpy.context.scene
dg = bpy.context.evaluated_depsgraph_get()

def ground(x, y):
    # Cast from below the fog plane (z=29.76) so only terrain is hit.
    r = scn.ray_cast(dg, Vector((x, y, 25.0)), Vector((0, 0, -1)))
    return r[1].z if r[0] else 5.0

def get_col(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        scn.collection.children.link(c)
    return c

def link_only(obj, col):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)

def box_into(bm, center, size, quat=None):
    mat = Matrix.Translation(center)
    if quat is not None:
        mat = mat @ quat.to_matrix().to_4x4()
    mat = mat @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    corners = [(-0.5,-0.5,-0.5),(0.5,-0.5,-0.5),(0.5,0.5,-0.5),(-0.5,0.5,-0.5),
               (-0.5,-0.5,0.5),(0.5,-0.5,0.5),(0.5,0.5,0.5),(-0.5,0.5,0.5)]
    vs = [bm.verts.new((mat @ Vector(c))) for c in corners]
    faces = [(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]
    for f in faces:
        try: bm.faces.new([vs[i] for i in f])
        except ValueError: pass

def finalize(bm, name, mat_names, col):
    me = bpy.data.meshes.new(name)
    bm.normal_update(); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    for mn in mat_names:
        ob.data.materials.append(bpy.data.materials[mn])
    scn.collection.objects.link(ob)
    link_only(ob, col)
    return ob

col_rural = get_col("COL_Rural")
col_plain = get_col("COL_Plain")

# ---- farm rectangle ----
x0, x1, y0, y1 = 103.0, 163.0, 103.0, 147.0
gate_cy = 125.0
gap_h = 3.5  # half gate opening

def edge_pts(ax, bx, ay, by, step=4.0):
    import math
    n = max(1, int(round(math.hypot(bx-ax, by-ay)/step)))
    pts = []
    for i in range(n+1):
        t = i/n
        x = ax+(bx-ax)*t; y = ay+(by-ay)*t
        pts.append((x, y, ground(x, y)))
    return pts

def build_fence(name, pts):
    bm = bmesh.new()
    # posts
    for (x, y, gz) in pts:
        box_into(bm, Vector((x, y, gz+0.75)), (0.18, 0.18, 1.5))
    # two rails connecting consecutive post tops
    for i in range(len(pts)-1):
        ax, ay, az = pts[i]; bx, by, bz = pts[i+1]
        for off in (0.55, 1.15):
            A = Vector((ax, ay, az+off)); B = Vector((bx, by, bz+off))
            d = B - A; L = d.length
            if L < 1e-4: continue
            quat = d.to_track_quat('X', 'Z')
            box_into(bm, (A+B)*0.5, (L, 0.08, 0.12), quat)
    return finalize(bm, name, ["MAT_Wood", "MAT_WoodDark"], col_rural)

# North (y1), East (x1), South (y0) full; West split around gate
build_fence("Fence_Plain_01", edge_pts(x0, x1, y1, y1))
build_fence("Fence_Plain_02", edge_pts(x1, x1, y1, y0))
build_fence("Fence_Plain_03", edge_pts(x1, x0, y0, y0))
build_fence("Fence_Plain_04", edge_pts(x0, x0, y0, gate_cy-gap_h))   # west, south of gate
build_fence("Fence_Plain_05", edge_pts(x0, x0, gate_cy+gap_h, y1))   # west, north of gate

# ---- Gate_Lake (faces west / -X toward lake) ----
bm = bmesh.new()
hA = Vector((x0, gate_cy-gap_h, ground(x0, gate_cy-gap_h)))
hB = Vector((x0, gate_cy+gap_h, ground(x0, gate_cy+gap_h)))
# gate posts (taller, darker handled by 2nd material slot via separate mesh? keep single mat list)
for h in (hA, hB):
    box_into(bm, Vector((h.x, h.y, h.z+0.95)), (0.28, 0.28, 1.9))
def leaf(hinge, ydir):
    # open outward toward -X (lake)
    d = Vector((-1.0, ydir*0.18, 0.0)).normalized()
    quat = d.to_track_quat('X', 'Z')
    base = hinge.z + 0.7
    center = hinge + d*1.5 + Vector((0, 0, 0.7))
    box_into(bm, center, (3.0, 0.07, 1.25), quat)          # panel
    top = hinge + d*1.5 + Vector((0, 0, 1.3))
    box_into(bm, top, (3.0, 0.1, 0.12), quat)              # top rail
    for s in (0.5, 1.5, 2.5):
        p = hinge + d*s + Vector((0, 0, 0.7))
        box_into(bm, p, (0.12, 0.1, 1.25), quat)           # slats
leaf(hA, -1.0)
leaf(hB, +1.0)
finalize(bm, "Gate_Lake", ["MAT_Wood"], col_rural)

# ---- Plain_Farm_Area guide (border ring, marked non-export) ----
bm = bmesh.new()
gz = min(ground(x0,y0), ground(x1,y1), ground(x0,y1), ground(x1,y0)) + 0.06
ring = [((x0+x1)/2, y1, x1-x0, 0.5), ((x0+x1)/2, y0, x1-x0, 0.5),
        (x1, (y0+y1)/2, 0.5, y1-y0), (x0, (y0+y1)/2, 0.5, y1-y0)]
for (cx, cy, sx, sy) in ring:
    box_into(bm, Vector((cx, cy, gz)), (sx, sy, 0.08))
guide = finalize(bm, "Plain_Farm_Area", ["MAT_Path"], col_plain)
guide["non_export"] = True
guide.hide_render = True

result = {
  "fences": [o.name for o in col_rural.objects],
  "rect": [x0, x1, y0, y1], "gate_at": [x0, gate_cy],
  "guide": guide.name,
}
