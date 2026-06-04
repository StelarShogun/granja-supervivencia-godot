import bpy, bmesh, math
from mathutils import Vector, Matrix

scn = bpy.context.scene
dg = bpy.context.evaluated_depsgraph_get()

def ground(x, y):
    r = scn.ray_cast(dg, Vector((x, y, 25.0)), Vector((0, 0, -1)))
    return r[1].z if r[0] else 5.0

def get_col(name):
    c = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if c.name not in [ch.name for ch in scn.collection.children_recursive]:
        scn.collection.children.link(c)
    return c

def link_only(obj, col):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)

def new_obj(me, name, mats, col):
    ob = bpy.data.objects.new(name, me)
    for mn in mats: ob.data.materials.append(bpy.data.materials[mn])
    scn.collection.objects.link(ob); link_only(ob, col)
    return ob

def cube(name, cx, cy, sx, sy, sz, mat, basez=None, rotz=0.0):
    gz = ground(cx, cy) if basez is None else basez
    bm = bmesh.new()
    m = Matrix.Translation((cx, cy, gz+sz/2)) @ Matrix.Rotation(rotz, 4, 'Z') @ Matrix.Diagonal((sx, sy, sz, 1))
    for c in [(-.5,-.5,-.5),(.5,-.5,-.5),(.5,.5,-.5),(-.5,.5,-.5),(-.5,-.5,.5),(.5,-.5,.5),(.5,.5,.5),(-.5,.5,.5)]:
        bm.verts.new(m @ Vector(c))
    bm.verts.ensure_lookup_table()
    for f in [(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]:
        bm.faces.new([bm.verts[i] for i in f])
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    return new_obj(me, name, [mat], col_props)

def cyl(name, cx, cy, r, h, mat, axis='Z'):
    gz = ground(cx, cy)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=r, radius2=r, depth=h)
    if axis == 'Y':
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0,0,0), matrix=Matrix.Rotation(math.radians(90),3,'X'))
        off = r
    else:
        off = h/2
    bmesh.ops.translate(bm, verts=bm.verts, vec=(cx, cy, gz+off))
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    return new_obj(me, name, [mat], col_props)

col_props = get_col("COL_Props")
col_path = get_col("COL_Path")

# ---------------- WORK AREA PROPS ----------------
# crates stacked
cube("Crate_01", 117.5, 129.0, 0.8, 0.8, 0.8, "MAT_Rural")
cube("Crate_02", 118.4, 129.4, 0.8, 0.8, 0.8, "MAT_Rural", rotz=0.3)
cube("Crate_03", 117.8, 129.1, 0.75, 0.75, 0.75, "MAT_Rural", basez=ground(117.8,129.1)+0.8)
# barrels
cyl("Barrel_01", 121.0, 128.2, 0.45, 0.95, "MAT_Metal")
cyl("Barrel_02", 121.9, 128.8, 0.45, 0.95, "MAT_Rural")
cyl("Barrel_03", 121.4, 127.4, 0.45, 0.95, "MAT_Metal")
# hay bales
cube("Hay_01", 125.0, 130.0, 1.3, 0.8, 0.8, "MAT_Hay")
cube("Hay_02", 125.0, 130.9, 1.3, 0.8, 0.8, "MAT_Hay")
cube("Hay_03", 120.0, 112.0, 1.3, 0.8, 0.8, "MAT_Hay")  # inside corral
# trough (bebedero) inside corral
cube("Trough_01", 126.0, 112.0, 2.0, 0.7, 0.55, "MAT_Wood")
# tools: simple rack (post + crossbar) + leaning shovel near barn
cube("Tool_01", 140.0, 131.0, 0.12, 1.4, 1.5, "MAT_WoodDark")
cube("Tool_02", 138.6, 131.3, 0.1, 0.1, 1.6, "MAT_Metal", rotz=0.4)
# cart (simple): bed + 2 wheels
cube("Cart_01", 130.0, 127.5, 2.2, 1.1, 0.5, "MAT_Wood", basez=ground(130,127.5)+0.45)
cyl("Cart_Wheel_L", 129.2, 126.9, 0.5, 0.18, "MAT_WoodDark", axis='Y')
cyl("Cart_Wheel_R", 129.2, 128.1, 0.5, 0.18, "MAT_WoodDark", axis='Y')

# ---------------- PATH_FARM_LAKE ----------------
wp = [(103,125),(88,127),(72,131),(54,134),(33,137),(12,139),
      (-12,140),(-38,142),(-62,143),(-86,144),(-103,144)]
half = 1.9
bm = bmesh.new()
left=[]; right=[]
for i,(x,y) in enumerate(wp):
    if i==0: t=Vector((wp[1][0]-x, wp[1][1]-y,0))
    elif i==len(wp)-1: t=Vector((x-wp[i-1][0], y-wp[i-1][1],0))
    else: t=Vector((wp[i+1][0]-wp[i-1][0], wp[i+1][1]-wp[i-1][1],0))
    t.normalize()
    n=Vector((-t.y, t.x, 0))
    lx,ly=x+n.x*half, y+n.y*half
    rx,ry=x-n.x*half, y-n.y*half
    left.append(bm.verts.new((lx,ly,ground(lx,ly)+0.06)))
    right.append(bm.verts.new((rx,ry,ground(rx,ry)+0.06)))
for i in range(len(wp)-1):
    bm.faces.new([left[i],left[i+1],right[i+1],right[i]])
me=bpy.data.meshes.new("Path_Farm_Lake"); bm.to_mesh(me); bm.free()
new_obj(me,"Path_Farm_Lake",["MAT_Path"],col_path)

result={"props":[o.name for o in col_props.objects if o.name.startswith(("Crate","Barrel","Hay","Trough","Tool","Cart"))],
        "path":"Path_Farm_Lake","path_end":[-103,144]}
