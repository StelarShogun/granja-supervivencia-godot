extends Node3D

# Ground Y assumption for bridge pillars/ramps — deep enough to be buried under any terrain.
const BRIDGE_GROUND_Y := -15.0
const BRIDGE_DECK_X   :=  24.153
const BRIDGE_DECK_Y   :=  17.724  # deck top  (collider center 15.024 + half 2.7)
const BRIDGE_DECK_Z   :=  -9.866  # deck center Z
const BRIDGE_HALF_W   :=  12.25   # half-width X  (24.5 / 2)
const BRIDGE_HALF_L   :=  13.4    # half-length Z  (26.8 / 2)
const RAMP_HALF_W     :=   7.0    # ramp walkable half-width

var _wood:  StandardMaterial3D
var _stone: StandardMaterial3D
var _red:   StandardMaterial3D
var _roof:  StandardMaterial3D
var _rock:  StandardMaterial3D


func _ready() -> void:
	_make_mats()
	_build_corral()
	_build_bridge()
	_build_bridge_ramps()
	_build_cave_entrance()
	_build_granero()


func _make_mats() -> void:
	_wood  = _mat(Color(0.55, 0.38, 0.22), 0.90)
	_stone = _mat(Color(0.62, 0.58, 0.50), 1.00)
	_red   = _mat(Color(0.70, 0.25, 0.15), 0.90)
	_roof  = _mat(Color(0.28, 0.22, 0.15), 0.85)
	_rock  = _mat(Color(0.32, 0.30, 0.28), 1.00)


# ─── Structures ─────────────────────────────────────────────────────────────

func _build_corral() -> void:
	var p := _group("Corral")
	_box(p, "Wall_South",  Vector3(132.653, 18.81, -146.866), Vector3(60.5, 5.5,  0.55), _wood)
	_box(p, "Wall_East",   Vector3(162.653, 20.65, -124.866), Vector3( 0.55, 5.8, 44.5), _wood)
	_box(p, "Wall_North",  Vector3(132.653, 19.89, -102.866), Vector3(60.5, 5.5,  0.55), _wood)
	_box(p, "Gate_Side1",  Vector3(102.653, 17.40, -112.116), Vector3( 0.55, 5.5, 18.9), _wood)
	_box(p, "Gate_Side2",  Vector3(102.653, 16.92, -137.616), Vector3( 0.55, 5.5, 18.9), _wood)
	_box(p, "Gate_Lintel", Vector3(102.653, 21.65, -124.866), Vector3( 0.55, 1.5,  6.0), _wood)


func _build_bridge() -> void:
	var p := _group("Bridge")
	var cx := BRIDGE_DECK_X
	var cz := BRIDGE_DECK_Z

	# Deck surface (thin visible plank layer)
	_box(p, "Deck",   Vector3(cx, BRIDGE_DECK_Y - 0.4,  cz), Vector3(24.5, 0.8, 26.8), _wood)
	_box(p, "Beam_N", Vector3(cx, BRIDGE_DECK_Y - 1.4,  cz - 10.0), Vector3(24.5, 0.6, 0.8), _wood)
	_box(p, "Beam_C", Vector3(cx, BRIDGE_DECK_Y - 1.4,  cz),        Vector3(24.5, 0.6, 0.8), _wood)
	_box(p, "Beam_S", Vector3(cx, BRIDGE_DECK_Y - 1.4,  cz + 10.0), Vector3(24.5, 0.6, 0.8), _wood)

	# Stone pillars — extend deep underground (BRIDGE_GROUND_Y) so they always meet terrain.
	var pillar_h  := BRIDGE_DECK_Y - 0.8 - BRIDGE_GROUND_Y
	var pillar_cy := BRIDGE_GROUND_Y + pillar_h * 0.5
	for xo: float in [-9.5, 9.5]:
		for zo: float in [-11.0, 11.0]:
			_box(p, "Pillar_%d_%d" % [int(xo * 10), int(zo * 10)],
				Vector3(cx + xo, pillar_cy, cz + zo),
				Vector3(2.5, pillar_h, 2.5), _stone)


