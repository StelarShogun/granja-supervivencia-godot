extends CanvasLayer

## Menú de pausa: continuar, guardar en el slot activo y volver al menú.
## Si no hay slot activo (caso anómalo), muestra selector de 5 slots.

@onready var _save_button: Button = $Panel/MenuButtons/SaveButton
@onready var _slot_list: VBoxContainer = $Panel/MenuButtons/SlotList
@onready var _feedback: Label = $Panel/MenuButtons/FeedbackLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/MenuButtons/ResumeButton.pressed.connect(_on_resume_button_pressed)
	_save_button.pressed.connect(_on_save_button_pressed)
	$Panel/MenuButtons/MainMenuButton.pressed.connect(_on_main_menu_button_pressed)
	hide()


func show_pause() -> void:
	_feedback.text = ""
	_slot_list.hide()
	show()
	$Panel/MenuButtons/ResumeButton.grab_focus()


func hide_pause() -> void:
	hide()


func _get_manager() -> Node:
	var managers := get_tree().get_nodes_in_group("game_manager")
	return managers[0] if managers.size() > 0 else null


func _on_resume_button_pressed() -> void:
	var manager := _get_manager()
	if manager != null and manager.has_method("resume_game"):
		manager.resume_game()


func _on_save_button_pressed() -> void:
	if SaveManager.active_slot >= 1 and SaveManager.active_slot <= SaveManager.SLOT_COUNT:
		_save_to_active_slot()
		return
	_show_slot_selector()


func _save_to_active_slot() -> void:
	var manager := _get_manager()
	if manager != null and manager.has_method("save_current_game"):
		manager.save_current_game()
		_feedback.text = "Partida guardada correctamente"
	else:
		_feedback.text = "No se pudo guardar la partida"


func _show_slot_selector() -> void:
	_feedback.text = "Elige un slot para guardar:"
	for child in _slot_list.get_children():
		child.queue_free()
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var button := Button.new()
		button.custom_minimum_size = Vector2(300, 40)
		var meta := SaveManager.get_save_metadata(slot)
		if meta.is_empty():
			button.text = "Slot %d — Vacío" % slot
		else:
			button.text = "Slot %d — %s (%s)" % [slot, meta["saved_at"], meta["mode_name"]]
		button.pressed.connect(_on_slot_chosen.bind(slot))
		_slot_list.add_child(button)
	_slot_list.show()


func _on_slot_chosen(slot: int) -> void:
	SaveManager.active_slot = slot
	_slot_list.hide()
	_save_to_active_slot()


func _on_main_menu_button_pressed() -> void:
	var manager := _get_manager()
	if manager != null and manager.has_method("save_current_game"):
		manager.save_current_game()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
