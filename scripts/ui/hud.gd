extends CanvasLayer

var _alert_token: int = 0
var _objective_pinned: bool = false
var _has_temp_message: bool = false

@onready var _health_bar: ProgressBar = $TopLeft/HealthContent/HealthBar
@onready var _label_animals: Label = $TopRight/ObjectivePanel/Content/AnimalRow/LabelAnimals
@onready var _label_progress: Label = $TopRight/ObjectivePanel/Content/LabelProgress
@onready var _label_message: Label = $MessagePanel/LabelMessage
@onready var _center_alert: PanelContainer = $CenterAlert
@onready var _label_alert: Label = $CenterAlert/LabelAlert
@onready var _oxygen_panel: PanelContainer = $OxygenPanel
@onready var _oxygen_bar: ProgressBar = $OxygenPanel/OxygenContent/OxygenBar
@onready var _message_panel: PanelContainer = $MessagePanel


func _ready() -> void:
	_center_alert.hide()
	_oxygen_panel.hide()
	_message_panel.hide()
	set_health(100.0, 100.0)
	set_animals(0, 10)
	set_progress(1)
	set_oxygen(100.0, 100.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F and event.pressed and not event.echo:
		_objective_pinned = not _objective_pinned
		if not _has_temp_message:
			_message_panel.visible = _objective_pinned
		get_viewport().set_input_as_handled()


func set_health(value: float, max_value: float) -> void:
	if _health_bar == null:
		return
	_health_bar.max_value = maxf(max_value, 1.0)
	_health_bar.value = clampf(value, 0.0, _health_bar.max_value)


func set_lives(value: int) -> void:
	set_health(float(value) * (100.0 / 3.0), 100.0)


func set_animals(value: int, goal: int) -> void:
	_label_animals.text = "Animales %d / %d" % [value, goal]


func set_progress(value: int) -> void:
	_label_progress.text = "Progresión %d / 3" % value


func set_message(text: String) -> void:
	_label_message.text = text
	_has_temp_message = true
	_message_panel.show()


func show_objective(text: String) -> void:
	_label_message.text = text
	_has_temp_message = false
	_message_panel.visible = _objective_pinned


func set_oxygen(value: float, max_value: float) -> void:
	_ensure_oxygen_refs()
	if _oxygen_bar == null:
		return
	_oxygen_bar.max_value = maxf(max_value, 1.0)
	_oxygen_bar.value = clampf(value, 0.0, _oxygen_bar.max_value)


func show_oxygen_bar(is_visible: bool) -> void:
	_ensure_oxygen_refs()
	if _oxygen_panel == null:
		return
	_oxygen_panel.visible = is_visible


func show_center_alert(text: String, seconds: float = 4.0) -> void:
	_alert_token += 1
	var token := _alert_token
	_label_alert.text = text
	_center_alert.modulate.a = 1.0
	_center_alert.show()
	await get_tree().create_timer(seconds).timeout
	if token == _alert_token:
		_center_alert.hide()


func _ensure_oxygen_refs() -> void:
	if _oxygen_panel == null:
		_oxygen_panel = get_node_or_null("OxygenPanel") as PanelContainer
	if _oxygen_bar == null:
		_oxygen_bar = get_node_or_null("OxygenPanel/OxygenContent/OxygenBar") as ProgressBar
