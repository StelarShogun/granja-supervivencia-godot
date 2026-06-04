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
		"WorldEnvironment",
		"SunLight",
		"DayNightCycle",
		"Level",
		"Level/Terreno_Finca",
		"Level/Terrain_BasicCollision/CollisionShape3D",
		"MapBounds",
		"MapBounds/Wall_North/CollisionShape3D",
		"MapBounds/Wall_South/CollisionShape3D",
		"MapBounds/Wall_East/CollisionShape3D",
		"MapBounds/Wall_West/CollisionShape3D",
		"ScenarioColliders/FenceCollider_01/CollisionShape3D",
		"ScenarioColliders/FenceCollider_02/CollisionShape3D",
		"ScenarioColliders/FenceCollider_03/CollisionShape3D",
		"ScenarioColliders/FenceCollider_04/CollisionShape3D",
		"ScenarioColliders/FenceCollider_05/CollisionShape3D",
		"ScenarioColliders/BridgeCollider/CollisionShape3D",
		"ScenarioColliders/BarnCollider/CollisionShape3D",
		"ScenarioColliders/CaveCollider/CollisionShape3D",
		"WaterAreas/LakeWaterArea/LakeWaterVisual",
		"WaterAreas/LakeWaterArea/CollisionShape3D",
		"WaterAreas/RiverWaterArea/RiverWater_01",
		"WaterAreas/RiverWaterArea/RiverWater_04",
		"WaterAreas/RiverWaterArea/CollisionShape_01",
		"WaterAreas/RiverWaterArea/CollisionShape_04",
		"SpawnPoints",
		"SpawnPoints/Player_Spawn",
		"SpawnPoints/Diablo_Spawn",
		"SpawnPoints/Diablo_Cave_Spawn",
		"SpawnPoints/AnimalSpawns",
		"SpawnPoints/CorralZone",
		"SpawnPoints/SafeCorralZone/CollisionShape3D",
		"Player",
		"Diablo",
		"Animals",
		"GameManager",
		"InteractiveObjects/CorralGate",
		"InteractiveObjects/MudTrap",
		"InteractiveObjects/BridgeTrigger",
		"UI/TopLeft/HeartsContainer",
		"UI/TopRight/ObjectivePanel/Content/AnimalRow/LabelAnimals",
		"UI/TopRight/ObjectivePanel/Content/LabelProgress",
		"UI/CenterAlert/LabelAlert",
		"UI/OxygenPanel/OxygenContent/OxygenBar",
		"UI/MessagePanel/LabelMessage",
		"PauseMenu",
	]:
		_check(main.has_node(path), "main has %s" % path)

	_check(not main.has_node("UI/LabelScore"), "HUD has no score label")

	var animal_spawns := main.get_node("SpawnPoints/AnimalSpawns")
	_check(animal_spawns.get_child_count() == 10, "main has 10 animal spawn markers")

	var world_environment := main.get_node("WorldEnvironment") as WorldEnvironment
	_check(world_environment.environment != null, "WorldEnvironment has Environment")
	if world_environment.environment != null:
		_check(world_environment.environment.fog_enabled, "fog enabled")
		_check(world_environment.environment.fog_density <= 0.0015, "fog density is very soft")

	var sun := main.get_node("SunLight") as DirectionalLight3D
	_check(sun.shadow_enabled, "sun shadows enabled")

	var lake := main.get_node("WaterAreas/LakeWaterArea") as Area3D
	var river := main.get_node("WaterAreas/RiverWaterArea") as Area3D
	var safe_zone := main.get_node("SpawnPoints/SafeCorralZone") as Area3D
	_check(lake.collision_layer == 16 and lake.collision_mask == 1, "lake water uses Water layer and Player mask")
	_check(river.collision_layer == 16 and river.collision_mask == 1, "river water uses Water layer and Player mask")
	_check(safe_zone.collision_layer == 32 and safe_zone.collision_mask == 1, "safe corral uses SafeZone layer and Player mask")

	var level := main.get_node("Level")
	await process_frame
	await process_frame
	_check(level.has_node("GeneratedCollisions"), "generated terrain collision root exists")
	if level.has_node("GeneratedCollisions"):
		_check(level.get_node("GeneratedCollisions").get_child_count() > 0, "generated terrain collisions exist")
		var generated := level.get_node("GeneratedCollisions")
		_check(generated.has_node("Fence_Plain_01_Collision"), "generated fence collision exists")
		_check(generated.has_node("Rock_M00_Collision"), "generated large rock collision exists")
		_check(generated.has_node("Tree_F000_Trunk_Collision"), "generated tree trunk collision exists")


