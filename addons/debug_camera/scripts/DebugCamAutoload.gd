extends Node

var debug_cam_2d = preload("res://addons/debug_camera/scripts/DebugCamera2D.gd")
var debug_cam_3d = preload("res://addons/debug_camera/scripts/DebugCamera3D.gd")


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var scene := tree.current_scene
	if scene == null:
		return

	var cam_2d := debug_cam_2d.new()
	var cam_3d := debug_cam_3d.new()

	if not scene.tree_exited.is_connected(_new_scene):
		scene.tree_exited.connect(_new_scene)

	if get_viewport().get_camera_2d() != null:
		scene.add_child(cam_2d)
	elif get_viewport().get_camera_3d() != null:
		scene.add_child(cam_3d)


func _new_scene():
	if get_tree() != null:
		await get_tree().node_added
		await get_tree().get_current_scene().ready
		_ready()
