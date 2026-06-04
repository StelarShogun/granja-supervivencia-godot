extends Area3D

@export var points: int = 100
@export var game_manager_path: NodePath = NodePath("../../GameManager")

var collected: bool = false


func _ready() -> void:
	add_to_group("animals")
	body_entered.connect(_on_body_entered)


func interact(player: Node) -> void:
	if player != null and player.is_in_group("player"):
		_collect()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_collect()


func _collect() -> void:
	if collected:
		return

	collected = true
	monitoring = false
	monitorable = false

	var manager := _get_game_manager()
	if manager != null and manager.has_method("collect_animal"):
		manager.collect_animal(points, self)

	hide()
	call_deferred("queue_free")


func _get_game_manager() -> Node:
	if game_manager_path != NodePath("") and has_node(game_manager_path):
		return get_node(game_manager_path)

	var managers := get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		return managers[0]
	return null
