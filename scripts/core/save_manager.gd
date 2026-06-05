extends Node

const SAVE_PATH := "user://savegame.json"

## 0 = Normal, 1 = Modo difícil
static var game_mode: int = 0

var pending_save_data: Dictionary = {}


func save_game(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudo guardar partida en %s" % SAVE_PATH)
		return

	file.store_string(JSON.stringify(data))
	file.close()


func load_game() -> Dictionary:
	if not has_save():
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("savegame.json"):
		dir.remove("savegame.json")
	pending_save_data = {}
