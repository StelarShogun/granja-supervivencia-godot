extends CanvasLayer

signal restart_requested
signal quit_requested

@onready var _panel: PanelContainer = $Panel
@onready var _label_title: Label = $Panel/VBox/LabelTitle
@onready var _label_sub: Label = $Panel/VBox/LabelSub
@onready var _btn_restart: Button = $Panel/VBox/BtnRestart
@onready var _btn_quit: Button = $Panel/VBox/BtnQuit


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_btn_restart.pressed.connect(_on_restart)
	_btn_quit.pressed.connect(_on_quit)


func show_victory(animals: int) -> void:
	_label_title.text = "¡Victoria!"
	_label_sub.text = "%d animales reunidos en el corral.\n¡Completaste el nivel!" % animals
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_restart() -> void:
	get_tree().paused = false
	hide()
	restart_requested.emit()
	get_tree().reload_current_scene()


func _on_quit() -> void:
	get_tree().paused = false
	quit_requested.emit()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
