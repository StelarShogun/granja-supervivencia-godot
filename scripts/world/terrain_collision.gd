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
	"Cave_Lip",
]
## NOTE: "Bridge_" removed — the GLB Bridge_Part_01 sits sunken at the
## gorge floor (obsolete; GlbCleanup deletes it). The walkable bridge is
## scripts/structures/wooden_bridge.gd, which builds its own collision.

const MAX_STRUCTURE_SHAPES := 128

## Cheap primitive collision proxies for blocking props (no mass trimesh).
## Trees get a trunk cylinder; large rocks and loose fences get an AABB box.
const TREE_PREFIXES := ["Lib_Tree"]
const TRUNK_RADIUS := 0.4
const TRUNK_HEIGHT := 2.5
const ROCK_PREFIXES := ["Rock_", "Lib_Rock", "River_Bank_Rock"]
const ROCK_MIN_SIZE := 1.0
const FENCE_PREFIXES := ["Lib_Fence", "POI_BrokenFence"]
const MAX_PROXY_SHAPES := 1500


func _ready() -> void:
	var source := get_parent().get_node_or_null("Terreno_Finca")
	if source == null:
		push_error("TerrainCollision: sibling 'Terreno_Finca' not found")
		return

	var terrain_built := 0
	var structure_built := 0
	var proxy_built := 0
	for mesh_instance in _collect_mesh_instances(source):
		if TERRAIN_MESHES.has(mesh_instance.name):
			if _add_trimesh(mesh_instance):
				terrain_built += 1
			continue
		if _is_structure_mesh(mesh_instance.name):
			if structure_built < MAX_STRUCTURE_SHAPES and _add_trimesh(mesh_instance):
				structure_built += 1
			continue
		if proxy_built >= MAX_PROXY_SHAPES:
			continue
		if _add_proxy(mesh_instance):
			proxy_built += 1

	print(
		"TerrainCollision: terrain=%d structure=%d proxy=%d shapes"
		% [terrain_built, structure_built, proxy_built]
	)


func _matches_prefix(mesh_name: String, prefixes: Array) -> bool:
	for prefix in prefixes:
		if mesh_name.begins_with(prefix):
			return true
	return false


## Primitive collision for blocking props: trunk cylinder for trees,
## AABB box for big rocks and loose fence segments.
func _add_proxy(mesh_instance: MeshInstance3D) -> bool:
	var mesh_name := String(mesh_instance.name)
	var aabb: AABB = mesh_instance.get_aabb()
	var xform := mesh_instance.global_transform

	if _matches_prefix(mesh_name, TREE_PREFIXES):
		var base_local := aabb.get_center()
		base_local.y = aabb.position.y
		var base := xform * base_local
		var scale_xz := maxf(xform.basis.get_scale().x, xform.basis.get_scale().z)
		var cyl := CylinderShape3D.new()
		cyl.radius = TRUNK_RADIUS * maxf(scale_xz, 0.2)
		cyl.height = TRUNK_HEIGHT
		var collider := CollisionShape3D.new()
		collider.shape = cyl
		add_child(collider)
		collider.global_transform = Transform3D(
			Basis(), base + Vector3.UP * TRUNK_HEIGHT * 0.5)
		return true

	var is_rock := _matches_prefix(mesh_name, ROCK_PREFIXES)
	var is_fence := _matches_prefix(mesh_name, FENCE_PREFIXES)
	if not is_rock and not is_fence:
		return false
	var world_size: Vector3 = aabb.size * xform.basis.get_scale()
	if is_rock and world_size[world_size.max_axis_index()] < ROCK_MIN_SIZE:
		return false
	var box := BoxShape3D.new()
	box.size = aabb.size
	var box_collider := CollisionShape3D.new()
	box_collider.shape = box
	add_child(box_collider)
	box_collider.global_transform = xform.translated_local(aabb.get_center())
	return true


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
