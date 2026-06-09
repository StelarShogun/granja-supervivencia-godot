extends CharacterBody3D

const MAX_HEALTH := 100.0

@export var walk_speed: float = 10.0
@export var run_speed: float = 18.0
@export var acceleration: float = 18.0
@export var deceleration: float = 22.0
@export var rotation_speed: float = 10.0
@export var mouse_sensitivity: float = 0.003
@export var camera_min_pitch: float = -55.0
@export var camera_max_pitch: float = 35.0
@export var invulnerability_time: float = 2.0
@export var diablo_damage: float = 34.0
@export var game_manager_path: NodePath = NodePath("../GameManager")
@export var jump_velocity: float = 8.0
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.0
@export var crouch_speed_multiplier: float = 0.5
@export var crouch_lerp_speed: float = 8.0
@export var stand_camera_y: float = 1.45
@export var crouch_camera_y: float = 0.85

var gravity: float = 25.0
var is_crouching: bool = false
var invulnerable: bool = false
var speed_multiplier: float = 1.0
var camera_enabled: bool = true
var health: float = MAX_HEALTH

var carried_animal: Node = null
var has_machete: bool = false

const MACHETE_RANGE := 3.5
const MACHETE_DAMAGE := 34.0

var _invulnerability_left: float = 0.0
var _frozen_left: float = 0.0
var _mud_slow_left: float = 0.0
var _interaction_targets: Array[Node] = []
var _camera_pitch: float = -15.0
var _footstep_timer: float = 0.0
var _run_wind_intensity: float = 0.0
var _was_moving: bool = false

@onready var _interaction_area: Area3D = $InteractionArea
@onready var _visual_mesh: Node3D = $Visual
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D

var _capsule_shape: CapsuleShape3D


func _ready() -> void:
	add_to_group("player")
	_capsule_shape = _collision_shape.shape as CapsuleShape3D
	_setup_camera_collision()
	_interaction_area.area_entered.connect(_on_interaction_area_entered)
	_interaction_area.area_exited.connect(_on_interaction_area_exited)
	_interaction_area.body_entered.connect(_on_interaction_body_entered)
	_interaction_area.body_exited.connect(_on_interaction_body_exited)
	reset_health()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var manager := _get_game_manager()
		if manager != null and manager.has_method("toggle_pause"):
			manager.toggle_pause()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and camera_enabled:
		_rotate_camera(event.relative)
		return

	if event.is_action_pressed("interact"):
		_try_interact()
		return

	if event.is_action_pressed("attack"):
		_try_machete_attack()


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_crouch(delta)

	var manager := _get_game_manager()
	if manager != null and bool(manager.get("game_over")):
		_run_wind_intensity = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_land_gravity(delta)
		move_and_slide()
		return

	if _frozen_left > 0.0:
		_run_wind_intensity = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_land_gravity(delta)
		move_and_slide()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := _get_move_direction()
	_apply_land_movement(delta, direction)
	move_and_slide()
	_update_footsteps(delta, input_dir)
	_update_run_wind(input_dir)


func _update_crouch(delta: float) -> void:
	if _capsule_shape == null:
		return

	var want_crouch := Input.is_action_pressed("crouch")
	if want_crouch:
		is_crouching = true
	elif is_crouching and _can_stand():
		is_crouching = false

	var target_height := crouch_height if is_crouching else stand_height
	var height := move_toward(_capsule_shape.height, target_height, crouch_lerp_speed * delta)
	_capsule_shape.height = height
	_collision_shape.position.y = height * 0.5
	# squash the whole character visual when crouching (base stays on ground)
	_visual_mesh.scale.y = height / maxf(stand_height, 0.001)

	var ratio := clampf((height - crouch_height) / maxf(stand_height - crouch_height, 0.001), 0.0, 1.0)
	_camera_pivot.position.y = lerpf(crouch_camera_y, stand_camera_y, ratio)


func _can_stand() -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return true
	var from := global_position + Vector3.UP * crouch_height
	var to := global_position + Vector3.UP * (stand_height + 0.1)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	query.exclude = [get_rid()]
	return space.intersect_ray(query).is_empty()


