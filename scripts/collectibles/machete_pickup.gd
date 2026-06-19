extends Area3D

@export var game_manager_path: NodePath = NodePath("../../../GameManager")


func _ready() -> void:
	add_to_group("interactives")
	collision_layer = 8
	collision_mask = 1


## Texto de la pista contextual que muestra el HUD al estar en rango.
func get_interaction_prompt() -> String:
	return "Presiona E para tomar el machete"


func interact(player: Node) -> void:
	if not player.has_method("equip_machete"):
		return
	if bool(player.get("has_machete")):
		var manager := _get_game_manager()
		if manager != null and manager.has_method("show_message"):
			manager.show_message("Ya llevas el machete.", 1.5)
		return

	player.equip_machete()
	AudioManager.play_pickup()
	var manager2 := _get_game_manager()
	if manager2 != null and manager2.has_method("show_message"):
		manager2.show_message("Machete equipado: tu única arma contra el Diablo. (Clic izq. / F para atacar)", 3.0)
	queue_free()


func _get_game_manager() -> Node:
	if game_manager_path != NodePath("") and has_node(game_manager_path):
		return get_node(game_manager_path)
	var managers := get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		return managers[0]
	return null
