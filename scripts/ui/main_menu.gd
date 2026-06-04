extends Control

@onready var _continue_button: Button = $Panel/MenuButtons/ContinueButton
@onready var _message_label: Label = $Panel/MessageLabel


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_continue_button.disabled = not SaveManager.has_save()
	$Panel/MenuButtons/NewGameButton.pressed.connect(_on_new_game_button_pressed)
	$Panel/MenuButtons/ContinueButton.pressed.connect(_on_continue_button_pressed)
	$Panel/MenuButtons/SettingsButton.pressed.connect(_on_settings_button_pressed)
	$Panel/MenuButtons/QuitButton.pressed.connect(_on_quit_button_pressed)


func _on_new_game_button_pressed() -> void:
	SaveManager.delete_save()
	SaveManager.pending_save_data = {}
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")


func _on_continue_button_pressed() -> void:
	if not SaveManager.has_save():
		_message_label.text = "No hay partida guardada."
		_continue_button.disabled = true
		return

	SaveManager.pending_save_data = SaveManager.load_game()
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")


func _on_settings_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
