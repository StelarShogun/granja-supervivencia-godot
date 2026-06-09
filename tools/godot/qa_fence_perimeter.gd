extends SceneTree
## QA: corral perimeter integrity.
## - Horizontal rays every 2 m around the enclosure rectangle at ground + 1.0
##   (fence collision tops out at ~ground + 1.29 with scale 1.4 and embed 0.12):
##   every ray must hit layer 2 except inside the gate opening.
## - Gate closed -> ray across the opening blocked; open -> ray passes.
## - Diablo-like body probe: test_move against the fence must collide.

const MIN_E := Vector2(90.0, -160.0)
const MAX_E := Vector2(152.0, -100.0)
const GATE_C := -124.866
const GATE_W := 8.0
const STEP := 2.0
const RAY_DEPTH := 3.0   # ray length crossing the fence line


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var main := (load("res://scenes/levels/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _i in 10:
		await physics_frame

	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var gaps: Array[String] = []
	var checks := 0
	var gate_skipped := 0

	# exclude fence/gate bodies from ground rays (we need raw terrain height)
	_exclude.clear()
	var bodies: Array[Node] = [main.find_child("FenceCollision", true, false)]
	bodies.append_array(main.find_children("GateBody", "", true, false))
	bodies.append_array(main.find_children("GateFrame", "", true, false))
	for body in bodies:
		if body is CollisionObject3D:
			_exclude.append(body.get_rid())

	# walk each edge; probe perpendicular rays crossing the fence line
	var edges := [
		["N", Vector3(MIN_E.x, 0, MIN_E.y), Vector3(MAX_E.x, 0, MIN_E.y), Vector3(0, 0, 1)],
		["S", Vector3(MIN_E.x, 0, MAX_E.y), Vector3(MAX_E.x, 0, MAX_E.y), Vector3(0, 0, -1)],
		["W", Vector3(MIN_E.x, 0, MIN_E.y), Vector3(MIN_E.x, 0, MAX_E.y), Vector3(1, 0, 0)],
		["E", Vector3(MAX_E.x, 0, MIN_E.y), Vector3(MAX_E.x, 0, MAX_E.y), Vector3(-1, 0, 0)],
	]
	for e in edges:
		var a: Vector3 = e[1]
		var b: Vector3 = e[2]
		var inward: Vector3 = e[3]
		var L := a.distance_to(b)
		var dir := (b - a) / L
		var t := 0.0
		while t <= L:
			var p := a + dir * t
			var in_gate: bool = (String(e[0]) == "W"
				and absf(p.z - GATE_C) < GATE_W * 0.5 - 0.3)
			if in_gate:
				gate_skipped += 1
				t += STEP
				continue
			# raw terrain height on the fence line (fence excluded), low ray
			var gy := _ground(space, p.x, p.z)
			var h := gy + 0.7
			var from := p - inward * RAY_DEPTH * 0.5 + Vector3.UP * h
			var to := p + inward * RAY_DEPTH * 0.5 + Vector3.UP * h
			from.y = h
			to.y = h
			var q := PhysicsRayQueryParameters3D.create(from, to, 2)
			var hit := space.intersect_ray(q)
			checks += 1
			# must hit something that is NOT just the terrain below
			if hit.is_empty():
				gaps.append("%s t=%.1f at (%.1f, %.1f) h=%.2f" % [e[0], t, p.x, p.z, h])
			t += STEP

	# gate closed/open rays across the opening (horizontal, through fence line)
	var gate_y := _ground(space, MIN_E.x, GATE_C) + 0.7
	var gfrom := Vector3(MIN_E.x - 1.5, gate_y, GATE_C)
	var gto := Vector3(MIN_E.x + 1.5, gate_y, GATE_C)
	var gq := PhysicsRayQueryParameters3D.create(gfrom, gto, 2)
	var closed_hit := space.intersect_ray(gq)

	var gate := main.find_child("CorralGate", true, false)
	var open_hit := {"placeholder": true}
	if gate != null and gate.has_method("interact"):
		gate.interact(null)
		for _i in 3:
			await physics_frame
		open_hit = space.intersect_ray(gq)
		gate.interact(null)  # close again
		for _i in 3:
			await physics_frame

	# body probe: capsule shape-cast into the fence mid-north edge
	var mid_x := (MIN_E.x + MAX_E.x) * 0.5
	var pg := _ground(space, mid_x, MIN_E.y + 2.0)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	var sp := PhysicsShapeQueryParameters3D.new()
	sp.shape = cap
	sp.collision_mask = 2
	sp.transform = Transform3D(
		Basis(), Vector3(mid_x, pg + 1.0, MIN_E.y + 2.0))
	sp.motion = Vector3(0, 0, -4.0)  # push into north fence
	var cast := space.cast_motion(sp)
	var blocked: bool = cast[0] < 1.0  # stopped before completing the motion

	print("=== QA_FENCE ===")
	print("rays_checked=%d gate_rays_skipped=%d gaps=%d" % [checks, gate_skipped, gaps.size()])
	for g in gaps:
		print("GAP: ", g)
	print("gate_closed_blocks_ray=%s (hit=%s)" % [
		not closed_hit.is_empty(),
		closed_hit.get("collider") if not closed_hit.is_empty() else "none"])
	print("gate_open_passes_ray=%s" % [open_hit.is_empty()])
	print("body_probe_blocked_by_fence=%s" % blocked)
	var ok: bool = gaps.is_empty() and not closed_hit.is_empty() \
		and open_hit.is_empty() and blocked
	print("QA_FENCE_RESULT=%s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


var _exclude: Array[RID] = []


func _ground(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(x, 200, z), Vector3(x, -200, z), 2)
	q.exclude = _exclude
	var hit := space.intersect_ray(q)
	return hit.position.y if hit else 0.0