func receive_damage(amount: float = -1.0) -> bool:
	if invulnerable or health <= 0.0:
		return false

	if amount < 0.0:
		amount = diablo_damage

	health = maxf(0.0, health - amount)
	invulnerable = true
	_invulnerability_left = invulnerability_time

	var manager := _get_game_manager()
	if manager != null:
		if manager.has_method("on_player_health_changed"):
			manager.on_player_health_changed(health, MAX_HEALTH)
		if health <= 0.0 and manager.has_method("lose_game"):
			manager.lose_game()
		elif manager.has_method("show_message"):
			manager.show_message("Recibiste daño. Busca un Cacique si necesitas curarte.", 1.8)

	_publish_health_ui()
	return true


func heal(amount: float) -> void:
	if health <= 0.0:
		return
	health = minf(MAX_HEALTH, health + amount)
	_publish_health_ui()
	var manager := _get_game_manager()
	if manager != null and manager.has_method("on_player_health_changed"):
		manager.on_player_health_changed(health, MAX_HEALTH)


func reset_health() -> void:
	health = MAX_HEALTH
	invulnerable = false
	_invulnerability_left = 0.0
	_publish_health_ui()


func get_health_ratio() -> float:
	return health / MAX_HEALTH


func apply_freeze(duration: float) -> void:
	_frozen_left = maxf(_frozen_left, duration)


func pickup_animal(animal: Node) -> bool:
	if carried_animal != null:
		var manager := _get_game_manager()
		if manager != null and manager.has_method("show_message"):
			manager.show_message("Ya llevas un animal. Llévalo al corral primero.", 2.0)
		return false
	carried_animal = animal
	var manager2 := _get_game_manager()
	if manager2 != null and manager2.has_method("show_message"):
		manager2.show_message("Llevando 1 animal. Ve al corral.", 2.0)
	return true


func drop_animal() -> void:
	if carried_animal == null:
		return
	if carried_animal.has_method("drop"):
		carried_animal.drop(global_position + Vector3(1.5, 0.0, 0.0))
	carried_animal = null


func deliver_animal() -> Node:
	var a := carried_animal
	carried_animal = null
	return a


func equip_machete() -> void:
	has_machete = true


func _try_machete_attack() -> void:
	if not has_machete:
		var manager := _get_game_manager()
		if manager != null and manager.has_method("show_message"):
			manager.show_message("Necesitas el machete del fondo del lago.", 1.8)
		return

	var diablo := _get_nearest_diablo()
	if diablo == null or not diablo.has_method("receive_machete_strike"):
		return
	if global_position.distance_to(diablo.global_position) > MACHETE_RANGE:
		var manager2 := _get_game_manager()
		if manager2 != null and manager2.has_method("show_message"):
			manager2.show_message("Demasiado lejos del Diablo.", 1.2)
		return

	if diablo.receive_machete_strike(MACHETE_DAMAGE):
		var manager3 := _get_game_manager()
		if manager3 != null and manager3.has_method("show_message"):
			manager3.show_message("Golpeaste al Diablo con el machete.", 1.5)


