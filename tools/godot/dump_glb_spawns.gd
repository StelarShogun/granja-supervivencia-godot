extends SceneTree

const NAMES := [
	"Sp_Player", "Sp_Diablo", "Sp_Diablo_Cave",
	"Sp_An05", "Sp_An06", "Sp_An07", "Sp_An08", "Sp_An09",
	"Sp_An11", "Sp_An12", "Sp_An13",
	"Sp_An19", "Sp_An20", "Sp_An21", "Sp_An22",
	"Cave_Lip_Top", "Granero_Floor",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var packed := load("res://scenes/levels/main.tscn") as PackedScene
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	var terreno := main.get_node("Level/Terreno_Finca")
	for name in NAMES:
		var n := _find(terreno, name) as Node3D
		if n:
			print("%s = %s" % [name, n.global_position])
		else:
			print("%s MISSING" % name)
	main.queue_free()
	quit(0)


func _find(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for c in node.get_children():
		var f := _find(c, name)
		if f:
			return f
	return null
