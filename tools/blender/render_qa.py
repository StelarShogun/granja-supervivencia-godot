import bpy, math
from mathutils import Vector, Euler

scn = bpy.context.scene
dg = bpy.context.evaluated_depsgraph_get()
def ground(x, y):
    r = scn.ray_cast(dg, Vector((x, y, 25.0)), Vector((0, 0, -1)))
    return r[1].z if r[0] else 5.0

hide = [o for o in bpy.data.objects if any(k in o.name for k in ("Neblina", "Relleno_Cielo"))]
saved = {o.name: o.hide_render for o in hide}
for o in hide:
    o.hide_render = True

scn.render.engine = 'BLENDER_WORKBENCH'
scn.render.resolution_x = 960; scn.render.resolution_y = 640
try:
    scn.display.shading.light = 'STUDIO'; scn.display.shading.color_type = 'MATERIAL'
except Exception: pass

def cam(loc, target=None, rot=None, ortho=None):
    c = bpy.data.objects.get("Cam_QA")
    if c is None:
        c = bpy.data.objects.new("Cam_QA", bpy.data.cameras.new("Cam_QA")); scn.collection.objects.link(c)
    c.location = loc
    if target is not None:
        d = (Vector(target) - Vector(loc)).normalized()
        c.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    elif rot is not None:
        c.rotation_euler = Euler(rot, 'XYZ')
    if ortho:
        c.data.type = 'ORTHO'; c.data.ortho_scale = ortho
    else:
        c.data.type = 'PERSP'; c.data.lens = 30
    scn.camera = c
    return c

def render(path):
    scn.render.filepath = path; bpy.ops.render.render(write_still=True)

# 1 farm aerial
cam((133, 124, 260), rot=(0, 0, 0), ortho=80); render("/tmp/qa_farm.png")
# 2 gate -> lake (stand inside farm, look west)
cam((113, 125, ground(113,125)+2.4), target=(-103, 144, 2.0)); render("/tmp/qa_gate_lake.png")
# 3 lake -> farm
cam((-95, 140, ground(-95,140)+3.0), target=(133, 128, ground(133,128)+3)); render("/tmp/qa_lake_farm.png")
# 4 ground level inside farm (rural)
cam((120, 120, ground(120,120)+1.8), target=(145, 135, ground(145,135)+2)); render("/tmp/qa_rural.png")

for o in hide:
    o.hide_render = saved[o.name]
result = {"imgs": ["/tmp/qa_farm.png", "/tmp/qa_gate_lake.png", "/tmp/qa_lake_farm.png", "/tmp/qa_rural.png"]}
