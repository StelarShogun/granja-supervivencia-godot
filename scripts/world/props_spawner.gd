extends Node3D

# Approximate terrain Y values per zone — updated after Terrain3D sculpt (Phase 2).
# All props face +Y (flat ground). If terrain changes, adjust these values or add
# a downward raycast at runtime (see _ground_y helper at bottom).

const LAKE_CENTER := Vector3(-150.347, -3.2, -144.866)
const LAKE_RX     := 62.0   # spawn reeds just outside lake rim
const LAKE_RZ     := 46.0

var _green:  StandardMaterial3D
var _trunk:  StandardMaterial3D
var _rock:   StandardMaterial3D
var _reed:   StandardMaterial3D
var _hay:    StandardMaterial3D
var _bush:   StandardMaterial3D
var _post:   StandardMaterial3D


func _ready() -> void:
	_make_mats()
	_spawn_forest_trees()
	_spawn_plain_rocks()
	_spawn_plain_bushes()
	_spawn_lake_reeds()
	_spawn_rural_props()
	_spawn_mountain_boulders()


func _make_mats() -> void:
	_green = _mat(Color(0.20, 0.48, 0.16), 1.0)
	_trunk = _mat(Color(0.40, 0.28, 0.15), 1.0)
	_rock  = _mat(Color(0.54, 0.51, 0.47), 1.0)
	_reed  = _mat(Color(0.35, 0.55, 0.20), 1.0)
	_hay   = _mat(Color(0.78, 0.68, 0.30), 0.95)
	_bush  = _mat(Color(0.24, 0.44, 0.14), 1.0)
	_post  = _mat(Color(0.48, 0.33, 0.18), 0.95)


# ─── Forest zone (northwest + north) ────────────────────────────────────────

func _spawn_forest_trees() -> void:
	var p := _group("ForestTrees")
	var positions: Array[Vector3] = [
		# Northwest cluster
		Vector3(-25.0,  8.0,  25.0), Vector3(-40.0,  7.0,  38.0),
		Vector3(-15.0, 10.0,  47.0), Vector3(-55.0,  6.0,  30.0),
		Vector3(-65.0,  5.0,  45.0), Vector3(-35.0,  9.0,  58.0),
		Vector3(-50.0,  8.0,  68.0), Vector3(-20.0, 11.0,  62.0),
		Vector3(-75.0,  5.0,  52.0), Vector3(-88.0,  4.0,  37.0),
		Vector3(-98.0,  3.0,  22.0), Vector3(-78.0,  4.5,  62.0),
		# North cluster
		Vector3( -8.0, 13.0,  78.0), Vector3( 12.0, 14.0,  88.0),
		Vector3( 28.0, 15.0,  82.0), Vector3( 38.0, 16.0,  72.0),
		Vector3( 22.0, 14.0,  95.0), Vector3(  2.0, 12.0,  98.0),
		Vector3(-22.0, 11.0,  93.0), Vector3(-42.0, 10.0,  80.0),
		Vector3(-58.0,  8.5,  88.0), Vector3(-35.0,  9.5, 105.0),
		# West scattered
		Vector3(-108.0,  3.0,  12.0), Vector3(-118.0,  2.0,  -3.0),
		Vector3( -98.0,  3.5,  -8.0), Vector3( -82.0,  4.5,  18.0),
		Vector3(-125.0,  2.0,  28.0), Vector3(-105.0,  3.0,  45.0),
	]
	for i in range(positions.size()):
		_tree(p, "Tree_%02d" % i, positions[i])


# ─── Open plain (center-west) ───────────────────────────────────────────────

func _spawn_plain_rocks() -> void:
	var p := _group("PlainRocks")
	var positions: Array[Vector3] = [
		Vector3(-52.0,  4.0, -12.0), Vector3(-68.0,  3.0,   8.0),
		Vector3(-38.0,  5.0,  -2.0), Vector3(-58.0,  4.5,  18.0),
		Vector3(-78.0,  3.0,  -2.0), Vector3(-28.0,  5.5, -18.0),
		Vector3(-45.0,  4.0,  28.0), Vector3(-88.0,  3.0,  -8.0),
		Vector3(-18.0,  6.0, -35.0), Vector3(-32.0,  5.0, -48.0),
	]
	for i in range(positions.size()):
		_rock_cluster(p, "Rock_%02d" % i, positions[i])


