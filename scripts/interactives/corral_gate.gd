extends Area3D

@export var open_angle_degrees: float = 90.0
@export var game_manager_path: NodePath = NodePath("../../GameManager")

var is_open: bool = false
var _closed_rotation_y: float = 0.0


func _ready() -> void:
	add_to_group("interactives")
	_closed_rotation_y = rotation.y


func interact(_player: Node) -> void:
	is_open = not is_open
	rotation.y = _closed_rotation_y + (deg_to_rad(open_angle_degrees) if is_open else 0.0)

	var manager := _get_game_manager()
	if manager != null and manager.has_method("show_message"):
		manager.show_message("Puerta del corral abierta." if is_open else "Puerta del corral cerrada.", 1.6)


func _get_game_manager() -> Node:
	if game_manager_path != NodePath("") and has_node(game_manager_path):
		return get_node(game_manager_path)

	var managers := get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		return managers[0]
	return null
