extends Area3D

@export var game_manager_path: NodePath = NodePath("../../GameManager")

var animals_count: int = 0
var animal_goal: int = 10


func _ready() -> void:
	add_to_group("interactives")
	add_to_group("corral_zone")
	body_entered.connect(_on_body_entered)


func set_count(count: int, goal: int) -> void:
	animals_count = count
	animal_goal = goal


func interact(_player: Node) -> void:
	_show_count_message()


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if SaveManager.game_mode == 1:
		_try_receive_animal(body)
	else:
		_show_count_message()


func _try_receive_animal(player: Node) -> void:
	if not player.has_method("deliver_animal"):
		_show_count_message()
		return
	var animal: Node = player.deliver_animal()
	if animal == null:
		_show_count_message()
		return
	# Score the delivered animal
	var manager := _get_game_manager()
	if manager != null and manager.has_method("collect_animal"):
		var pts: int = int(animal.get("points")) if animal.has_method("get") else 100
		if animal.has_method("_collect"):
			pass
		# Mark collected manually
		if animal.has_method("get"):
			animal.set("collected", true)
			animal.set("_following", false)
		animal.hide()
		animal.call_deferred("queue_free")
		manager.collect_animal(pts, animal)


func _show_count_message() -> void:
	var manager := _get_game_manager()
	if manager != null and manager.has_method("show_message"):
		manager.show_message("Zona del corral. Animales: %d / %d" % [animals_count, animal_goal], 1.8)


func _get_game_manager() -> Node:
	if game_manager_path != NodePath("") and has_node(game_manager_path):
		return get_node(game_manager_path)
	var managers := get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		return managers[0]
	return null
