extends CharacterBody3D

@export var player_path: NodePath = NodePath("../Player")
@export var spawn_path: NodePath = NodePath("../SpawnPoints/Diablo_Spawn")
@export var game_manager_path: NodePath = NodePath("../GameManager")

## Normal mode speeds per progress level (1/2/3)
@export var speed_normal: Vector3 = Vector3(5.0, 7.0, 9.0)
## Modo difícil speeds per progress level (1/2/3)
@export var speed_kojima: Vector3 = Vector3(15.0, 18.0, 22.0)

@export var contact_cooldown: float = 0.8
@export var jump_velocity: float = 11.0
@export var run_animation_speed_threshold: float = 6.0
## Minimum height difference above Diablo before he jumps
@export var jump_threshold: float = 1.8

## Distance at which magic freeze triggers
@export var freeze_range: float = 6.0
## How long the freeze lasts (Normal mode)
@export var freeze_duration_normal: float = 2.0
## How long the freeze lasts (Kojima mode)
@export var freeze_duration_kojima: float = 3.0
## Cooldown between freeze casts (Normal)
@export var freeze_cooldown_normal: float = 7.0
## Cooldown between freeze casts (Kojima)
@export var freeze_cooldown_kojima: float = 3.0

var chase_speed: float = 5.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var active: bool = false
var target_in_safe_zone: bool = false

var _cooldown_left: float = 0.0
var _freeze_cooldown_left: float = 0.0
var _daylight_hidden: bool = false
var _health: float = 100.0
var _animation_player: AnimationPlayer
var _current_animation: StringName = &""
var _action_locked: bool = false
var _dying: bool = false
var _reset_after_attack: bool = false

const DIABLO_MAX_HEALTH := 100.0
const LOOPING_ANIMATIONS: Array[StringName] = [&"Idle", &"Walk", &"Run"]
const ATTACK_ANIMATIONS: Array[StringName] = [&"Attack", &"Attack_2", &"Attack_3"]

@onready var _hit_box: Area3D = $HitBox


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("diablo")
	chase_speed = speed_normal.x
	_animation_player = _find_animation_player($Visual)
	_setup_animation_player()
	_hit_box.body_entered.connect(_on_hit_box_body_entered)
	deactivate()


func _physics_process(delta: float) -> void:
	if not active:
		return

	if _cooldown_left > 0.0:
		_cooldown_left -= delta
	if _freeze_cooldown_left > 0.0:
		_freeze_cooldown_left -= delta
	if _action_locked:
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		move_and_slide()
		return

	var manager := _get_game_manager()
	if manager != null and bool(manager.get("game_over")):
		velocity.x = 0.0
		velocity.z = 0.0
		_play_idle_animation()
		_apply_gravity(delta)
		move_and_slide()
		return

	if manager != null and _is_player_safe(manager):
		velocity.x = 0.0
		velocity.z = 0.0
		_play_idle_animation()
		_apply_gravity(delta)
		move_and_slide()
		return

	# Normal/fácil: hide during daytime; modo difícil: always visible
	if SaveManager.game_mode != SaveManager.MODE_HARD:
		var night := _is_night()
		if not night and not _daylight_hidden:
			_daylight_hidden = true
			hide()
		elif night and _daylight_hidden:
			_daylight_hidden = false
			show()
		if not night:
			velocity.x = 0.0
			velocity.z = 0.0
			_play_idle_animation()
			_apply_gravity(delta)
			move_and_slide()
			return
	elif _daylight_hidden:
		_daylight_hidden = false
		show()

	var player := _get_player()
	if player == null:
		_play_idle_animation()
		_apply_gravity(delta)
		move_and_slide()
		return

	# Magic freeze
	var dist := global_position.distance_to(player.global_position)
	if dist < freeze_range and _freeze_cooldown_left <= 0.0:
		var hard := SaveManager.game_mode == SaveManager.MODE_HARD
		var dur := freeze_duration_kojima if hard else freeze_duration_normal
		var cd := freeze_cooldown_kojima if hard else freeze_cooldown_normal
		if SaveManager.game_mode == SaveManager.MODE_EASY:
			dur *= 0.6
			cd *= 1.5
		if player.has_method("apply_freeze"):
			player.apply_freeze(dur)
			_freeze_cooldown_left = cd
			if manager != null and manager.has_method("show_message"):
				manager.show_message("El Diablo usó magia oscura. ¡Paralizado!", dur)

	var direction: Vector3 = player.global_position - global_position
	direction.y = 0.0

	if direction.length_squared() > 0.04:
		direction = direction.normalized()
		velocity.x = direction.x * chase_speed
		velocity.z = direction.z * chase_speed
		look_at(global_position + direction, Vector3.UP)
		_play_locomotion_animation()
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_play_idle_animation()

	# Jump to reach elevated player or climb terrain
	var height_diff := player.global_position.y - global_position.y
	if height_diff > jump_threshold and is_on_floor():
		velocity.y = jump_velocity

	_apply_gravity(delta)
	move_and_slide()


func set_progress(progress: int) -> void:
	var speeds := speed_normal
	if SaveManager.game_mode == SaveManager.MODE_HARD:
		speeds = speed_kojima
	elif SaveManager.game_mode == SaveManager.MODE_EASY:
		speeds = speed_normal * 0.7
	match progress:
		1:
			chase_speed = speeds.x
		2:
			chase_speed = speeds.y
		_:
			chase_speed = speeds.z


func set_target_safe_zone(value: bool) -> void:
	target_in_safe_zone = value
	if value:
		velocity.x = 0.0
		velocity.z = 0.0
		_play_idle_animation()


