"""Reshape the river gorge: remove the raised central spine, build a flat continuous
walkable floor with smoothly sloped banks, keep ~30 m depth, keep the cliff feel.
Leaves the lake and all props untouched. Re-exports Terreno_Finca.glb.

Root cause fixed: the gorge centerline (dcan<4) sat ~25 m HIGHER than the side
troughs (dcan 4-12), creating a spine that split the channel into two walls.
"""
import bpy
import numpy as np

BLEND = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.blend"
GLB = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.glb"

RIVER_XY = [
    (150.0, -132.0), (120.0, -95.0), (82.0, -48.0), (34.0, 18.0),
    (-28.0, 58.0), (-78.0, 90.0), (-112.0, 118.0), (-150.0, 145.0),
]

W_FLOOR = 6.0       # flat-floor half width  -> 12 m walkable bottom
W_TOP = 30.0        # channel half width at rim (gentler, natural slope ~48 deg)
FEATHER = 8.0       # blend zone outside W_TOP back into existing terrain
D_MAX = 30.0        # gorge depth
NOISE_AMP = 2.2     # bank roughness to break grid "column" regularity
ARC_RAMP0 = 18.0    # depth ramps in from here (mountain head)
ARC_RAMP1 = 105.0   # full depth from here
ARC_MAX = 352.0     # stop before the lake basin

# lake protection ellipse (Blender XY)
LAKE_CX, LAKE_CY, LAKE_RX, LAKE_RY = -178.0, 144.0, 62.0, 46.0
LAKE_Z_GUARD = -42.0


