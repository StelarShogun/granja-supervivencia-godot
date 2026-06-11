extends Node

const ANIMAL_GOAL := 10
const AUTOSAVE_INTERVAL := 300.0  # 5 minutos, sobre el slot activo
## Logs de validación del spawn del Diablo (raycast, collider, posición final).
const DEBUG_DIABLO_SPAWN := false
## Capa de colisión del terreno caminable (TerrainCollision).
const WORLD_LAYER := 2

@export var animals_in_corral: int = 0
@export var current_progress: int = 1
@export var player_path: NodePath = NodePath("../Player")
@export var diablo_path: NodePath = NodePath("../Diablo")
@export var ui_path: NodePath = NodePath("../UI")
@export var pause_menu_path: NodePath = NodePath("../PauseMenu")
@export var defeat_screen_path: NodePath = NodePath("../DefeatScreen")
@export var corral_zone_path: NodePath = NodePath("../SpawnPoints/CorralZone")
@export var safe_corral_zone_path: NodePath = NodePath("../SpawnPoints/SafeCorralZone")
@export var animal_spawn_path: NodePath = NodePath("../SpawnPoints/AnimalSpawns")
@export var animal_container_path: NodePath = NodePath("../Animals")
@export var diablo_cave_spawn_path: NodePath = NodePath("../SpawnPoints/Diablo_Cave_Spawn")
@export var animal_scene: PackedScene = preload("res://scenes/animals/animal.tscn")
## Species variants picked per spawn slot. Falls back to animal_scene if empty.
@export var animal_species_scenes: Array[PackedScene] = [
	preload("res://scenes/animals/animal_cow.tscn"),
	preload("res://scenes/animals/animal_chicken.tscn"),
	preload("res://scenes/animals/animal_sheep.tscn"),
	preload("res://scenes/animals/animal_pig.tscn"),
	preload("res://scenes/animals/animal_goat.tscn"),
]
@export var diablo_spawn_delay: float = 60.0
@export var autosave_enabled: bool = true
@export var diablo_timer_enabled: bool = true

var game_started: bool = false
var game_over: bool = false
var victory: bool = false
var diablo_spawned: bool = false
var player_in_safe_zone: bool = false
var player_entered_cave: bool = false
var elapsed_time: float = 0.0

var _current_message: String = ""
var _message_time_left: float = 0.0
var _used_spawn_indices: Dictionary = {}
var _spawned_animals: Array[Node] = []
var _spawn_request_id: int = 0
var _save_accumulator: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_manager")
	var ambient := preload("res://scripts/world/ambient_audio_controller.gd").new()
	ambient.name = "AmbientAudioController"
	ambient.player_path = player_path
	add_child(ambient)
	_restore_objective_message()
	call_deferred("_boot_game")


func _process(delta: float) -> void:
	if game_started and not game_over and not get_tree().paused:
		elapsed_time += delta
		_save_accumulator += delta
		if _save_accumulator >= AUTOSAVE_INTERVAL:
			_save_accumulator = 0.0
			save_current_game()
			show_message("Partida guardada", 1.2)

	if _message_time_left > 0.0:
		_message_time_left -= delta
		if _message_time_left <= 0.0 and not game_over:
			_restore_objective_message()
			_update_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and game_started and not game_over:
		toggle_pause()
		get_viewport().set_input_as_handled()


func _boot_game() -> void:
	if SaveManager.pending_save_data.is_empty():
		start_new_game()
	else:
		var data := SaveManager.pending_save_data.duplicate(true)
		SaveManager.pending_save_data = {}
		continue_game(data)


func start_game() -> void:
	start_new_game()


