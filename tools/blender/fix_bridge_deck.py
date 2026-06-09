"""Fix the bridge deck: floor mesh (Bridge_Part_01) shares the structure's local
coordinate frame but carries a corrupt scale-100 transform -> it renders far away
and the bridge looks floorless. Align the deck transform to the structure
(Bridge_01) so the walkable floor sits under the railings. Re-export the GLB.
"""
import bpy
from mathutils import Vector

BLEND = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.blend"
GLB = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.glb"


def log(m):
    print(f"[bridge] {m}", flush=True)


def world_bbox(o):
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    mw = o.matrix_world
    for v in o.data.vertices:
        w = mw @ v.co
        for i in range(3):
            mn[i] = min(mn[i], w[i])
            mx[i] = max(mx[i], w[i])
    return mn, mx


def main():
    if bpy.data.filepath != BLEND:
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    struct = bpy.data.objects.get("Bridge_01")
    deck = bpy.data.objects.get("Bridge_Part_01")
    if struct is None or deck is None:
        raise RuntimeError(f"bridge objects missing struct={struct} deck={deck}")

    mn_s, mx_s = world_bbox(struct)
    mn_d0, mx_d0 = world_bbox(deck)
    log(f"struct world bbox {[round(v,1) for v in mn_s]}..{[round(v,1) for v in mx_s]}")
    log(f"deck  BEFORE world bbox {[round(v,1) for v in mn_d0]}..{[round(v,1) for v in mx_d0]}")
    log(f"deck obj matrix scale before={tuple(round(v,2) for v in deck.matrix_world.to_scale())}")

    # deck mesh data lives in the same local frame as the structure -> copy transform
    deck.matrix_world = struct.matrix_world.copy()

    mn_d1, mx_d1 = world_bbox(deck)
    log(f"deck  AFTER  world bbox {[round(v,1) for v in mn_d1]}..{[round(v,1) for v in mx_d1]}")
    log(f"deck top Y={mx_d1.z:.2f}  struct base Y={mn_s.z:.2f}  span X={mx_d1.x-mn_d1.x:.1f} Z={mx_d1.y-mn_d1.y:.1f}")

    bpy.ops.wm.save_mainfile(filepath=BLEND)
    log("blend saved")

    vl = bpy.context.view_layer

    def find_lc(lc, name):
        if lc.collection.name == name:
            return lc
        for c in lc.children:
            r = find_lc(c, name)
            if r:
                return r
        return None

    lib = find_lc(vl.layer_collection, "COL_PropLibrary")
    prev = None
    if lib:
        prev = lib.exclude
        lib.exclude = True
    vl.update()
    bpy.ops.export_scene.gltf(
        filepath=GLB, export_format="GLB", export_apply=True,
        export_yup=True, use_visible=True,
    )
    if lib and prev is not None:
        lib.exclude = prev
    log(f"exported {GLB}")
    log("DONE")


main()
