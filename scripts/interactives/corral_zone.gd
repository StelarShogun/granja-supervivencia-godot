extends Area3D

@export var game_manager_path: NodePath = NodePath("../../GameManager")

var animals_count: int = 0
var animal_goal: int = 10

const RESIDENT_OFFSETS: Array[Vector3] = [
	Vector3(-8.0, 0.0, -7.0),
	Vector3(-3.0, 0.0, -8.0),
	Vector3(3.0, 0.0, -8.0),
	Vector3(8.0, 0.0, -7.0),
	Vector3(-9.0, 0.0, 1.0),
	Vector3(9.0, 0.0, 1.0),
	Vector3(-7.0, 0.0, 8.0),
	Vector3(-2.0, 0.0, 9.0),
	Vector3(3.0, 0.0, 9.0),
	Vector3(8.0, 0.0, 8.0),
]

var _marker: MeshInstance3D


func _ready() -> void:
	add_to_group("interactives")
	add_to_group("corral_zone")
	body_entered.connect(_on_body_entered)
	_marker = get_node_or_null("CorralMarker") as MeshInstance3D
	_build_delivery_beacon()


func set_count(count: int, goal: int) -> void:
	animals_count = count
	animal_goal = goal


func interact(_player: Node) -> void:
	_show_count_message()


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_try_receive_animal(body)


func _try_receive_animal(player: Node) -> void:
	if not player.has_method("deliver_animal"):
		_show_count_message()
		return
	var animal: Node = player.deliver_animal()
	if animal == null:
		_show_count_message()
		return
	place_animal(animal, animals_count)
	var manager := _get_game_manager()
	if manager != null and manager.has_method("collect_animal"):
		manager.collect_animal(animal)


func place_animal(animal: Node, slot: int, play_sound: bool = true) -> void:
	if animal == null:
		return
	var index := clampi(slot, 0, RESIDENT_OFFSETS.size() - 1)
	var resident_position := global_position + RESIDENT_OFFSETS[index]
	if animal.has_method("register_in_corral"):
		animal.register_in_corral(resident_position, play_sound)


func _process(_delta: float) -> void:
	if _marker == null:
		return
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.045
	_marker.scale = Vector3(pulse, 1.0, pulse)


func _build_delivery_beacon() -> void:
	var beacon := OmniLight3D.new()
	beacon.name = "DeliveryBeacon"
	beacon.position = Vector3(0.0, 1.5, 0.0)
	beacon.light_color = Color(1.0, 0.72, 0.12)
	beacon.light_energy = 2.2
	beacon.omni_range = 8.0
	beacon.shadow_enabled = false
	add_child(beacon)


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
