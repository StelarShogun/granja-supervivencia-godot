extends SceneTree

const GROUND_MASK := 2

# Rural 3 + lake 3 + mountain 4 = 10 active slots (matches game_manager targets).
const ANIMAL_GLB_NAMES := [
	"Sp_An07", "Sp_An08", "Sp_An09",
	"Sp_An11", "Sp_An12", "Sp_An13",
	"Sp_An19", "Sp_An20", "Sp_An21", "Sp_An22",
]

const SNAP_NODES := {
	"SpawnPoints/Player_Spawn": "Sp_Player",
	"SpawnPoints/Diablo_Spawn": "Sp_Diablo",
	"SpawnPoints/Diablo_Cave_Spawn": "Sp_Diablo_Cave",
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var packed := load("res://scenes/levels/main.tscn") as PackedScene
	var main := packed.instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame

	var terreno := main.get_node("Level/Terreno_Finca")
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state

	for godot_path in SNAP_NODES:
		var glb_name: String = SNAP_NODES[godot_path]
		var glb := _find_node(terreno, glb_name) as Node3D
		if glb:
			var p := glb.global_position
			p.y = _ground_y(p, space) + 0.5
			print("SYNC %s = %s" % [godot_path, p])

	for i in ANIMAL_GLB_NAMES.size():
		var glb := _find_node(terreno, ANIMAL_GLB_NAMES[i]) as Node3D
		if glb == null:
			print("MISSING ", ANIMAL_GLB_NAMES[i])
			continue
		var p := glb.global_position
		p.y = _ground_y(p, space) + 0.35
		print("SYNC SpawnPoints/AnimalSpawns/AnimalSpawn_%02d = %s" % [i + 1, p])

	# Corral / granero / gate from GLB meshes
	for label in ["Granero_Floor", "Corral_01"]:
		var n := _find_node(terreno, label) as Node3D
		if n:
			print("REF %s = %s" % [label, n.global_position])

	var bridge := _find_node(terreno, "Bridge_01") as Node3D
	if bridge:
		var bp := bridge.global_position
		bp.y = _ground_y(bp, space) + 1.0
		print("SYNC ScenarioColliders/BridgeCollider = %s" % bp)
		print("SYNC InteractiveObjects/BridgeTrigger = %s" % Vector3(bp.x, bp.y + 1.2, bp.z))

	var cave_lip := _find_node(terreno, "Cave_Lip_Top") as Node3D
	if cave_lip:
		print("SYNC InteractiveObjects/CaveTrigger = %s" % cave_lip.global_position)
		var cave_ground := _ground_y(Vector3(165.0, 0.0, 178.0), space)
		print(
			"SYNC ScenarioColliders/CaveCollider = %s"
			% Vector3(165.0, cave_ground + 7.0, 178.0)
		)

	for label_path in [
		["corral", Vector3(124.653, 0.0, -113.366)],
		["gate", Vector3(101.242, 0.0, -124.866)],
		["bridge_old", Vector3(27.6, 0.0, -10.0)],
		["cacique1", Vector3(95.0, 0.0, -70.0)],
		["cacique2", Vector3(118.0, 0.0, -100.0)],
		["cacique3", Vector3(105.0, 0.0, -115.0)],
	]:
		var gy := _ground_y(label_path[1], space)
		print("GROUND %s xz=%s y=%.3f" % [label_path[0], label_path[1], gy])

	main.queue_free()
	quit(0)


func _ground_y(pos: Vector3, space: PhysicsDirectSpaceState3D) -> float:
	var from := Vector3(pos.x, pos.y + 120.0, pos.z)
	var to := Vector3(pos.x, pos.y - 200.0, pos.z)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = GROUND_MASK
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		from = Vector3(pos.x, 200.0, pos.z)
		to = Vector3(pos.x, -200.0, pos.z)
		hit = space.intersect_ray(q)
	if hit.is_empty():
		return pos.y
	return float(hit.position.y)


func _find_node(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for c in node.get_children():
		var f := _find_node(c, name)
		if f:
			return f
	return null
