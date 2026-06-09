extends Node3D
## Builds a closed modular wooden fence around a rectangular enclosure at
## runtime as a CONTINUOUS CHAIN: each edge is sampled into N+1 ground points
## (N = ceil(edge / tile)) and one tile is stretched between every pair of
## consecutive points, so neighbouring tiles share their endpoints exactly —
## zero gaps, zero overlaps, no fan-shaped seams on slopes. Convex bumps get
## one subdivision pass so the rail never sinks into the ground mid-tile.
## The gate edge leaves an exact gate_width opening (posts/doors are built by
## the CorralGate scene). Visuals use one MultiMeshInstance3D; collision is one
## oriented box per tile under a single StaticBody3D on layer 2.

@export var fence_glb: PackedScene
@export var enclosure_min := Vector2(90.0, -160.0)   ## Godot X,Z
@export var enclosure_max := Vector2(152.0, -100.0)
@export_enum("North(-Z)", "South(+Z)", "West(-X)", "East(+X)") var gate_side := 2
@export var gate_center := -124.866  ## along the gate edge (X for N/S, Z for W/E)
@export var gate_width := 8.0
@export var fence_scale := 1.4       ## visual height/depth scale
@export var embed := 0.12            ## sink base into ground to avoid light gaps
@export var collision_depth := 0.3

var _mesh_len := 5.143               ## unscaled fence_unit length (from AABB)
var _tile_len := 7.2                 ## target tile length = mesh_len * fence_scale
var _tile_mesh: Mesh
var _last_ground := 0.0
var _ground_warnings := 0


func _ready() -> void:
	if fence_glb == null:
		push_error("FenceBuilder: fence_glb not set")
		return
	_tile_mesh = _extract_mesh(fence_glb)
	if _tile_mesh == null:
		push_error("FenceBuilder: no mesh in fence_glb")
		return
	_mesh_len = _tile_mesh.get_aabb().size.x
	_tile_len = _mesh_len * fence_scale
	await get_tree().physics_frame
	await get_tree().physics_frame
	_build()


func _extract_mesh(ps: PackedScene) -> Mesh:
	var inst := ps.instantiate()
	var found: Mesh = null
	var stack: Array = [inst]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and n.mesh != null:
			found = n.mesh
			break
		for c in n.get_children():
			stack.append(c)
	inst.free()
	return found


func _build() -> void:
	var x0 := enclosure_min.x
	var x1 := enclosure_max.x
	var z0 := enclosure_min.y
	var z1 := enclosure_max.y

	var edges := [
		[Vector2(x0, z0), Vector2(x1, z0), 0],  # north (-Z)
		[Vector2(x1, z1), Vector2(x0, z1), 1],  # south (+Z)
		[Vector2(x0, z1), Vector2(x0, z0), 2],  # west (-X)
		[Vector2(x1, z0), Vector2(x1, z1), 3],  # east (+X)
	]

	var xforms: Array[Transform3D] = []
	for e in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		if int(e[2]) == gate_side:
			for seg in _split_gate_edge(a, b):
				_chain_segment(seg[0], seg[1], xforms)
		else:
			_chain_segment(a, b, xforms)

	var inv := global_transform.affine_inverse()

	# visuals
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _tile_mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, inv * xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "FenceVisual"
	mmi.multimesh = mm
	add_child(mmi)

	# collision: one oriented box per tile, matching the stretched visual
	var body := StaticBody3D.new()
	body.name = "FenceCollision"
	body.collision_layer = 2
	body.collision_mask = 0
	add_child(body)
	var aabb := _tile_mesh.get_aabb()
	for xf in xforms:
		var box_size := Vector3(
			aabb.size.x * xf.basis.get_scale().x,
			aabb.size.y * fence_scale,
			collision_depth)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box_size
		cs.shape = shape
		var basis := xf.basis.orthonormalized()
		var origin := xf.origin + basis * Vector3(0, box_size.y * 0.5, 0)
		cs.transform = inv * Transform3D(basis, origin)
		body.add_child(cs)

	print("FenceBuilder: %d fence tiles (chained), %d ground warnings"
		% [xforms.size(), _ground_warnings])


