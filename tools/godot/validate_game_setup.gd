extends SceneTree

var _failures: Array[String] = []
var _main: Node = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	_check_project_settings()
	_check_input_map()
	_check_menu_scenes()

	var packed := load("res://scenes/levels/main.tscn") as PackedScene
	_check(packed != null, "main.tscn loads as PackedScene")
	if packed == null:
		_finish()
		return

	_main = packed.instantiate()
	root.add_child(_main)
	var manager := _main.get_node_or_null("GameManager")
	if manager != null:
		manager.set("autosave_enabled", false)
		manager.set("diablo_timer_enabled", false)
		manager.set("diablo_spawn_delay", 60.0)
	await process_frame
	await process_frame

	_check_main_nodes(_main)
	await _check_runtime_mechanics(_main)

	_main.queue_free()
	await process_frame
	_finish()


func _check_project_settings() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/ui/main_menu.tscn", "main menu configured as main scene")


func _check_input_map() -> void:
	for action in ["move_forward", "move_backward", "move_left", "move_right", "run", "interact", "pause"]:
		_check(InputMap.has_action(action), "InputMap has %s" % action)
		_check(InputMap.action_get_events(action).size() > 0, "InputMap %s has event" % action)


func _check_menu_scenes() -> void:
	for path in [
		"res://scenes/ui/main_menu.tscn",
		"res://scenes/ui/settings_menu.tscn",
		"res://scenes/ui/hud.tscn",
		"res://scenes/ui/pause_menu.tscn",
		"res://scenes/ui/defeat_screen.tscn",
	]:
		var packed := load(path) as PackedScene
		_check(packed != null, "%s loads" % path)
		if packed != null:
			var instance := packed.instantiate()
			_check(instance != null and instance.get_script() != null, "%s has root script" % path)
			if instance != null:
				instance.free()


func _check_main_nodes(main: Node) -> void:
	for path in [
		"Sky3D",
		"Sky3D/SunLight",
		"DayNightBridge",
		"Level",
		"MapBounds",
		"SpawnPoints",
		"SpawnPoints/Player_Spawn",
		"SpawnPoints/Diablo_Cave_Spawn",
		"SpawnPoints/AnimalSpawns",
		"SpawnPoints/CorralZone",
		"SpawnPoints/SafeCorralZone/CollisionShape3D",
		"Player",
		"Diablo",
		"Animals",
		"GameManager",
		"InteractiveObjects/CorralGate",
		"InteractiveObjects/MudTrap_01",
		"InteractiveObjects/BridgeTrigger",
		"InteractiveObjects/CaveTrigger",
		"InteractiveObjects/Cacique_01",
		"UI/TopLeft/HealthContent/HealthBar",
		"UI/TopRight/ObjectivePanel/Content/AnimalRow/LabelAnimals",
		"UI/OxygenPanel/OxygenContent/OxygenBar",
		"PauseMenu",
		"DefeatScreen",
		"VictoryScreen",
	]:
		_check(main.has_node(path), "main has %s" % path)

	_check(not main.has_node("UI/TopLeft/HeartsContainer"), "HUD uses health bar not hearts")
	_check(not main.has_node("UI/LabelScore"), "HUD has no score label")

	var animal_spawns := main.get_node("SpawnPoints/AnimalSpawns")
	_check(animal_spawns.get_child_count() == 10, "main has 10 animal spawn markers")

	var sun := main.get_node("Sky3D/SunLight") as DirectionalLight3D
	_check(sun != null and sun.shadow_enabled, "sun shadows enabled")

	var safe_zone := main.get_node("SpawnPoints/SafeCorralZone") as Area3D
	_check(safe_zone.collision_layer == 32, "safe corral uses SafeZone layer")


