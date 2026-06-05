extends Node3D
## Low-poly inaccessible hills and forest backdrop around the playable map.

@export var map_center: Vector3 = Vector3.ZERO
@export var inner_radius: float = 235.0
@export var mid_radius: float = 310.0
@export var outer_radius: float = 390.0
@export var segment_count: int = 72
@export var hill_base_height: float = 4.0
@export var hill_amplitude: float = 16.0
@export var mountain_amplitude: float = 48.0
@export var visibility_end: float = 520.0

const HILL_COLOR := Color(0.16, 0.34, 0.14, 1.0)
const MOUNTAIN_COLOR := Color(0.22, 0.28, 0.18, 1.0)
const RIDGE_COLOR := Color(0.30, 0.26, 0.20, 1.0)


func _ready() -> void:
	_build_ring("Hills", inner_radius, mid_radius, hill_base_height, hill_amplitude, HILL_COLOR)
	_build_ring("Mountains", mid_radius, outer_radius, hill_base_height + 8.0, mountain_amplitude, MOUNTAIN_COLOR)
	_build_ridge_caps(outer_radius, mountain_amplitude * 0.55, RIDGE_COLOR)


func _build_ring(
	ring_name: String,
	radius_inner: float,
	radius_outer: float,
	base_h: float,
	amplitude: float,
	color: Color
) -> void:
	var mi := MeshInstance3D.new()
	mi.name = ring_name
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.visibility_range_end = visibility_end

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = maxi(segment_count, 12)

	for i in range(segs):
		var a0: float = float(i) / float(segs) * TAU
		var a1: float = float(i + 1) / float(segs) * TAU
		var h0_in: float = _height_at(a0, base_h, amplitude, 0.0)
		var h1_in: float = _height_at(a1, base_h, amplitude, 0.0)
		var h0_out: float = _height_at(a0, base_h, amplitude, 1.35)
		var h1_out: float = _height_at(a1, base_h, amplitude, 1.35)

		var in0 := map_center + Vector3(cos(a0) * radius_inner, h0_in, sin(a0) * radius_inner)
		var in1 := map_center + Vector3(cos(a1) * radius_inner, h1_in, sin(a1) * radius_inner)
		var out0 := map_center + Vector3(cos(a0) * radius_outer, h0_out, sin(a0) * radius_outer)
		var out1 := map_center + Vector3(cos(a1) * radius_outer, h1_out, sin(a1) * radius_outer)

		st.add_vertex(in0)
		st.add_vertex(out0)
		st.add_vertex(in1)

		st.add_vertex(in1)
		st.add_vertex(out0)
		st.add_vertex(out1)

	st.generate_normals()
	mi.mesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mi.material_override = mat

	add_child(mi)


func _build_ridge_caps(radius: float, amplitude: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "RidgeSilhouette"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.visibility_range_end = visibility_end

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = maxi(segment_count, 12)
	var ridge_w: float = 14.0

	for i in range(segs):
		if i % 5 != 0:
			continue
		var a: float = float(i) / float(segs) * TAU
		var peak_h: float = _height_at(a, hill_base_height + 14.0, amplitude, 2.0)
		var base_h: float = peak_h - amplitude * 0.65
		var dir := Vector3(cos(a), 0.0, sin(a))
		var perp := Vector3(-dir.z, 0.0, dir.x)
		var center := map_center + dir * radius

		var left := center + perp * ridge_w * 0.5
		var right := center - perp * ridge_w * 0.5
		var peak := center + Vector3(0.0, amplitude * 0.9, 0.0)
		left.y = base_h
		right.y = base_h
		peak.y = peak_h

		st.add_vertex(left)
		st.add_vertex(peak)
		st.add_vertex(right)

	st.generate_normals()
	mi.mesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.metallic = 0.0
	mi.material_override = mat

	add_child(mi)


func _height_at(angle: float, base_h: float, amplitude: float, layer: float) -> float:
	var w1: float = sin(angle * 3.0 + layer) * 0.55
	var w2: float = cos(angle * 5.0 - layer * 1.7) * 0.3
	var w3: float = sin(angle * 11.0 + layer * 0.4) * 0.15
	return base_h + amplitude * (w1 + w2 + w3)
