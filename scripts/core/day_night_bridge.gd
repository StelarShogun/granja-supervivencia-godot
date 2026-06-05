extends Node
## Exposes Sky3D TimeOfDay as day_night_cycle for Diablo and spawn logic.

@export var time_of_day_node_path: NodePath = NodePath("../Sky3D/TimeOfDay")
@export_range(0.0, 24.0, 0.01) var day_start_hour: float = 6.0

var time_of_day: float = 0.28


func _ready() -> void:
	add_to_group("day_night_cycle")


func _process(_delta: float) -> void:
	var tod := get_node_or_null(time_of_day_node_path)
	if tod == null:
		return
	var hours: float = float(tod.get("current_time"))
	time_of_day = fposmod((hours - day_start_hour) / 24.0, 1.0)
