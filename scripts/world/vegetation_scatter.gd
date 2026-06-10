extends Node3D

## Runtime vegetation scatter. Visual layer only — terrain meshes, gameplay
## nodes, navigation and existing collisions are never modified.
##
## - Grass clumps (grass.glb "Grass Generic Small") cover EVERY green zone:
##   instances are sampled directly on the Terrain_Main triangles whose
##   material is grass/forest ground, so river bed (MAT_Wet), paths
##   (MAT_Path), rock and mud are excluded automatically.
## - A dense pine forest (pine_forest.glb, light LOD of SJ-Frosted Pine
##   Tree) fills the whole region across the river bridge (NW half-plane).
## - Accent pines (pine_low.glb, high LOD) dress map borders and the
##   mountain fringe.
## - EVERY pine gets a simple trunk collision cylinder on layer 2 (same
##   proxy style terrain_collision.gd uses for Lib_Tree).
## Chunked MultiMeshes + visibility ranges keep the FPS stable.

const GRASS_GLB := "res://assets/models/environment/grass.glb"
const PINE_GLB := "res://assets/models/environment/pine_low.glb"
const FOREST_GLB := "res://assets/models/environment/pine_forest.glb"

## Terrain surfaces that count as "green ground".
const GREEN_MAT_KEYWORDS := ["grass", "forest"]

const GRASS_PER_M2 := 1.0 / 40.0
const GRASS_MAX := 3800
const GRASS_CHUNK := 64.0
const GRASS_VIS_RANGE := 115.0

const FOREST_PER_M2 := 1.0 / 130.0
const FOREST_MAX := 240
const FOREST_MIN_SPACING := 12.0
const FOREST_CHUNK := 96.0
const FOREST_VIS_RANGE := 260.0

## River line (world XZ). Forest side = cross((p - P1), V) < 0, which is
## the area you reach after crossing the bridge from the farm side.
const RIVER_P1 := Vector2(53.0, -65.0)
const RIVER_P2 := Vector2(-142.0, 134.0)
## Sampled river course points — extra buffer so trees keep off the banks.
const RIVER_POINTS := [
	Vector2(-142.7, 134.3), Vector2(-78.8, 75.4), Vector2(-74.3, 68.2),
	Vector2(-67.6, 61.3), Vector2(-68.0, 46.1), Vector2(-61.3, 39.7),
	Vector2(-55.9, 32.0), Vector2(-48.9, 25.6), Vector2(-23.8, 25.0),
	Vector2(-133.6, 125.8), Vector2(16.1, -11.9), Vector2(16.8, -34.2),
	Vector2(53.8, -65.7), Vector2(-125.7, 118.7), Vector2(-119.7, 109.3),
	Vector2(-113.2, 101.1), Vector2(-108.5, 98.1), Vector2(-110.0, 86.5),
	Vector2(-104.4, 80.3), Vector2(-96.9, 76.7), Vector2(-91.8, 73.4),
]
const RIVER_TREE_BUFFER := 6.0

## Riverbank grass accents: (x, z, expected_ground_y).
const GRASS_BANKS := [
	Vector3(-142.7, 5.8, 134.3), Vector3(-78.8, 7.2, 75.4),
	Vector3(-74.3, 7.0, 68.2), Vector3(-67.6, 7.2, 61.3),
	Vector3(-68.0, 5.5, 46.1), Vector3(-61.3, 6.3, 39.7),
	Vector3(-55.9, 7.2, 32.0), Vector3(-48.9, 9.4, 25.6),
	Vector3(-23.8, 17.3, 25.0), Vector3(-133.6, 6.6, 125.8),
	Vector3(16.8, 16.7, -34.2), Vector3(53.8, 10.9, -65.7),
	Vector3(-125.7, 7.0, 118.7), Vector3(-119.7, 6.9, 109.3),
	Vector3(-113.2, 6.2, 101.1), Vector3(-108.5, 6.2, 98.1),
	Vector3(-110.0, 4.7, 86.5), Vector3(-104.4, 4.2, 80.3),
	Vector3(-96.9, 4.6, 76.7), Vector3(-91.8, 4.9, 73.4),
]

