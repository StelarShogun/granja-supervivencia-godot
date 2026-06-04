extends CharacterBody3D

@export var player_path: NodePath = NodePath("../Player")
@export var spawn_path: NodePath = NodePath("../SpawnPoints/Diablo_Spawn")
@export var game_manager_path: NodePath = NodePath("../GameManager")
@export var base_speed: float = 3.0
@export var contact_cooldown: float = 0.8

var chase_speed: float = 3.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var active: bool = false
var target_in_safe_zone: bool = false

var _cooldown_left: float = 0.0

@onready var _hit_box: Area3D = $HitBox


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("diablo")
	chase_speed = base_speed
	_hit_box.body_entered.connect(_on_hit_box_body_entered)
	deactivate()


func _physics_process(delta: float) -> void:
	if not active:
		return

	if _cooldown_left > 0.0:
		_cooldown_left -= delta

	var manager := _get_game_manager()
	if manager != null and bool(manager.get("game_over")):
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		move_and_slide()
		return
	if manager != null and _is_player_safe(manager):
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		move_and_slide()
		return

	var player := _get_player()
	if player == null:
		_apply_gravity(delta)
		move_and_slide()
		return

	var direction: Vector3 = player.global_position - global_position
	direction.y = 0.0

	if direction.length_squared() > 0.04:
		direction = direction.normalized()
		velocity.x = direction.x * chase_speed
		velocity.z = direction.z * chase_speed
		look_at(global_position + direction, Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	_apply_gravity(delta)
	move_and_slide()


func set_progress(progress: int) -> void:
	match progress:
		1:
			chase_speed = 3.0
		2:
			chase_speed = 4.0
		_:
			chase_speed = 5.0


func set_target_safe_zone(value: bool) -> void:
	target_in_safe_zone = value
	if value:
		velocity.x = 0.0
		velocity.z = 0.0


func reset_position() -> void:
	var spawn := _get_spawn()
	if spawn != null:
		global_position = spawn.global_position
	velocity = Vector3.ZERO


func reset_to_spawn() -> void:
	reset_position()


func activate() -> void:
	active = true
	show()
	set_physics_process(true)
	if _hit_box != null:
		_hit_box.monitoring = true
		_hit_box.monitorable = true


func deactivate() -> void:
	active = false
	hide()
	velocity = Vector3.ZERO
	set_physics_process(false)
	if _hit_box != null:
		_hit_box.monitoring = false
		_hit_box.monitorable = false


func _on_hit_box_body_entered(body: Node3D) -> void:
	if _cooldown_left > 0.0:
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("receive_damage"):
		return
	var manager := _get_game_manager()
	if manager != null and _is_player_safe(manager):
		return

	var damaged: bool = body.receive_damage()
	if damaged:
		_cooldown_left = contact_cooldown
		if manager != null and manager.has_method("show_message"):
			manager.show_message("El Diablo te alcanzo.", 1.7)
		reset_position()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = maxf(velocity.y, -0.2)


func _get_player() -> Node3D:
	if player_path != NodePath("") and has_node(player_path):
		return get_node(player_path) as Node3D

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node3D
	return null


func _get_spawn() -> Node3D:
	if spawn_path != NodePath("") and has_node(spawn_path):
		return get_node(spawn_path) as Node3D
	return null


func _get_game_manager() -> Node:
	if game_manager_path != NodePath("") and has_node(game_manager_path):
		return get_node(game_manager_path)

	var managers := get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		return managers[0]
	return null


func _is_player_safe(manager: Node) -> bool:
	if target_in_safe_zone:
		return true
	if manager.has_method("is_player_in_safe_zone"):
		return bool(manager.is_player_in_safe_zone())
	return bool(manager.get("player_in_safe_zone"))
