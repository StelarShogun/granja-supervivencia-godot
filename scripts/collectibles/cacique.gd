extends Area3D

@export var heal_amount: float = 40.0
@export var game_manager_path: NodePath = NodePath("../../GameManager")


func _ready() -> void:
	add_to_group("interactives")
	body_entered.connect(_on_body_entered)


func interact(player: Node) -> void:
	_try_consume(player)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_try_consume(body)


func _try_consume(player: Node) -> void:
	if not player.has_method("heal"):
		return
	var max_hp: float = float(player.get("MAX_HEALTH"))
	var current: float = float(player.get("health"))
	if current >= max_hp:
		var manager := _get_game_manager()
		if manager != null and manager.has_method("show_message"):
			manager.show_message("Ya tienes la vida al máximo.", 1.5)
		return

	player.heal(heal_amount)
	var manager2 := _get_game_manager()
	if manager2 != null and manager2.has_method("show_message"):
		manager2.show_message("Cacique: +%.0f vida." % heal_amount, 1.8)

	hide()
	monitoring = false
	queue_free()


func _get_game_manager() -> Node:
	if game_manager_path != NodePath("") and has_node(game_manager_path):
		return get_node(game_manager_path)
	var managers := get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		return managers[0]
	return null
