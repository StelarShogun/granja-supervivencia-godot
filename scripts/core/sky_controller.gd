extends Node
## Configures the Sky3D node at runtime.
##
## Sky3D builds its TimeOfDay, SkyDome, SunLight and MoonLight children when it
## is instantiated, so its property setters only take effect once those children
## exist. Setting the values from the scene file is unreliable (the setters run
## before the children are created and silently skip). This controller applies
## the desired configuration in _ready, after Sky3D has finished initializing,
## and keeps a light, controlled atmosphere instead of Sky3D's defaults.

@export var sky3d_path: NodePath = NodePath("../Sky3D")

## Real-world minutes for a full in-game day. 5 minutes keeps day and night
## visible during a short play session (the old cycle used 300 seconds).
@export var minutes_per_day: float = 5.0
## In-game hour to start at (0-24). Mid-morning reads clearly.
@export var start_time: float = 9.0
## Maximum sun light energy at midday.
@export var sun_energy: float = 1.2
## Maximum moon light energy at night so the night stays playable.
@export var moon_energy: float = 0.35

@export_group("Fog")
## Fog stays off by default. The previous runtime fog path could make the game
## camera look grey even when the editor viewport showed the sky correctly.
@export var fog_enabled: bool = false
@export var fog_density: float = 0.0
@export var fog_light_color: Color = Color(0.7, 0.78, 0.82)
@export var fog_light_energy: float = 0.2

var _fog_cleanup_frames: int = 8


func _ready() -> void:
	call_deferred("_apply_sky_config")


func _process(_delta: float) -> void:
	if _fog_cleanup_frames <= 0:
		return
	_fog_cleanup_frames -= 1
	var sky := get_node_or_null(sky3d_path)
	if sky != null:
		_disable_fog_meshes(sky)


func _apply_sky_config() -> void:
	var sky := get_node_or_null(sky3d_path)
	if sky == null:
		push_warning("SkyController: Sky3D node not found at %s" % sky3d_path)
		return

	sky.minutes_per_day = minutes_per_day
	sky.current_time = start_time
	sky.game_time_enabled = true
	sky.sun_energy = sun_energy
	sky.moon_energy = moon_energy

	# Disable Sky3D's screen-space fog and any generated fog mesh.
	sky.fog_enabled = false
	_disable_fog_meshes(sky)

	var env: Environment = sky.environment
	if env == null:
		return
	env.background_mode = Environment.BG_SKY
	env.fog_enabled = fog_enabled
	env.fog_density = fog_density
	env.fog_light_color = fog_light_color
	env.fog_light_energy = fog_light_energy
	env.volumetric_fog_enabled = false


func _disable_fog_meshes(root: Node) -> void:
	if root is Node3D:
		var node_name := str(root.name).to_lower()
		if node_name.contains("fog") or node_name.contains("neblina"):
			(root as Node3D).visible = false
	for child in root.get_children():
		_disable_fog_meshes(child)
