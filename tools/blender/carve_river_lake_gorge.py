"""Carve 30 m river gorge + 100 m lake, bridge, rope descent, machete. River/lake only."""
import math
import bpy
from mathutils import Matrix, Vector

BLEND = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.blend"
GLB = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.glb"
BRIDGE_GLB = (
    "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/props/structure/"
    "wooden_bridge_roofed_bridge_cap_-24mb.glb"
)

RIVER_HALF_WIDTH = 14.0
RIVER_DEPTH = 30.0
LAKE_CX, LAKE_CY = -150.347, 144.866
LAKE_RX, LAKE_RY = 62.0, 48.0
LAKE_SURFACE_Z = -3.2
LAKE_DEPTH = 100.0
LAKE_FLOOR_Z = LAKE_SURFACE_Z - LAKE_DEPTH
LAKE_WALL_START = 0.72

RIVER_XY = [
    (150.0, -132.0),
    (120.0, -95.0),
    (82.0, -48.0),
    (34.0, 18.0),
    (-28.0, 58.0),
    (-78.0, 90.0),
    (-112.0, 118.0),
    (-150.0, 145.0),
]

# Forest sample away from river polyline (92,-60 sits on the river course).
FOREST_TEST = (185.0, -175.0, 25.0)


def log(msg):
    print(f"[gorge] {msg}", flush=True)


def smoothstep(edge0, edge1, x):
    if edge1 <= edge0:
        return 1.0 if x >= edge1 else 0.0
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def _find_layer_coll(layer_coll, name):
    if layer_coll.collection.name == name:
        return layer_coll
    for child in layer_coll.children:
        found = _find_layer_coll(child, name)
        if found:
            return found
    return None


def sample_path_surface_z(terrain, path_xy):
    mw = terrain.matrix_world
    samples = []
    for x, y in path_xy:
        best = None
        best_d = 1e9
        for vert in terrain.data.vertices:
            w = mw @ vert.co
            d = (w.x - x) ** 2 + (w.y - y) ** 2
            if d < best_d:
                best_d = d
                best = w.z
        samples.append((x, y, best))
    return samples


def closest_on_polyline(px, py, points):
    best = (1e9, 0, 0.0, points[0][0], points[0][1])
    for i in range(len(points) - 1):
        x0, y0, _ = points[i]
        x1, y1, _ = points[i + 1]
        dx = x1 - x0
        dy = y1 - y0
        seg_len2 = dx * dx + dy * dy
        if seg_len2 < 1e-6:
            continue
        t = max(0.0, min(1.0, ((px - x0) * dx + (py - y0) * dy) / seg_len2))
        cx = x0 + t * dx
        cy = y0 + t * dy
        dist = math.hypot(px - cx, py - cy)
        if dist < best[0]:
            best = (dist, i, t, cx, cy)
    return best


def path_z_at(points, seg, t):
    z0 = points[seg][2]
    z1 = points[seg + 1][2]
    return z0 + t * (z1 - z0)


def in_lake_norm(x, y):
    dx = (x - LAKE_CX) / LAKE_RX
    dy = (y - LAKE_CY) / LAKE_RY
    return dx * dx + dy * dy


def lake_target_z(x, y, orig_z):
    norm = in_lake_norm(x, y)
    if norm > 1.0:
        return orig_z
    dist = math.sqrt(norm)
    if dist <= LAKE_WALL_START:
        return LAKE_FLOOR_Z
    blend = smoothstep(1.0, LAKE_WALL_START, dist)
    return LAKE_FLOOR_Z + (orig_z - LAKE_FLOOR_Z) * blend


def river_target_z(x, y, orig_z, path_points):
    dist, seg, t, _, _ = closest_on_polyline(x, y, path_points)
    if dist > RIVER_HALF_WIDTH:
        return orig_z
    rim = path_z_at(path_points, seg, t)
    center_bed = rim - RIVER_DEPTH
    edge_blend = smoothstep(RIVER_HALF_WIDTH, RIVER_HALF_WIDTH * 0.35, dist)
    target = center_bed + (rim - center_bed) * (1.0 - edge_blend)
    return min(orig_z, target)


def carve_terrain(terrain):
    mesh = terrain.data
    mw = terrain.matrix_world
    imw = mw.inverted()
    path_points = sample_path_surface_z(terrain, RIVER_XY)
    log(f"path surface Z: {[round(p[2], 1) for p in path_points]}")

    orig = []
    for vert in mesh.vertices:
        orig.append((mw @ vert.co).copy())

    changed = 0
    river_changed = 0
    lake_changed = 0
    for idx, vert in enumerate(mesh.vertices):
        w = orig[idx]
        o_z = w.z
        in_lake = in_lake_norm(w.x, w.y) <= 1.0
        dist, _, _, _, _ = closest_on_polyline(w.x, w.y, path_points)
        in_river = dist <= RIVER_HALF_WIDTH

        if not in_lake and not in_river:
            continue

        if in_lake:
            target = lake_target_z(w.x, w.y, o_z)
            lake_changed += 1
        else:
            target = river_target_z(w.x, w.y, o_z, path_points)
            river_changed += 1

        if in_lake and in_river:
            target = min(
                lake_target_z(w.x, w.y, o_z),
                river_target_z(w.x, w.y, o_z, path_points),
            )

        if target < o_z - 0.05:
            w.z = target
            vert.co = imw @ w
            changed += 1

    mesh.update()
    terrain.data.update()
    log(f"carved verts={changed} river={river_changed} lake={lake_changed}")
    return path_points


