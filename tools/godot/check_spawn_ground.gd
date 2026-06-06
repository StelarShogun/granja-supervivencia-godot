extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var packed := load("res://scenes/levels/main.tscn") as PackedScene
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var spawn := main.get_node("SpawnPoints/Player_Spawn") as Node3D
	var terreno := main.get_node("Level/Terreno_Finca")

	print("Player_Spawn: ", spawn.global_position)

	for name in ["Terrain_Main", "Mtn_Main", "Sp_Player", "Granero"]:
		var n := _find_node(terreno, name) as Node3D
		if n:
			print(name, " global=", n.global_position, " local=", n.position, " scale=", n.scale)
			if n is MeshInstance3D:
				var mi := n as MeshInstance3D
				if mi.mesh:
					var aabb := mi.mesh.get_aabb()
					print("  mesh_aabb size=", aabb.size, " pos=", aabb.position)

	# Sample terrain mesh vertex world Y near spawn xz
	var terrain := _find_node(terreno, "Terrain_Main") as MeshInstance3D
	if terrain and terrain.mesh:
		var best_y := -9999.0
		var sx := spawn.global_position.x
		var sz := spawn.global_position.z
		for i in min(terrain.mesh.get_surface_count(), 1):
			var arrays := terrain.mesh.surface_get_arrays(i)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for v in verts:
				var w := terrain.global_transform * v
				var d2 := (w.x - sx) * (w.x - sx) + (w.z - sz) * (w.z - sz)
				if d2 < 25.0 and w.y > best_y:
					best_y = w.y
		print("Terrain_Main max vertex Y within 5m of spawn: ", best_y)

	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var from := spawn.global_position + Vector3(0, 80, 0)
	var to := spawn.global_position + Vector3(0, -100, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 2
	var hit: Dictionary = space.intersect_ray(q)
	if hit:
		print("Collision hit y=", hit.position.y, " collider=", hit.collider.name)

	var player := main.get_node("Player") as CharacterBody3D
	player.global_position = spawn.global_position
	for i in 30:
		await physics_frame
	print("Player after settle: ", player.global_position, " on_floor=", player.is_on_floor(), " vel=", player.velocity)

	main.queue_free()
	quit(0)


func _find_node(node: Node, name: String) -> Node3D:
	if node == null:
		return null
	if node.name == name and node is Node3D:
		return node
	for c in node.get_children():
		var f := _find_node(c, name)
		if f:
			return f
	return null
