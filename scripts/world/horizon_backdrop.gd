@tool
extends Node3D

## Distant low-poly horizon: layered ridge "curtains" of forest and mountains
## ringing the play area so the world reads as continuing past the map walls.
## Pure geometry + vertex colors, no external textures, no collision. Built once
## in _ready (and live in the editor via @tool). Lit by the scene's sun, so it
## darkens with the Sky3D day/night cycle on its own.
##
## Each layer is a closed ring wall facing inward; stacking three rings at
## growing radius/height gives parallax depth from the central viewpoint.

@export var rebuild: bool = false:
	set(value):
		if value:
			_build()

## segments around the full circle (more = smoother ridgeline)
@export_range(48, 360, 1) var segments: int = 180
@export var base_y: float = -6.0
@export var noise_seed: int = 7

## Per layer: radius, valley/peak height, noise freq, peak sharpness, colors.
const LAYERS := [
	# mid forested hills — sharp peaks with deep valleys (sky shows through)
	{"r": 700.0, "h0": 2.0, "h1": 230.0, "freq": 5.0, "sharp": 2.6,
		"c0": Color(0.13, 0.22, 0.16), "c1": Color(0.28, 0.40, 0.32)},
	# far mountains — taller, bluer, fade into fog/sky between the near peaks
	{"r": 1080.0, "h0": 6.0, "h1": 330.0, "freq": 3.2, "sharp": 2.8,
		"c0": Color(0.38, 0.46, 0.56), "c1": Color(0.52, 0.60, 0.70)},
]


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()

	var rng := RandomNumberGenerator.new()
	var layer_index := 0
	for layer in LAYERS:
		var noise := FastNoiseLite.new()
		noise.seed = seed + layer_index * 31
		noise.frequency = 0.01
		noise.fractal_octaves = 4
		_build_ring(layer, noise, rng, layer_index)
		layer_index += 1


func _build_ring(layer: Dictionary, noise: FastNoiseLite, _rng: RandomNumberGenerator,
		index: int) -> void:
	var radius: float = layer["r"]
	var h0: float = layer["h0"]
	var h1: float = layer["h1"]
	var freq: float = layer["freq"]
	var sharp: float = layer["sharp"]
	var c0: Color = layer["c0"]
	var c1: Color = layer["c1"]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var heights := PackedFloat32Array()
	heights.resize(segments + 1)
	for i in segments + 1:
		var ang := float(i) / float(segments) * TAU
		# three-band ridged noise: broad ranges, medium peaks, fine jitter
		var broad := noise.get_noise_2d(cos(ang) * freq, sin(ang) * freq) * 0.5 + 0.5
		var med := noise.get_noise_2d(cos(ang) * freq * 3.0, sin(ang) * freq * 3.0) * 0.5 + 0.5
		var fine := noise.get_noise_2d(cos(ang) * freq * 7.0, sin(ang) * freq * 7.0) * 0.5 + 0.5
		var t := clampf(broad * 0.6 + med * 0.3 + fine * 0.1, 0.0, 1.0)
		# sharpen so peaks spike and valleys sink toward the fog line
		t = pow(t, sharp)
		heights[i] = lerpf(h0, h1, t)
	heights[segments] = heights[0]

	for i in segments:
		var a0 := float(i) / float(segments) * TAU
		var a1 := float(i + 1) / float(segments) * TAU
		var p0b := Vector3(cos(a0) * radius, base_y, sin(a0) * radius)
		var p1b := Vector3(cos(a1) * radius, base_y, sin(a1) * radius)
		var p0t := Vector3(cos(a0) * radius, base_y + heights[i], sin(a0) * radius)
		var p1t := Vector3(cos(a1) * radius, base_y + heights[i + 1], sin(a1) * radius)
		# inward-facing quad (two triangles), color gradient bottom->top
		_tri(st, p0b, c0, p0t, c1, p1t, c1)
		_tri(st, p0b, c0, p1t, c1, p1b, c0)

	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "HorizonLayer_%d" % index
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)
	if Engine.is_editor_hint() and get_tree() != null:
		mi.owner = get_tree().edited_scene_root


func _tri(st: SurfaceTool, a: Vector3, ca: Color, b: Vector3, cb: Color,
		c: Vector3, cc: Color) -> void:
	st.set_color(ca); st.add_vertex(a)
	st.set_color(cb); st.add_vertex(b)
	st.set_color(cc); st.add_vertex(c)