def ensure_collection(name, parent=None):
    coll = bpy.data.collections.get(name)
    if coll is None:
        coll = bpy.data.collections.new(name)
        (parent or bpy.context.scene.collection).children.link(coll)
    return coll


def link_exclusive(obj, coll):
    for user in list(obj.users_collection):
        user.objects.unlink(obj)
    coll.objects.link(obj)


def replace_bridge():
    scn = bpy.context.scene
    old = bpy.data.objects.get("Bridge_01")
    if old is not None:
        omn = [1e9, 1e9, 1e9]
        omx = [-1e9, -1e9, -1e9]
        for corner in old.bound_box:
            w = old.matrix_world @ Vector(corner)
            for i in range(3):
                omn[i] = min(omn[i], w[i])
                omx[i] = max(omx[i], w[i])
        o_center = [(omn[i] + omx[i]) / 2 for i in range(3)]
        o_span_y = omx[1] - omn[1]
        o_deck_top = omx[2]
    else:
        o_center = [27.6, 10.0, 15.0]
        o_span_y = 26.6
        o_deck_top = 17.5

    coll = ensure_collection("COL_Bridge")
    for obj in list(coll.objects):
        bpy.data.objects.remove(obj, do_unlink=True)

    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=BRIDGE_GLB)
    new_objs = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new_objs if o.type == "MESH"]

    def world_bbox(objs):
        mn = [1e9] * 3
        mx = [-1e9] * 3
        for obj in objs:
            obj_mw = obj.matrix_world
            for v in obj.data.vertices:
                w = obj_mw @ v.co
                for i in range(3):
                    mn[i] = min(mn[i], w[i])
                    mx[i] = max(mx[i], w[i])
        return mn, mx

    for mesh_obj in meshes:
        mesh_obj.data.transform(mesh_obj.matrix_world)
        mesh_obj.matrix_world = Matrix.Identity(4)

    for obj in new_objs:
        if obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)

    nmn, nmx = world_bbox(meshes)
    scale = (o_span_y * 1.02) / max(0.001, nmx[1] - nmn[1])
    scale_m = Matrix.Diagonal((scale, scale, scale, 1.0))
    for mesh_obj in meshes:
        mesh_obj.data.transform(scale_m)

    nmn, nmx = world_bbox(meshes)
    n_center = [(nmn[i] + nmx[i]) / 2 for i in range(3)]
    floor = next((o for o in meshes if "floor" in o.name.lower()), None)
    deck_top = world_bbox([floor])[1][2] if floor else nmx[2]
    delta = Vector(
        (
            o_center[0] - n_center[0],
            o_center[1] - n_center[1],
            o_deck_top - deck_top,
        )
    )
    for mesh_obj in meshes:
        mesh_obj.data.transform(Matrix.Translation(delta))

    if old is not None:
        bpy.data.objects.remove(old, do_unlink=True)

    for i, mesh_obj in enumerate(meshes):
        mesh_obj.name = "Bridge_01" if i == 0 else f"Bridge_Part_{i:02d}"
        mesh_obj.data.name = mesh_obj.name + "_mesh"
        link_exclusive(mesh_obj, coll)

    fmn, fmx = world_bbox(meshes)
    log(
        "bridge "
        f"deck_z={fmx[2]:.2f} span_y={fmx[1]-fmn[1]:.1f} x={fmn[0]:.1f}..{fmx[0]:.1f}"
    )
    return fmn, fmx


def terrain_bed_z(terrain, x, y):
    mw = terrain.matrix_world
    best = None
    best_d = 1e9
    for vert in terrain.data.vertices:
        w = mw @ vert.co
        d = (w.x - x) ** 2 + (w.y - y) ** 2
        if d < best_d:
            best_d = d
            best = w.z
    return best


