extends Area3D

@export var game_manager_path: NodePath = NodePath("../../GameManager")
@export var cave_message: String = "Entraste a la cueva de la montaña."
@export var diablo_warning: String = "Algo se mueve en la oscuridad. El Diablo aún no ha salido."

var _triggered: bool = false


func _ready() -> void:
	add_to_group("interactives")
	body_entered.connect(_on_body_entered)


func interact(_player: Node) -> void:
	_fire()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_fire()


func _fire() -> void:
	if _triggered:
		return
	_triggered = true

	var manager := _get_game_manager()
	if manager == null:
		return

	if manager.has_method("show_message"):
		manager.show_message(cave_message, 2.4)

	if manager.has_method("set_player_entered_cave"):
		manager.set_player_entered_cave(true)

	if not bool(manager.get("diablo_spawned")) and manager.has_method("show_message"):
		manager.show_message(diablo_warning, 3.0)


func _get_game_manager() -> Node:
	if game_manager_path != NodePath("") and has_node(game_manager_path):
		return get_node(game_manager_path)
	var managers := get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		return managers[0]
	return null
