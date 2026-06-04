extends Area3D

@export var game_manager_path: NodePath = NodePath("../../GameManager")


func _ready() -> void:
	add_to_group("safe_zone")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var manager := _get_game_manager()
	if manager != null and manager.has_method("set_player_safe_zone"):
		manager.set_player_safe_zone(true)


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var manager := _get_game_manager()
	if manager != null and manager.has_method("set_player_safe_zone"):
		manager.set_player_safe_zone(false)


func _get_game_manager() -> Node:
	if game_manager_path != NodePath("") and has_node(game_manager_path):
		return get_node(game_manager_path)

	var managers := get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		return managers[0]
	return null
