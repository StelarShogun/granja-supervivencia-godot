@tool
extends StaticBody3D
## Parametric hollow building (barn / shed) with a real interior, a doorway and
## a gable roof. Geometry + collision are rebuilt from the exported parameters,
## so the same scene is reusable at any size. Runs in the editor (@tool) so the
## structure is visible while authoring, and at runtime for collision.
##
## Generated children are not owned by the scene -> the .tscn stays tiny and the
## structure is always rebuilt from parameters.

@export var footprint := Vector2(10.0, 8.0)   ## interior X by Z size (metres)
@export var wall_height := 4.0
@export var wall_thickness := 0.25
@export var door_width := 3.0
@export var door_height := 2.6
@export var roof_height := 2.6
@export var roof_overhang := 0.4
@export var wall_color := Color(0.56, 0.41, 0.26)
@export var roof_color := Color(0.42, 0.16, 0.12)
@export var floor_color := Color(0.30, 0.25, 0.20)
@export var rebuild := false:        ## tick in the editor to force a rebuild
	set(v):
		rebuild = false
		if is_inside_tree():
			_build()


@export var snap_to_ground := true

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	_build()
	if snap_to_ground and not Engine.is_editor_hint():
		_snap_to_ground()


func _snap_to_ground() -> void:
	# wait for the runtime terrain collision (StaticBody layer 2) to build
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 120.0
	var to := global_position + Vector3.DOWN * 200.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 2)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit:
		global_position.y = hit.position.y - 0.05


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _box(name_: String, size: Vector3, pos: Vector3, mat: StandardMaterial3D, collide := true) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		cs.position = pos
		add_child(cs)


func _build() -> void:
	for c in get_children():
		c.free()

	var wmat := _mat(wall_color)
	var fmat := _mat(floor_color)
	var rmat := _mat(roof_color)

	var ix := footprint.x
	var iz := footprint.y
	var t := wall_thickness
	var h := wall_height
	# outer span (wall centrelines sit on the footprint edges)
	var ox := ix + t
	var oz := iz + t

	# floor
	_box("Floor", Vector3(ox, 0.2, oz), Vector3(0, 0.1, 0), fmat)

	# back wall (+Z) and the two side walls
	_box("Wall_Back", Vector3(ox, h, t), Vector3(0, h * 0.5, iz * 0.5), wmat)
	_box("Wall_Left", Vector3(t, h, oz), Vector3(-ix * 0.5, h * 0.5, 0), wmat)
	_box("Wall_Right", Vector3(t, h, oz), Vector3(ix * 0.5, h * 0.5, 0), wmat)

	# front wall (-Z) with a centred doorway: two jambs + a lintel
	var dw: float = min(door_width, ix - 0.5)
	var dh: float = min(door_height, h - 0.3)
	var side_w := (ox - dw) * 0.5
	var front_z := -iz * 0.5
	_box("Wall_Front_L", Vector3(side_w, h, t),
		Vector3(-(dw + side_w) * 0.5, h * 0.5, front_z), wmat)
	_box("Wall_Front_R", Vector3(side_w, h, t),
		Vector3((dw + side_w) * 0.5, h * 0.5, front_z), wmat)
	_box("Wall_Front_Top", Vector3(dw, h - dh, t),
		Vector3(0, dh + (h - dh) * 0.5, front_z), wmat)

	# gable roof: a triangular prism along the ridge (Z), capping the walls
	var roof := PrismMesh.new()
	roof.size = Vector3(ox + roof_overhang * 2.0, roof_height, oz + roof_overhang * 2.0)
	roof.material = rmat
	var rmi := MeshInstance3D.new()
	rmi.name = "Roof"
	rmi.mesh = roof
	rmi.position = Vector3(0, h + roof_height * 0.5, 0)
	add_child(rmi)
	# roof collision (trimesh) so it is solid from outside
	var rcs := CollisionShape3D.new()
	rcs.shape = roof.create_trimesh_shape()
	rcs.position = rmi.position
	add_child(rcs)
