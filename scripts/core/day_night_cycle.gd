extends Node

@export var day_length_seconds: float = 300.0
@export var sun_light_path: NodePath = NodePath("../SunLight")
@export var world_environment_path: NodePath = NodePath("../WorldEnvironment")
@export_range(0.0, 1.0, 0.001) var time_of_day: float = 0.28

var running: bool = true


func _process(delta: float) -> void:
	if not running or day_length_seconds <= 0.0:
		return

	time_of_day = fposmod(time_of_day + delta / day_length_seconds, 1.0)
	_apply_time_of_day()


func _apply_time_of_day() -> void:
	var sun := get_node_or_null(sun_light_path) as DirectionalLight3D
	var world_environment := get_node_or_null(world_environment_path) as WorldEnvironment
	var daylight := clampf(sin(time_of_day * TAU), 0.0, 1.0)
	var dusk := clampf(1.0 - abs(time_of_day - 0.72) * 8.0, 0.0, 1.0)

	if sun != null:
		sun.rotation_degrees.x = lerpf(-15.0, -175.0, time_of_day)
		sun.rotation_degrees.y = -35.0
		sun.light_energy = lerpf(0.32, 1.35, daylight)
		sun.light_color = Color(1.0, 0.92 - dusk * 0.18, 0.78 - dusk * 0.28).lerp(Color(0.56, 0.66, 0.92), 1.0 - daylight)

	if world_environment != null and world_environment.environment != null:
		var env := world_environment.environment
		env.ambient_light_energy = lerpf(0.28, 0.72, daylight)
		env.ambient_light_color = Color(0.34, 0.42, 0.56).lerp(Color(0.75, 0.82, 0.68), daylight)
