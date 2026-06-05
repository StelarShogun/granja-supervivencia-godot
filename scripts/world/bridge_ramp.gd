extends Node3D
## Builds a walkable ramp at the finca (south, -Z) approach of Bridge_01.
##
## The deck sits on pilings ~7 m above the finca ground (deck top ~17.7, ground
## ~11), so the player cannot climb onto the bridge from the finca side. At
## runtime (when collision exists) this raycasts the deck top just inside the
## south edge and the terrain further south, then generates a sloped ramp mesh
## + trimesh collision bridging the gap. The slope is kept under the player's
## floor_max_angle (45 deg) so it is walkable in both directions.

@export var deck_x: float = 24.0
## Z just inside the deck's south edge (deck top spans z ~-22..+2).
@export var deck_edge_z: float = -21.0
## How far south (-Z) the ramp reaches to meet the finca ground.
@export var ramp_length: float = 14.0
@export var ramp_width: float = 14.0
@export var terrain_mask: int = 2
@export var start_delay: float = 0.8
@export var ramp_color: Color = Color(0.45, 0.34, 0.22, 1.0)
@export var enabled: bool = true
## When true, only dump a height profile along the bridge axis and skip building.
@export var debug_profile: bool = false


func _ready() -> void:
	if not enabled:
		return
	await get_tree().create_timer(start_delay).timeout
	if debug_profile:
		_dump_profile()
		return
	build()


func _dump_profile() -> void:
	var s := ""
	for zi in range(-32, 24, 2):
		var y := _ray_down(Vector3(deck_x, 80.0, float(zi)))
		s += "z%d=%s " % [zi, ("nan" if is_nan(y) else "%.1f" % y)]
	print("[BridgeRamp] x=%.0f profile: %s" % [deck_x, s])


func build() -> void:
	# Near edge sits on the deck top; far edge drops south (-Z) to finca ground.
	var z0 := deck_edge_z
	var z1 := deck_edge_z - ramp_length
	var deck_y := _ray_down(Vector3(deck_x, 50.0, z0))
	var ground_y := _ray_down(Vector3(deck_x, 60.0, z1))
	if is_nan(deck_y) or is_nan(ground_y):
		push_warning("BridgeRamp: could not probe deck (%s) or ground (%s)" % [deck_y, ground_y])
		return
	print("[BridgeRamp] deck_y=%.2f ground_y=%.2f gap=%.2f" % [deck_y, ground_y, deck_y - ground_y])

	var hw := ramp_width * 0.5
	# Quad: near edge at deck height, far edge at ground height.
	var verts := PackedVector3Array([
		Vector3(deck_x - hw, deck_y, z0),
		Vector3(deck_x + hw, deck_y, z0),
		Vector3(deck_x + hw, ground_y, z1),
		Vector3(deck_x - hw, ground_y, z1),
	])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = _flat_normals(verts)
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.name = "BridgeRampMesh"
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ramp_color
	mat.roughness = 0.9
	mi.material_override = mat
	add_child(mi)

	var body := StaticBody3D.new()
	body.name = "BridgeRampBody"
	body.collision_layer = terrain_mask
	body.collision_mask = 5
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)


func _ray_down(from: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	if space == null:
		return NAN
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 120.0, terrain_mask)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return NAN
	return float(hit.position.y)


func _flat_normals(verts: PackedVector3Array) -> PackedVector3Array:
	var n := (verts[1] - verts[0]).cross(verts[2] - verts[0]).normalized()
	if n.y < 0.0:
		n = -n
	return PackedVector3Array([n, n, n, n])
