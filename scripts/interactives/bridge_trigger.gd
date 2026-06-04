extends Area3D

@export var message: String = "Puente de cruce del río"
@export var game_manager_path: NodePath = NodePath("../../GameManager")


func _ready() -> void:
	add_to_group("interactives")
	body_entered.connect(_on_body_entered)


func interact(_player: Node) -> void:
	_show_message()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_show_message()


func _show_message() -> void:
	var manager := _get_game_manager()
	if manager != null and manager.has_method("show_message"):
		manager.show_message(message, 1.8)


func _get_game_manager() -> Node:
	if game_manager_path != NodePath("") and has_node(game_manager_path):
		return get_node(game_manager_path)

	var managers := get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		return managers[0]
	return null
