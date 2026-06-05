@tool
extends Node3D
## Builds the river water surface as a continuous channel-fitted ribbon.
##
## The carved riverbed and banks come from the imported terrain; this generator
## only produces the *water*. It is sampled per cross-section so the surface can
## change width along the course, flare open where the river meets the lake, and
## drop to the lake surface level at the mouth so the two water bodies blend
## without a visible seam. The depth-fade water material hides the bed in the
## deep centre while the banks read shallow.

@export var river_width: float = 9.0:
	set(value):
		river_width = maxf(value, 0.5)
		_request_generate()
@export var mouth_width: float = 32.0:
	set(value):
		mouth_width = maxf(value, river_width)
		_request_generate()
## Normalised distance along the course (0..1) where the channel starts flaring
## open toward the lake.
@export_range(0.0, 1.0, 0.01) var flare_start: float = 0.74:
	set(value):
		flare_start = clampf(value, 0.0, 0.99)
		_request_generate()
## Vertices across the channel = cross_segments + 1. More segments give the
## flared mouth a smoother low-poly fan.
@export_range(1, 8, 1) var cross_segments: int = 4:
	set(value):
		cross_segments = maxi(value, 1)
		_request_generate()
@export var flow_speed: float = 0.18
@export var uv_flow_scale: float = 0.08:
	set(value):
		uv_flow_scale = maxf(value, 0.001)
		_request_generate()
@export var bank_margin: float = 0.35:
	set(value):
		bank_margin = maxf(value, 0.0)
		_request_generate()
## Water level of the lake. The mouth blends the river surface up/down to this.
@export var lake_surface_y: float = -3.2:
	set(value):
		lake_surface_y = value
		_request_generate()
## Distance the mouth is pushed past the last path point, into the lake, so the
## river water overlaps the lake disc and hides the join.
@export var mouth_overlap: float = 12.0:
	set(value):
		mouth_overlap = maxf(value, 0.0)
		_request_generate()
@export var path_node_path: NodePath = NodePath("RiverPath")
@export var mesh_node_path: NodePath = NodePath("RiverMesh")
@export var river_points: PackedVector3Array = PackedVector3Array([
	Vector3(149.653, 98.0, 132.134),
	Vector3(119.653, 71.0, 95.134),
	Vector3(81.653, 38.0, 48.134),
	Vector3(33.653, 12.0, -17.866),
	Vector3(-28.347, 4.0, -57.866),
	Vector3(-78.347, -4.0, -89.866),
	Vector3(-112.347, -5.2, -117.866),
	Vector3(-150.347, -4.2, -144.866),
])
@export var river_material: Material:
	set(value):
		river_material = value
		_apply_material()
@export var update_in_editor: bool = true
@export var regenerate_now: bool:
	get:
		return false
	set(value):
		if value:
			_request_generate()

var _regen_pending: bool = false


func _ready() -> void:
	call_deferred("generate")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_request_generate()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and update_in_editor and _regen_pending:
		_regen_pending = false
		generate()


func generate() -> void:
	var path := get_node_or_null(path_node_path) as Path3D
	var mesh_node := get_node_or_null(mesh_node_path) as MeshInstance3D
	if path == null or mesh_node == null:
		return

	if (path.curve == null or path.curve.point_count <= 0) and river_points.size() >= 2:
		path.curve = _build_curve_from_points(river_points)

	var points := _get_path_points(path.curve)
	if points.size() < 2:
		mesh_node.mesh = null
		return

	# Append an extra point pushed into the lake so the water overlaps the disc.
	if mouth_overlap > 0.0:
		var last := points[points.size() - 1]
		var dir := (last - points[points.size() - 2]).normalized()
		points.append(last + dir * mouth_overlap)

	# Cumulative distance for flow UVs and the normalised flare/blend factor.
	var cum := PackedFloat32Array()
	cum.resize(points.size())
	cum[0] = 0.0
	for i in range(1, points.size()):
		cum[i] = cum[i - 1] + points[i].distance_to(points[i - 1])
	var total := maxf(cum[cum.size() - 1], 0.001)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var ring_verts := cross_segments + 1

	for i in points.size():
		var point := points[i]
		var t := cum[i] / total
		var flare := smoothstep(flare_start, 1.0, t)
		var width := lerpf(river_width, mouth_width, flare)
		var half := maxf(0.25, width * 0.5 - bank_margin)

		# Blend the surface height to the lake level over the final stretch so
		# the mouth shares the lake's water plane.
		var blend := smoothstep(0.86, 1.0, t)
		var surface_y := lerpf(point.y, lake_surface_y, blend)

		var tangent := _point_tangent(points, i)
		var side := Vector3(-tangent.z, 0.0, tangent.x).normalized()
		if side.length_squared() < 0.001:
			side = Vector3.RIGHT

		for j in ring_verts:
			var f := float(j) / float(cross_segments)
			var offset := lerpf(-half, half, f)
			vertices.append(Vector3(point.x + side.x * offset, surface_y, point.z + side.z * offset))
			normals.append(Vector3.UP)
			uvs.append(Vector2(f, cum[i] * uv_flow_scale))

	for i in points.size() - 1:
		var base := i * ring_verts
		var next := (i + 1) * ring_verts
		for j in cross_segments:
			indices.append(base + j)
			indices.append(base + j + 1)
			indices.append(next + j)
			indices.append(base + j + 1)
			indices.append(next + j + 1)
			indices.append(next + j)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_node.mesh = mesh
	_apply_material()


func _get_path_points(curve: Curve3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	if curve == null:
		return points
	if curve.point_count <= 0:
		return points

	var baked := curve.get_baked_points()
	if baked.size() >= 2:
		for point in baked:
			points.append(point)
		return points

	for i in curve.point_count:
		points.append(curve.get_point_position(i))
	return points


func _build_curve_from_points(points: PackedVector3Array) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 2.0
	for point in points:
		curve.add_point(point)
	return curve


func _point_tangent(points: PackedVector3Array, index: int) -> Vector3:
	if index <= 0:
		return (points[1] - points[0]).normalized()
	if index >= points.size() - 1:
		return (points[index] - points[index - 1]).normalized()
	return (points[index + 1] - points[index - 1]).normalized()


func _request_generate() -> void:
	if not is_inside_tree():
		return
	if Engine.is_editor_hint():
		_regen_pending = true
		call_deferred("generate")
	else:
		generate()


func _apply_material() -> void:
	var mesh_node := get_node_or_null(mesh_node_path) as MeshInstance3D
	if mesh_node != null and river_material != null:
		mesh_node.material_override = river_material
