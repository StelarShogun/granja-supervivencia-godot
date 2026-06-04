extends CharacterBody3D

@export var walk_speed: float = 10.0
@export var run_speed: float = 18.0
@export var acceleration: float = 18.0
@export var deceleration: float = 22.0
@export var rotation_speed: float = 10.0
@export var mouse_sensitivity: float = 0.003
@export var camera_min_pitch: float = -55.0
@export var camera_max_pitch: float = 35.0
@export var invulnerability_time: float = 2.0
@export var game_manager_path: NodePath = NodePath("../GameManager")
@export var max_oxygen: float = 100.0
@export var oxygen_drain_rate: float = 12.0
@export var oxygen_recover_rate: float = 25.0
@export var drowning_damage_interval: float = 1.0
@export var water_move_speed_multiplier: float = 0.45
@export var water_gravity: float = 4.0
@export var water_sink_speed: float = 1.2
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
var oxygen: float = 100.0

var _invulnerability_left: float = 0.0
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
		_apply_gravity(delta)
		move_and_slide()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	var forward := -_camera_pivot.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := _camera_pivot.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var direction := right * input_dir.x + forward * -input_dir.y
	if direction.length_squared() > 1.0:
		direction = direction.normalized()

	var target_speed := walk_speed
	if Input.is_action_pressed("run") and not is_crouching and not is_in_water:
		target_speed = run_speed
	target_speed *= speed_multiplier
	if is_crouching:
		target_speed *= crouch_speed_multiplier
	if is_in_water:
		target_speed *= water_move_speed_multiplier

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if direction.length_squared() > 0.001:
		horizontal_velocity = horizontal_velocity.move_toward(direction * target_speed, acceleration * delta)
		var target_yaw := atan2(direction.x, direction.z)
		_visual_mesh.rotation.y = lerp_angle(_visual_mesh.rotation.y, target_yaw, rotation_speed * delta)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, deceleration * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	_apply_gravity(delta)
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_in_water and not is_crouching:
		velocity.y = jump_velocity
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


func receive_damage() -> bool:
	if invulnerable:
		return false

	invulnerable = true
	_invulnerability_left = invulnerability_time

	var manager := _get_game_manager()
	if manager != null and manager.has_method("player_hit"):
		manager.player_hit()

	return true


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
	var manager := _get_game_manager()
	if manager != null and manager.has_method("player_hit"):
		manager.player_hit()
	if manager != null and manager.has_method("show_message"):
		manager.show_message("Te estas ahogando. Sal del agua.", 1.4)


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


func _apply_gravity(delta: float) -> void:
	if is_in_water:
		var target_y := -water_sink_speed if _water_is_deep else -0.15
		if global_position.y > _water_surface_y + 0.2:
			target_y = minf(target_y, -0.4)
		velocity.y = move_toward(velocity.y, target_y, water_gravity * delta)
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = maxf(velocity.y, -0.2)


func _update_timers(delta: float) -> void:
	if _invulnerability_left > 0.0:
		_invulnerability_left -= delta
		if _invulnerability_left <= 0.0:
			invulnerable = false

	if _mud_slow_left > 0.0:
		_mud_slow_left -= delta
		if _mud_slow_left <= 0.0:
			speed_multiplier = 1.0


func _update_water_state(delta: float) -> void:
	if is_in_water and _water_is_deep:
		oxygen = maxf(0.0, oxygen - oxygen_drain_rate * delta)
		if oxygen <= 0.0:
			_drowning_damage_left -= delta
			if _drowning_damage_left <= 0.0:
				_drowning_damage_left = drowning_damage_interval
				receive_drowning_damage()
	else:
		oxygen = minf(max_oxygen, oxygen + oxygen_recover_rate * delta)
		_drowning_damage_left = 0.0

	_publish_oxygen_ui()


func _refresh_water_flags() -> void:
	is_in_water = not _water_sources.is_empty()
	_water_is_deep = false
	_water_surface_y = global_position.y

	for source_id in _water_sources:
		var data: Dictionary = _water_sources[source_id]
		_water_is_deep = _water_is_deep or bool(data.get("deep", false))
		_water_surface_y = maxf(_water_surface_y, float(data.get("surface_y", _water_surface_y)))


func _publish_oxygen_ui() -> void:
	var manager := _get_game_manager()
	if manager != null and manager.has_method("update_player_oxygen"):
		manager.update_player_oxygen(oxygen, max_oxygen, _water_is_deep or oxygen < max_oxygen)


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
