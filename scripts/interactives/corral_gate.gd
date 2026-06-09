extends Area3D
## Real farm gate for the corral fence opening. Node origin = south end of the
## opening; the opening runs along local +Z for gate_width metres.
## Structure (all built in _ready, low-poly boxes in the fence wood style):
##   LeftPost / RightPost  - solid posts with collision, flanking the opening
##   GateDoor_L / GateDoor_R - two swinging leaves with rails, planks, a
##       diagonal brace and visible hinge blocks, each with its own
##       StaticBody3D matching the visible geometry
## E-interact swings both leaves 100 degrees inward; leaf collision is
## disabled while open so Player and Diablo can pass.

@export var fence_glb: PackedScene          # kept for API compat (unused)
@export var gate_width := 8.0
@export var open_angle_degrees := 100.0
@export var collision_depth := 0.22
@export var game_manager_path: NodePath = NodePath("../../GameManager")

const POST := Vector3(0.45, 2.1, 0.45)
const LEAF_H := 1.45

var is_open := false
var _doors: Array[Node3D] = []
var _door_shapes: Array[CollisionShape3D] = []
var _closed_rot: Array[float] = []

var _wood: StandardMaterial3D
var _wood_dark: StandardMaterial3D


func _ready() -> void:
	add_to_group("interactives")
	_wood = _mat(Color(0.48, 0.31, 0.16))
	_wood_dark = _mat(Color(0.30, 0.19, 0.10))
	_build_gate()


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.92
	return m


func _box(parent: Node3D, name_: String, size: Vector3, pos: Vector3,
		mat: StandardMaterial3D, roll := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = mesh
	mi.position = pos
	if roll != 0.0:
		mi.rotation.x = roll
	parent.add_child(mi)
	return mi


func _build_gate() -> void:
	for c in get_children():
		c.free()
	_doors.clear()
	_door_shapes.clear()
	_closed_rot.clear()

	# frame posts with collision
	var frame := StaticBody3D.new()
	frame.name = "GateFrame"
	frame.collision_layer = 2
	frame.collision_mask = 0
	add_child(frame)
	for it in [["LeftPost", 0.0], ["RightPost", gate_width]]:
		var z: float = it[1]
		_box(self, it[0], POST, Vector3(0, POST.y * 0.5, z), _wood)
		# small cap on top of each post
		_box(self, String(it[0]) + "_Cap", Vector3(0.55, 0.1, 0.55),
			Vector3(0, POST.y + 0.05, z), _wood_dark)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = POST
		cs.shape = sh
		cs.position = Vector3(0, POST.y * 0.5, z)
		frame.add_child(cs)

	# two leaves: L hinged at the left (z=0) post opening towards +Z,
	# R hinged at the right (z=gate_width) post opening towards -Z
	var leaf_len := gate_width * 0.5 - 0.32
	_make_leaf("GateDoor_L", 0.28, 1.0, leaf_len)
	_make_leaf("GateDoor_R", gate_width - 0.28, -1.0, leaf_len)

	# interaction volume covering the whole opening
	var interact := CollisionShape3D.new()
	var ibox := BoxShape3D.new()
	ibox.size = Vector3(2.6, 2.2, gate_width + 1.2)
	interact.shape = ibox
	interact.position = Vector3(0, 1.1, gate_width * 0.5)
	add_child(interact)


## One swinging leaf. hinge_z: pivot position; dir: +1 leaf grows +Z, -1 grows -Z.
func _make_leaf(name_: String, hinge_z: float, dir: float, leaf_len: float) -> void:
	var pivot := Node3D.new()
	pivot.name = name_
	pivot.position = Vector3(0, 0, hinge_z)
	add_child(pivot)

	var L := leaf_len * dir
	var mid := L * 0.5

	# horizontal rails (top / bottom)
	for rail in [["Rail_Bottom", 0.38], ["Rail_Top", 1.18]]:
		_box(pivot, rail[0], Vector3(0.10, 0.16, leaf_len),
			Vector3(0, rail[1], mid), _wood)
	# vertical planks: hinge side, middle, latch side
	for it in [["Plank_Hinge", 0.10 * dir], ["Plank_Mid", mid],
			["Plank_End", L - 0.10 * dir]]:
		_box(pivot, it[0], Vector3(0.12, LEAF_H, 0.16),
			Vector3(0, LEAF_H * 0.5 + 0.05, it[1]), _wood)
	# diagonal brace between the rails
	var brace_len := sqrt(leaf_len * leaf_len + 0.8 * 0.8) - 0.25
	var brace := _box(pivot, "Brace", Vector3(0.08, 0.14, brace_len),
		Vector3(0, (0.38 + 1.18) * 0.5 + 0.08, mid), _wood_dark)
	brace.rotation.x = atan2(0.8, leaf_len) * dir
	# hinge blocks against the post
	for hy in [0.42, 1.16]:
		_box(pivot, "Hinge_%d" % int(hy * 100),
			Vector3(0.20, 0.12, 0.14), Vector3(0, hy, 0.04 * dir), _wood_dark)

	# leaf collision matching the visible geometry, active only when closed
	var body := StaticBody3D.new()
	body.name = "GateBody"
	body.collision_layer = 2
	body.collision_mask = 0
	pivot.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(collision_depth, LEAF_H + 0.2, leaf_len)
	cs.shape = sh
	cs.position = Vector3(0, (LEAF_H + 0.2) * 0.5, mid)
	body.add_child(cs)

	_doors.append(pivot)
	_door_shapes.append(cs)
	_closed_rot.append(0.0)


func interact(_player: Node) -> void:
	is_open = not is_open
	var swing := deg_to_rad(open_angle_degrees)
	for i in _doors.size():
		var target := _closed_rot[i]
		if is_open:
			# both leaves swing inward (towards +X, into the pen)
			target += swing if i == 0 else -swing
		var tw := create_tween()
		tw.tween_property(_doors[i], "rotation:y", target, 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for shape in _door_shapes:
		shape.disabled = is_open

	var manager := _get_game_manager()
	if manager != null and manager.has_method("show_message"):
		manager.show_message(
			"Puerta del corral abierta." if is_open else "Puerta del corral cerrada.", 1.6)


func _get_game_manager() -> Node:
	if game_manager_path != NodePath("") and has_node(game_manager_path):
		return get_node(game_manager_path)
	var managers := get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		return managers[0]
	return null
