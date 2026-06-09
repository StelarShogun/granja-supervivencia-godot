"""Extract one clean tileable fence unit (Left+Middle+Right, one copy each) from
modular_fence_system.glb, recenter base to origin with length along +X, render
preview images, and export fence_unit.glb for use in Godot."""
import bpy
import numpy as np

FENCE_GLB = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/props/structure/modular_fence_system.glb"
OUT_GLB = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/props/structure/fence_unit.glb"
RENDER = "/tmp/fence_unit_{}.png"


def log(m):
    print(f"[fence] {m}", flush=True)


def world_bbox(o):
    mw = o.matrix_world
    vs = np.array([(mw @ v.co)[:] for v in o.data.vertices])
    return vs.min(0), vs.max(0)


def main():
    bpy.ops.wm.read_homefile(use_empty=True)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=FENCE_GLB)
    new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]

    keep = {}
    for o in new:
        for k in ("Left", "Middle", "Right"):
            if k.lower() in o.name.lower() and k not in keep:
                keep[k] = o
    keepset = set(keep.values())
    for o in new:
        if o not in keepset:
            bpy.data.objects.remove(o, do_unlink=True)
    log(f"kept {[o.name for o in keep.values()]}")

    # apply transforms then join
    for o in keep.values():
        o.select_set(True)
    bpy.context.view_layer.objects.active = keep["Middle"]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    unit = bpy.context.view_layer.objects.active
    unit.name = "FenceUnit"
    unit.data.name = "FenceUnit_mesh"

    mn, mx = world_bbox(unit)
    log(f"raw bbox min={mn.round(2)} max={mx.round(2)} size={(mx-mn).round(2)}")

    # recenter: X,Y centered, base Z -> 0
    shift = np.array([-(mn[0] + mx[0]) / 2, -(mn[1] + mx[1]) / 2, -mn[2]])
    for v in unit.data.vertices:
        v.co.x += shift[0]
        v.co.y += shift[1]
        v.co.z += shift[2]
    unit.data.update()
    mn, mx = world_bbox(unit)
    log(f"centered bbox min={mn.round(2)} max={mx.round(2)} -> tile length X={mx[0]-mn[0]:.3f} height Z={mx[2]:.3f}")

    # render previews
    scn = bpy.context.scene
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    scn.collection.objects.link(cam)
    scn.camera = cam
    light_data = bpy.data.lights.new("Sun", "SUN")
    light_data.energy = 3.0
    light = bpy.data.objects.new("Sun", light_data)
    scn.collection.objects.link(light)
    light.rotation_euler = (0.6, 0.2, 0.3)
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES"):
        try:
            scn.render.engine = eng
            break
        except Exception:
            continue
    scn.render.resolution_x = 700
    scn.render.resolution_y = 400
    span = max(mx[0] - mn[0], 2.0)
    for label, loc, rot in [
        ("persp", (span * 1.3, -span * 1.6, mx[2] * 1.6 + 1.5), (1.05, 0, 0.55)),
        ("front", (0, -span * 2.2, mx[2] * 0.6), (1.5708, 0, 0)),
    ]:
        cam.location = loc
        cam.rotation_euler = rot
        scn.render.filepath = RENDER.format(label)
        bpy.ops.render.render(write_still=True)
        log(f"rendered {RENDER.format(label)}")

    # export unit
    for o in bpy.data.objects:
        o.select_set(o is unit)
    bpy.context.view_layer.objects.active = unit
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB",
                              use_selection=True, export_yup=True, export_apply=True)
    log(f"exported {OUT_GLB}")
    log("DONE")


main()
