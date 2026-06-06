extends SceneTree

const GROUND_MASK := 2
const MAX_GROUND_GAP := 3.0
const SKIP_GROUND_CHECK := [
	"FenceCollider", "Granero", "BridgeCollider", "BridgeTrigger", "CaveCollider",
	"Diablo_Cave_Spawn",
]
const MAX_WATER_SURFACE_GAP := 4.0

var _issues: Array[String] = []
var _ok: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var packed := load("res://scenes/levels/main.tscn") as PackedScene
	var main := packed.instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame

	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var terreno := main.get_node_or_null("Level/Terreno_Finca")

	_audit_glb_spawns(terreno, main, space)
	_audit_markers(main, space, "SpawnPoints")
	_audit_markers(main, space, "ScenarioColliders")
	_audit_markers(main, space, "InteractiveObjects")
	_audit_water(main, space)
	_audit_glb_content(terreno)

	print("=== AUDIT_OK (%d) ===" % _ok.size())
	for line in _ok:
		print("OK: ", line)
	print("=== AUDIT_ISSUES (%d) ===" % _issues.size())
	for line in _issues:
		print("ISSUE: ", line)

	var exit_code := 0 if _issues.is_empty() else 1
	main.queue_free()
	quit(exit_code)


func _audit_glb_spawns(terreno: Node, main: Node, space: PhysicsDirectSpaceState3D) -> void:
	if terreno == null:
		_issues.append("Terreno_Finca missing")
		return

	var pairs := [
		["Sp_Player", "SpawnPoints/Player_Spawn"],
		["Sp_Diablo", "SpawnPoints/Diablo_Spawn"],
		["Sp_Diablo_Cave", "SpawnPoints/Diablo_Cave_Spawn"],
	]
	for pair in pairs:
		var glb := _find_node(terreno, pair[0]) as Node3D
		var godot := main.get_node_or_null(pair[1]) as Node3D
		if glb == null:
			_issues.append("GLB marker missing: %s" % pair[0])
			continue
		if godot == null:
			_issues.append("Godot marker missing: %s" % pair[1])
			continue
		var delta: Vector3 = godot.global_position - glb.global_position
		if delta.length() > 1.5:
			_issues.append(
				"%s vs %s delta=%s (glb=%s godot=%s)"
				% [pair[0], pair[1], delta, glb.global_position, godot.global_position]
			)
		else:
			_ok.append("%s aligned to %s (delta=%.2f)" % [pair[0], pair[1], delta.length()])


func _audit_markers(main: Node, space: PhysicsDirectSpaceState3D, root_name: String) -> void:
	var root := main.get_node_or_null(root_name)
	if root == null:
		_issues.append("Node missing: %s" % root_name)
		return
	_walk_markers(root, root_name, space)


func _walk_markers(node: Node, prefix: String, space: PhysicsDirectSpaceState3D) -> void:
	if node is Node3D and (node is StaticBody3D or node is Area3D):
		var p := (node as Node3D).global_position
		if node.name.contains("River") or node.name.contains("Lake") or node.name.contains("Water"):
			return
		if node is Area3D and node.get_parent() != null and node.get_parent().name == "RiverArea":
			return
		if not _should_skip_ground(node.name):
			_check_ground("%s/%s" % [prefix, node.name], p, space)
	for child in node.get_children():
		var child_path := "%s/%s" % [prefix, child.name]
		if child is Marker3D:
			if not _should_skip_ground(child.name):
				_check_ground(child_path, (child as Node3D).global_position, space)
			continue
		_walk_markers(child, child_path, space)


func _check_ground(label: String, pos: Vector3, space: PhysicsDirectSpaceState3D) -> void:
	var hit := _ray_ground(pos, space)
	if hit.is_empty():
		_issues.append("%s: no ground hit at %s" % [label, pos])
		return
	var gap := pos.y - float(hit.position.y)
	if absf(gap) > MAX_GROUND_GAP:
		_issues.append(
			"%s: Y gap %.2f (marker=%.2f ground=%.2f) at %s"
			% [label, gap, pos.y, hit.position.y, Vector2(pos.x, pos.z)]
		)
	else:
		_ok.append("%s ground gap %.2f" % [label, gap])


func _audit_water(main: Node, space: PhysicsDirectSpaceState3D) -> void:
	var river := main.get_node_or_null("WaterGameplay/RiverArea")
	if river:
		var seg_count := 0
		var bad_segs := 0
		for child in river.get_children():
			if child is CollisionShape3D:
				seg_count += 1
				var wp := (child as Node3D).global_position
				var rh := _ray_ground(wp, space)
				if rh.is_empty():
					bad_segs += 1
					_issues.append("River seg %s: no ground at %s" % [child.name, wp])
				elif wp.y - float(rh.position.y) > MAX_WATER_SURFACE_GAP:
					bad_segs += 1
					_issues.append(
						"River seg %s: surface %.2f vs ground %.2f"
						% [child.name, wp.y, rh.position.y]
					)
		if bad_segs == 0:
			_ok.append("River %d segments aligned" % seg_count)


func _audit_glb_content(terreno: Node) -> void:
	if terreno == null:
		return
	var required := ["Terrain_Main", "Mtn_Main", "Sp_Player"]
	for name in required:
		if _find_node(terreno, name) == null:
			_issues.append("GLB missing node: %s" % name)
		else:
			_ok.append("GLB has %s" % name)
	for name in ["Granero_Floor", "Corral_Fence_000", "Bridge_01"]:
		var n := _find_node(terreno, name)
		if n == null:
			_issues.append("GLB missing structure: %s" % name)
		elif n is Node3D and n.global_position.length() < 0.01:
			_issues.append("%s at world origin — likely unplaced" % name)
		else:
			_ok.append("GLB has %s at %s" % [name, (n as Node3D).global_position if n is Node3D else "n/a"])


func _should_skip_ground(node_name: String) -> bool:
	for token in SKIP_GROUND_CHECK:
		if node_name.contains(token):
			return true
	return false


func _ray_ground(pos: Vector3, space: PhysicsDirectSpaceState3D) -> Dictionary:
	var from := pos + Vector3(0, 120, 0)
	var to := pos + Vector3(0, -200, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = GROUND_MASK
	return space.intersect_ray(q)


func _find_node(node: Node, name: String) -> Node:
	if node == null:
		return null
	if node.name == name:
		return node
	for c in node.get_children():
		var f := _find_node(c, name)
		if f:
			return f
	return null