func _spawn_plain_bushes() -> void:
	var p := _group("PlainBushes")
	var positions: Array[Vector3] = [
		Vector3(-35.0,  4.5,  12.0), Vector3(-55.0,  3.5,  -8.0),
		Vector3(-22.0,  5.0,  22.0), Vector3(-70.0,  3.0,  25.0),
		Vector3(-15.0,  6.0, -10.0), Vector3(-48.0,  4.0,  35.0),
		Vector3( -8.0,  6.5, -28.0), Vector3(-62.0,  3.5,  42.0),
		Vector3(-80.0,  3.0,  12.0), Vector3(-38.0,  4.5, -30.0),
		Vector3(-18.0,  5.5,  40.0), Vector3(-92.0,  2.5,  30.0),
	]
	for i in range(positions.size()):
		_place_bush(p, "Bush_%02d" % i, positions[i])


# ─── Lake + river shores ─────────────────────────────────────────────────────

func _spawn_lake_reeds() -> void:
	var p := _group("LakeReeds")
	var count := 18
	for i in range(count):
		var angle := float(i) / count * TAU
		# Slightly outside the lake ellipse rim
		var rx := LAKE_RX + randf_range(-3.0, 5.0)
		var rz := LAKE_RZ + randf_range(-3.0, 5.0)
		var pos := Vector3(
			LAKE_CENTER.x + cos(angle) * rx,
			LAKE_CENTER.y + 0.5,          # just above water surface
			LAKE_CENTER.z + sin(angle) * rz)
		_place_reed(p, "Reed_%02d" % i, pos)

	# River bank reeds along lower river (P4-P7)
	var river_banks: Array[Vector3] = [
		Vector3(-30.0,  4.5, -60.0), Vector3(-45.0,  3.0, -68.0),
		Vector3(-62.0,  2.0, -80.0), Vector3(-78.0, -3.5, -90.0),
		Vector3(-95.0, -4.5,-102.0), Vector3(-112.0,-5.0,-118.0),
		Vector3(-128.0,-4.8,-130.0), Vector3(-142.0,-4.0,-140.0),
	]
	for i in range(river_banks.size()):
		_place_reed(p, "RiverReed_%02d" % i, river_banks[i])


# ─── Rural zone (east — near corral + granero) ───────────────────────────────

func _spawn_rural_props() -> void:
	var p := _group("RuralProps")

	# Hay bales near granero (base pos 82, 17.57, -113) — Y matches new terrain
	var hay_positions: Array[Vector3] = [
		Vector3( 74.0, 17.2, -108.0), Vector3( 78.0, 17.0, -104.0),
		Vector3( 72.0, 17.4, -118.0), Vector3( 85.0, 17.8, -120.0),
		Vector3( 90.0, 17.6, -107.0), Vector3( 68.0, 17.1, -113.0),
	]
	for i in range(hay_positions.size()):
		_hay_bale(p, "Hay_%02d" % i, hay_positions[i])

	# Fence posts along rural access path (west of corral gate x≈102)
	var post_positions: Array[Vector3] = [
		Vector3( 96.0, 17.0, -75.0), Vector3( 96.0, 17.2, -82.0),
		Vector3( 96.0, 17.4, -89.0), Vector3( 96.0, 17.5, -96.0),
		Vector3( 78.0, 17.3, -96.0), Vector3( 70.0, 17.0, -96.0),
	]
	for i in range(post_positions.size()):
		_fence_post(p, "Post_%02d" % i, post_positions[i])

	# Scattered rocks near farm
	var farm_rocks: Array[Vector3] = [
		Vector3(115.0, 18.0, -80.0), Vector3(108.0, 18.5, -72.0),
		Vector3(125.0, 17.8, -90.0),
	]
	for i in range(farm_rocks.size()):
		_rock_cluster(p, "FarmRock_%02d" % i, farm_rocks[i])


# ─── Mountain boulders (northeast) ───────────────────────────────────────────

func _spawn_mountain_boulders() -> void:
	var p := _group("MountainBoulders")
	var positions: Array[Vector3] = [
		Vector3(115.0,  32.0,  55.0), Vector3(128.0,  42.0,  75.0),
		Vector3(142.0,  55.0,  95.0), Vector3(150.0,  65.0, 115.0),
		Vector3(138.0,  50.0, 108.0), Vector3(122.0,  38.0,  85.0),
		Vector3(158.0,  72.0, 140.0), Vector3(148.0,  68.0, 155.0),
		Vector3(162.0,  78.0, 165.0),
	]
	for i in range(positions.size()):
		_boulder(p, "Boulder_%02d" % i, positions[i])


