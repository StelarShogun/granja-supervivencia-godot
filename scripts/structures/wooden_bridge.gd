extends StaticBody3D

## Low-poly wooden bridge built at runtime over the river crossing.
## The node's yaw (from the scene) sets the crossing direction; on load the
## script raycasts both ends and snaps position + pitch so the deck rests
## flush with the terrain on each side. Collision: one deck box on layer 2
## (same layer as terrain), so player, Diablo and animals walk it normally.

@export var length: float = 16.0
@export var width: float = 3.6
@export var deck_thickness: float = 0.3
@export var rail_height: float = 0.95

const TERRAIN_MASK := 2
const WOOD := Color(0.45, 0.33, 0.2)
const WOOD_DARK := Color(0.36, 0.26, 0.16)


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	await get_tree().physics_frame
	await get_tree().physics_frame
	_align_to_ground()
	_build()


func _align_to_ground() -> void:
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var ex := global_transform.basis.x.normalized()
	var half := length * 0.5 - 1.0
	var a := _ground(space, global_position + ex * half)
	var b := _ground(space, global_position - ex * half)
	if a == Vector3.INF or b == Vector3.INF:
		return
	# Rebuild the basis so local X runs from bank B to bank A (pitch
	# follows the slope) while keeping the original yaw.
	var z0 := global_transform.basis.z
	z0.y = 0.0
	z0 = z0.normalized()
	var x_dir := (a - b).normalized()
	x_dir = (x_dir - z0 * z0.dot(x_dir)).normalized()
	var y_dir := z0.cross(x_dir).normalized()
	global_transform.basis = Basis(x_dir, y_dir, z0).orthonormalized()
	var mid := (a + b) * 0.5
	global_position = mid + y_dir * (deck_thickness * 0.5)


func _ground(space: PhysicsDirectSpaceState3D, at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(
		at + Vector3(0, 30, 0), at + Vector3(0, -40, 0), TERRAIN_MASK)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	return hit.position if not hit.is_empty() else Vector3.INF


func _build() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = WOOD
	wood.roughness = 1.0
	var wood_dark := wood.duplicate() as StandardMaterial3D
	wood_dark.albedo_color = WOOD_DARK

	# Deck (visual + the single collision box).
	_box(Vector3(length, deck_thickness, width), Vector3.ZERO, wood, true)

	# Cross planks on top for the low-poly look.
	var plank_count := int(length / 1.6)
	for i in plank_count:
		var x := -length * 0.5 + (i + 0.5) * (length / plank_count)
		_box(Vector3(length / plank_count - 0.12, 0.06, width),
			Vector3(x, deck_thickness * 0.5 + 0.03, 0), wood_dark, false)

	# Side rails + posts.
	for side in [-1.0, 1.0]:
		var z: float = side * (width * 0.5 - 0.12)
		_box(Vector3(length, 0.1, 0.12),
			Vector3(0, rail_height, z), wood_dark, false)
		var post_count := 5
		for i in post_count:
			var x := -length * 0.5 + 0.4 + i * ((length - 0.8) / (post_count - 1))
			_box(Vector3(0.14, rail_height, 0.14),
				Vector3(x, rail_height * 0.5, z), wood, false)

	# Short support legs at both ends (reach into the banks).
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.2, 1.6, 0.2),
				Vector3(sx * (length * 0.5 - 0.6), -0.8,
					sz * (width * 0.5 - 0.3)), wood, false)


func _box(size: Vector3, pos: Vector3, mat: Material, collide: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)
	if collide:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = pos
		add_child(shape)
