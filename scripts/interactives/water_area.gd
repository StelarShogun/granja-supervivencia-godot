extends Area3D

@export var deep_water: bool = true
@export var water_surface_y: float = 0.0
@export var use_body_y_as_surface: bool = false
@export var game_manager_path: NodePath = NodePath("../../GameManager")
@export var enter_message: String = "Entraste al agua. Vigila el oxigeno."
@export var exit_message: String = "Saliste del agua."


func _ready() -> void:
	add_to_group("water")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("enter_water"):
		var surface_y := body.global_position.y if use_body_y_as_surface else water_surface_y
		body.enter_water(self, deep_water, surface_y)
	var manager := _get_game_manager()
	if manager != null and manager.has_method("show_message"):
		manager.show_message(enter_message, 1.8)


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("exit_water"):
		body.exit_water(self)
	var manager := _get_game_manager()
	if manager != null and manager.has_method("show_message"):
		manager.show_message(exit_message, 1.2)


func _get_game_manager() -> Node:
	if game_manager_path != NodePath("") and has_node(game_manager_path):
		return get_node(game_manager_path)

	var managers := get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		return managers[0]
	return null