func _build_bridge_ramps() -> void:
	# Static ramps replace BridgeRamp.gd (which needs terrain raycast).
	# Each ramp = visual quad mesh + trimesh StaticBody3D for walkability.
	var p := _group("BridgeRamps")
	var cx  := BRIDGE_DECK_X
	var dy  := BRIDGE_DECK_Y
	var gy  := 7.0        # estimated finca ground height near bridge
	var hw  := RAMP_HALF_W

	# South ramp: deck south edge z = BRIDGE_DECK_Z + BRIDGE_HALF_L ≈ 3.534
	# goes further south to z = 3.534 + 14 = 17.534
	var zn_s := BRIDGE_DECK_Z + BRIDGE_HALF_L          # 3.534 (near = deck edge)
	var zf_s := zn_s + 14.0                             # 17.534 (far = ground)
	_ramp(p, "RampNorth",
		Vector3(cx - hw, dy, zn_s), Vector3(cx + hw, dy, zn_s),
		Vector3(cx + hw, gy, zf_s), Vector3(cx - hw, gy, zf_s))

	# North ramp: deck north edge z = BRIDGE_DECK_Z - BRIDGE_HALF_L ≈ -23.266
	# goes further north to z = -23.266 - 14 = -37.266
	var zn_n := BRIDGE_DECK_Z - BRIDGE_HALF_L          # -23.266
	var zf_n := zn_n - 14.0                             # -37.266
	_ramp(p, "RampSouth",
		Vector3(cx - hw, dy, zn_n), Vector3(cx + hw, dy, zn_n),
		Vector3(cx + hw, gy, zf_n), Vector3(cx - hw, gy, zf_n))


func _build_cave_entrance() -> void:
	var p := _group("CaveEntrance")
	var bp := Vector3(150.0, 82.87, 130.0)
	_box(p, "RockLeft",  bp + Vector3(-13.0,  0.0,  0.0), Vector3(4.0, 14.0, 12.0), _rock)
	_box(p, "RockRight", bp + Vector3( 13.0,  0.0,  0.0), Vector3(4.0, 14.0, 12.0), _rock)
	_box(p, "Arch",      bp + Vector3(  0.0,  6.5,  0.0), Vector3(22.0,  2.0, 12.0), _rock)
	_box(p, "BoulderL",  bp + Vector3(-16.0, -5.5, -3.0), Vector3(3.5,  3.0,  3.5), _rock)
	_box(p, "BoulderR",  bp + Vector3( 16.0, -5.5,  4.0), Vector3(3.0,  2.5,  3.0), _rock)


func _build_granero() -> void:
	# Visual only — collision is handled by 4 StaticBody3D walls in ScenarioColliders.
	var p  := _group("Granero")
	var b  := Vector3(82.0, 17.57, -113.0)
	var hw := 10.0
	var hd :=  7.0
	var h  :=  9.0

	_box(p, "Wall_N",  b + Vector3(  0.0, h * 0.5, -hd   ), Vector3(hw * 2.0, h, 0.5),           _red)
	_box(p, "Wall_S",  b + Vector3(  0.0, h * 0.5,  hd   ), Vector3(hw * 2.0, h, 0.5),           _red)
	_box(p, "Wall_E",  b + Vector3(  hw,  h * 0.5,  0.0  ), Vector3(0.5, h, hd * 2.0),           _red)
	_box(p, "Wall_W",  b + Vector3( -hw,  h * 0.5,  0.0  ), Vector3(0.5, h, hd * 2.0),           _red)
	_box(p, "Roof",    b + Vector3(  0.0, h + 0.5,  0.0  ), Vector3(hw * 2.0 + 1.2, 0.6, hd * 2.0 + 1.2), _roof)
	_box(p, "Floor",   b + Vector3(  0.0, 0.3,       0.0 ), Vector3(hw * 2.0,       0.6, hd * 2.0),       _roof)
	_box(p, "Lintel",  b + Vector3( -hw,  h * 0.65,  0.0 ), Vector3(0.5, h * 0.3, 3.0),          _roof)


# ─── Helpers ────────────────────────────────────────────────────────────────

func _ramp(parent: Node3D, nm: String,
		v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	# Build a quad mesh (v0 v1 v2 / v0 v2 v3) and a walkable StaticBody3D.
	var verts := PackedVector3Array([v0, v1, v2, v3])
	var n := _quad_normal(v0, v1, v2)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([n, n, n, n])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.name = nm + "Mesh"
	mi.mesh = mesh
	mi.material_override = _wood
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

	var body := StaticBody3D.new()
	body.name = nm + "Body"
	body.collision_layer = 2
	body.collision_mask  = 5
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	parent.add_child(body)


func _group(nm: String) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	add_child(n)
	return n


func _box(parent: Node3D, nm: String, pos: Vector3, sz: Vector3,
		mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.position = pos
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.set_surface_override_material(0, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness    = roughness
	return m


func _quad_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var n := (b - a).cross(c - a).normalized()
	return n if n.y >= 0.0 else -n