func _check_runtime_mechanics(main: Node) -> void:
	var manager := main.get_node("GameManager")
	_check(manager != null, "GameManager exists")
	if manager == null:
		return

	for method in ["start_new_game", "continue_game", "collect_animal", "on_player_health_changed", "update_progression", "spawn_diablo", "win_game", "lose_game", "update_ui", "spawn_animals", "set_player_entered_cave"]:
		_check(manager.has_method(method), "GameManager has %s" % method)

	var player := main.get_node("Player") as Node3D
	_check(player.has_method("heal"), "Player has heal")
	_check(player.has_method("reset_health"), "Player has reset_health")
	_check(player.has_method("receive_damage"), "Player has receive_damage")
	_check(player.has_method("is_submerged"), "Player has is_submerged")
	_check(player.has_method("is_swimming"), "Player has is_swimming")
	_check(player.has_method("is_diving"), "Player has is_diving")
	_check(float(player.get("MAX_HEALTH")) == 100.0, "Player MAX_HEALTH is 100")
	_check(float(player.get("diablo_damage")) == 34.0, "Player diablo_damage is 34")
	await _check_player_movement_does_not_rotate_camera(player)
	await _check_water_mechanics(player, manager)

	var diablo := main.get_node("Diablo")
	_check(not bool(diablo.get("active")), "Diablo inactive at start")
	_check(float(diablo.get("chase_speed")) == 5.0, "Diablo speed is 5.0 at progress 1")

	var ui := main.get_node("UI")
	for method in ["set_health", "set_animals", "set_progress", "set_message", "set_oxygen", "show_oxygen_bar"]:
		_check(ui.has_method(method), "HUD has %s" % method)

	_check(main.has_node("DayNightBridge"), "day night bridge exists")

	var animals := main.get_node("Animals")
	_check(animals.get_child_count() == 3, "progress 1 spawns 3 active animals")

	await _deliver_next_animal(main)
	await _deliver_next_animal(main)
	await _deliver_next_animal(main)
	await process_frame
	_check(int(manager.get("animals_in_corral")) == 3, "animals counter reaches 3 after corral delivery")
	_check(int(manager.get("current_progress")) == 2, "progress changes to 2 at 3 animals")
	_check(float(diablo.get("chase_speed")) == 7.0, "Diablo speed is 7.0 at progress 2")

	await _deliver_next_animal(main)
	await _deliver_next_animal(main)
	await _deliver_next_animal(main)
	await process_frame
	_check(int(manager.get("animals_in_corral")) == 6, "animals counter reaches 6")
	_check(int(manager.get("current_progress")) == 3, "progress changes to 3 at 6 animals")
	_check(float(diablo.get("chase_speed")) == 9.0, "Diablo speed is 9.0 at progress 3")

	for i in 4:
		await _deliver_next_animal(main)
	await process_frame
	_check(int(manager.get("animals_in_corral")) == 10, "animals counter reaches 10")
	_check(bool(manager.get("victory")), "victory set at 10 animals")

	manager.set("game_over", false)
	manager.set("victory", false)
	player.reset_health()
	player.receive_damage(100.0)
	await process_frame
	_check(float(player.get("health")) <= 0.0, "player health reaches 0 after lethal damage")
	_check(bool(manager.get("game_over")), "game_over set on defeat")


func _check_water_mechanics(player: Node3D, manager: Node) -> void:
	player.enter_water(null, true, 2.0)
	player.global_position.y = 0.5
	player.set("swim_state", player.SwimState.UNDERWATER)
	await physics_frame
	_check(bool(player.get("is_in_water")), "Player enters water state")
	_check(player.call("is_swimming"), "Player is swimming")
	_check(player.call("is_diving"), "Player can dive underwater")
	_check(player.call("is_submerged"), "Player is submerged while diving")
	player.set("oxygen", 0.0)
	await physics_frame
	_check(float(player.get("health")) < float(player.get("MAX_HEALTH")), "drowning reduces health")
	player.exit_water(null)
	await physics_frame
	_check(not bool(player.get("is_in_water")), "Player exits water state")
	_check(not player.call("is_diving"), "Player stops diving on exit")
	player.reset_health()
	manager.set("game_over", false)
	manager.set("victory", false)


func _deliver_next_animal(main: Node) -> void:
	var animals := main.get_node("Animals")
	_check(animals.get_child_count() > 0, "there is an active animal to deliver")
	if animals.get_child_count() == 0:
		return

	var animal := animals.get_child(0)
	var player := main.get_node("Player")
	if animal.has_method("interact"):
		animal.interact(player)
	await process_frame

	var corral := main.get_node("SpawnPoints/CorralZone")
	if corral.has_method("_try_receive_animal"):
		corral._try_receive_animal(player)
	await process_frame


func _check_player_movement_does_not_rotate_camera(player: Node3D) -> void:
	var camera_pivot := player.get_node_or_null("CameraPivot") as Node3D
	_check(camera_pivot != null, "Player has CameraPivot")
	if camera_pivot == null:
		return

	var player_yaw: float = player.rotation.y
	var pivot_yaw: float = camera_pivot.rotation.y
	Input.action_press("move_forward")
	await physics_frame
	await physics_frame
	Input.action_release("move_forward")
	_check(is_equal_approx(player.rotation.y, player_yaw), "WASD does not rotate Player root")
	_check(is_equal_approx(camera_pivot.rotation.y, pivot_yaw), "WASD does not rotate CameraPivot")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("VALIDATION_OK")
		quit(0)
	else:
		print("VALIDATION_FAILED")
		for failure in _failures:
			print("- %s" % failure)
		quit(1)
