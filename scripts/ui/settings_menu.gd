extends Control

const SETTINGS_PATH := "user://settings.json"
const DEFAULT_KEYS := {
	"move_forward": KEY_W,
	"move_backward": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"run": KEY_SHIFT,
	"interact": KEY_E,
	"pause": KEY_ESCAPE,
}
const ACTION_NAMES := {
	"move_forward": "Avanzar",
	"move_backward": "Retroceder",
	"move_left": "Izquierda",
	"move_right": "Derecha",
	"run": "Correr",
	"interact": "Interactuar",
	"pause": "Pausa",
}

var _waiting_action: String = ""
var _action_buttons: Dictionary = {}
var _volume: float = 0.8

@onready var _volume_slider: HSlider = $Panel/Content/AudioRow/VolumeSlider
@onready var _waiting_label: Label = $Panel/Content/WaitingLabel


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_volume_slider.value_changed.connect(_on_volume_slider_value_changed)
	$Panel/Content/ButtonRow/ResetButton.pressed.connect(_on_reset_button_pressed)
	$Panel/Content/ButtonRow/BackButton.pressed.connect(_on_back_button_pressed)
	_collect_action_buttons()
	load_settings()
	_refresh_action_labels()


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_action.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_set_action_key(_waiting_action, event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)
		_waiting_action = ""
		_waiting_label.text = "Tecla reasignada."
		save_settings()
		get_viewport().set_input_as_handled()


func save_settings() -> void:
	var data := {
		"volume": _volume_slider.value,
		"keys": _current_key_settings(),
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()


func load_settings() -> void:
	var data := {}
	if FileAccess.file_exists(SETTINGS_PATH):
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				data = parsed

	_volume = float(data.get("volume", 0.8))
	_volume_slider.value = _volume

	var keys: Dictionary = data.get("keys", {})
	for action in DEFAULT_KEYS:
		var keycode := int(keys.get(action, DEFAULT_KEYS[action]))
		_set_action_key(action, keycode)

	apply_settings()


func apply_settings() -> void:
	_volume = float(_volume_slider.value)
	AudioManager.apply_master_volume(_volume)
	_refresh_action_labels()


func _collect_action_buttons() -> void:
	for action in DEFAULT_KEYS:
		var button := get_node("Panel/Content/ControlsGrid/%sButton" % action) as Button
		if button != null:
			_action_buttons[action] = button
			button.pressed.connect(_start_rebind.bind(action))


func _start_rebind(action: String) -> void:
	_waiting_action = action
	_waiting_label.text = "Presiona una tecla para %s..." % ACTION_NAMES[action]


func _set_action_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)
	_refresh_action_labels()


func _current_key_settings() -> Dictionary:
	var keys := {}
	for action in DEFAULT_KEYS:
		var keycode: int = int(DEFAULT_KEYS[action])
		var events := InputMap.action_get_events(action)
		for event in events:
			if event is InputEventKey:
				keycode = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
				break
		keys[action] = keycode
	return keys


func _refresh_action_labels() -> void:
	for action in _action_buttons:
		var button := _action_buttons[action] as Button
		var keycode := int(_current_key_settings().get(action, DEFAULT_KEYS[action]))
		button.text = "%s: %s" % [ACTION_NAMES[action], OS.get_keycode_string(keycode)]


func _on_volume_slider_value_changed(value: float) -> void:
	_volume = value
	apply_settings()
	save_settings()


func _on_reset_button_pressed() -> void:
	for action in DEFAULT_KEYS:
		_set_action_key(action, DEFAULT_KEYS[action])
	_waiting_label.text = "Controles restaurados."
	save_settings()


func _on_back_button_pressed() -> void:
	save_settings()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
