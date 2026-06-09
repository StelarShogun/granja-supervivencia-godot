extends SceneTree

## QA headless: instancia menú principal/pausa y ejercita SaveManager (5 slots).


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var failures := 0

	# SaveManager: API de slots.
	var sm := root.get_node("/root/SaveManager")
	sm.active_slot = 4
	sm.save_game({"game_mode": 2, "animals_in_corral": 7, "current_progress": 3})
	if not sm.has_save(4):
		failures += 1
		print("FAIL: has_save(4) tras save_game")
	var meta: Dictionary = sm.get_save_metadata(4)
	if meta.get("mode_name", "") != "Fácil" or meta.get("animals_in_corral", -1) != 7:
		failures += 1
		print("FAIL: metadata slot 4 = ", meta)
	var data: Dictionary = sm.load_game(4)
	if int(data.get("slot_id", -1)) != 4 or str(data.get("saved_at", "")).is_empty():
		failures += 1
		print("FAIL: load_game(4) sin slot_id/saved_at: ", data)
	sm.delete_save(4)
	if sm.has_save(4):
		failures += 1
		print("FAIL: delete_save(4) no borró")
	if sm.has_save(0) or sm.has_save(6):
		failures += 1
		print("FAIL: slots fuera de rango reportan datos")

	# Menú principal: instancia y navegación básica.
	var menu_scene := load("res://scenes/ui/main_menu.tscn") as PackedScene
	var menu = menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	var main_panel: Control = menu.get_node("Layout/VBox/MainPanel")
	var buttons: Array = main_panel.get_node("Buttons").get_children()
	if buttons.size() != 2:
		failures += 1
		print("FAIL: menú principal debe tener 2 botones, tiene ", buttons.size())
	menu.get_node("Layout/VBox/MainPanel/Buttons/NewGameButton").emit_signal("pressed")
	await process_frame
	if not (menu.get_node("Layout/VBox/DifficultyPanel") as Control).visible:
		failures += 1
		print("FAIL: Nueva partida no abre panel de dificultad")
	menu.get_node("Layout/VBox/DifficultyPanel/VBox/EasyButton").emit_signal("pressed")
	await process_frame
	var slot_list: VBoxContainer = menu.get_node("Layout/VBox/SlotSelectPanel/VBox/SlotList")
	if slot_list.get_child_count() != 5:
		failures += 1
		print("FAIL: selector de slots debe tener 5, tiene ", slot_list.get_child_count())
	menu.queue_free()
	await process_frame

	# Menú de pausa: instancia limpia.
	var pause_scene := load("res://scenes/ui/pause_menu.tscn") as PackedScene
	var pause = pause_scene.instantiate()
	root.add_child(pause)
	await process_frame
	for required in ["ResumeButton", "SaveButton", "MainMenuButton"]:
		if pause.get_node_or_null("Panel/MenuButtons/%s" % required) == null:
			failures += 1
			print("FAIL: pausa sin botón ", required)
	pause.queue_free()
	await process_frame

	if failures == 0:
		print("QA_MENU_SAVE: PASS")
	else:
		print("QA_MENU_SAVE: %d FALLOS" % failures)
	quit(0 if failures == 0 else 1)
