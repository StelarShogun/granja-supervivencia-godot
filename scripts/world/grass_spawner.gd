@tool
extends Node3D

@export var grass_scene: PackedScene
@export var density: int = 1200
@export var area_center: Vector3 = Vector3(20.0, 0.0, -30.0)
@export var area_size: Vector2 = Vector2(180.0, 150.0)
@export var min_y: float = -1.0
@export var max_y: float = 10.0
@export var min_scale: float = 0.6
@export var max_scale: float = 1.3
@export var raycast_from_y: float = 60.0
@export var enabled: bool = true

var _multi_mesh: MultiMeshInstance3D

func _ready() -> void:
	if not enabled:
		return
	if Engine.is_editor_hint():
		return
	call_deferred("_spawn_grass")


func _spawn_grass() -> void:
	if grass_scene == null:
		return

	var space := get_world_3d().direct_space_state
	if space == null:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var transforms: Array[Transform3D] = []

	var half_x := area_size.x * 0.5
	var half_z := area_size.y * 0.5

	var attempts := 0
	while transforms.size() < density and attempts < density * 8:
		attempts += 1
		var rx := area_center.x + rng.randf_range(-half_x, half_x)
		var rz := area_center.z + rng.randf_range(-half_z, half_z)

		var query := PhysicsRayQueryParameters3D.create(
			Vector3(rx, raycast_from_y, rz),
			Vector3(rx, -20.0, rz)
		)
		query.collision_mask = 2
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue

		var hy: float = hit.position.y
		if hy < min_y or hy > max_y:
			continue
		var n: Vector3 = hit.normal
		if n.dot(Vector3.UP) < 0.7:
			continue

		var scale_v := rng.randf_range(min_scale, max_scale)
		var rot_y := rng.randf_range(0.0, TAU)
		var xform := Transform3D(
			Basis(Vector3.UP, rot_y).scaled(Vector3.ONE * scale_v),
			hit.position
		)
		transforms.append(xform)

	if transforms.is_empty():
		return

	var root := grass_scene.instantiate()
	add_child(root)
	root.visible = false

	var source_mesh: Mesh = null
	for child in root.get_children():
		if child is MeshInstance3D:
			source_mesh = (child as MeshInstance3D).mesh
			break
	if source_mesh == null and root is MeshInstance3D:
		source_mesh = (root as MeshInstance3D).mesh

	if source_mesh == null:
		root.queue_free()
		return
	root.queue_free()

	_multi_mesh = MultiMeshInstance3D.new()
	_multi_mesh.name = "GrassField"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = source_mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	_multi_mesh.multimesh = mm
	add_child(_multi_mesh)
