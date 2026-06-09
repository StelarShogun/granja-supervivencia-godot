extends SceneTree
## QA probe: verify player-blocking collision (layer 2) via horizontal raycasts
## at player chest height against barn, shed, fence, bridge, big rocks, trees.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var packed := load("res://scenes/levels/main.tscn") as PackedScene
	var main := packed.instantiate()
	root.add_child(main)
	for _i in 8:
		await physics_frame

	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state

	var probes := [
		# name, from (outside), to (inside target)
		["Barn wall", Vector3(134, 11.2, -156), Vector3(134, 11.2, -146)],
		["Shed wall", Vector3(103, 9.5, -158), Vector3(103, 9.5, -150)],
		["Corral fence N", Vector3(110, 9.6, -168), Vector3(110, 9.6, -152)],
	]

	var bridge := main.find_child("Bridge_Part_01", true, false) as Node3D
	if bridge != null:
		var bp: Vector3 = bridge.global_position
		probes.append(["Bridge deck (down)",
			bp + Vector3(0, 30, 0), bp + Vector3(0, -30, 0)])

	# auto-pick a big rock and a tree from TerrainCollision proxies
	var terreno := main.get_node_or_null("Level/Terreno_Finca")
	var rock: Node3D = null
	var tree: Node3D = null
	var stack: Array = [terreno]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			if rock == null and String(n.name).begins_with("Rock_M"):
				rock = n
			if tree == null and String(n.name).begins_with("Lib_Tree"):
				tree = n
		for c in n.get_children():
			stack.append(c)
	for pair in [["Rock", rock], ["Tree trunk", tree]]:
		var node: Node3D = pair[1]
		if node == null:
			continue
		var aabb: AABB = (node as MeshInstance3D).get_aabb()
		var center: Vector3 = node.global_transform * aabb.get_center()
		var base_local: Vector3 = aabb.get_center()
		base_local.y = aabb.position.y
		var base: Vector3 = node.global_transform * base_local
		var h := base.y + 1.2
		probes.append(["%s (%s)" % [pair[0], node.name],
			Vector3(center.x - 6, h, center.z), Vector3(center.x, h, center.z)])

	for p in probes:
		var q := PhysicsRayQueryParameters3D.create(p[1], p[2], 2)
		var hit := space.intersect_ray(q)
		if hit:
			print("BLOCK OK: %s hit %s at %.1f m" % [
				p[0], hit.collider.name, p[1].distance_to(hit.position)])
		else:
			print("NO BLOCK: %s (ray %s -> %s)" % [p[0], p[1], p[2]])

	quit()
