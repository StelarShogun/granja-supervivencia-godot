extends Area3D

@export var bottom_position: Vector3 = Vector3.ZERO
@export var game_manager_path: NodePath = NodePath("../../../GameManager")


func _ready() -> void:
	add_to_group("interactives")
	collision_layer = 8
	collision_mask = 1


func interact(player: Node) -> void:
	if bottom_position == Vector3.ZERO:
		return
	if not player is Node3D:
		return
	var node := player as Node3D
	node.global_position = bottom_position + Vector3(0.0, 0.5, 0.0)
	if node is CharacterBody3D:
		node.velocity = Vector3.ZERO
	var manager := _get_game_manager()
	if manager != null and manager.has_method("show_message"):
		manager.show_message("Bajaste por la cuerda al cauce del río.", 2.0)


func _get_game_manager() -> Node:
	if game_manager_path != NodePath("") and has_node(game_manager_path):
		return get_node(game_manager_path)
	var managers := get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		return managers[0]
	return null
