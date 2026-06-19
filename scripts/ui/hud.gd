extends CanvasLayer

var _alert_token: int = 0
var _objective_pinned: bool = false
var _has_temp_message: bool = false

@onready var _health_bar: ProgressBar = $HealthPanel/HealthContent/HealthRow/HealthBar
@onready var _health_value: Label = $HealthPanel/HealthContent/HealthRow/LabelHealthValue
@onready var _label_animals: Label = $ObjectivePanel/Content/AnimalRow/LabelAnimals
@onready var _label_progress: Label = $ObjectivePanel/Content/LabelProgress
@onready var _label_machete: Label = $ObjectivePanel/Content/LabelMachete
@onready var _label_message: Label = $MessagePanel/LabelMessage
@onready var _message_panel: PanelContainer = $MessagePanel
@onready var _center_alert: PanelContainer = $CenterAlert
@onready var _label_alert: Label = $CenterAlert/LabelAlert
@onready var _interact_prompt: Label = $InteractPrompt


func _ready() -> void:
	_center_alert.hide()
	_message_panel.hide()
	_interact_prompt.hide()
	set_health(100.0, 100.0)
	set_animals(0, 10)
	set_progress(1)
	set_machete(false)


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
	if _health_value != null:
		_health_value.text = "%d" % int(round(_health_bar.value))


func set_lives(value: int) -> void:
	set_health(float(value) * (100.0 / 3.0), 100.0)


func set_animals(value: int, goal: int) -> void:
	_label_animals.text = "Animales %d / %d" % [value, goal]


func set_progress(value: int, total: int = 3) -> void:
	_label_progress.text = "Nivel %d / %d" % [value, total]


## Refleja si el jugador ya tiene el machete del fondo del cráter.
func set_machete(equipped: bool) -> void:
	if _label_machete == null:
		return
	if equipped:
		_label_machete.text = "Machete: listo"
		_label_machete.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6, 1.0))
	else:
		_label_machete.text = "Machete: en el cráter"
		_label_machete.add_theme_color_override("font_color", Color(0.78, 0.78, 0.8, 1.0))


func set_message(text: String) -> void:
	_label_message.text = text
	_has_temp_message = true
	_message_panel.show()


func show_objective(text: String) -> void:
	_label_message.text = text
	_has_temp_message = false
	_message_panel.visible = _objective_pinned


## Pista contextual de interacción (p.ej. "Presiona E para tomar el machete").
## Se muestra solo mientras el jugador está en rango de un interactuable.
func show_interact_prompt(text: String) -> void:
	if _interact_prompt == null:
		return
	_interact_prompt.text = text
	_interact_prompt.show()


func hide_interact_prompt() -> void:
	if _interact_prompt != null:
		_interact_prompt.hide()


func show_center_alert(text: String, seconds: float = 4.0) -> void:
	_alert_token += 1
	var token := _alert_token
	_label_alert.text = text
	_center_alert.modulate.a = 1.0
	_center_alert.show()
	await get_tree().create_timer(seconds).timeout
	if token == _alert_token:
		_center_alert.hide()
