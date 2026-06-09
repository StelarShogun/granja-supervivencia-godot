extends Node

## Sistema de guardado con 5 slots (user://save_slot_N.save, JSON).
## El slot activo se fija al iniciar/cargar partida y lo usan el
## autoguardado y el guardado manual desde pausa.

const SLOT_COUNT := 5
const SLOT_PATH := "user://save_slot_%d.save"
const LEGACY_PATH := "user://savegame.json"

const MODE_NORMAL := 0
const MODE_HARD := 1
const MODE_EASY := 2

const MODE_NAMES := {
	MODE_NORMAL: "Normal",
	MODE_HARD: "Difícil",
	MODE_EASY: "Fácil",
}

## 0 = Normal, 1 = Difícil, 2 = Fácil (0/1 preservan los saves antiguos).
static var game_mode: int = MODE_NORMAL

## Slot en uso por la partida actual (1..5). 0 = sin slot activo.
var active_slot: int = 0

var pending_save_data: Dictionary = {}


static func mode_name(mode: int) -> String:
	return MODE_NAMES.get(mode, "Normal")


func slot_path(slot_id: int) -> String:
	return SLOT_PATH % slot_id


func has_save(slot_id: int) -> bool:
	if slot_id < 1 or slot_id > SLOT_COUNT:
		return false
	return FileAccess.file_exists(slot_path(slot_id))


## Guarda en el slot activo. Añade metadata (slot_id, fecha, escena).
func save_game(data: Dictionary) -> void:
	if active_slot < 1 or active_slot > SLOT_COUNT:
		push_warning("SaveManager: sin slot activo, no se guardó la partida")
		return
	save_to_slot(active_slot, data)


func save_to_slot(slot_id: int, data: Dictionary) -> void:
	if slot_id < 1 or slot_id > SLOT_COUNT:
		push_warning("SaveManager: slot inválido %d" % slot_id)
		return
	var payload := data.duplicate(true)
	payload["slot_id"] = slot_id
	payload["saved_at"] = Time.get_datetime_string_from_system(false, true)
	payload["scene"] = "res://scenes/levels/main.tscn"
	if not payload.has("game_mode"):
		payload["game_mode"] = game_mode

	var file := FileAccess.open(slot_path(slot_id), FileAccess.WRITE)
	if file == null:
		push_warning("No se pudo guardar partida en %s" % slot_path(slot_id))
		return
	file.store_string(JSON.stringify(payload))
	file.close()


func load_game(slot_id: int) -> Dictionary:
	if not has_save(slot_id):
		return {}
	var file := FileAccess.open(slot_path(slot_id), FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


## Metadata ligera para mostrar en los menús de slots.
func get_save_metadata(slot_id: int) -> Dictionary:
	var data := load_game(slot_id)
	if data.is_empty():
		return {}
	return {
		"slot_id": slot_id,
		"saved_at": str(data.get("saved_at", "—")),
		"game_mode": int(data.get("game_mode", MODE_NORMAL)),
		"mode_name": mode_name(int(data.get("game_mode", MODE_NORMAL))),
		"animals_in_corral": int(data.get("animals_in_corral", 0)),
		"current_progress": int(data.get("current_progress", 1)),
	}


func delete_save(slot_id: int) -> void:
	if slot_id < 1 or slot_id > SLOT_COUNT:
		return
	var dir := DirAccess.open("user://")
	var file_name := slot_path(slot_id).trim_prefix("user://")
	if dir != null and dir.file_exists(file_name):
		dir.remove(file_name)


## Migra el guardado antiguo de archivo único al Slot 1 (una sola vez).
func _ready() -> void:
	if not FileAccess.file_exists(LEGACY_PATH) or has_save(1):
		return
	var file := FileAccess.open(LEGACY_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and not (parsed as Dictionary).is_empty():
		save_to_slot(1, parsed)
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove(LEGACY_PATH)