func reset_position() -> void:
	var spawn := _get_spawn()
	if spawn != null:
		global_position = spawn.global_position
	velocity = Vector3.ZERO


func reset_to_spawn() -> void:
	reset_position()


func activate() -> void:
	active = true
	_dying = false
	_action_locked = false
	_reset_after_attack = false
	reset_health()
	set_physics_process(true)
	if _hit_box != null:
		_hit_box.monitoring = true
		_hit_box.monitorable = true
	if SaveManager.game_mode != SaveManager.MODE_HARD and not _is_night():
		_daylight_hidden = true
		hide()
	else:
		_daylight_hidden = false
		show()
		_play_action_animation(&"Roaring")


func deactivate() -> void:
	active = false
	_dying = false
	_action_locked = false
	_reset_after_attack = false
	_daylight_hidden = false
	hide()
	velocity = Vector3.ZERO
	_stop_all_animation()
	set_physics_process(false)
	if _hit_box != null:
		_hit_box.monitoring = false
		_hit_box.monitorable = false


func receive_machete_strike(amount: float) -> bool:
	if not active:
		return false
	_health = maxf(0.0, _health - amount)
	var manager := _get_game_manager()
	if _health <= 0.0:
		_begin_dying()
		if manager != null and manager.has_method("show_message"):
			manager.show_message("El Diablo cayó derrotado por el machete.", 3.0)
		return true
	if manager != null and manager.has_method("show_message"):
		manager.show_message("El Diablo recibió daño. Vida restante: %.0f." % _health, 1.5)
	return true


func reset_health() -> void:
	_health = DIABLO_MAX_HEALTH


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

	# Modo difícil: drop carried animal on hit
	if SaveManager.game_mode == SaveManager.MODE_HARD and body.has_method("drop_animal"):
		body.drop_animal()

	var damaged: bool = body.receive_damage()
	if damaged:
		var cd := contact_cooldown
		if SaveManager.game_mode == SaveManager.MODE_HARD:
			cd = 0.4
		elif SaveManager.game_mode == SaveManager.MODE_EASY:
			cd = contact_cooldown * 2.0
		_cooldown_left = cd
		if manager != null and manager.has_method("show_message"):
			manager.show_message("El Diablo te alcanzó.", 1.7)
		_reset_after_attack = true
		var attack := ATTACK_ANIMATIONS[randi_range(0, ATTACK_ANIMATIONS.size() - 1)]
		if not _play_action_animation(attack):
			_reset_after_attack = false
			reset_position()


func _setup_animation_player() -> void:
	if _animation_player == null:
		return
	for animation_name_text in _animation_player.get_animation_list():
		var animation_name := StringName(animation_name_text)
		var animation := _animation_player.get_animation(animation_name)
		if animation == null:
			continue
		animation.loop_mode = (
			Animation.LOOP_LINEAR
			if LOOPING_ANIMATIONS.has(_animation_basename(animation_name))
			else Animation.LOOP_NONE
		)
	_animation_player.animation_finished.connect(_on_animation_finished)


func _play_locomotion_animation() -> void:
	var animation_name := &"Run" if chase_speed >= run_animation_speed_threshold else &"Walk"
	_play_animation(animation_name, false)


func _play_action_animation(animation_name: StringName) -> bool:
	return _play_animation(animation_name, true)


func _play_animation(animation_name: StringName, lock_action: bool) -> bool:
	if _animation_player == null:
		return false
	var resolved := _resolve_animation(animation_name)
	if resolved == &"":
		return false
	_action_locked = lock_action
	if resolved == _current_animation and _animation_player.is_playing():
		return true
	_current_animation = resolved
	_animation_player.play(resolved, 0.15)
	return true


func _play_idle_animation() -> void:
	if _action_locked or _dying:
		return
	_play_animation(&"Idle", false)


func _stop_all_animation() -> void:
	if _animation_player != null:
		_animation_player.stop()
	_current_animation = &""


func _begin_dying() -> void:
	active = false
	_dying = true
	_action_locked = true
	_reset_after_attack = false
	velocity = Vector3.ZERO
	set_physics_process(false)
	if _hit_box != null:
		_hit_box.monitoring = false
		_hit_box.monitorable = false
	if not _play_action_animation(&"Dying"):
		_dying = false
		hide()


func _on_animation_finished(animation_name: StringName) -> void:
	var basename := _animation_basename(animation_name)
	if basename == &"Dying" and _dying:
		_dying = false
		_action_locked = false
		_current_animation = &""
		hide()
		return
	if ATTACK_ANIMATIONS.has(basename) and _reset_after_attack:
		_reset_after_attack = false
		_action_locked = false
		_current_animation = &""
		reset_position()
		return
	if basename == &"Roaring":
		_action_locked = false
		_current_animation = &""


func _resolve_animation(wanted: StringName) -> StringName:
	if _animation_player == null:
		return &""
	for animation_name_text in _animation_player.get_animation_list():
		var animation_name := StringName(animation_name_text)
		if animation_name == wanted or _animation_basename(animation_name) == wanted:
			return animation_name
	return &""


func _animation_basename(animation_name: StringName) -> StringName:
	var text := String(animation_name)
	var separator := text.rfind("|")
	if separator >= 0:
		text = text.substr(separator + 1)
	return StringName(text)


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _is_night() -> bool:
	var dnc := get_tree().get_first_node_in_group("day_night_cycle")
	if dnc == null:
		return true
	return sin(float(dnc.get("time_of_day")) * TAU) < 0.0


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