## Accent pine positions (x, z): borders + mountain fringe.
const PINES := [
	Vector2(-220, -150), Vector2(-232, -120), Vector2(-215, -85),
	Vector2(-238, -50), Vector2(-222, -10), Vector2(-230, 40),
	Vector2(-218, 90), Vector2(-235, 130), Vector2(-224, 170),
	Vector2(-180, -190), Vector2(-140, -185), Vector2(-95, -195),
	Vector2(-50, -188), Vector2(-5, -194), Vector2(40, -190),
	Vector2(85, -196), Vector2(130, -188), Vector2(170, -193),
	Vector2(175, -60), Vector2(180, -15), Vector2(170, 30), Vector2(178, 70),
	Vector2(-190, 225), Vector2(-140, 232), Vector2(-90, 220),
	Vector2(-40, 228), Vector2(0, 236),
	Vector2(-160, 160), Vector2(-120, 180), Vector2(-60, 200),
	Vector2(35, 120), Vector2(48, 140), Vector2(30, 155),
	Vector2(55, 170), Vector2(25, 95),
]

## Keep-out circles: (x, z, radius). Gameplay must stay clear.
const EXCLUSIONS := [
	Vector3(19.65, -14.95, 12.0),  # bridge + trigger + both exits
	Vector3(61.3, -43.7, 6.0),     # player spawn
	Vector3(16.5, -23.6, 4.0), Vector3(44.5, -31.6, 4.0),
	Vector3(74.5, -55.6, 4.0), Vector3(-129.5, -97.6, 5.0),
	Vector3(-165.5, -109.6, 5.0), Vector3(-197.5, -95.6, 5.0),
	Vector3(70.5, 142.4, 4.0), Vector3(92.5, 172.4, 4.0),
	Vector3(110.5, 210.4, 4.0), Vector3(138.5, 160.4, 4.0),
	Vector3(29.65, -30.5, 5.0), Vector3(14.0, -6.0, 5.0),
	Vector3(-22.0, 28.0, 5.0),     # mud traps
	Vector3(95.0, -70.0, 4.0), Vector3(118.0, -100.0, 4.0),
	Vector3(105.0, -115.0, 4.0),   # caciques
	Vector3(128.5, 207.4, 7.0),    # cave trigger
]

## Corral enclosure + margin (FenceBuilder rect 90,-160 .. 152,-100).
const CORRAL_MIN := Vector2(84.0, -166.0)
const CORRAL_MAX := Vector2(158.0, -94.0)

const TERRAIN_MASK := 2
const RAY_TOP := 250.0
const RAY_LEN := 500.0

var _stats := {"grass": 0, "banks": 0, "forest": 0, "pines": 0, "trunks": 0}


