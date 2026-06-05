extends Node3D
## Re-projects water-edge decoration (reeds, river rocks) onto the real terrain
## surface at runtime.
##
## The props are baked into the imported GLB, so their positions cannot be
## overridden durably in the scene file. After the terrain collision is built we
## raycast straight down from each prop and snap its base to the ground/bank/bed,
## removing the "floating" and "crossing the water" artefacts. Horizontal
## position is preserved; only height is corrected.

@export var terrain_root_path: NodePath = NodePath("../Level/Terreno_Finca")
## Physics layers the ground/bank/bed collision lives on (terrain builder uses 2).
@export_flags_3d_physics var terrain_mask: int = 2
@export var ray_up: float = 40.0
@export var ray_down: float = 120.0
## Delay so the terrain collision (built deferred in _ready) exists first.
@export var start_delay: float = 0.7
@export var enabled: bool = true

## Name-prefix groups and how far their origin sits relative to the hit point.
## Reeds grow up from their base, so base sits on the ground (offset 0).
## Rocks read better slightly embedded.
const REED_PREFIXES := ["LakeReed_", "RiverReed_"]
const ROCK_PREFIXES := ["River_Rock_", "River_Bank_Rock_"]
@export var reed_offset: float = 0.0
@export var rock_offset: float = -0.3


func _ready() -> void:
	if not enabled:
		return
	await get_tree().create_timer(start_delay).timeout
	reproject_all()


func reproject_all() -> void:
	var root := get_node_or_null(terrain_root_path)
	if root == null:
		push_warning("WaterDecoReproject: terrain root not found.")
		return

	var moved_reeds := 0
	var moved_rocks := 0
	var missed := 0
	var targets: Array[MeshInstance3D] = []
	_collect(root, targets)

	for mi in targets:
		var offset: float = reed_offset if _matches(mi.name, REED_PREFIXES) else rock_offset
		var ground_y := _ground_height(mi.global_position)
		if is_nan(ground_y):
			missed += 1
			continue
		var pos := mi.global_position
		pos.y = ground_y + offset
		mi.global_position = pos
		if _matches(mi.name, REED_PREFIXES):
			moved_reeds += 1
		else:
			moved_rocks += 1

	print("[WaterDecoReproject] reeds=%d rocks=%d missed=%d" % [moved_reeds, moved_rocks, missed])


func _ground_height(world_pos: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	if space == null:
		return NAN
	var from := Vector3(world_pos.x, world_pos.y + ray_up, world_pos.z)
	var to := Vector3(world_pos.x, world_pos.y - ray_down, world_pos.z)
	var query := PhysicsRayQueryParameters3D.create(from, to, terrain_mask)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return NAN
	return float(hit.position.y)


func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and _is_target(node.name):
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect(child, out)


func _is_target(node_name: StringName) -> bool:
	return _matches(node_name, REED_PREFIXES) or _matches(node_name, ROCK_PREFIXES)


func _matches(node_name: StringName, prefixes: Array) -> bool:
	var n := str(node_name)
	for p in prefixes:
		if n.begins_with(p):
			return true
	return false
