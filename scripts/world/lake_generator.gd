@tool
extends Node3D

@export var mesh_node_path: NodePath = NodePath("LakeWaterMesh")
@export var lake_material: Material:
	set(value):
		lake_material = value
		_apply_material()
@export var center: Vector3 = Vector3(-150.347, -3.2, -144.866):
	set(value):
		center = value
		_request_generate()
@export var radius_x: float = 47.0:
	set(value):
		radius_x = maxf(value, 1.0)
		_request_generate()
@export var radius_z: float = 31.0:
	set(value):
		radius_z = maxf(value, 1.0)
		_request_generate()
@export var surface_y: float = -3.2:
	set(value):
		surface_y = value
		center.y = value
		_request_generate()
@export var shoreline_points: int = 34:
	set(value):
		shoreline_points = maxi(value, 8)
		_request_generate()
@export var wobble: float = 0.16:
	set(value):
		wobble = clampf(value, 0.0, 0.45)
		_request_generate()
@export var update_in_editor: bool = true
@export var regenerate_now: bool:
	get:
		return false
	set(value):
		if value:
			_request_generate()

var _regen_pending: bool = false


func _ready() -> void:
	center.y = surface_y
	call_deferred("generate")


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and update_in_editor and _regen_pending:
		_regen_pending = false
		generate()


func generate() -> void:
	var mesh_node := get_node_or_null(mesh_node_path) as MeshInstance3D
	if mesh_node == null:
		return

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	vertices.append(Vector3(center.x, surface_y, center.z))
	normals.append(Vector3.UP)
	uvs.append(Vector2(0.5, 0.5))

	for i in shoreline_points:
		var t := TAU * float(i) / float(shoreline_points)
		var irregular := 1.0 + sin(t * 3.0 + 0.4) * wobble + cos(t * 5.0 - 0.7) * wobble * 0.55
		var x := center.x + cos(t) * radius_x * irregular
		var z := center.z + sin(t) * radius_z * (1.0 + cos(t * 4.0) * wobble * 0.45)
		vertices.append(Vector3(x, surface_y, z))
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.5 + cos(t) * 0.5 * irregular, 0.5 + sin(t) * 0.5))

	for i in shoreline_points:
		var current := i + 1
		var next := 1 if i == shoreline_points - 1 else current + 1
		indices.append(0)
		indices.append(current)
		indices.append(next)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_node.mesh = mesh
	_apply_material()


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
	if mesh_node != null and lake_material != null:
		mesh_node.material_override = lake_material