func start_new_game() -> void:
	_clear_animals()
	animals_in_corral = 0
	current_progress = 1
	game_started = true
	game_over = false
	victory = false
	diablo_spawned = false
	player_in_safe_zone = false
	player_entered_cave = false
	elapsed_time = 0.0
	_current_message = ""
	_message_time_left = 0.0
	_save_accumulator = 0.0
	_used_spawn_indices.clear()
	_spawned_animals.clear()

	match SaveManager.game_mode:
		SaveManager.MODE_HARD:
			diablo_spawn_delay = 20.0
			show_message("Modo difícil activado. El Diablo viene.", 4.0)
		SaveManager.MODE_EASY:
			diablo_spawn_delay = 90.0
			show_message("Modo fácil: explora la finca con calma.", 3.0)
		_:
			diablo_spawn_delay = 60.0

	var player := get_node_or_null(player_path)
	var player_spawn := get_node_or_null("../SpawnPoints/Player_Spawn") as Node3D
	if player != null and player_spawn != null:
		(player as Node3D).global_position = player_spawn.global_position
	if player != null and player.has_method("reset_health"):
		player.reset_health()
	if player != null and player.has_method("capture_mouse"):
		player.capture_mouse()

	var diablo := get_node_or_null(diablo_path)
	_prepare_diablo_hidden(diablo)
	_update_diablo_safe_state()

	_restore_objective_message()
	_update_diablo_speed()
	spawn_animals()
	AudioManager.enter_gameplay()
	update_ui()
	save_current_game()
	_spawn_request_id += 1
	if diablo_timer_enabled:
		spawn_diablo_after_delay(_spawn_request_id)


func continue_game(data: Dictionary) -> void:
	SaveManager.game_mode = int(data.get("game_mode", SaveManager.game_mode))
	start_new_game()
	animals_in_corral = int(data.get("animals_in_corral", 0))
	current_progress = int(data.get("current_progress", 1))
	elapsed_time = float(data.get("elapsed_time", 0.0))
	diablo_spawned = bool(data.get("diablo_spawned", false))
	player_entered_cave = bool(data.get("player_entered_cave", false))
	player_in_safe_zone = false
	_used_spawn_indices.clear()
	for i in mini(animals_in_corral, 10):
		_used_spawn_indices[i] = true

	var player := get_node_or_null(player_path)
	if player != null:
		if data.has("health"):
			player.health = clampf(float(data.get("health", 100.0)), 0.0, player.MAX_HEALTH)
		elif data.has("lives"):
			player.health = clampf((float(data.get("lives", 3)) / 3.0) * player.MAX_HEALTH, 0.0, player.MAX_HEALTH)
		if player.has_method("_publish_health_ui"):
			player._publish_health_ui()

	var player_3d := player as Node3D
	var pos_data = data.get("player_position", null)
	if player_3d != null and pos_data is Array and pos_data.size() == 3:
		var restored := Vector3(float(pos_data[0]), float(pos_data[1]), float(pos_data[2]))
		if restored.y > -2.0 and restored.length() < 300.0:
			player_3d.global_position = restored
		else:
			var spawn := get_node_or_null("../SpawnPoints/Player_Spawn") as Node3D
			if spawn != null:
				player_3d.global_position = spawn.global_position

	update_progression(false)
	spawn_animals()
	if diablo_spawned or elapsed_time >= diablo_spawn_delay:
		spawn_diablo(false)
	else:
		var diablo := get_node_or_null(diablo_path)
		_prepare_diablo_hidden(diablo)
		_spawn_request_id += 1
		if diablo_timer_enabled:
			spawn_diablo_after_delay(_spawn_request_id)
	update_ui()


func collect_animal(source_animal: Node = null) -> void:
	if game_over or victory:
		return

	if source_animal != null:
		_spawned_animals.erase(source_animal)

	animals_in_corral += 1
	_prune_spawned_animals()

	var old_progress := current_progress
	update_progression()
	if game_over:
		return

	if current_progress == old_progress:
		show_message("Animal registrado en el corral.", 1.4)

	update_ui()
	save_current_game()


