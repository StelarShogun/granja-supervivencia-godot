extends Area3D

## Per-species rest offsets above the ground hit point (node origin must be at
## the model's base). The placeholder sphere has its base at y=0 -> offset 0.
## When real GLB models land in assets/models/animals/, measure each pivot and
## fill in its entry; species is matched against the node name (lowercase).
const GROUND_OFFSETS := {
	"cow": 0.0,
	"chicken": 0.0,
	"sheep": 0.0,
	"pig": 0.0,
	"goat": 0.0,
}
const GROUND_MASK := 2          ## terrain + structures collision layer
const SNAP_LERP_SPEED := 8.0    ## smooth ground-follow while wandering
const LOOPING_ANIMATION_BASENAMES: Array[StringName] = [
	&"Idle",
	&"Idle_2",
	&"Idle_Headlow",
	&"Eating",
	&"Walk",
	&"WalkSlow",
	&"Run",
	&"Gallop",
]
const ANIMATION_BY_MODEL := {
	"pig": {
		"idle": [&"Idle"],
		"walk": [&"WalkSlow", &"Walk"],
		"fast": [&"Run", &"Walk"],
	},
	"sheep": {
		"idle": [&"Idle"],
		"walk": [&"WalkSlow", &"Walk"],
		"fast": [&"Run", &"Walk"],
	},
	"horse": {
		"idle": [&"Idle"],
		"walk": [&"WalkSlow", &"Walk"],
		"fast": [&"Run", &"Walk"],
	},
	"bull": {
		"idle": [&"Idle", &"Idle_2", &"Idle_Headlow"],
		"walk": [&"Walk"],
		"fast": [&"Gallop", &"Walk"],
	},
	"cow": {
		"idle": [&"Idle", &"Idle_2", &"Idle_Headlow"],
		"walk": [&"Walk"],
		"fast": [&"Gallop", &"Walk"],
	},
	"chicken": {
		"idle": [&"Idle"],
		"walk": [&"Walk"],
		"fast": [&"Walk"],
	},
	"goat": {
		"idle": [&"Idle"],
		"walk": [&"Walk"],
		"fast": [&"Run", &"Walk"],
	},
	"generic": {
		"idle": [&"Idle", &"Idle_2", &"Idle_Headlow"],
		"walk": [&"WalkSlow", &"Walk"],
		"fast": [&"Gallop", &"Run", &"Walk"],
	},
}

@export var game_manager_path: NodePath = NodePath("../../GameManager")
@export var animal_kind: String = "vaca"
@export var proximity_radius: float = 18.0
@export var proximity_bleat_min: float = 6.0
@export var proximity_bleat_max: float = 14.0
@export var wander_speed: float = 1.8
@export var wander_radius: float = 120.0
@export var wander_interval_min: float = 3.0
@export var wander_interval_max: float = 7.0
@export var turn_speed: float = 6.0
@export var front_yaw_offset_degrees: float = 0.0
@export var follow_stop_distance: float = 0.35
## Extra height above the ground hit point; overridden by GROUND_OFFSETS
## when the node name contains a known species.
@export var ground_offset: float = 0.0

var collected: bool = false

var _wander_target: Vector3
var _wander_timer: float = 0.0
var _bleat_timer: float = 0.0
var _has_start: bool = false
var _following: bool = false
var _follow_target: Node3D = null
var _voice: AudioStreamPlayer3D
var _cached_player: Node3D = null
var _animation_player: AnimationPlayer
var _current_animation: StringName = &""
var _model_key: StringName = &"generic"


func _ready() -> void:
	add_to_group("animals")
	body_entered.connect(_on_body_entered)
	_wander_target = global_position
	_wander_timer = randf_range(wander_interval_min, wander_interval_max)
	_bleat_timer = randf_range(5.0, 8.0)
	_resolve_animal_kind()
	_model_key = _resolve_model_key()
	_setup_voice()
	_animation_player = _find_animation_player(self)
	_setup_animation_loops()
	_update_animation(&"idle")
	_cached_player = get_tree().get_first_node_in_group("player") as Node3D
	var lower := name.to_lower()
	for species in GROUND_OFFSETS:
		if lower.contains(species):
			ground_offset = GROUND_OFFSETS[species]
			break
	# snap after the physics space is ready (covers initial spawn, progression
	# spawns and save-game loads -- all paths instantiate this scene)
	_snap_when_ready.call_deferred()


