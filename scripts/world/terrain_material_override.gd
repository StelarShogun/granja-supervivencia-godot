extends Node

@export var terrain_root_path: NodePath = NodePath("../Level/Terreno_Finca")
@export var tex_grass: Texture2D = preload("res://assets/models/environment/Terreno_Finca_forrest_ground_01_diff_1k.jpg")
@export var tex_dirt: Texture2D = preload("res://assets/models/environment/Terreno_Finca_dirt_floor_diff_1k.jpg")

# Mesh names that are pure terrain surface (not trees, rocks, structures)
const BLEND_PREFIXES := [
	"Terrain_", "RuralZone", "Plain_", "Path_", "OpenField",
	"Grass_", "Ground_", "FarmField", "Field_", "Finca_Plain",
]
const BLEND_MATS := [
	"MAT_Grass", "MAT_Dirt", "MAT_Rural", "MAT_Forest",
	"MAT_Path", "MAT_Hay",
]
# Flat water surfaces baked into the GLB. The procedural WaterSystem is the
# source of truth, so these duplicates are hidden at runtime to avoid double
# surfaces and z-fighting. Their basin/bed/bank geometry is kept.
const HIDE_NAMES := [
	# Only the flat baked water planes are hidden; the procedural WaterSystem
	# is the source of truth for the water surface. The GLB River_Bed/Banks are
	# kept visible — their wet-mud texture is the real channel (cauce), and the
	# procedural water is widened to fill it.
	"Lake_Water_Surface", "River_Water_Surface",
]

var _blend_material: ShaderMaterial


func _ready() -> void:
	call_deferred("_apply_overrides")


func _apply_overrides() -> void:
	var shader := load("res://shaders/terrain_blend.gdshader") as Shader
	if shader == null:
		return

	_blend_material = ShaderMaterial.new()
	_blend_material.shader = shader
	if tex_grass != null:
		_blend_material.set_shader_parameter("tex_grass", tex_grass)
	if tex_dirt != null:
		_blend_material.set_shader_parameter("tex_dirt", tex_dirt)

	var root := get_node_or_null(terrain_root_path)
	if root == null:
		return

	_override_children(root)


func _override_children(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.name in HIDE_NAMES:
			mi.visible = false
		elif _should_blend(mi):
			# Override all surface materials
			for s in mi.get_surface_override_material_count():
				mi.set_surface_override_material(s, _blend_material)
	for child in node.get_children():
		_override_children(child)


func _should_blend(mi: MeshInstance3D) -> bool:
	# Match by name prefix
	for prefix in BLEND_PREFIXES:
		if mi.name.begins_with(prefix):
			return true
	# Match by material name on the mesh resource
	if mi.mesh == null:
		return false
	for s in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(s)
		if mat != null and mat.resource_name in BLEND_MATS:
			return true
	return false
