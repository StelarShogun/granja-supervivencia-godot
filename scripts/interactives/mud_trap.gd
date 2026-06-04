extends Area3D

@export var slow_multiplier: float = 0.45
@export var slow_duration: float = 2.0
@export var game_manager_path: NodePath = NodePath("../../GameManager")
## Drop the trap onto the terrain at runtime so it is never floating or buried,
## even when placed with an approximate height.
@export var snap_to_ground: bool = true


func _ready() -> void:
	add_to_group("interactives")
	body_entered.connect(_on_body_entered)
	if snap_to_ground:
		_deferred_snap()


func _deferred_snap() -> void:
	# Wait for the terrain collision to be built before raycasting.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var from := global_position + Vector3.UP * 40.0
	var to := global_position + Vector3.DOWN * 80.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = float(hit.position.y) + 0.06


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	if body.has_method("slow_down"):
		body.slow_down(slow_duration)
	elif body.has_method("apply_mud_slow"):
		body.apply_mud_slow(slow_multiplier, slow_duration)

	var manager := _get_game_manager()
	if manager != null and manager.has_method("show_message"):
		manager.show_message("Barro: movimiento reducido temporalmente.", 1.8)


func _get_game_manager() -> Node:
	if game_manager_path != NodePath("") and has_node(game_manager_path):
		return get_node(game_manager_path)

	var managers := get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		return managers[0]
	return null