func on_player_health_changed(_current: float, _maximum: float) -> void:
	update_ui()
	if _current > 0.0 and _current < _maximum * 0.35:
		show_message("Vida baja. Busca un Cacique.", 2.0)


func show_message(message: String, duration: float = 2.0) -> void:
	if game_over:
		return
	_current_message = message
	_message_time_left = duration
	update_ui()


func update_progression(show_progress_message: bool = true) -> void:
	if animals_in_corral >= ANIMAL_GOAL:
		win_game()
		return

	var old_progress := current_progress
	if animals_in_corral >= 6:
		current_progress = 3
	elif animals_in_corral >= 3:
		current_progress = 2
	else:
		current_progress = 1

	if current_progress != old_progress:
		_update_diablo_speed()
		spawn_animals()
		AudioManager.play_progression()
		if show_progress_message:
			show_message("Progresión %d activada." % current_progress, 2.4)


func spawn_animals() -> void:
	_prune_spawned_animals()

	if animal_scene == null:
		return

	var spawn_root := get_node_or_null(animal_spawn_path)
	var container := get_node_or_null(animal_container_path)
	if spawn_root == null or container == null:
		return

	var markers: Array[Node] = []
	for child in spawn_root.get_children():
		if child is Marker3D:
			markers.append(child)

	var target_count := _active_animal_target()
	while animals_in_corral + _spawned_animals.size() < target_count:
		var index := _next_available_spawn_index(markers.size())
		if index < 0:
			return

		var marker := markers[index] as Marker3D
		var scene := animal_scene
		if not animal_species_scenes.is_empty():
			# stable per-slot species so reloads repopulate consistently
			scene = animal_species_scenes[index % animal_species_scenes.size()]
		var animal := scene.instantiate()
		animal.name = "%s_%02d" % [animal.name, index + 1]
		var kinds := ["vaca", "gallina", "oveja", "vaca", "cabra"]
		animal.set("animal_kind", kinds[index % kinds.size()])
		animal.set("game_manager_path", NodePath("../../GameManager"))
		container.add_child(animal)
		if animal is Node3D:
			(animal as Node3D).global_transform = marker.global_transform
		_spawned_animals.append(animal)
		_used_spawn_indices[index] = true


func spawn_animals_for_progress() -> void:
	spawn_animals()


func spawn_diablo_after_delay(request_id: int = 0) -> void:
	var local_request := request_id if request_id != 0 else _spawn_request_id
	var wait_time := maxf(0.0, diablo_spawn_delay - elapsed_time)
	if wait_time > 0.0:
		await get_tree().create_timer(wait_time).timeout
	if SaveManager.game_mode != SaveManager.MODE_HARD:
		while not _is_night():
			if local_request != _spawn_request_id or not game_started or game_over:
				return
			await get_tree().create_timer(2.0).timeout
	if local_request == _spawn_request_id and game_started and not game_over and not diablo_spawned:
		spawn_diablo()


func _is_night() -> bool:
	var dnc := get_tree().get_first_node_in_group("day_night_cycle")
	if dnc == null:
		return true
	return sin(float(dnc.get("time_of_day")) * TAU) < 0.0


func spawn_diablo(show_alert: bool = true) -> void:
	var diablo := get_node_or_null(diablo_path)
	if diablo == null:
		return

	var spawn := get_node_or_null(diablo_cave_spawn_path) as Node3D
	if spawn != null and diablo is Node3D:
		(diablo as Node3D).global_position = _ground_snap(
			spawn.global_position, diablo as Node3D, 0.6, "QA-DIABLO")
	if diablo.has_method("set_progress"):
		diablo.set_progress(current_progress)
	if diablo.has_method("activate"):
		diablo.activate()
	_update_diablo_safe_state()

	diablo_spawned = true
	if DEBUG_DIABLO_SPAWN and diablo is Node3D:
		print("[QA-DIABLO] final=%v active=%s visible=%s" % [
			(diablo as Node3D).global_position,
			str(diablo.get("active")),
			str((diablo as Node3D).visible),
		])
	if show_alert:
		var ui := get_node_or_null(ui_path)
		if ui != null and ui.has_method("show_center_alert"):
			ui.show_center_alert("¡El Diablo ha salido de la cueva!", 4.0)
		show_message("El Diablo salió de la cueva. Mantente lejos.", 4.0)
	save_current_game()


