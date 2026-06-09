extends SceneTree
## QA: every spawned animal must rest on the ground (|base - terrain| <= 0.15)
## right after spawn and again after wandering for a few seconds.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var main := (load("res://scenes/levels/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _i in 12:
		await physics_frame

	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	_check(main, space, "after spawn")

	# let them wander across slopes, then re-check
	for _i in 240:
		await physics_frame
	_check(main, space, "after wandering")
	quit(0)


func _check(main: Node, space: PhysicsDirectSpaceState3D, label: String) -> void:
	var animals := main.get_tree().get_nodes_in_group("animals")
	var bad := 0
	print("=== QA_ANIMALS %s: %d animals ===" % [label, animals.size()])
	if animals.is_empty():
		print("NO ANIMALS INSTANCED")
		bad += 1
	for a in animals:
		if not (a is Node3D):
			continue
		var p: Vector3 = (a as Node3D).global_position
		var q := PhysicsRayQueryParameters3D.create(
			p + Vector3.UP * 80.0, p + Vector3.DOWN * 220.0, 2)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			print("NO GROUND under %s at %s" % [a.name, p])
			bad += 1
			continue
		var gap: float = p.y - hit.position.y
		var status := "OK" if absf(gap) <= 0.15 else "FLOAT" if gap > 0 else "BURIED"
		if status != "OK":
			bad += 1
		print("%s %s gap=%.2f at (%.0f, %.0f)" % [status, a.name, gap, p.x, p.z])
	print("QA_ANIMALS_%s=%s" % [label.replace(" ", "_"), "PASS" if bad == 0 else "FAIL"])