func _snap_when_ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	snap_to_ground()


## Raycast straight down onto layer 2 and rest the base on the hit point.
## Safe fallback: keeps the current height when nothing is hit.
func snap_to_ground() -> void:
	var hit := _ground_hit(global_position)
	if hit.is_empty():
		push_warning("Animal %s: no ground under %s, keeping height" % [name, global_position])
		return
	global_position.y = hit.position.y + ground_offset


func _ground_hit(at: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * 60.0, at + Vector3.DOWN * 200.0, GROUND_MASK)
	return space.intersect_ray(q)


func _process(delta: float) -> void:
	if collected:
		return

	if _following and _follow_target != null:
		var target_pos := _follow_target.global_position + Vector3(1.2, 0.0, 0.0)
		var follow_diff := target_pos - global_position
		follow_diff.y = 0.0
		if follow_diff.length() > follow_stop_distance:
			_face_direction(follow_diff, delta)
			var previous_position := global_position
			global_position = global_position.lerp(target_pos, 12.0 * delta)
			var moved_distance := Vector2(
				global_position.x - previous_position.x,
				global_position.z - previous_position.z
			).length()
			_update_animation(&"fast" if moved_distance > 0.01 else &"idle")
		else:
			_update_animation(&"idle")
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
		_face_direction(diff, delta)
		var step := diff.normalized() * wander_speed * delta
		global_position += Vector3(step.x, 0.0, step.z)
		_update_animation(&"walk")
	else:
		_update_animation(&"idle")

	# follow the terrain while wandering (the old code kept Y frozen, which
	# left animals hovering or buried after walking across slopes)
	var hit := _ground_hit(global_position)
	if not hit.is_empty():
		var target_y: float = hit.position.y + ground_offset
		global_position.y = lerpf(
			global_position.y, target_y, minf(1.0, SNAP_LERP_SPEED * delta))

	_update_proximity_voice(delta)


func _resolve_animal_kind() -> void:
	if animal_kind != "vaca":
		return
	var lower := name.to_lower()
	if lower.contains("chicken") or lower.contains("gallina"):
		animal_kind = "gallina"
	elif lower.contains("sheep") or lower.contains("oveja"):
		animal_kind = "oveja"
	elif lower.contains("goat") or lower.contains("cabra"):
		animal_kind = "cabra"
	elif lower.contains("bull") or lower.contains("toro"):
		animal_kind = "toro"
	elif lower.contains("pig") or lower.contains("cerdo"):
		animal_kind = "cerdo"
	elif lower.contains("horse") or lower.contains("caballo"):
		animal_kind = "caballo"
	elif lower.contains("cow") or lower.contains("vaca"):
		animal_kind = "vaca"


func _setup_voice() -> void:
	_voice = AudioStreamPlayer3D.new()
	_voice.name = "AnimalVoice"
	_voice.max_distance = proximity_radius
	_voice.unit_size = 5.0
	_voice.bus = &"Master"
	var stream := AudioManager.get_animal_stream(animal_kind)
	if stream != null:
		_voice.stream = stream
	add_child(_voice)


func _update_proximity_voice(delta: float) -> void:
	_ensure_player()
	if _cached_player == null:
		return
	var distance := global_position.distance_to(_cached_player.global_position)
	if distance > proximity_radius:
		_bleat_timer = minf(_bleat_timer, randf_range(2.0, 4.0))
		return
	_bleat_timer -= delta
	if _bleat_timer <= 0.0:
		_bleat_spatial(distance)
		_bleat_timer = randf_range(proximity_bleat_min, proximity_bleat_max)