func _active_animal_target() -> int:
	match current_progress:
		1:
			return 3
		2:
			return 6
		_:
			return ANIMAL_GOAL


func _next_available_spawn_index(marker_count: int) -> int:
	for i in marker_count:
		if not _used_spawn_indices.has(i):
			return i
	return -1


func _prune_spawned_animals() -> void:
	for i in range(_spawned_animals.size() - 1, -1, -1):
		if not is_instance_valid(_spawned_animals[i]):
			_spawned_animals.remove_at(i)


func _update_diablo_speed() -> void:
	var diablo := get_node_or_null(diablo_path)
	if diablo != null and diablo.has_method("set_progress"):
		diablo.set_progress(current_progress)


func update_ui() -> void:
	var ui := get_node_or_null(ui_path)
	var player := get_node_or_null(player_path)
	if ui != null:
		if player != null and ui.has_method("set_health"):
			ui.set_health(float(player.get("health")), float(player.get("MAX_HEALTH")))
		if ui.has_method("set_animals"):
			ui.set_animals(animals_in_corral, ANIMAL_GOAL)
		if ui.has_method("set_progress"):
			ui.set_progress(current_progress)
		if _message_time_left > 0.0:
			if ui.has_method("set_message"):
				ui.set_message(_current_message)
		elif ui.has_method("show_objective"):
			ui.show_objective(_current_message)

	var corral := get_node_or_null(corral_zone_path)
	if corral != null and corral.has_method("set_count"):
		corral.set_count(animals_in_corral, ANIMAL_GOAL)


func update_player_health(value: float, max_value: float) -> void:
	var ui := get_node_or_null(ui_path)
	if ui != null and ui.has_method("set_health"):
		ui.set_health(value, max_value)


func set_player_safe_zone(value: bool) -> void:
	if player_in_safe_zone == value:
		return

	player_in_safe_zone = value
	_update_diablo_safe_state()
	if player_in_safe_zone:
		show_message("Zona segura: El Diablo no puede entrar.", 2.2)
	else:
		show_message("Saliste de la zona segura.", 1.6)


func set_player_entered_cave(value: bool) -> void:
	if player_entered_cave == value:
		return
	player_entered_cave = value
	save_current_game()


func is_player_in_safe_zone() -> bool:
	return player_in_safe_zone


func _restore_objective_message() -> void:
	_current_message = _objective_message()
	_message_time_left = 0.0


func _objective_message() -> String:
	if victory:
		return "Victoria: reuniste 10 animales en el corral."
	if game_over:
		return "Derrota: te quedaste sin vida."

	var carry_hint := " (1 animal a la vez)" if SaveManager.game_mode == SaveManager.MODE_HARD else ""
	match current_progress:
		1:
			return "Recolecta animales y llévalos al corral." + carry_hint
		2:
			return "Progresión 2: lleva 6 animales al corral." + carry_hint
		_:
			return "Progresión 3: completa 10 animales en el corral." + carry_hint


func win_game() -> void:
	animals_in_corral = ANIMAL_GOAL
	current_progress = 3
	victory = true
	game_over = true
	AudioManager.stop_gameplay()
	AudioManager.play_victory()
	_restore_objective_message()
	_update_diablo_speed()
	update_ui()
	save_current_game()
	var vs := get_node_or_null("../VictoryScreen")
	if vs != null and vs.has_method("show_victory"):
		vs.show_victory(animals_in_corral)