def create_rope_descent(terrain, bridge_bbox, path_points):
    fmn, fmx = bridge_bbox
    dist, seg, t, _, _ = closest_on_polyline(34.0, 18.0, path_points)
    bed_z = path_z_at(path_points, seg, t) - RIVER_DEPTH + 0.4
    top = Vector((fmx[0] - 1.5, (fmn[1] + fmx[1]) / 2.0, fmx[2] - 0.25))
    mid = Vector((36.0, 14.0, (top.z + bed_z) * 0.45))
    bed = Vector((34.0, 18.0, bed_z))

    for name in ("Rope_Descent", "Sp_Rope_Top", "Sp_Rope_Bottom"):
        obj = bpy.data.objects.get(name)
        if obj:
            bpy.data.objects.remove(obj, do_unlink=True)

    curve_data = bpy.data.curves.new("Rope_Descent_Curve", "CURVE")
    curve_data.dimensions = "3D"
    curve_data.fill_mode = "FULL"
    curve_data.bevel_depth = 0.045
    curve_data.bevel_resolution = 4
    spline = curve_data.splines.new("BEZIER")
    spline.bezier_points.add(2)
    pts = [top, mid, bed]
    for bp, co in zip(spline.bezier_points, pts):
        bp.co = co
        bp.handle_left_type = "AUTO"
        bp.handle_right_type = "AUTO"

    rope = bpy.data.objects.new("Rope_Descent", curve_data)
    mat = bpy.data.materials.get("MAT_Rope") or bpy.data.materials.new("MAT_Rope")
    if not mat.use_nodes:
        mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.18, 0.12, 0.05, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.85
    curve_data.materials.append(mat)

    poi = ensure_collection("COL_POI")
    link_exclusive(rope, poi)

    for name, loc in (("Sp_Rope_Top", top), ("Sp_Rope_Bottom", bed)):
        empty = bpy.data.objects.new(name, None)
        empty.empty_display_size = 1.2
        empty.location = loc
        link_exclusive(empty, poi)

    log(f"rope top={tuple(round(v,1) for v in top)} bottom={tuple(round(v,1) for v in bed)}")
    return top, bed


def ensure_machete():
    machete = bpy.data.objects.get("Machete")
    if machete is None:
        raise RuntimeError("Machete object missing — add once before deleting backups")

    machete.location = (LAKE_CX, LAKE_CY, LAKE_FLOOR_Z + 0.15)
    machete.rotation_euler = (math.radians(15.0), math.radians(5.0), math.radians(30.0))
    machete.scale = (0.35, 0.35, 0.35)
    poi = ensure_collection("COL_POI")
    link_exclusive(machete, poi)

    marker = bpy.data.objects.get("Sp_Machete")
    if marker is None:
        marker = bpy.data.objects.new("Sp_Machete", None)
        marker.empty_display_size = 1.5
    marker.location = machete.location
    link_exclusive(marker, poi)
    log(f"machete z={machete.location.z:.2f}")


def verify(terrain, path_points):
    mw = terrain.matrix_world
    all_z = [(mw @ v.co).z for v in terrain.data.vertices]
    forest = []
    for v in terrain.data.vertices:
        w = mw @ v.co
        if (w.x - FOREST_TEST[0]) ** 2 + (w.y - FOREST_TEST[1]) ** 2 <= FOREST_TEST[2] ** 2:
            forest.append(w.z)

    samples = []
    for x, y, _ in path_points:
        samples.append(terrain_bed_z(terrain, x, y))

    lake_center = terrain_bed_z(terrain, LAKE_CX, LAKE_CY)
    result = {
        "min_z": round(min(all_z), 2),
        "forest_min_z": round(min(forest), 2) if forest else None,
        "lake_center_z": round(lake_center, 2),
        "lake_floor_target": round(LAKE_FLOOR_Z, 2),
        "river_bed_samples": [round(z, 2) for z in samples],
    }
    if min(forest) < 20.0:
        raise RuntimeError(f"Forest crater detected: min_z={min(forest):.2f}")
    if lake_center > LAKE_FLOOR_Z + 2.0:
        raise RuntimeError(f"Lake too shallow: {lake_center:.2f}")
    log(f"verify {result}")
    return result


def export_glb():
    view_layer = bpy.context.view_layer
    lib_lc = _find_layer_coll(view_layer.layer_collection, "COL_PropLibrary")
    prev_exclude = None
    if lib_lc:
        prev_exclude = lib_lc.exclude
        lib_lc.exclude = True
    view_layer.update()
    bpy.ops.export_scene.gltf(
        filepath=GLB,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        use_visible=True,
    )
    if lib_lc and prev_exclude is not None:
        lib_lc.exclude = prev_exclude


def main():
    if bpy.data.filepath != BLEND:
        bpy.ops.wm.open_mainfile(filepath=BLEND)

    terrain = bpy.data.objects.get("Terrain_Main")
    if terrain is None:
        raise RuntimeError("Terrain_Main missing")

    path_points = carve_terrain(terrain)
    bridge_bbox = replace_bridge()
    create_rope_descent(terrain, bridge_bbox, path_points)
    ensure_machete()
    verify(terrain, path_points)
    bpy.ops.wm.save_mainfile(filepath=BLEND)
    export_glb()
    log(f"saved blend + {GLB}")


main()
