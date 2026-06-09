"""Restore-export helper: place Machete at lake floor and export clean GLB."""
import math
import bpy

BLEND = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.blend"
GLB = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.glb"
LAKE_CX, LAKE_CY = -150.347, 144.866


def _find_layer_coll(layer_coll, name):
    if layer_coll.collection.name == name:
        return layer_coll
    for child in layer_coll.children:
        found = _find_layer_coll(child, name)
        if found:
            return found
    return None


def _lake_floor_z(terrain):
    mw = terrain.matrix_world
    samples = []
    for vert in terrain.data.vertices:
        world = mw @ vert.co
        if abs(world.x - LAKE_CX) < 8.0 and abs(world.y - LAKE_CY) < 8.0:
            samples.append(world.z)
    if not samples:
        raise RuntimeError("Could not sample lake floor on Terrain_Main")
    return min(samples)


def _forest_min_z(terrain):
    mw = terrain.matrix_world
    samples = []
    for vert in terrain.data.vertices:
        world = mw @ vert.co
        if (world.x - 92.7) ** 2 + (world.y + 60.3) ** 2 <= 900.0:
            samples.append(world.z)
    return min(samples) if samples else None


def _ensure_machete(lake_floor_z):
    machete = bpy.data.objects.get("Machete")
    if machete is None:
        raise RuntimeError("Machete object missing in blend")

    machete.name = "Machete"
    machete.location = (LAKE_CX, LAKE_CY, lake_floor_z + 0.12)
    machete.rotation_euler = (math.radians(15.0), math.radians(5.0), math.radians(30.0))
    machete.scale = (0.35, 0.35, 0.35)

    poi = bpy.data.collections.get("COL_POI")
    if poi:
        for coll in list(machete.users_collection):
            coll.objects.unlink(machete)
        poi.objects.link(machete)
    return machete


def main():
    if bpy.data.filepath != BLEND:
        bpy.ops.wm.open_mainfile(filepath=BLEND)

    for obj in list(bpy.data.objects):
        if "052e68da" in obj.name:
            bpy.data.objects.remove(obj, do_unlink=True)

    terrain = bpy.data.objects["Terrain_Main"]
    all_z = [(terrain.matrix_world @ v.co).z for v in terrain.data.vertices]
    if min(all_z) <= -15.0:
        raise RuntimeError(f"Terrain_Main still broken: min Z={min(all_z):.2f}")

    lake_floor = _lake_floor_z(terrain)
    machete = _ensure_machete(lake_floor)

    bpy.ops.wm.save_mainfile(filepath=BLEND)

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

    forest_min = _forest_min_z(terrain)
    print(
        "DONE",
        {
            "terrain_min_z": round(min(all_z), 2),
            "forest_min_z": round(forest_min, 2) if forest_min is not None else None,
            "lake_floor_z": round(lake_floor, 2),
            "machete_loc": tuple(round(v, 2) for v in machete.location),
            "machete_scale": tuple(round(v, 2) for v in machete.scale),
            "glb": GLB,
        },
        flush=True,
    )


main()
