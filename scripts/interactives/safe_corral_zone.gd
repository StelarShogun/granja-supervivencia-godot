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
	# Entering the safe zone immediately delivers a carried animal: it counts
	# toward the goal and is released to wander freely inside the corral.
	_deliver_carried(body)


## Deliver the animal the player is carrying (if any): count it and release it
## to roam the corral. Safe to call alongside CorralZone — deliver_animal()
## nulls the carry, so whichever zone fires first wins and the other no-ops.
func _deliver_carried(player: Node) -> void:
	if not player.has_method("deliver_animal"):
		return
	var animal: Node = player.deliver_animal()
	if animal == null:
		return
	if animal.has_method("register_in_corral"):
		animal.register_in_corral(global_position)
	var manager := _get_game_manager()
	if manager != null and manager.has_method("collect_animal"):
		manager.collect_animal(animal)


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
