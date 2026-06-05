extends Area3D

@export var points: int = 100
@export var game_manager_path: NodePath = NodePath("../../GameManager")
@export var wander_speed: float = 1.8
@export var wander_radius: float = 120.0
@export var wander_interval_min: float = 3.0
@export var wander_interval_max: float = 7.0

var collected: bool = false

var _wander_target: Vector3
var _wander_timer: float = 0.0
var _has_start: bool = false

# Kojima mode: animal follows carrier
var _following: bool = false
var _follow_target: Node3D = null


func _ready() -> void:
	add_to_group("animals")
	body_entered.connect(_on_body_entered)
	_wander_target = global_position
	_wander_timer = randf_range(wander_interval_min, wander_interval_max)


func _process(delta: float) -> void:
	if collected:
		return

	if _following and _follow_target != null:
		var target_pos := _follow_target.global_position + Vector3(1.2, 0.6, 0.0)
		global_position = global_position.lerp(target_pos, 12.0 * delta)
		return

	if not _has_start:
		_has_start = true
		_wander_target = global_position

	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_wander_target()
		_wander_timer = randf_range(wander_interval_min, wander_interval_max)

	var diff := _wander_target - global_position
	diff.y = 0.0
	if diff.length() > 1.0:
		var step := diff.normalized() * wander_speed * delta
		global_position += Vector3(step.x, 0.0, step.z)


func _pick_wander_target() -> void:
	var angle := randf() * TAU
	var radius := randf_range(20.0, wander_radius)
	var nx := global_position.x + cos(angle) * radius
	var nz := global_position.z + sin(angle) * radius
	nx = clampf(nx, -230.0, 230.0)
	nz = clampf(nz, -230.0, 230.0)
	var dx := nx - (-150.0)
	var dz := nz - (-145.0)
	if (dx * dx) / (55.0 * 55.0) + (dz * dz) / (40.0 * 40.0) < 1.0:
		angle += PI
		nx = global_position.x + cos(angle) * radius
		nz = global_position.z + sin(angle) * radius
	_wander_target = Vector3(nx, global_position.y, nz)


func interact(player: Node) -> void:
	if player != null and player.is_in_group("player"):
		if SaveManager.game_mode == 1:
			_try_pickup(player)
		else:
			_collect()


func pickup(player: Node) -> void:
	_try_pickup(player)


func drop(drop_position: Vector3) -> void:
	_following = false
	_follow_target = null
	global_position = drop_position
	_wander_target = drop_position


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if SaveManager.game_mode == 1:
		_try_pickup(body)
	else:
		_collect()


func _try_pickup(player: Node) -> void:
	if collected or _following:
		return
	if player.has_method("pickup_animal"):
		var ok: bool = player.pickup_animal(self)
		if ok:
			_following = true
			_follow_target = player as Node3D
			monitoring = false


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