func _check_runtime_mechanics(main: Node) -> void:
	var manager := main.get_node("GameManager")
	_check(manager != null, "GameManager exists")
	if manager == null:
		return

	for method in ["start_new_game", "continue_game", "collect_animal", "player_hit", "update_progression", "spawn_diablo_after_delay", "spawn_diablo", "win_game", "lose_game", "update_ui", "spawn_animals"]:
		_check(manager.has_method(method), "GameManager has %s" % method)

	var player := main.get_node("Player") as Node3D
	_check(player.has_method("slow_down"), "Player has slow_down")
	_check(player.has_method("receive_damage"), "Player has receive_damage")
	_check(player.has_method("receive_drowning_damage"), "Player has receive_drowning_damage")
	_check(player.has_method("enter_water"), "Player has enter_water")
	_check(player.has_method("exit_water"), "Player has exit_water")
	_check(player.has_method("capture_mouse"), "Player has capture_mouse")
	_check(player.has_method("release_mouse"), "Player has release_mouse")
	_check(float(player.get("walk_speed")) == 10.0, "Player walk speed is 10.0")
	_check(float(player.get("run_speed")) == 18.0, "Player run speed is 18.0")
	_check(float(player.get("acceleration")) == 18.0, "Player acceleration is 18.0")
	_check(float(player.get("deceleration")) == 22.0, "Player deceleration is 22.0")
	_check(float(player.get("gravity")) == 25.0, "Player gravity is 25.0")
	_check(float(player.get("max_oxygen")) == 100.0, "Player max oxygen is 100")
	_check(float(player.get("water_move_speed_multiplier")) == 0.45, "Player water speed multiplier is 0.45")
	await _check_player_movement_does_not_rotate_camera(player)
	await _check_water_mechanics(main, player, manager)

	var diablo := main.get_node("Diablo")
	_check(diablo.has_method("reset_position"), "Diablo has reset_position")
	_check(diablo.has_method("activate"), "Diablo has activate")
	_check(diablo.has_method("deactivate"), "Diablo has deactivate")
	_check(diablo.has_method("set_target_safe_zone"), "Diablo has set_target_safe_zone")
	_check(not bool(diablo.get("active")), "Diablo inactive at start")
	_check(not diablo.visible, "Diablo hidden at start")
	_check(float(diablo.get("chase_speed")) == 3.0, "Diablo speed is 3.0 at progress 1")

	var ui := main.get_node("UI")
	for method in ["set_lives", "set_animals", "set_progress", "set_message", "show_center_alert", "set_oxygen", "show_oxygen_bar"]:
		_check(ui.has_method(method), "HUD has %s" % method)

	var cycle := main.get_node("DayNightCycle")
	_check(cycle.get("day_length_seconds") == 300.0, "day/night cycle uses 300 seconds")

	var animals := main.get_node("Animals")
	_check(animals.get_child_count() == 3, "progress 1 spawns 3 active animals")

	await _collect_next_animal(main)
	await _collect_next_animal(main)
	await _collect_next_animal(main)
	await process_frame
	_check(int(manager.get("animals_in_corral")) == 3, "animals counter reaches 3")
	_check(int(manager.get("score")) == 300, "score reaches 300 after 3 animals")
	_check(int(manager.get("current_progress")) == 2, "progress changes to 2 at 3 animals")
	_check(float(diablo.get("chase_speed")) == 4.0, "Diablo speed is 4.0 at progress 2")
	_check(animals.get_child_count() == 3, "progress 2 keeps 3 active animals after refill")

	await _collect_next_animal(main)
	await _collect_next_animal(main)
	await _collect_next_animal(main)
	await process_frame
	_check(int(manager.get("animals_in_corral")) == 6, "animals counter reaches 6")
	_check(int(manager.get("current_progress")) == 3, "progress changes to 3 at 6 animals")
	_check(float(diablo.get("chase_speed")) == 5.0, "Diablo speed is 5.0 at progress 3")
	_check(animals.get_child_count() == 4, "progress 3 refills toward 10 total animals")

	for i in 4:
		await _collect_next_animal(main)
	await process_frame
	_check(int(manager.get("animals_in_corral")) == 10, "animals counter reaches 10")
	_check(bool(manager.get("victory")), "victory set at 10 animals")
	_check(bool(manager.get("game_over")), "game_over set on victory")

	manager.set("game_over", false)
	manager.set("victory", false)
	manager.set("diablo_spawned", false)
	diablo.deactivate()
	manager.spawn_diablo(false)
	await process_frame
	_check(bool(manager.get("diablo_spawned")), "Diablo spawned flag set")
	_check(bool(diablo.get("active")), "Diablo active after spawn_diablo")
	_check(diablo.visible, "Diablo visible after spawn_diablo")

	manager.set("game_over", false)
	manager.set("victory", false)
	manager.set("lives", 3)
	manager.player_lost_life()
	manager.player_lost_life()
	manager.player_lost_life()
	await process_frame
	_check(int(manager.get("lives")) == 0, "lives reach 0 after 3 hits")
	_check(bool(manager.get("game_over")), "game_over set on defeat")


func _check_water_mechanics(main: Node, player: Node3D, manager: Node) -> void:
	var lake := main.get_node("WaterAreas/LakeWaterArea")
	var ui := main.get_node("UI")
	_check(ui.has_method("set_oxygen"), "HUD can set oxygen")

	player.enter_water(lake, true, -0.8)
	await physics_frame
	_check(bool(player.get("is_in_water")), "Player enters water state")
	_check(float(player.get("oxygen")) < float(player.get("max_oxygen")), "oxygen drains in water")

	manager.set("lives", 3)
	player.set("oxygen", 0.0)
	await physics_frame
	_check(int(manager.get("lives")) < 3, "drowning damage removes life")

	player.exit_water(lake)
	await physics_frame
	_check(not bool(player.get("is_in_water")), "Player exits water state")
	manager.set("lives", 3)
	manager.set("game_over", false)
	manager.set("victory", false)

	manager.set_player_safe_zone(true)
	await process_frame
	var diablo := main.get_node("Diablo")
	_check(bool(manager.get("player_in_safe_zone")), "GameManager tracks player safe zone")
	_check(bool(diablo.get("target_in_safe_zone")), "Diablo receives safe zone state")
	manager.set_player_safe_zone(false)
	await process_frame
	_check(not bool(manager.get("player_in_safe_zone")), "GameManager clears player safe zone")


func _collect_next_animal(main: Node) -> void:
	var animals := main.get_node("Animals")
	_check(animals.get_child_count() > 0, "there is an active animal to collect")
	if animals.get_child_count() == 0:
		return

	var animal := animals.get_child(0)
	var player := main.get_node("Player")
	if animal.has_method("interact"):
		animal.interact(player)
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
