"""Snap Sp_* markers to terrain; add Sp_Diablo_Cave; export GLB."""
import bpy
from mathutils import Vector

BLEND = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.blend"
GLB = "/home/dilan/Documentos/GitHub/granja-supervivencia-godot/assets/models/environment/Terreno_Finca.glb"

# Godot (x, z) -> Blender horizontal (x, y) where godot_z = -blender_y
CAVE_GODOT_XZ = (165.0, 178.0)

SPAWN_OFFSETS = {
	"Sp_Player": 0.5,
	"Sp_Diablo": 0.5,
	"Sp_Diablo_Cave": 0.5,
}
DEFAULT_ANIMAL_OFFSET = 0.35


def log(msg: str) -> None:
	print(f"[snap_spawns] {msg}", flush=True)


def godot_xz_to_blender_xy(gx: float, gz: float) -> tuple[float, float]:
	return gx, -gz


def ground_z(bx: float, by: float, scn, dg) -> float:
	result = scn.ray_cast(dg, Vector((bx, by, 120.0)), Vector((0, 0, -1)))
	if result[0]:
		return result[1].z
	result = scn.ray_cast(dg, Vector((bx, by, 200.0)), Vector((0, 0, -1)))
	return result[1].z if result[0] else 5.0


def main() -> dict:
	if bpy.data.filepath != BLEND:
		bpy.ops.wm.open_mainfile(filepath=BLEND)

	scn = bpy.context.scene
	dg = bpy.context.evaluated_depsgraph_get()
	snapped = 0

	bx, by = godot_xz_to_blender_xy(*CAVE_GODOT_XZ)
	cave = bpy.data.objects.get("Sp_Diablo_Cave")
	if cave is None:
		cave = bpy.data.objects.new("Sp_Diablo_Cave", None)
		cave.empty_display_type = "SPHERE"
		cave.empty_display_size = 1.2
		scn.collection.objects.link(cave)
		log("created Sp_Diablo_Cave")
	lip = bpy.data.objects.get("Cave_Lip_Top")
	if lip is not None:
		cave_z = lip.location.z + SPAWN_OFFSETS["Sp_Diablo_Cave"]
		cave.location = (bx, by, cave_z)
	else:
		cave_z = ground_z(bx, by, scn, dg) + SPAWN_OFFSETS["Sp_Diablo_Cave"]
		cave.location = (bx, by, cave_z)
	log(f"Sp_Diablo_Cave blender=({bx:.1f},{by:.1f},{cave_z:.3f})")

	for obj in bpy.data.objects:
		if not obj.name.startswith("Sp_"):
			continue
		if obj.name == "Sp_Diablo_Cave":
			continue
		bx, by = obj.location.x, obj.location.y
		gz = ground_z(bx, by, scn, dg)
		offset = SPAWN_OFFSETS.get(obj.name, DEFAULT_ANIMAL_OFFSET)
		new_z = gz + offset
		obj.location.z = new_z
		snapped += 1
		log(f"{obj.name} z={new_z:.3f} at ({bx:.1f},{by:.1f})")

	bpy.ops.wm.save_mainfile()
	bpy.ops.export_scene.gltf(
		filepath=GLB,
		export_format="GLB",
		export_apply=True,
		export_yup=True,
	)
	log(f"snapped={snapped} exported={GLB}")
	return {"snapped": snapped}


result = main()