func lose_game() -> void:
	if game_over:
		return
	victory = false
	game_over = true
	AudioManager.stop_gameplay()
	AudioManager.play_defeat()
	_restore_objective_message()
	update_ui()
	save_current_game()
	var ds := get_node_or_null(defeat_screen_path)
	if ds != null and ds.has_method("show_defeat"):
		ds.show_defeat()


func toggle_pause() -> void:
	if get_tree().paused:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	get_tree().paused = true
	var player := get_node_or_null(player_path)
	if player != null and player.has_method("release_mouse"):
		player.release_mouse()
	var pause_menu := get_node_or_null(pause_menu_path)
	if pause_menu != null and pause_menu.has_method("show_pause"):
		pause_menu.show_pause()


func resume_game() -> void:
	get_tree().paused = false
	var pause_menu := get_node_or_null(pause_menu_path)
	if pause_menu != null and pause_menu.has_method("hide_pause"):
		pause_menu.hide_pause()
	var player := get_node_or_null(player_path)
	if player != null and player.has_method("capture_mouse") and game_started and not game_over:
		player.capture_mouse()


func save_current_game() -> void:
	if not game_started or not autosave_enabled:
		return
	var player := get_node_or_null(player_path) as Node3D
	var player_position := [0.0, 0.0, 0.0]
	var health_value := 100.0
	if player != null:
		player_position = [player.global_position.x, player.global_position.y, player.global_position.z]
		if player.get("health") != null:
			health_value = float(player.get("health"))
	SaveManager.save_game({
		"health": health_value,
		"game_mode": SaveManager.game_mode,
		"animals_in_corral": animals_in_corral,
		"current_progress": current_progress,
		"player_position": player_position,
		"elapsed_time": elapsed_time,
		"diablo_spawned": diablo_spawned,
		"player_entered_cave": player_entered_cave,
	})


func _prepare_diablo_hidden(diablo: Node) -> void:
	if diablo == null:
		return
	var spawn := get_node_or_null(diablo_cave_spawn_path) as Node3D
	if spawn != null and diablo is Node3D:
		(diablo as Node3D).global_position = spawn.global_position
	if diablo.has_method("deactivate"):
		diablo.deactivate()
	if diablo.has_method("set_target_safe_zone"):
		diablo.set_target_safe_zone(false)


func _update_diablo_safe_state() -> void:
	var diablo := get_node_or_null(diablo_path)
	if diablo != null and diablo.has_method("set_target_safe_zone"):
		diablo.set_target_safe_zone(player_in_safe_zone)


## Raycast vertical contra la capa World. Devuelve la posición del marcador
## ajustada para quedar `offset_y` por encima del suelo real. Si el rayo no
## golpea nada, devuelve la posición original (el marcador manda).
func _ground_snap(
	marker_pos: Vector3,
	context: Node3D,
	offset_y: float = 0.6,
	tag: String = "QA-SNAP"
) -> Vector3:
	var world := context.get_world_3d()
	if world == null:
		return marker_pos
	var from := marker_pos + Vector3.UP * 2.0
	var to := marker_pos + Vector3.DOWN * 120.0
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		if DEBUG_DIABLO_SPAWN:
			print("[%s] marker=%v raycast SIN hit; uso marcador" % [tag, marker_pos])
		return marker_pos
	var ground: Vector3 = hit["position"]
	var collider_name := "?"
	if hit.has("collider") and hit["collider"] != null:
		collider_name = String((hit["collider"] as Node).name)
	if DEBUG_DIABLO_SPAWN:
		print("[%s] marker=%v hit=%v collider=%s final=%v" % [
			tag, marker_pos, ground, collider_name,
			ground + Vector3.UP * offset_y,
		])
	return ground + Vector3.UP * offset_y


func _clear_animals() -> void:
	var container := get_node_or_null(animal_container_path)
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()


func _update_ui() -> void:
	update_ui()


func _win_game() -> void:
	win_game()


func _lose_game() -> void:
	lose_game()