func _get_nearest_diablo() -> Node3D:
	var best: Node3D = null
	var best_dist := MACHETE_RANGE
	for node in get_tree().get_nodes_in_group("diablo"):
		if not node is Node3D or not node.visible:
			continue
		var dist := global_position.distance_to(node.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = node
	return best


func slow_down(seconds: float) -> void:
	apply_mud_slow(0.45, seconds)


func apply_mud_slow(multiplier: float = 0.45, duration: float = 2.0) -> void:
	speed_multiplier = clampf(multiplier, 0.1, 1.0)
	_mud_slow_left = maxf(_mud_slow_left, duration)


func _publish_health_ui() -> void:
	var manager := _get_game_manager()
	if manager != null and manager.has_method("update_player_health"):
		manager.update_player_health(health, MAX_HEALTH)


func capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_enabled = true


func release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	camera_enabled = false


func _setup_camera_collision() -> void:
	if _spring_arm == null:
		return
	_spring_arm.collision_mask = 2
	_spring_arm.margin = maxf(_spring_arm.margin, 0.3)
	_spring_arm.add_excluded_object(get_rid())
	_spring_arm.rotation_degrees.x = _camera_pitch


func _rotate_camera(relative_motion: Vector2) -> void:
	_camera_pivot.rotate_y(-relative_motion.x * mouse_sensitivity)
	_camera_pitch = clampf(
		_camera_pitch - relative_motion.y * mouse_sensitivity * 180.0 / PI,
		camera_min_pitch,
		camera_max_pitch
	)
	_spring_arm.rotation_degrees.x = _camera_pitch


func _get_move_direction() -> Vector3:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var basis := _camera_pivot.global_transform.basis
	var forward_flat := -basis.z
	forward_flat.y = 0.0
	forward_flat = forward_flat.normalized()
	var right_flat := basis.x
	right_flat.y = 0.0
	right_flat = right_flat.normalized()
	var direction_flat := right_flat * input_dir.x + forward_flat * -input_dir.y
	if direction_flat.length_squared() > 1.0:
		direction_flat = direction_flat.normalized()
	return direction_flat


func _apply_land_movement(delta: float, direction: Vector3) -> void:
	var target_speed := walk_speed
	if Input.is_action_pressed("run") and not is_crouching:
		target_speed = run_speed
	target_speed *= speed_multiplier
	if is_crouching:
		target_speed *= crouch_speed_multiplier

	_apply_horizontal_movement(delta, direction, target_speed)
	_apply_land_gravity(delta)
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = jump_velocity
		AudioManager.play_jump()


func _apply_horizontal_movement(delta: float, direction: Vector3, target_speed: float) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if direction.length_squared() > 0.001:
		horizontal_velocity = horizontal_velocity.move_toward(direction * target_speed, acceleration * delta)
		var target_yaw := atan2(direction.x, direction.z)
		_visual_mesh.rotation.y = lerp_angle(_visual_mesh.rotation.y, target_yaw, rotation_speed * delta)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, deceleration * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _apply_land_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = maxf(velocity.y, -0.2)


func _update_timers(delta: float) -> void:
	if _invulnerability_left > 0.0:
		_invulnerability_left -= delta
		if _invulnerability_left <= 0.0:
			invulnerable = false

	if _frozen_left > 0.0:
		_frozen_left -= delta

	if _mud_slow_left > 0.0:
		_mud_slow_left -= delta
		if _mud_slow_left <= 0.0:
			speed_multiplier = 1.0


func _try_interact() -> void:
	_prune_interaction_targets()
	for target in _interaction_targets:
		if target != null and target.has_method("interact"):
			target.interact(self)
			return

	var manager := _get_game_manager()
	if manager != null and manager.has_method("show_message"):
		manager.show_message("No hay nada para interactuar aqui.", 1.5)


func _on_interaction_area_entered(area: Area3D) -> void:
	_add_interaction_target(area)


func _on_interaction_area_exited(area: Area3D) -> void:
	_interaction_targets.erase(area)


func _on_interaction_body_entered(body: Node3D) -> void:
	_add_interaction_target(body)


func _on_interaction_body_exited(body: Node3D) -> void:
	_interaction_targets.erase(body)


func _add_interaction_target(target: Node) -> void:
	if target != null and target.has_method("interact") and not _interaction_targets.has(target):
		_interaction_targets.append(target)


func _prune_interaction_targets() -> void:
	for i in range(_interaction_targets.size() - 1, -1, -1):
		if not is_instance_valid(_interaction_targets[i]):
			_interaction_targets.remove_at(i)


func get_run_wind_intensity() -> float:
	return _run_wind_intensity


func _update_run_wind(input_dir: Vector2) -> void:
	var running := (
		Input.is_action_pressed("run")
		and not is_crouching
		and input_dir.length_squared() > 0.001
		and Vector2(velocity.x, velocity.z).length() > walk_speed * 0.55
	)
	var target := 0.0
	if running:
		var speed_ratio := clampf(Vector2(velocity.x, velocity.z).length() / run_speed, 0.0, 1.0)
		target = lerpf(0.35, 1.0, speed_ratio)
	_run_wind_intensity = move_toward(_run_wind_intensity, target, get_physics_process_delta_time() * 3.0)


func _update_footsteps(delta: float, input_dir: Vector2) -> void:
	if _frozen_left > 0.0:
		_footstep_timer = 0.0
		_was_moving = false
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var wants_move := input_dir.length_squared() > 0.001
	var is_moving := wants_move and is_on_floor() and horizontal_speed >= 1.2

	if not is_moving:
		_footstep_timer = 0.0
		_was_moving = false
		return

	if not _was_moving:
		var interval := 0.38 if (Input.is_action_pressed("run") and not is_crouching) else 0.52
		_footstep_timer = interval * 0.55
		_was_moving = true
		return

	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		AudioManager.play_footstep()
		var interval := 0.38 if (Input.is_action_pressed("run") and not is_crouching) else 0.52
		_footstep_timer = interval


func _get_game_manager() -> Node:
	if game_manager_path != NodePath("") and has_node(game_manager_path):
		return get_node(game_manager_path)

	var managers := get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		return managers[0]
	return null
