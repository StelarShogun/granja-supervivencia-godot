"""Sample terrain height around the player spawn (Blender XY ~120,120) to plan a
wide flat fenced area, and report the fence GLB segment dimensions."""
import bpy
import numpy as np

BLEND = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.blend"
FENCE_GLB = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/props/structure/modular_fence_system.glb"


def log(m):
    print(f"[spawn] {m}", flush=True)


def terrain_grid():
    t = bpy.data.objects.get("Terrain_Main")
    mw = np.array(t.matrix_world)
    n = len(t.data.vertices)
    co = np.empty(n * 3)
    t.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    world = (np.hstack([co, np.ones((n, 1))]) @ mw.T)[:, :3]
    X, Y, Z = world[:, 0], world[:, 1], world[:, 2]
    log("terrain height grid around spawn (Blender X across, Y down): Z median per 12m cell")
    xs = range(40, 201, 16)
    ys = range(40, 201, 16)
    header = "Yv\\Xv " + " ".join(f"{x:5d}" for x in xs)
    log(header)
    for y in ys:
        row = []
        for x in xs:
            m = (np.abs(X - x) < 8) & (np.abs(Y - y) < 8)
            row.append(f"{np.median(Z[m]):5.1f}" if m.sum() else "  -- ")
        log(f"{y:5d} " + " ".join(row))


def fence_dims():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=FENCE_GLB)
    new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    log(f"fence imported meshes={len(new)}")
    groups = {"Left": [], "Middle": [], "Right": []}
    for o in new:
        for k in groups:
            if k.lower() in o.name.lower():
                groups[k].append(o)
    for k, objs in groups.items():
        if not objs:
            continue
        o = objs[0]
        mw = o.matrix_world
        vs = [mw @ v.co for v in o.data.vertices]
        xs = [v.x for v in vs]
        ys = [v.y for v in vs]
        zs = [v.z for v in vs]
        log(f"{k}: count={len(objs)} verts={len(o.data.vertices)} "
            f"size=({max(xs)-min(xs):.2f},{max(ys)-min(ys):.2f},{max(zs)-min(zs):.2f}) "
            f"world_center=({(max(xs)+min(xs))/2:.1f},{(max(ys)+min(ys))/2:.1f},{(max(zs)+min(zs))/2:.1f})")
    # spacing between consecutive middle copies
    mids = sorted(groups["Middle"], key=lambda o: o.matrix_world.translation.x)
    cs = []
    for o in mids:
        mw = o.matrix_world
        xs = [(mw @ v.co).x for v in o.data.vertices]
        cs.append((min(xs) + max(xs)) / 2)
    diffs = [round(cs[i + 1] - cs[i], 2) for i in range(len(cs) - 1)]
    log(f"middle centers X={[round(c,1) for c in cs]}")
    log(f"middle spacing diffs={diffs}")
    # cleanup
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)


def main():
    if bpy.data.filepath != BLEND:
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    terrain_grid()
    fence_dims()
    log("DONE")


main()
