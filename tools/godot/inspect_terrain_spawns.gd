extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var packed := load("res://assets/models/environment/Terreno_Finca.glb") as PackedScene
	if packed == null:
		push_error("Could not load Terreno_Finca.glb")
		quit(1)
		return

	var terrain := packed.instantiate()
	root.add_child(terrain)
	await process_frame

	var stats := {
		"MeshInstance3D": 0,
		"StaticBody3D": 0,
		"CollisionShape3D": 0,
		"MarkerLike": 0,
	}
	var large_meshes: Array[Dictionary] = []
	_collect_stats(terrain, stats)
	_collect_large_meshes(terrain, large_meshes)
	large_meshes.sort_custom(_sort_by_area_desc)
	print("STATS=%s" % stats)
	for i in mini(large_meshes.size(), 30):
		var item := large_meshes[i]
		print("MESH=%s size=%s pos=%s" % [item["path"], item["size"], item["position"]])
	_print_spawn_nodes(terrain)
	terrain.queue_free()
	await process_frame
	quit(0)


func _print_spawn_nodes(node: Node) -> void:
	if node.name.begins_with("Sp_") and node is Node3D:
		var node_3d := node as Node3D
		print("%s=%s" % [node.name, node_3d.global_position])

	for child in node.get_children():
		_print_spawn_nodes(child)


func _collect_stats(node: Node, stats: Dictionary) -> void:
	if node is MeshInstance3D:
		stats["MeshInstance3D"] += 1
	if node is StaticBody3D:
		stats["StaticBody3D"] += 1
	if node is CollisionShape3D:
		stats["CollisionShape3D"] += 1
	if node.name.begins_with("Sp_"):
		stats["MarkerLike"] += 1

	for child in node.get_children():
		_collect_stats(child, stats)


func _collect_large_meshes(node: Node, large_meshes: Array[Dictionary]) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var aabb := mesh_node.get_aabb()
		var size := aabb.size * mesh_node.global_transform.basis.get_scale()
		var area := absf(size.x * size.z)
		if area > 100.0 or size.length() > 40.0:
			large_meshes.append({
				"path": str(mesh_node.get_path()),
				"size": size,
				"position": mesh_node.global_position,
				"area": area,
			})

	for child in node.get_children():
		_collect_large_meshes(child, large_meshes)


func _sort_by_area_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a["area"]) > float(b["area"])
