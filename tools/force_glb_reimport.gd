@tool
extends EditorScript

func _run() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	fs.reimport_files(["res://assets/models/environment/Terreno_Finca.glb"])
	print("[ForceReimport] GLB reimport triggered")