func _ready() -> void:
	# Wait until the sibling TerrainCollision has built its physics shapes
	# (needed for the few raycast-based placements).
	await get_tree().physics_frame
	await get_tree().physics_frame
	_build()


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260609

	var grass_mesh := _merged_mesh(GRASS_GLB, 0.1)
	var pine_mesh := _merged_mesh(PINE_GLB, 0.1)
	var forest_mesh := _merged_mesh(FOREST_GLB, 0.1)
	if grass_mesh == null or pine_mesh == null or forest_mesh == null:
		push_error("VegetationScatter: missing vegetation meshes")
		return

	var tris := _green_triangles()
	if tris.is_empty():
		push_error("VegetationScatter: no green terrain triangles found")
		return
	var total_area: float = tris.cum_area[tris.cum_area.size() - 1]

	# ---- grass everywhere on green ground ----
	var grass_count: int = mini(int(total_area * GRASS_PER_M2), GRASS_MAX)
	var grass_xforms: Array[Transform3D] = []
	var attempts := 0
	while grass_xforms.size() < grass_count and attempts < grass_count * 3:
		attempts += 1
		var s := _sample_triangle(tris, rng)
		if s.normal.y < 0.7:
			continue
		if not _allowed(s.point.x, s.point.z):
			continue
		grass_xforms.append(_xform(s.point, rng, 1.1, 1.9))
	_stats.grass = grass_xforms.size()

	# riverbank accents (raycast-snapped)
	var space := get_world_3d().direct_space_state
	for bank in GRASS_BANKS:
		for i in 2:
			var x: float = bank.x + rng.randf_range(-2.5, 2.5)
			var z: float = bank.z + rng.randf_range(-2.5, 2.5)
			if not _allowed(x, z):
				continue
			var hit := _ground(space, x, z)
			if hit.is_empty() or hit.normal.y < 0.7:
				continue
			if absf(hit.position.y - bank.y) > 2.0:
				continue
			grass_xforms.append(_xform(hit.position, rng, 0.8, 1.3))
			_stats.banks += 1

	_add_chunked("Grass", grass_mesh, grass_xforms, GRASS_CHUNK,
		GRASS_VIS_RANGE, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

	# ---- dense forest across the bridge (NW of the river) ----
	var forest_xforms: Array[Transform3D] = []
	var occupied := {}
	var forest_target: int = FOREST_MAX
	attempts = 0
	while forest_xforms.size() < forest_target and attempts < forest_target * 8:
		attempts += 1
		var s := _sample_triangle(tris, rng)
		var p2 := Vector2(s.point.x, s.point.z)
		if not _in_forest_region(p2):
			continue
		if s.normal.y < 0.6 or not _allowed(p2.x, p2.y):
			continue
		if _near_river(p2):
			continue
		if not _claim_spacing(occupied, p2, FOREST_MIN_SPACING):
			continue
		var t := _xform(s.point, rng, 0.9, 1.5)  # 10.6 m .. 17.6 m tall
		forest_xforms.append(t)
		_add_trunk(t.origin, t.basis.get_scale().x)
	_stats.forest = forest_xforms.size()
	# Shadows off for the mass forest: ~430 trees, the shadow pass would
	# halve the framerate. Accent pines keep shadows.
	_add_chunked("Forest", forest_mesh, forest_xforms, FOREST_CHUNK,
		FOREST_VIS_RANGE, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

	# ---- accent pines: borders + mountain fringe ----
	var pine_xforms: Array[Transform3D] = []
	for p in PINES:
		var hit := _ground(space, p.x, p.y)
		if hit.is_empty() or hit.normal.y < 0.5 or not _allowed(p.x, p.y):
			continue
		var t := _xform(hit.position, rng, 0.9, 1.45)
		pine_xforms.append(t)
		_add_trunk(t.origin, t.basis.get_scale().x)
	_stats.pines = pine_xforms.size()
	_add_chunked("Pines", pine_mesh, pine_xforms, 999.0, 0.0,
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

	print("VegetationScatter: grass=%d banks=%d forest=%d pines=%d trunks=%d"
		% [_stats.grass, _stats.banks, _stats.forest, _stats.pines,
			_stats.trunks])


## ---------- terrain sampling ----------

## Collect world-space triangles of every green Terrain_Main surface.
func _green_triangles() -> Dictionary:
	var terreno := get_parent().get_node_or_null("Terreno_Finca")
	if terreno == null:
		return {}
	var mi := terreno.find_child("Terrain_Main", true, false) as MeshInstance3D
	if mi == null or mi.mesh == null:
		return {}
	var xf := mi.global_transform
	var pa := PackedVector3Array()
	var pb := PackedVector3Array()
	var pc := PackedVector3Array()
	var cum := PackedFloat64Array()
	var running := 0.0
	for s in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(s)
		if mat == null:
			continue
		var mat_name := mat.resource_name.to_lower()
		var green := false
		for kw in GREEN_MAT_KEYWORDS:
			if mat_name.contains(kw):
				green = true
				break
		if not green:
			continue
		var arrays := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, idx.size(), 3):
			var a := xf * verts[idx[i]]
			var b := xf * verts[idx[i + 1]]
			var c := xf * verts[idx[i + 2]]
			var area := (b - a).cross(c - a).length() * 0.5
			if area <= 0.0001:
				continue
			running += area
			pa.append(a)
			pb.append(b)
			pc.append(c)
			cum.append(running)
	return {"a": pa, "b": pb, "c": pc, "cum_area": cum}


## Area-weighted random point on the green triangle soup.
func _sample_triangle(tris: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cum: PackedFloat64Array = tris.cum_area
	var target := rng.randf() * cum[cum.size() - 1]
	var lo := 0
	var hi := cum.size() - 1
	while lo < hi:
		var mid := (lo + hi) >> 1
		if cum[mid] < target:
			lo = mid + 1
		else:
			hi = mid
	var a: Vector3 = tris.a[lo]
	var b: Vector3 = tris.b[lo]
	var c: Vector3 = tris.c[lo]
	var r1 := sqrt(rng.randf())
	var r2 := rng.randf()
	var point := a * (1.0 - r1) + b * (r1 * (1.0 - r2)) + c * (r1 * r2)
	# Godot meshes use clockwise front faces, so invert the cross product
	# to get the upward-facing normal.
	var normal := (c - a).cross(b - a).normalized()
	return {"point": point, "normal": normal}


## ---------- region / spacing filters ----------

func _in_forest_region(p: Vector2) -> bool:
	var v := RIVER_P2 - RIVER_P1
	var w := p - RIVER_P1
	return w.cross(v) < 0.0


func _near_river(p: Vector2) -> bool:
	for rp in RIVER_POINTS:
		if p.distance_to(rp) < RIVER_TREE_BUFFER:
			return true
	return false


func _claim_spacing(occupied: Dictionary, p: Vector2, spacing: float) -> bool:
	var cell := Vector2i(int(floor(p.x / spacing)), int(floor(p.y / spacing)))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var key := cell + Vector2i(dx, dy)
			if occupied.has(key) and occupied[key].distance_to(p) < spacing:
				return false
	occupied[cell] = p
	return true


func _allowed(x: float, z: float) -> bool:
	if x > CORRAL_MIN.x and x < CORRAL_MAX.x \
			and z > CORRAL_MIN.y and z < CORRAL_MAX.y:
		return false
	for e in EXCLUSIONS:
		if Vector2(x, z).distance_to(Vector2(e.x, e.y)) < e.z:
			return false
	return true


func _ground(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(x, RAY_TOP, z), Vector3(x, RAY_TOP - RAY_LEN, z), TERRAIN_MASK)
	return space.intersect_ray(query)


## ---------- builders ----------

func _xform(pos: Vector3, rng: RandomNumberGenerator,
		smin: float, smax: float) -> Transform3D:
	var basis := Basis(Vector3.UP, rng.randf() * TAU)
	basis = basis.scaled(Vector3.ONE * rng.randf_range(smin, smax))
	return Transform3D(basis, pos)


## Split transforms into world-grid chunks; one MultiMeshInstance3D per
## chunk with a visibility range, so distant vegetation stops rendering.
func _add_chunked(prefix: String, mesh: ArrayMesh, xforms: Array[Transform3D],
		chunk_size: float, vis_range: float, shadow: int) -> void:
	var buckets := {}
	for t in xforms:
		var key := Vector2i(int(floor(t.origin.x / chunk_size)),
			int(floor(t.origin.z / chunk_size)))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(t)
	for key in buckets:
		var list: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var inst := MultiMeshInstance3D.new()
		inst.name = "%s_%d_%d" % [prefix, key.x, key.y]
		inst.multimesh = mm
		inst.cast_shadow = shadow
		if vis_range > 0.0:
			inst.visibility_range_end = vis_range
			inst.visibility_range_end_margin = 8.0
			inst.visibility_range_fade_mode = \
				GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(inst)


func _add_trunk(pos: Vector3, scale: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.45 * scale
	cyl.height = 3.5 * scale
	shape.shape = cyl
	shape.position = Vector3(0, 1.75 * scale, 0)
	body.add_child(shape)
	add_child(body)
	body.global_position = pos
	_stats.trunks += 1


## ---------- mesh helpers ----------

## Merge every solid MeshInstance3D in a GLB scene into one ArrayMesh.
## min_height filters out flat particle-emitter planes (grass.glb ships two).
func _merged_mesh(scene_path: String, min_height: float) -> ArrayMesh:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return null
	var inst := packed.instantiate()
	var out := ArrayMesh.new()
	_collect_surfaces(inst, out, min_height)
	inst.free()
	if out.get_surface_count() == 0:
		return null
	return out


func _collect_surfaces(node: Node, out: ArrayMesh, min_height: float) -> void:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		var aabb := mi.mesh.get_aabb()
		if aabb.size.y >= min_height:
			for s in mi.mesh.get_surface_count():
				var idx := out.get_surface_count()
				out.add_surface_from_arrays(
					Mesh.PRIMITIVE_TRIANGLES, mi.mesh.surface_get_arrays(s))
				out.surface_set_material(idx, _adjusted(mi.get_active_material(s)))
	for child in node.get_children():
		_collect_surfaces(child, out, min_height)


## Match the low-poly rural look: flat roughness, low specular.
func _adjusted(mat: Material) -> Material:
	var std := mat as StandardMaterial3D
	if std == null:
		return mat
	var copy := std.duplicate() as StandardMaterial3D
	copy.roughness = 1.0
	copy.metallic = 0.0
	copy.metallic_specular = 0.15
	return copy