func _bleat_spatial(distance: float) -> void:
	if _voice == null or _voice.stream == null or _voice.playing:
		return
	var closeness := 1.0 - clampf(distance / proximity_radius, 0.0, 1.0)
	_voice.volume_db = lerpf(-24.0, -3.0, closeness)
	_voice.pitch_scale = randf_range(0.94, 1.06)
	_voice.play()


func _ensure_player() -> void:
	if _cached_player == null or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player") as Node3D


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
		_try_pickup(player)


func pickup(player: Node) -> void:
	_try_pickup(player)


func drop(drop_position: Vector3) -> void:
	_following = false
	_follow_target = null
	global_position = drop_position
	_wander_target = drop_position
	snap_to_ground()


func register_in_corral() -> void:
	if collected:
		return
	collected = true
	_following = false
	_follow_target = null
	monitoring = false
	monitorable = false
	AudioManager.play_animal_sfx(animal_kind, -3.0)
	hide()
	call_deferred("queue_free")


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_try_pickup(body)


func _try_pickup(player: Node) -> void:
	if collected or _following:
		return
	if player.has_method("pickup_animal"):
		var ok: bool = player.pickup_animal(self)
		if ok:
			_following = true
			_follow_target = player as Node3D
			set_deferred("monitoring", false)
			_bleat_spatial(0.5)


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root == null:
		return null
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _setup_animation_loops() -> void:
	if _animation_player == null:
		return

	for animation_name_text in _animation_player.get_animation_list():
		var animation_name := StringName(animation_name_text)
		var animation := _animation_player.get_animation(animation_name)
		if animation != null:
			var basename := _animation_basename(animation_name)
			animation.loop_mode = (
				Animation.LOOP_LINEAR
				if LOOPING_ANIMATION_BASENAMES.has(basename)
				else Animation.LOOP_NONE
			)


func _update_animation(state: StringName) -> void:
	if _animation_player == null:
		return

	var next_animation := _get_animation_for_state(state)
	if next_animation == &"" or next_animation == _current_animation:
		return

	_current_animation = next_animation
	_animation_player.play(next_animation)


func _get_animation_for_state(state: StringName) -> StringName:
	var model_key := String(_model_key)
	var model_map: Dictionary = ANIMATION_BY_MODEL.get(model_key, ANIMATION_BY_MODEL["generic"])
	var state_key := String(state)
	if not model_map.has(state_key):
		state_key = "idle"
	return _first_available_animation(model_map[state_key])


func _first_available_animation(names: Array) -> StringName:
	var animation_list := _animation_player.get_animation_list()
	for wanted_name in names:
		var wanted_basename := StringName(wanted_name)
		for animation_name_text in animation_list:
			var animation_name := StringName(animation_name_text)
			if animation_name == wanted_basename or _animation_basename(animation_name) == wanted_basename:
				return animation_name
	return &""


func _animation_basename(animation_name: StringName) -> StringName:
	var text := String(animation_name)
	var separator := text.rfind("|")
	if separator >= 0:
		text = text.substr(separator + 1)
	return StringName(text)


func _resolve_model_key() -> StringName:
	var search_text := "%s %s %s" % [name, animal_kind, _animation_source_text()]
	var lower := search_text.to_lower()
	for model_key in ANIMATION_BY_MODEL.keys():
		if model_key == "generic":
			continue
		if lower.contains(model_key):
			return StringName(model_key)
	return &"generic"


func _animation_source_text() -> String:
	if _animation_player == null:
		return ""
	var cursor: Node = _animation_player
	var names: Array[String] = []
	while cursor != null:
		names.append(cursor.name)
		cursor = cursor.get_parent()
	return " ".join(names)


func _face_direction(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return

	var yaw_offset := deg_to_rad(front_yaw_offset_degrees)
	var target_yaw := atan2(direction.x, direction.z) + yaw_offset
	rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)


func _get_game_manager() -> Node:
	if game_manager_path != NodePath("") and has_node(game_manager_path):
		return get_node(game_manager_path)
	var managers := get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		return managers[0]
	return null