func _split_gate_edge(a: Vector2, b: Vector2) -> Array:
	var dir := (b - a).normalized()
	var horizontal := absf(dir.x) > absf(dir.y)
	var a_along := a.x if horizontal else a.y
	var b_along := b.x if horizontal else b.y
	var lo := minf(a_along, b_along)
	var hi := maxf(a_along, b_along)
	var g0 := clampf(gate_center - gate_width * 0.5, lo, hi)
	var g1 := clampf(gate_center + gate_width * 0.5, lo, hi)
	var p_g0 := Vector2(g0, a.y) if horizontal else Vector2(a.x, g0)
	var p_g1 := Vector2(g1, a.y) if horizontal else Vector2(a.x, g1)
	var segs: Array = []
	if a_along < b_along:
		segs = [[a, p_g0], [p_g1, b]]
	else:
		segs = [[a, p_g1], [p_g0, b]]
	var out: Array = []
	for s in segs:
		if (s[0] as Vector2).distance_to(s[1] as Vector2) > 0.5:
			out.append(s)
	return out


## Chains tiles between shared ground points along one straight segment.
func _chain_segment(a: Vector2, b: Vector2, out: Array[Transform3D]) -> void:
	var length := a.distance_to(b)
	if length < 0.001:
		return
	var dir := (b - a) / length
	var count := int(ceil(length / _tile_len))
	if count < 1:
		count = 1

	# N+1 shared ground points
	var pts: Array[Vector3] = []
	for i in count + 1:
		var p := a + dir * (length * float(i) / float(count))
		pts.append(Vector3(p.x, _ground_robust(p, dir), p.y))

	# one subdivision pass: insert a midpoint where the ground bulges above
	# the straight tile line (convex terrain would bury the rail mid-tile)
	var refined: Array[Vector3] = []
	for i in count:
		var p := pts[i]
		var q := pts[i + 1]
		refined.append(p)
		var mid2 := Vector2((p.x + q.x) * 0.5, (p.z + q.z) * 0.5)
		var gm = _ground(mid2.x, mid2.y)
		if gm != null and float(gm) - (p.y + q.y) * 0.5 > 0.15:
			refined.append(Vector3(mid2.x, float(gm), mid2.y))
	refined.append(pts[count])

	for i in refined.size() - 1:
		_tile_between(refined[i], refined[i + 1], dir, out)


## Stretches one tile exactly between two shared 3D points.
func _tile_between(p: Vector3, q: Vector3, dir: Vector2,
		out: Array[Transform3D]) -> void:
	var dh := Vector2(q.x - p.x, q.z - p.z).length()
	if dh < 0.05:
		return
	var dy := q.y - p.y
	var chord := sqrt(dh * dh + dy * dy)
	var yaw := atan2(-dir.y, dir.x)   # local +X follows the edge
	var pitch := atan2(dy, dh)
	var sx := chord / _mesh_len       # stretch so endpoints meet exactly
	var basis := (Basis(Vector3.UP, yaw)
		* Basis(Vector3(0, 0, 1), pitch)).scaled(
		Vector3(sx, fence_scale, fence_scale))
	var mid := (p + q) * 0.5 + Vector3.DOWN * embed
	out.append(Transform3D(basis, mid))


func _ground_robust(center: Vector2, dir: Vector2) -> float:
	var offsets := [
		Vector2.ZERO,
		dir * 0.3, dir * -0.3,
		Vector2(dir.y, -dir.x) * 0.3, Vector2(-dir.y, dir.x) * 0.3,
	]
	for off in offsets:
		var hit = _ground(center.x + off.x, center.y + off.y)
		if hit != null:
			_last_ground = float(hit)
			return float(hit)
	_ground_warnings += 1
	push_warning("FenceBuilder: no ground at %s, reusing y=%.2f" % [center, _last_ground])
	return _last_ground


func _ground(x: float, z: float):
	var space := get_world_3d().direct_space_state
	var from := Vector3(x, 200.0, z)
	var to := Vector3(x, -200.0, z)
	var q := PhysicsRayQueryParameters3D.create(from, to, 2)
	var hit := space.intersect_ray(q)
	if hit:
		return hit.position.y
	return null
