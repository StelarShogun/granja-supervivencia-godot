"""Replace Bridge_01 with the roofed wooden bridge GLB.

The GLB ships a Cinema4D/Sketchfab/FBX wrapper hierarchy with empties scaled
100x / 0.01x. We bake each mesh's full world matrix into its vertices and reset
the object transform to identity, dropping the wrapper empties entirely. Then we
fit the clean meshes to the old Bridge_01 span (same XY center, crossing along
Y) with the deck at the old deck height, delete Bridge_01, and rename to
Bridge_01 so Godot's "Bridge_" collision prefix + BridgeTrigger still apply.

Run via the in-Blender MCP socket.
"""
import bpy
import mathutils

BRIDGE_GLB = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/props/structure/wooden_bridge_roofed_bridge_cap_-24mb.glb"

scn = bpy.context.scene


def world_bbox(objs):
    """World-space bbox from real vertices (bound_box can be stale after
    direct mesh-data edits)."""
    mn = [1e9] * 3
    mx = [-1e9] * 3
    for o in objs:
        mw = o.matrix_world
        for v in o.data.vertices:
            w = mw @ v.co
            for i in range(3):
                mn[i] = min(mn[i], w[i])
                mx[i] = max(mx[i], w[i])
    return mn, mx


def bake_world_to_mesh(o):
    """Bake matrix_world into vertices, reset object transform to identity."""
    mw = o.matrix_world.copy()
    o.data.transform(mw)
    o.data.update()
    o.matrix_world = mathutils.Matrix.Identity(4)
    o.parent = None


def run():
    # Old Bridge_01 footprint (captured before it was removed):
    #   x 5.9..49.3, y -3.3..23.3, z 12.5..17.5, center (27.6, 10, 15)
    old = bpy.data.objects.get("Bridge_01")
    if old is not None:
        omn, omx = world_bbox([old])
        o_center = [(omn[i] + omx[i]) / 2 for i in range(3)]
        o_span_y = omx[1] - omn[1]
        o_deck_top = omx[2]
    else:
        o_center = [27.6, 10.0, 15.0]
        o_span_y = 26.6
        o_deck_top = 17.5

    coll = bpy.data.collections.get("COL_Bridge")
    if coll:
        for o in list(coll.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    else:
        coll = bpy.data.collections.new("COL_Bridge")
        scn.collection.children.link(coll)

    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=BRIDGE_GLB)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == 'MESH']

    # bake world transform into each mesh, drop the wrapper empties
    for m in meshes:
        bake_world_to_mesh(m)
    for o in new:
        if o.type != 'MESH':
            bpy.data.objects.remove(o, do_unlink=True)

    # now meshes live in real world space with identity transforms
    nmn, nmx = world_bbox(meshes)
    n_len_y = nmx[1] - nmn[1]

    # uniform scale to match crossing span (slightly longer), about world origin
    s = (o_span_y * 1.02) / n_len_y
    S = mathutils.Matrix.Diagonal((s, s, s, 1.0))
    for m in meshes:
        m.data.transform(S)
        m.data.update()

    # recompute, then translate: XY center to old, deck top to old deck top
    nmn, nmx = world_bbox(meshes)
    n_center = [(nmn[i] + nmx[i]) / 2 for i in range(3)]
    floor = next((o for o in meshes if "floor" in o.name.lower()), None)
    deck_top_now = world_bbox([floor])[1][2] if floor else nmx[2]

    dx = o_center[0] - n_center[0]
    dy = o_center[1] - n_center[1]
    dz = o_deck_top - deck_top_now
    T = mathutils.Matrix.Translation((dx, dy, dz))
    for m in meshes:
        m.data.transform(T)
        m.data.update()

    # file into COL_Bridge, rename for Godot prefix
    for i, m in enumerate(meshes):
        for c in list(m.users_collection):
            c.objects.unlink(m)
        coll.objects.link(m)
        m.name = "Bridge_01" if i == 0 else f"Bridge_Part_{i}"
        m.data.name = m.name + "_mesh"

    if old is not None:
        bpy.data.objects.remove(old, do_unlink=True)

    fmn, fmx = world_bbox(meshes)
    return {
        "scale_factor": round(s, 3),
        "world_dims": [round(fmx[i] - fmn[i], 2) for i in range(3)],
        "x_range": [round(fmn[0], 1), round(fmx[0], 1)],
        "y_range": [round(fmn[1], 1), round(fmx[1], 1)],
        "z_range": [round(fmn[2], 2), round(fmx[2], 2)],
        "deck_top_z": round(fmx[2], 2),
        "old_deck_top_z": round(o_deck_top, 2),
        "meshes": [m.name for m in meshes],
    }


result = run()
