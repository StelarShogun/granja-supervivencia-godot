extends StaticBody3D

## Builds trimesh collision from the named terrain meshes inside the
## sibling "Terreno_Finca" GLB instance. Only walkable/swimmable ground is
## collided (props keep no collision). Runs once at scene load.

## Lake basin and river channel are sculpted into Terrain_Main.
const TERRAIN_MESHES := [
	"Terrain_Main",
	"Mtn_Main",
]

## Walkable structures exported from the GLB (trimesh per mesh).
const STRUCTURE_PREFIXES := [
	"Granero_",
	"Corral_Fence",
	"Corral_GatePost",
	"Bridge_",
	"Cave_Lip",
]

const MAX_STRUCTURE_SHAPES := 128


func _ready() -> void:
	var source := get_parent().get_node_or_null("Terreno_Finca")
	if source == null:
		push_error("TerrainCollision: sibling 'Terreno_Finca' not found")
		return

	var terrain_built := 0
	var structure_built := 0
	for mesh_instance in _collect_mesh_instances(source):
		if TERRAIN_MESHES.has(mesh_instance.name):
			if _add_trimesh(mesh_instance):
				terrain_built += 1
			continue
		if structure_built >= MAX_STRUCTURE_SHAPES:
			continue
		if not _is_structure_mesh(mesh_instance.name):
			continue
		if _add_trimesh(mesh_instance):
			structure_built += 1

	print(
		"TerrainCollision: terrain=%d structure=%d trimesh shapes"
		% [terrain_built, structure_built]
	)


func _is_structure_mesh(mesh_name: String) -> bool:
	for prefix in STRUCTURE_PREFIXES:
		if mesh_name.begins_with(prefix):
			return true
	return false


func _add_trimesh(mesh_instance: MeshInstance3D) -> bool:
	var shape: Shape3D = mesh_instance.mesh.create_trimesh_shape()
	if shape == null:
		return false
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	collider.global_transform = mesh_instance.global_transform
	return true


func _collect_mesh_instances(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D and node.mesh != null:
		result.append(node)
	for child in node.get_children():
		result += _collect_mesh_instances(child)
	return result
