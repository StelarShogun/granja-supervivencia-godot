@tool
extends SceneTree

const VS := preload("res://scripts/world/vegetation_scatter.gd")


func _init() -> void:
	var node: Node3D = VS.new()
	var mesh: ArrayMesh = node._build_grass_mesh()
	if mesh == null:
		print("FAIL: grass mesh null")
		node.free()
		quit(1)
		return
	var aabb := mesh.get_aabb()
	print("grass mesh OK surfaces=", mesh.get_surface_count(),
		" height=", aabb.size.y, " width=", aabb.size.x)
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s) as StandardMaterial3D
		print("  surf", s, " transparency=", mat.transparency,
			" cull=", mat.cull_mode, " vtxcol=", mat.vertex_color_use_as_albedo,
			" albedo=", mat.albedo_color, " tex=", mat.albedo_texture)
	node.free()
	quit(0)
