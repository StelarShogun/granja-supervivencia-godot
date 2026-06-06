extends CharacterBody3D

const MAX_HEALTH := 100.0

enum SwimState { NONE, SURFACE, UNDERWATER }

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
@export var drowning_damage: float = 15.0
@export var game_manager_path: NodePath = NodePath("../GameManager")
@export var max_oxygen: float = 100.0
@export var oxygen_drain_rate: float = 12.0
@export var oxygen_recover_rate: float = 25.0
@export var oxygen_surface_recover_rate: float = 35.0
@export var drowning_damage_interval: float = 1.0
@export var swim_speed: float = 7.0
@export var swim_sprint_speed: float = 10.0
@export var dive_swim_speed: float = 5.0
@export var swim_vertical_speed: float = 6.0
@export var swim_surface_body_offset: float = 1.05
@export var submerged_depth: float = 0.4
@export var water_gravity: float = 4.0
@export var water_sink_speed: float = 1.2
@export var shallow_wade_depth: float = 0.55
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
var is_in_water: bool = false
var swim_state: SwimState = SwimState.NONE
var oxygen: float = 100.0
var health: float = MAX_HEALTH

## Animal being carried (null = not carrying); modo difícil: 1 a la vez
var carried_animal: Node = null

var _invulnerability_left: float = 0.0
var _frozen_left: float = 0.0
var _mud_slow_left: float = 0.0
var _drowning_damage_left: float = 0.0
var _water_surface_y: float = 0.0
var _water_is_deep: bool = false
var _water_sources: Dictionary = {}
var _interaction_targets: Array[Node] = []
var _camera_pitch: float = -15.0

@onready var _interaction_area: Area3D = $InteractionArea
@onready var _visual_mesh: MeshInstance3D = $MeshInstance3D
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D

var _capsule_shape: CapsuleShape3D
var _capsule_mesh: CapsuleMesh


func _ready() -> void:
	add_to_group("player")
	oxygen = max_oxygen
	_capsule_shape = _collision_shape.shape as CapsuleShape3D
	_capsule_mesh = _visual_mesh.mesh as CapsuleMesh
	_setup_camera_collision()
	_interaction_area.area_entered.connect(_on_interaction_area_entered)
	_interaction_area.area_exited.connect(_on_interaction_area_exited)
	_interaction_area.body_entered.connect(_on_interaction_body_entered)
	_interaction_area.body_exited.connect(_on_interaction_body_exited)
	reset_health()
	_publish_oxygen_ui()


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


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_water_state(delta)
	_update_crouch(delta)

	var manager := _get_game_manager()
	if manager != null and bool(manager.get("game_over")):
		velocity.x = 0.0
		velocity.z = 0.0
		if is_in_water:
			_apply_swim_vertical(delta)
		else:
			_apply_land_gravity(delta)
		move_and_slide()
		return

	# Magic freeze: player cannot move but gravity still applies
	if _frozen_left > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		if is_in_water:
			_apply_swim_vertical(delta)
		else:
			_apply_land_gravity(delta)
		move_and_slide()
		return

	var swim_direction := _get_move_direction()
	if is_in_water:
		_apply_swim_movement(delta, swim_direction)
	else:
		_apply_land_movement(delta, swim_direction)
	move_and_slide()


func _update_crouch(delta: float) -> void:
	if _capsule_shape == null:
		return

	var want_crouch := Input.is_action_pressed("crouch") and not is_in_water
	if want_crouch:
		is_crouching = true
	elif is_crouching and _can_stand():
		is_crouching = false

	var target_height := crouch_height if is_crouching else stand_height
	var height := move_toward(_capsule_shape.height, target_height, crouch_lerp_speed * delta)
	_capsule_shape.height = height
	_collision_shape.position.y = height * 0.5
	if _capsule_mesh != null:
		_capsule_mesh.height = height
	_visual_mesh.position.y = height * 0.5

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


func is_swimming() -> bool:
	return is_in_water


func is_diving() -> bool:
	return swim_state == SwimState.UNDERWATER


func is_submerged() -> bool:
	if not is_in_water or not _water_is_deep:
		return false
	if swim_state == SwimState.UNDERWATER:
		return true
	return global_position.y < _water_surface_y - submerged_depth


func get_water_surface_y() -> float:
	return _water_surface_y


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


func slow_down(seconds: float) -> void:
	apply_mud_slow(0.45, seconds)


func apply_mud_slow(multiplier: float = 0.45, duration: float = 2.0) -> void:
	speed_multiplier = clampf(multiplier, 0.1, 1.0)
	_mud_slow_left = maxf(_mud_slow_left, duration)


func enter_water(source: Node = null, deep_water: bool = false, water_surface_y: float = 0.0) -> void:
	var source_id := source.get_instance_id() if source != null else get_instance_id()
	_water_sources[source_id] = {
		"deep": deep_water,
		"surface_y": water_surface_y,
	}
	_refresh_water_flags()
	_publish_oxygen_ui()


func exit_water(source: Node = null) -> void:
	var source_id := source.get_instance_id() if source != null else get_instance_id()
	_water_sources.erase(source_id)
	_refresh_water_flags()
	_publish_oxygen_ui()


