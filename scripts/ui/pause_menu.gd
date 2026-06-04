extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/MenuButtons/ResumeButton.pressed.connect(_on_resume_button_pressed)
	$Panel/MenuButtons/SettingsButton.pressed.connect(_on_settings_button_pressed)
	$Panel/MenuButtons/MainMenuButton.pressed.connect(_on_main_menu_button_pressed)
	hide()


func show_pause() -> void:
	show()


func hide_pause() -> void:
	hide()


func _get_manager() -> Node:
	var managers := get_tree().get_nodes_in_group("game_manager")
	return managers[0] if managers.size() > 0 else null


func _on_resume_button_pressed() -> void:
	var manager := _get_manager()
	if manager != null and manager.has_method("resume_game"):
		manager.resume_game()


func _on_settings_button_pressed() -> void:
	var manager := _get_manager()
	if manager != null and manager.has_method("save_current_game"):
		manager.save_current_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")


func _on_main_menu_button_pressed() -> void:
	var manager := _get_manager()
	if manager != null and manager.has_method("save_current_game"):
		manager.save_current_game()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
