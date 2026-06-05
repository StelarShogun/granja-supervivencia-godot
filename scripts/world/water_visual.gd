extends Node3D

const WATER_SURFACE_Y := -3.2
const LAKE_CENTER      := Vector3(-150.347, WATER_SURFACE_Y, -144.866)
const LAKE_RADIUS_X    := 60.0
const LAKE_RADIUS_Z    := 44.0
const RIVER_WIDTH      := 8.0

const RIVER_POINTS := [
	Vector3(149.653,  98.0,  132.134),
	Vector3(119.653,  71.0,   95.134),
	Vector3( 81.653,  38.0,   48.134),
	Vector3( 33.653,  12.0,  -17.866),
	Vector3(-28.347,   4.0,  -57.866),
	Vector3(-78.347,  -4.0,  -89.866),
	Vector3(-112.347, -5.2, -117.866),
	Vector3(-150.347, -4.2, -144.866),
]

const BASE_MAT_PATH := "res://addons/boujie_water_shader/prefabs/deep_ocean_material.tres"


func _ready() -> void:
	_build_lake()
	_build_river()


func _build_lake() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Lake"
	mi.position = LAKE_CENTER

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var segments := 48
	var center := Vector3.ZERO

	for i in range(segments):
		var a0 := float(i) / segments * TAU
		var a1 := float(i + 1) / segments * TAU
		var v0 := Vector3(cos(a0) * LAKE_RADIUS_X, 0.0, sin(a0) * LAKE_RADIUS_Z)
		var v1 := Vector3(cos(a1) * LAKE_RADIUS_X, 0.0, sin(a1) * LAKE_RADIUS_Z)
		var uv_c := Vector2(0.5, 0.5)
		var uv0  := Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5)
		var uv1  := Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5)
		st.set_uv(uv_c); st.add_vertex(center)
		st.set_uv(uv0);  st.add_vertex(v0)
		st.set_uv(uv1);  st.add_vertex(v1)

	st.generate_normals()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := _load_mat()
	if mat:
		mat.set_shader_parameter("color_deep",   Color(0.05, 0.18, 0.45, 1.0))
		mat.set_shader_parameter("color_shallow", Color(0.10, 0.35, 0.55, 0.3))
		mat.set_shader_parameter("beers_law",     0.05)
		mat.set_shader_parameter("depth_offset",  -8.0)
		mat.set_shader_parameter("distance_fade_min",  100.0)
		mat.set_shader_parameter("distance_fade_max",  160.0)
		mat.set_shader_parameter("foam_fade_min",       50.0)
		mat.set_shader_parameter("foam_fade_max",      110.0)
		mat.set_shader_parameter("shore_fade_min",      50.0)
		mat.set_shader_parameter("shore_fade_max",      110.0)
		mat.set_shader_parameter("vertex_wave_fade_min",  60.0)
		mat.set_shader_parameter("vertex_wave_fade_max", 130.0)
		mat.set_shader_parameter("depth_fog_fade_min",   50.0)
		mat.set_shader_parameter("depth_fog_fade_max",  110.0)
		# Calmer waves for enclosed lake
		mat.set_shader_parameter("WaveAmplitudes",
			PackedFloat32Array([0.25, 0.002, 0.12, 0.08]))
		mi.material_override = mat

	add_child(mi)


func _build_river() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "River"

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var total_len := 0.0
	for i in range(len(RIVER_POINTS) - 1):
		total_len += RIVER_POINTS[i].distance_to(RIVER_POINTS[i + 1])

	var cum_len := 0.0
	for i in range(len(RIVER_POINTS) - 1):
		var p0: Vector3 = RIVER_POINTS[i]
		var p1: Vector3 = RIVER_POINTS[i + 1]
		var seg: float = p0.distance_to(p1)
		var dir: Vector3 = (Vector3(p1.x - p0.x, 0.0, p1.z - p0.z)).normalized()
		var perp: Vector3 = Vector3(-dir.z, 0.0, dir.x)
		var w: float = RIVER_WIDTH * 0.5
		var uv0: float = cum_len / total_len
		var uv1: float = (cum_len + seg) / total_len

		var a := Vector3(p0.x + perp.x * w, p0.y, p0.z + perp.z * w)
		var b := Vector3(p0.x - perp.x * w, p0.y, p0.z - perp.z * w)
		var c := Vector3(p1.x + perp.x * w, p1.y, p1.z + perp.z * w)
		var d := Vector3(p1.x - perp.x * w, p1.y, p1.z - perp.z * w)

		st.set_uv(Vector2(0.0, uv0)); st.add_vertex(a)
		st.set_uv(Vector2(1.0, uv0)); st.add_vertex(b)
		st.set_uv(Vector2(0.0, uv1)); st.add_vertex(c)

		st.set_uv(Vector2(1.0, uv0)); st.add_vertex(b)
		st.set_uv(Vector2(1.0, uv1)); st.add_vertex(d)
		st.set_uv(Vector2(0.0, uv1)); st.add_vertex(c)

		cum_len += seg

	st.generate_normals()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := _load_mat()
	if mat:
		mat.set_shader_parameter("color_deep",   Color(0.10, 0.30, 0.50, 1.0))
		mat.set_shader_parameter("color_shallow", Color(0.20, 0.50, 0.65, 0.4))
		mat.set_shader_parameter("beers_law",     0.08)
		mat.set_shader_parameter("depth_offset",  -3.0)
		mat.set_shader_parameter("distance_fade_min",  80.0)
		mat.set_shader_parameter("distance_fade_max", 160.0)
		mat.set_shader_parameter("foam_fade_min",      30.0)
		mat.set_shader_parameter("foam_fade_max",      80.0)
		mat.set_shader_parameter("shore_fade_min",     20.0)
		mat.set_shader_parameter("shore_fade_max",     60.0)
		mat.set_shader_parameter("vertex_wave_fade_min",  30.0)
		mat.set_shader_parameter("vertex_wave_fade_max",  80.0)
		mat.set_shader_parameter("depth_fog_fade_min",    30.0)
		mat.set_shader_parameter("depth_fog_fade_max",    80.0)
		# Minimal waves — river current feel
		mat.set_shader_parameter("WaveAmplitudes",
			PackedFloat32Array([0.05, 0.001, 0.03, 0.02]))
		mat.set_shader_parameter("WaveFrequencies",
			PackedFloat32Array([0.06, 3.0, 0.12, 0.12]))
		mi.material_override = mat

	add_child(mi)


func _load_mat() -> ShaderMaterial:
	var base := load(BASE_MAT_PATH) as ShaderMaterial
	if base == null:
		push_warning("water_visual.gd: cannot load boujie base material")
		return null
	return base.duplicate() as ShaderMaterial