func receive_drowning_damage() -> void:
	receive_damage(drowning_damage)
	var manager := _get_game_manager()
	if manager != null and manager.has_method("show_message"):
		manager.show_message("Te estas ahogando. Sal del agua.", 1.4)


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
	# Camera must collide only with the World layer (terrain, mountain, rocks,
	# fences, structures) and must never snap onto the player's own body.
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
	if is_diving():
		var forward := -basis.z
		var right := basis.x
		var direction := right * input_dir.x + forward * -input_dir.y
		if direction.length_squared() > 1.0:
			direction = direction.normalized()
		return direction

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


func _apply_swim_movement(delta: float, direction: Vector3) -> void:
	_update_swim_state()

	var target_speed := swim_speed
	if swim_state == SwimState.UNDERWATER:
		target_speed = dive_swim_speed
	elif Input.is_action_pressed("run"):
		target_speed = swim_sprint_speed
	target_speed *= speed_multiplier

	_apply_horizontal_movement(delta, direction, target_speed, true)
	_apply_swim_vertical(delta)


func _apply_horizontal_movement(
	delta: float,
	direction: Vector3,
	target_speed: float,
	use_full_3d: bool = false
) -> void:
	if use_full_3d and is_diving():
		if direction.length_squared() > 0.001:
			velocity = velocity.move_toward(direction * target_speed, acceleration * delta * 0.75)
			var flat := Vector3(direction.x, 0.0, direction.z)
			if flat.length_squared() > 0.001:
				var target_yaw := atan2(flat.x, flat.z)
				_visual_mesh.rotation.y = lerp_angle(_visual_mesh.rotation.y, target_yaw, rotation_speed * delta)
		else:
			velocity = velocity.move_toward(Vector3.ZERO, deceleration * delta)
		return

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


func _update_swim_state() -> void:
	if not is_in_water:
		swim_state = SwimState.NONE
		return

	if not _water_is_deep:
		swim_state = SwimState.SURFACE
		return

	var depth_below_surface := _water_surface_y - global_position.y
	var want_dive := Input.is_action_pressed("crouch")
	var want_rise := Input.is_action_pressed("jump")

	match swim_state:
		SwimState.NONE, SwimState.SURFACE:
			if want_dive:
				swim_state = SwimState.UNDERWATER
			else:
				swim_state = SwimState.SURFACE
		SwimState.UNDERWATER:
			if want_rise and not want_dive:
				swim_state = SwimState.SURFACE
			elif depth_below_surface < submerged_depth * 0.35 and not want_dive:
				swim_state = SwimState.SURFACE


func _apply_swim_vertical(delta: float) -> void:
	if not _water_is_deep:
		var wade_y := _water_surface_y - shallow_wade_depth
		velocity.y = move_toward(
			velocity.y,
			(wade_y - global_position.y) * 4.0,
			water_gravity * delta
		)
		return

	if swim_state == SwimState.UNDERWATER:
		var target_vy := -water_sink_speed * 0.25
		if Input.is_action_pressed("jump"):
			target_vy = swim_vertical_speed
		elif Input.is_action_pressed("crouch"):
			target_vy = -swim_vertical_speed
		velocity.y = move_toward(velocity.y, target_vy, water_gravity * delta)
		return

	var float_y := _water_surface_y - swim_surface_body_offset
	if Input.is_action_pressed("jump"):
		velocity.y = move_toward(velocity.y, swim_vertical_speed * 0.35, water_gravity * delta)
	else:
		velocity.y = move_toward(
			velocity.y,
			(float_y - global_position.y) * 5.0,
			water_gravity * delta
		)


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


func _update_water_state(delta: float) -> void:
	if is_submerged():
		oxygen = maxf(0.0, oxygen - oxygen_drain_rate * delta)
		if oxygen <= 0.0:
			_drowning_damage_left -= delta
			if _drowning_damage_left <= 0.0:
				_drowning_damage_left = drowning_damage_interval
				receive_drowning_damage()
	elif is_in_water:
		var recover_rate := oxygen_surface_recover_rate if _water_is_deep else oxygen_recover_rate
		oxygen = minf(max_oxygen, oxygen + recover_rate * delta)
		_drowning_damage_left = 0.0
	else:
		oxygen = minf(max_oxygen, oxygen + oxygen_recover_rate * delta)
		_drowning_damage_left = 0.0

	_publish_oxygen_ui()


func _refresh_water_flags() -> void:
	var was_in_water := is_in_water
	is_in_water = not _water_sources.is_empty()
	_water_is_deep = false
	_water_surface_y = global_position.y

	for source_id in _water_sources:
		var data: Dictionary = _water_sources[source_id]
		_water_is_deep = _water_is_deep or bool(data.get("deep", false))
		_water_surface_y = maxf(_water_surface_y, float(data.get("surface_y", _water_surface_y)))

	if is_in_water and not was_in_water:
		swim_state = SwimState.SURFACE if _water_is_deep else SwimState.SURFACE
	elif not is_in_water:
		swim_state = SwimState.NONE


func _publish_oxygen_ui() -> void:
	var manager := _get_game_manager()
	if manager != null and manager.has_method("update_player_oxygen"):
		var show_oxygen := _water_is_deep and is_in_water
		manager.update_player_oxygen(oxygen, max_oxygen, show_oxygen or oxygen < max_oxygen)


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


func _get_game_manager() -> Node:
	if game_manager_path != NodePath("") and has_node(game_manager_path):
		return get_node(game_manager_path)

	var managers := get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		return managers[0]
	return null
