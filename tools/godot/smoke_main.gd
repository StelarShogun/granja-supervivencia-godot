@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/levels/main.tscn") as PackedScene
	if packed == null:
		print("FAIL: main.tscn null")
		quit(1); return
	var main := packed.instantiate()
	root.add_child(main)
	# vegetation_scatter waits 2 physics frames then builds; give it margin.
	for i in 25:
		await physics_frame
	# Report grass MultiMesh coverage so the scatter is verified to have run.
	var grass := 0
	var grass_inst := 0
	for n in root.find_children("Grass_*", "MultiMeshInstance3D", true, false):
		grass += 1
		if n.multimesh != null:
			grass_inst += n.multimesh.instance_count
	print("SMOKE main.tscn OK  grass_chunks=", grass, " grass_instances=", grass_inst)
	quit(0)
