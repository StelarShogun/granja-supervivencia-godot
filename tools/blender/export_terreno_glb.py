"""Export Terreno_Finca.glb for Godot, excluding the prop library.

Run via the in-Blender MCP socket. Saves the .blend, hides COL_PropLibrary
(source variants near origin that must NOT ship), exports visible objects to
GLB with Y-up + applied modifiers, then restores visibility.
"""
import bpy
import functools

GLB_PATH = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.glb"


def _find_layer_coll(layer_coll, name):
    if layer_coll.collection.name == name:
        return layer_coll
    for ch in layer_coll.children:
        r = _find_layer_coll(ch, name)
        if r:
            return r
    return None


def run():
    vl = bpy.context.view_layer
    lib_lc = _find_layer_coll(vl.layer_collection, "COL_PropLibrary")
    prev_exclude = None
    if lib_lc:
        prev_exclude = lib_lc.exclude
        lib_lc.exclude = True   # removes from view layer -> not "visible" for export

    # also defensively hide any leftover root empties
    bpy.context.view_layer.update()

    visible_meshes = sum(
        1 for o in vl.objects if o.type == 'MESH' and o.visible_get())

    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        use_visible=True,
    )

    if lib_lc and prev_exclude is not None:
        lib_lc.exclude = prev_exclude

    return {"glb": GLB_PATH, "exported_visible_meshes": visible_meshes}


result = run()
