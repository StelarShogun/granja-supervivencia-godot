import bpy, bmesh, math
from mathutils import Vector, Matrix

scn = bpy.context.scene
dg = bpy.context.evaluated_depsgraph_get()

def ground(x, y):
    r = scn.ray_cast(dg, Vector((x, y, 25.0)), Vector((0, 0, -1)))
    return r[1].z if r[0] else 5.0

def get_col(name):
    c = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if c.name not in scn.collection.children and c.name not in [ch.name for ch in scn.collection.children_recursive]:
        scn.collection.children.link(c)
    return c

def link_only(obj, col):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)

def box_into(bm, center, size, basis=None):
    mat = Matrix.Translation(center)
    if basis is not None:
        mat = mat @ basis.to_4x4()
    mat = mat @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    corners = [(-0.5,-0.5,-0.5),(0.5,-0.5,-0.5),(0.5,0.5,-0.5),(-0.5,0.5,-0.5),
               (-0.5,-0.5,0.5),(0.5,-0.5,0.5),(0.5,0.5,0.5),(-0.5,0.5,0.5)]
    vs = [bm.verts.new((mat @ Vector(c))) for c in corners]
    for f in [(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]:
        try: bm.faces.new([vs[i] for i in f])
        except ValueError: pass

def slope_basis(slope_dir):
    x_ax = Vector((1.0, 0.0, 0.0))
    y_ax = slope_dir.normalized()
    z_ax = x_ax.cross(y_ax).normalized()
    x_ax = y_ax.cross(z_ax).normalized()
    return Matrix((x_ax, y_ax, z_ax)).transposed()

def tri(bm, a, b, c):
    vs = [bm.verts.new(a), bm.verts.new(b), bm.verts.new(c)]
    try: bm.faces.new(vs)
    except ValueError: pass

def finalize(bm, name, mats, col):
    me = bpy.data.meshes.new(name)
    bm.normal_update(); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    for mn in mats: ob.data.materials.append(bpy.data.materials[mn])
    scn.collection.objects.link(ob); link_only(ob, col)
    return ob

col_rural = get_col("COL_Rural")

# ============ BARN_01 (hollow, gable, big west door) ============
bx0,bx1,by0,by1 = 139.0,151.0,130.5,139.5
cx=(bx0+bx1)/2; cy=(by0+by1)/2
gz=min(ground(bx0,by0),ground(bx1,by1),ground(bx0,by1),ground(bx1,by0))
H=4.0; PEAK=3.0
bm=bmesh.new()
# back (east) wall
box_into(bm, Vector((bx1, cy, gz+H/2)), (0.2, by1-by0, H))
# side walls
box_into(bm, Vector((cx, by0, gz+H/2)), (bx1-bx0, 0.2, H))
box_into(bm, Vector((cx, by1, gz+H/2)), (bx1-bx0, 0.2, H))
# front (west) wall with door gap (door y[133,137] h3.5)
dy0,dy1,dh=133.0,137.0,3.5
box_into(bm, Vector((bx0, (by0+dy0)/2, gz+H/2)), (0.2, dy0-by0, H))
box_into(bm, Vector((bx0, (dy1+by1)/2, gz+H/2)), (0.2, by1-dy1, H))
box_into(bm, Vector((bx0, (dy0+dy1)/2, gz+(dh+H)/2)), (0.2, dy1-dy0, H-dh))
# roof (two slabs) ridge along X at y=cy, z=gz+H+PEAK
eaveZ=gz+H; ridgeZ=gz+H+PEAK; halfY=(by1-by0)/2
sl=math.hypot(halfY, PEAK); over=0.5
b1=slope_basis(Vector((0.0, halfY, PEAK)))
box_into(bm, Vector((cx,(by0+cy)/2,(eaveZ+ridgeZ)/2)), (bx1-bx0+over, sl+over, 0.2), b1)
b2=slope_basis(Vector((0.0,-halfY, PEAK)))
box_into(bm, Vector((cx,(by1+cy)/2,(eaveZ+ridgeZ)/2)), (bx1-bx0+over, sl+over, 0.2), b2)
# gable triangles (east + west ends)
for xe in (bx0,bx1):
    tri(bm, Vector((xe,by0,eaveZ)), Vector((xe,by1,eaveZ)), Vector((xe,cy,ridgeZ)))
finalize(bm,"Barn_01",["MAT_WoodDark","MAT_Roof"],col_rural)
# assign roof faces (last 2 slab boxes + tris) -> set material index by polygon normal z small? simpler: keep slot0; recolor roof via second slot on slabs
# (kept single-material visually acceptable; roof tint applied in phase via material slots not critical)

# ============ RANCH_01 (open shed, 6 posts, gable roof, no walls) ============
rx0,rx1,ry0,ry1=114.0,121.0,134.0,140.0
gz=min(ground(rx0,ry0),ground(rx1,ry1),ground(rx0,ry1),ground(rx1,ry0))
TOP=2.6
bm=bmesh.new()
for x in (rx0,(rx0+rx1)/2,rx1):
    for y in (ry0,ry1):
        zz=ground(x,y)
        box_into(bm, Vector((x,y,zz+TOP/2)), (0.22,0.22,TOP))
rcy=(ry0+ry1)/2; peak=1.2; halfY=(ry1-ry0)/2; sl=math.hypot(halfY,peak); over=0.6
eaveZ=gz+TOP; ridgeZ=gz+TOP+peak
b1=slope_basis(Vector((0.0,halfY,peak)))
box_into(bm, Vector(((rx0+rx1)/2,(ry0+rcy)/2,(eaveZ+ridgeZ)/2)), (rx1-rx0+over,sl+over,0.16), b1)
b2=slope_basis(Vector((0.0,-halfY,peak)))
box_into(bm, Vector(((rx0+rx1)/2,(ry1+rcy)/2,(eaveZ+ridgeZ)/2)), (rx1-rx0+over,sl+over,0.16), b2)
finalize(bm,"Ranch_01",["MAT_Wood","MAT_Roof"],col_rural)

# ============ COOP_01 (small box + mono roof + tiny run) ============
cxx0,cxx1,cyy0,cyy1=148.0,151.0,116.0,118.5
gz=ground((cxx0+cxx1)/2,(cyy0+cyy1)/2)
bm=bmesh.new()
ch=1.4
# walls (thin, hollow-ish small) -> 4 walls
box_into(bm, Vector(((cxx0+cxx1)/2,cyy0,gz+ch/2)), (cxx1-cxx0,0.12,ch))
box_into(bm, Vector(((cxx0+cxx1)/2,cyy1,gz+ch/2)), (cxx1-cxx0,0.12,ch))
box_into(bm, Vector((cxx0,(cyy0+cyy1)/2,gz+ch/2)), (0.12,cyy1-cyy0,ch))
box_into(bm, Vector((cxx1,(cyy0+cyy1)/2,gz+ch/2)), (0.12,cyy1-cyy0,ch))
# mono-pitch roof
b=slope_basis(Vector((0.0,cyy1-cyy0,0.6)))
box_into(bm, Vector(((cxx0+cxx1)/2,(cyy0+cyy1)/2,gz+ch+0.3)), (cxx1-cxx0+0.3, math.hypot(cyy1-cyy0,0.6)+0.2,0.12), b)
# tiny run fence (north side, 3 posts + rail)
for x in (cxx0,(cxx0+cxx1)/2,cxx1):
    zz=ground(x,cyy1+1.6); box_into(bm, Vector((x,cyy1+1.6,zz+0.4)),(0.1,0.1,0.8))
zz=ground((cxx0+cxx1)/2,cyy1+1.6)
box_into(bm, Vector(((cxx0+cxx1)/2,cyy1+1.6,zz+0.6)),(cxx1-cxx0,0.06,0.08))
finalize(bm,"Coop_01",["MAT_Wood","MAT_Roof"],col_rural)

# ============ CORRAL_01 (post & rail, open, gap on north) ============
qx0,qx1,qy0,qy1=112.0,138.0,106.0,121.0
bm=bmesh.new()
def rail_run(pts):
    for (x,y,z) in pts:
        box_into(bm, Vector((x,y,z+0.7)),(0.16,0.16,1.4))
    for i in range(len(pts)-1):
        ax,ay,az=pts[i]; bxp,byp,bz=pts[i+1]
        for off in (0.5,1.05):
            A=Vector((ax,ay,az+off)); B=Vector((bxp,byp,bz+off)); d=B-A; L=d.length
            if L<1e-4: continue
            box_into(bm,(A+B)*0.5,(L,0.07,0.1), d.to_track_quat('X','Z').to_matrix())
def line(ax,bx,ay,by,step=3.5):
    n=max(1,int(round(math.hypot(bx-ax,by-ay)/step))); return [(ax+(bx-ax)*i/n, ay+(by-ay)*i/n, ground(ax+(bx-ax)*i/n, ay+(by-ay)*i/n)) for i in range(n+1)]
rail_run(line(qx0,qx1,qy0,qy0))   # south
rail_run(line(qx1,qx1,qy0,qy1))   # east
rail_run(line(qx0,qx0,qy0,qy1))   # west
# north with gap near x=128..133
rail_run(line(qx0,127.0,qy1,qy1))
rail_run(line(133.0,qx1,qy1,qy1))
finalize(bm,"Corral_01",["MAT_WoodDark","MAT_Wood"],col_rural)

result={"built":[o.name for o in col_rural.objects],
 "barn":[bx0,bx1,by0,by1],"ranch":[rx0,rx1,ry0,ry1],
 "coop":[cxx0,cxx1,cyy0,cyy1],"corral":[qx0,qx1,qy0,qy1]}