# ─── Prop builders ───────────────────────────────────────────────────────────

func _tree(parent: Node3D, nm: String, base: Vector3) -> void:
	var root := Node3D.new()
	root.name = nm
	root.position = base
	parent.add_child(root)
	# Trunk
	_mi(root, "Trunk",  Vector3(0.0, 1.5, 0.0), Vector3(0.5, 3.0, 0.5), _trunk)
	# Crown layers (stacked boxes — low poly pyramid)
	_mi(root, "Crown1", Vector3(0.0, 3.8, 0.0), Vector3(3.2, 1.0, 3.2), _green)
	_mi(root, "Crown2", Vector3(0.0, 4.8, 0.0), Vector3(2.4, 0.9, 2.4), _green)
	_mi(root, "Crown3", Vector3(0.0, 5.6, 0.0), Vector3(1.6, 0.8, 1.6), _green)
	_mi(root, "Crown4", Vector3(0.0, 6.2, 0.0), Vector3(0.8, 0.7, 0.8), _green)


func _rock_cluster(parent: Node3D, nm: String, base: Vector3) -> void:
	var root := Node3D.new()
	root.name = nm
	root.position = base
	parent.add_child(root)
	_mi(root, "Base",   Vector3( 0.0,  0.5,  0.0), Vector3(2.2, 1.0, 2.0), _rock)
	_mi(root, "TopA",   Vector3( 0.3,  1.2,  0.2), Vector3(1.4, 0.8, 1.2), _rock)
	_mi(root, "TopB",   Vector3(-0.4,  0.9, -0.3), Vector3(1.0, 0.6, 0.9), _rock)


func _boulder(parent: Node3D, nm: String, base: Vector3) -> void:
	var root := Node3D.new()
	root.name = nm
	root.position = base
	parent.add_child(root)
	_mi(root, "Main",   Vector3( 0.0, 1.5,  0.0), Vector3(3.5, 3.0, 3.2), _rock)
	_mi(root, "Side",   Vector3( 1.5, 0.8,  0.8), Vector3(2.0, 2.0, 2.0), _rock)
	_mi(root, "Small",  Vector3(-1.2, 0.6, -1.0), Vector3(1.5, 1.5, 1.5), _rock)


func _place_bush(parent: Node3D, nm: String, base: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.position = base + Vector3(0.0, 0.5, 0.0)
	var bm := BoxMesh.new()
	bm.size = Vector3(1.6, 1.0, 1.6)
	mi.mesh = bm
	mi.set_surface_override_material(0, _bush)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _place_reed(parent: Node3D, nm: String, base: Vector3) -> void:
	var root := Node3D.new()
	root.name = nm
	root.position = base
	parent.add_child(root)
	# 2-3 thin stalks per reed cluster
	for i in range(3):
		var off := Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
		var h   := randf_range(1.4, 2.2)
		_mi(root, "Stalk_%d" % i, off + Vector3(0.0, h * 0.5, 0.0),
			Vector3(0.12, h, 0.12), _reed)


func _hay_bale(parent: Node3D, nm: String, base: Vector3) -> void:
	var root := Node3D.new()
	root.name = nm
	root.position = base
	parent.add_child(root)
	_mi(root, "Bale",  Vector3(0.0, 0.5, 0.0), Vector3(1.2, 1.0, 1.6), _hay)
	_mi(root, "Band1", Vector3(0.0, 0.5, 0.38), Vector3(1.22, 1.02, 0.08), _post)
	_mi(root, "Band2", Vector3(0.0, 0.5,-0.38), Vector3(1.22, 1.02, 0.08), _post)


func _fence_post(parent: Node3D, nm: String, base: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.position = base + Vector3(0.0, 1.5, 0.0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.18, 3.0, 0.18)
	mi.mesh = bm
	mi.set_surface_override_material(0, _post)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# ─── Primitives ──────────────────────────────────────────────────────────────

func _mi(parent: Node3D, nm: String, pos: Vector3, sz: Vector3,
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


func _group(nm: String) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	add_child(n)
	return n


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness    = roughness
	return m
