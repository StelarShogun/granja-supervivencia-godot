extends SceneTree

const NAMES := [
	"Bridge_01", "Bridge_Ramp_South", "Corral_01", "Cave_Lip_Top",
	"Granero_Floor", "Gate_Corral", "Corral_Gate",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var packed := load("res://assets/models/environment/Terreno_Finca.glb") as PackedScene
	var root_node := packed.instantiate()
	root.add_child(root_node)
	await process_frame
	for name in NAMES:
		var n := _find(root_node, name) as Node3D
		if n:
			print("%s world=%s path=%s" % [name, n.global_position, n.get_path()])
		else:
			print("%s MISSING" % name)
	root_node.queue_free()
	quit(0)


func _find(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for c in node.get_children():
		var f := _find(c, name)
		if f:
			return f
	return null
