import bpy, math
from mathutils import Vector, Euler

scn = bpy.context.scene
scn.render.engine = 'BLENDER_WORKBENCH'
scn.render.resolution_x = 900
scn.render.resolution_y = 650
scn.render.resolution_percentage = 100
try:
    scn.display.shading.light = 'STUDIO'
    scn.display.shading.color_type = 'MATERIAL'
except Exception:
    pass

def cam(name, loc, rot_euler, ortho=None):
    c = bpy.data.objects.get(name)
    if c is None:
        d = bpy.data.cameras.new(name)
        c = bpy.data.objects.new(name, d)
        scn.collection.objects.link(c)
    c.location = loc
    c.rotation_euler = Euler(rot_euler, 'XYZ')
    if ortho:
        c.data.type = 'ORTHO'; c.data.ortho_scale = ortho
    else:
        c.data.type = 'PERSP'; c.data.lens = 35
    return c

def render(camobj, path):
    scn.camera = camobj
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)

# aerial ortho over farm center (133,125)
a = cam("Cam_Air", (133, 125, 220), (0, 0, 0), ortho=110)
render(a, "/tmp/chk_air.png")

# from gate looking toward lake (-X). gate at (103,125)
import mathutils
gz = 6.0
eye = Vector((108, 125, gz+2.0))
target = Vector((-150, 145, 2.0))
d = (target - eye).normalized()
rot = d.to_track_quat('-Z', 'Y').to_euler()
g = cam("Cam_GateView", eye, (rot.x, rot.y, rot.z))
render(g, "/tmp/chk_gate.png")

result = {"air": "/tmp/chk_air.png", "gate": "/tmp/chk_gate.png"}