def log(m):
    print(f"[reshape] {m}", flush=True)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def main():
    if bpy.data.filepath != BLEND:
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    t = bpy.data.objects.get("Terrain_Main")
    if t is None:
        raise RuntimeError("Terrain_Main missing")

    mw = np.array(t.matrix_world)
    imw = np.array(t.matrix_world.inverted())
    n = len(t.data.vertices)
    co = np.empty(n * 3)
    t.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    world = (np.hstack([co, np.ones((n, 1))]) @ mw.T)[:, :3]
    X, Y, Z = world[:, 0].copy(), world[:, 1].copy(), world[:, 2].copy()
    Z_orig = Z.copy()

    # distance + arc to polyline
    P = np.array(RIVER_XY)
    seglen = np.hypot(np.diff(P[:, 0]), np.diff(P[:, 1]))
    arc0 = np.concatenate([[0], np.cumsum(seglen)])
    total_arc = arc0[-1]
    best_d = np.full(n, 1e18)
    best_arc = np.zeros(n)
    for i in range(len(P) - 1):
        a, b = P[i], P[i + 1]
        ab = b - a
        L2 = ab @ ab
        tt = np.clip(((X - a[0]) * ab[0] + (Y - a[1]) * ab[1]) / L2, 0, 1)
        cx = a[0] + tt * ab[0]
        cy = a[1] + tt * ab[1]
        d = np.hypot(X - cx, Y - cy)
        m = d < best_d
        best_d[m] = d[m]
        best_arc[m] = arc0[i] + tt[m] * seglen[i]

    # lake mask (protected)
    lake = ((X - LAKE_CX) / LAKE_RX) ** 2 + ((Y - LAKE_CY) / LAKE_RY) ** 2 <= 1.0
    lake |= Z_orig < LAKE_Z_GUARD

    # rim profile rim_z(arc): median terrain Z in band [W_TOP+4, W_TOP+14], per 6 m bin
    band = (best_d >= W_TOP + 4) & (best_d <= W_TOP + 14) & (~lake)
    nb = int(total_arc / 6) + 1
    bin_idx = np.clip((best_arc / 6).astype(int), 0, nb - 1)
    rim_arc = (np.arange(nb) + 0.5) * 6.0
    rim_val = np.full(nb, np.nan)
    for k in range(nb):
        sel = band & (bin_idx == k)
        if sel.sum() >= 3:
            rim_val[k] = np.median(Z[sel])
    # fill nan by interpolation then smooth (moving average)
    good = ~np.isnan(rim_val)
    rim_val = np.interp(rim_arc, rim_arc[good], rim_val[good])
    kern = np.ones(5) / 5.0
    rim_val = np.convolve(np.pad(rim_val, 2, mode="edge"), kern, mode="valid")
    log(f"rim profile arc0..end: {[round(v,1) for v in rim_val[::6]]}")

    rim_z = np.interp(best_arc, rim_arc, rim_val)
    depth = D_MAX * smoothstep(ARC_RAMP0, ARC_RAMP1, best_arc)

    # bank factor: 1 inside floor, cosine down to 0 at W_TOP
    tt = np.clip((best_d - W_FLOOR) / (W_TOP - W_FLOOR), 0.0, 1.0)
    bank = 0.5 * (1.0 + np.cos(np.pi * tt))            # 1 -> 0
    profile_z = rim_z - depth * bank

    # bank roughness: organic noise, zero on the flat floor and at the rim,
    # max mid-bank -> breaks the regular-grid "vertical column" read
    nf = (0.55 * np.sin(0.23 * X + 0.37 * Y)
          + 0.35 * np.sin(0.41 * X - 0.19 * Y + 1.7)
          + 0.30 * np.sin(0.61 * Y + 0.5)
          + 0.25 * np.sin(0.53 * X - 2.1))
    window = np.sin(np.pi * np.clip(tt, 0.0, 1.0))     # 0 at floor edge & rim
    on_bank = (best_d > W_FLOOR).astype(float)
    profile_z = profile_z + NOISE_AMP * window * nf * on_bank

    core = (best_d <= W_TOP) & (best_arc <= ARC_MAX) & (~lake)
    feather = (best_d > W_TOP) & (best_d <= W_TOP + FEATHER) & (best_arc <= ARC_MAX) & (~lake)

    newZ = Z.copy()
    newZ[core] = profile_z[core]
    # feather: blend rim_z (profile at edge) -> existing terrain
    ft = (best_d[feather] - W_TOP) / FEATHER          # 0..1
    blend = 0.5 * (1.0 + np.cos(np.pi * ft))          # 1 at W_TOP -> 0
    newZ[feather] = profile_z[feather] * blend + Z[feather] * (1.0 - blend)

    changed = core | feather
    Z[changed] = newZ[changed]

    # write back
    world2 = np.column_stack([X, Y, Z, np.ones(n)])
    local = (world2 @ imw.T)[:, :3]
    flat = local.reshape(-1).astype(np.float64)
    t.data.vertices.foreach_set("co", flat)
    t.data.update()

    moved = changed.sum()
    spine_before = Z_orig[(best_d < 4) & (best_arc > 60) & (best_arc < 330) & (~lake)]
    spine_after = Z[(best_d < 4) & (best_arc > 60) & (best_arc < 330) & (~lake)]
    side = Z[(best_d >= 4) & (best_d < 10) & (best_arc > 60) & (best_arc < 330) & (~lake)]
    log(f"verts reshaped={moved} (core={core.sum()} feather={feather.sum()})")
    log(f"centerline Z mean before={spine_before.mean():.1f} after={spine_after.mean():.1f}")
    log(f"side(4-10) Z mean after={side.mean():.1f}  -> floor now below sides? {spine_after.mean() < side.mean()}")

    # cross-section recheck mid arc 60..330
    log("post cross-section (arc 60..330):")
    mid = (best_arc > 60) & (best_arc < 330)
    for lo in range(0, 28, 4):
        mm = mid & (best_d >= lo) & (best_d < lo + 4)
        if mm.sum():
            log(f"  dist[{lo:2d},{lo+4:2d}) Zmean={Z[mm].mean():7.2f}")

    bpy.ops.wm.save_mainfile(filepath=BLEND)
    log("blend saved")

    # export (exclude prop library)
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
