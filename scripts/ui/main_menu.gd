extends Control

## Menú principal "Finca Tica: Vida de Campo".
## Flujo: Continuar → slots con datos | Nueva → dificultad → slot (+ confirmación).

const GAME_SCENE := "res://scenes/levels/main.tscn"

@onready var _main_panel: PanelContainer = $Layout/VBox/MainPanel
@onready var _load_panel: PanelContainer = $Layout/VBox/LoadPanel
@onready var _difficulty_panel: PanelContainer = $Layout/VBox/DifficultyPanel
@onready var _slot_select_panel: PanelContainer = $Layout/VBox/SlotSelectPanel
@onready var _confirm_overwrite: Control = $ConfirmOverwrite
@onready var _load_slot_list: VBoxContainer = $Layout/VBox/LoadPanel/VBox/SlotList
@onready var _select_slot_list: VBoxContainer = $Layout/VBox/SlotSelectPanel/VBox/SlotList

var _pending_mode: int = SaveManager.MODE_NORMAL
var _pending_slot: int = 0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false

	$Layout/VBox/MainPanel/Buttons/ContinueButton.pressed.connect(_on_continue_pressed)
	$Layout/VBox/MainPanel/Buttons/NewGameButton.pressed.connect(_on_new_game_pressed)
	$Layout/VBox/LoadPanel/VBox/BackButton.pressed.connect(_show_main)
	$Layout/VBox/DifficultyPanel/VBox/BackButton.pressed.connect(_show_main)
	$Layout/VBox/SlotSelectPanel/VBox/BackButton.pressed.connect(_on_slot_select_back)
	$Layout/VBox/DifficultyPanel/VBox/EasyButton.pressed.connect(_on_difficulty_chosen.bind(SaveManager.MODE_EASY))
	$Layout/VBox/DifficultyPanel/VBox/NormalButton.pressed.connect(_on_difficulty_chosen.bind(SaveManager.MODE_NORMAL))
	$Layout/VBox/DifficultyPanel/VBox/HardButton.pressed.connect(_on_difficulty_chosen.bind(SaveManager.MODE_HARD))
	$ConfirmOverwrite/Panel/VBox/Buttons/YesButton.pressed.connect(_on_overwrite_confirmed)
	$ConfirmOverwrite/Panel/VBox/Buttons/CancelButton.pressed.connect(_on_overwrite_cancelled)

	_show_main()


## ─── Navegación entre paneles ────────────────────────────────────────────────

func _show_main() -> void:
	_main_panel.show()
	_load_panel.hide()
	_difficulty_panel.hide()
	_slot_select_panel.hide()
	_confirm_overwrite.hide()
	var has_any := false
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		if SaveManager.has_save(slot):
			has_any = true
			break
	var continue_button: Button = $Layout/VBox/MainPanel/Buttons/ContinueButton
	continue_button.disabled = not has_any
	if has_any:
		continue_button.grab_focus()
	else:
		$Layout/VBox/MainPanel/Buttons/NewGameButton.grab_focus()


func _on_continue_pressed() -> void:
	_main_panel.hide()
	_load_panel.show()
	_populate_slots(_load_slot_list, false)
	$Layout/VBox/LoadPanel/VBox/BackButton.grab_focus()


func _on_new_game_pressed() -> void:
	_main_panel.hide()
	_difficulty_panel.show()
	$Layout/VBox/DifficultyPanel/VBox/NormalButton.grab_focus()


func _on_difficulty_chosen(mode: int) -> void:
	_pending_mode = mode
	_difficulty_panel.hide()
	_slot_select_panel.show()
	_populate_slots(_select_slot_list, true)
	$Layout/VBox/SlotSelectPanel/VBox/BackButton.grab_focus()


func _on_slot_select_back() -> void:
	_slot_select_panel.hide()
	_difficulty_panel.show()


## ─── Slots ───────────────────────────────────────────────────────────────────

func _populate_slots(container: VBoxContainer, select_mode: bool) -> void:
	for child in container.get_children():
		child.queue_free()

	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var button := Button.new()
		button.custom_minimum_size = Vector2(520, 56)
		var meta := SaveManager.get_save_metadata(slot)
		if meta.is_empty():
			if select_mode:
				button.text = "Slot %d — Vacío" % slot
			else:
				button.text = "Slot %d — No hay partida guardada" % slot
				button.disabled = true
		else:
			button.text = "Slot %d — %s\nModo %s — Animales %d/10" % [
				slot,
				meta["saved_at"],
				meta["mode_name"],
				meta["animals_in_corral"],
			]
		if select_mode:
			button.pressed.connect(_on_new_game_slot_pressed.bind(slot))
		else:
			button.pressed.connect(_on_load_slot_pressed.bind(slot))
		container.add_child(button)


func _on_load_slot_pressed(slot: int) -> void:
	var data := SaveManager.load_game(slot)
	if data.is_empty():
		return
	SaveManager.active_slot = slot
	SaveManager.game_mode = int(data.get("game_mode", SaveManager.MODE_NORMAL))
	SaveManager.pending_save_data = data
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_new_game_slot_pressed(slot: int) -> void:
	if SaveManager.has_save(slot):
		_pending_slot = slot
		_confirm_overwrite.show()
		$ConfirmOverwrite/Panel/VBox/Buttons/CancelButton.grab_focus()
		return
	_start_new_game(slot)


func _on_overwrite_confirmed() -> void:
	_confirm_overwrite.hide()
	if _pending_slot > 0:
		_start_new_game(_pending_slot)


func _on_overwrite_cancelled() -> void:
	_pending_slot = 0
	_confirm_overwrite.hide()


func _start_new_game(slot: int) -> void:
	SaveManager.game_mode = _pending_mode
	SaveManager.active_slot = slot
	SaveManager.delete_save(slot)
	SaveManager.pending_save_data = {}
	get_tree().change_scene_to_file(GAME_SCENE)
