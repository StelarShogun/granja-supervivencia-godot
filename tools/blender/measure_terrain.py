"""Headless measurement of current Terreno_Finca terrain: gorge cross-section, lake, bounds."""
import bpy
import numpy as np

BLEND = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.blend"

RIVER_XY = [
    (150.0, -132.0), (120.0, -95.0), (82.0, -48.0), (34.0, 18.0),
    (-28.0, 58.0), (-78.0, 90.0), (-112.0, 118.0), (-150.0, 145.0),
]


def log(m):
    print(f"[measure] {m}", flush=True)


def main():
    if bpy.data.filepath != BLEND:
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    t = bpy.data.objects.get("Terrain_Main")
    if t is None:
        raise RuntimeError("Terrain_Main missing")
    mw = np.array(t.matrix_world)
    n = len(t.data.vertices)
    co = np.empty(n * 3)
    t.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    ones = np.ones((n, 1))
    world = (np.hstack([co, ones]) @ mw.T)[:, :3]
    X, Y, Z = world[:, 0], world[:, 1], world[:, 2]
    log(f"verts={n} X[{X.min():.1f},{X.max():.1f}] Y[{Y.min():.1f},{Y.max():.1f}] Z[{Z.min():.1f},{Z.max():.1f}]")

    # distance + arc to polyline
    P = np.array(RIVER_XY)
    seglen = np.hypot(np.diff(P[:, 0]), np.diff(P[:, 1]))
    arc0 = np.concatenate([[0], np.cumsum(seglen)])
    best_d = np.full(n, 1e18)
    best_arc = np.zeros(n)
    for i in range(len(P) - 1):
        a = P[i]
        b = P[i + 1]
        ab = b - a
        L2 = ab @ ab
        tt = ((X - a[0]) * ab[0] + (Y - a[1]) * ab[1]) / L2
        tt = np.clip(tt, 0, 1)
        cx = a[0] + tt * ab[0]
        cy = a[1] + tt * ab[1]
        d = np.hypot(X - cx, Y - cy)
        m = d < best_d
        best_d[m] = d[m]
        best_arc[m] = arc0[i] + tt[m] * seglen[i]
    log(f"total arc length={arc0[-1]:.1f}")

    # cross-section: bins of distance for verts near mid-gorge (arc 40..120)
    midmask = (best_arc > 40) & (best_arc < 140) & (best_d < 40)
    for lo in range(0, 40, 4):
        mm = midmask & (best_d >= lo) & (best_d < lo + 4)
        if mm.sum() > 0:
            log(f"  mid dist[{lo:2d},{lo+4:2d}) n={mm.sum():4d} Zmean={Z[mm].mean():7.2f} Zmin={Z[mm].min():7.2f} Zmax={Z[mm].max():7.2f}")

    # axis floor profile (dcan<5) along arc
    log("axis floor (dcan<5):")
    ax = best_d < 5
    for lo in range(0, int(arc0[-1]) + 20, 30):
        mm = ax & (best_arc >= lo) & (best_arc < lo + 30)
        if mm.sum() > 0:
            log(f"  arc[{lo:3d},{lo+30:3d}) n={mm.sum():3d} floorZmean={Z[mm].mean():7.2f} min={Z[mm].min():7.2f}")

    # rim height band (dcan 24..34) along arc
    log("rim band (dcan 24..34):")
    rb = (best_d >= 24) & (best_d < 34)
    for lo in range(0, int(arc0[-1]) + 20, 30):
        mm = rb & (best_arc >= lo) & (best_arc < lo + 30)
        if mm.sum() > 0:
            log(f"  arc[{lo:3d},{lo+30:3d}) rimZmedian={np.median(Z[mm]):7.2f}")

    # lake: find deep cluster away from river axis
    deep = (Z < -30) & (best_d > 40)
    if deep.sum() > 0:
        log(f"LAKE deep(Z<-30,offaxis) n={deep.sum()} centroid=({X[deep].mean():.1f},{Y[deep].mean():.1f}) Zmin={Z[deep].min():.1f}")
    else:
        log("no off-axis deep lake cluster (Z<-30)")

    # structures present
    for nm in ["Barn", "Shed", "Granero", "Bridge_01", "Machete", "Rope_Descent"]:
        o = bpy.data.objects.get(nm)
        log(f"obj {nm}: {'present' if o else 'absent'}")
    log("DONE")


main()
