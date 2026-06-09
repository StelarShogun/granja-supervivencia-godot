extends Node3D

## Removes obsolete / duplicate meshes that should no longer ship in Terreno_Finca.glb.
## Keeps runtime stable when the editor still holds a stale GLB instance.

const REMOVE_EXACT := [
	"Barn_01",
	"Corral_01",
	"Ranch_01",
	"Plain_Farm_Area",
	"Bridge_Ramp_South",
	"Lake_Water_Surface",
	"River_Water_Surface",
	"Borde_Alto_Norte",
]

const REMOVE_PREFIXES := [
	"MudTrap_",
	"MudPuddle_",
	"Charco_Pequeno_",
	"Monticulo_20ha_",
	"Lake_",
	"Lake_Reed",
	"Dock_",
]


const ROPE_SCRIPT := preload("res://scripts/interactives/rope_descent.gd")
const MACHETE_SCRIPT := preload("res://scripts/collectibles/machete_pickup.gd")


func _ready() -> void:
	var terreno := get_parent().get_node_or_null("Terreno_Finca")
	if terreno == null:
		return
	_cleanup(terreno)
	_spawn_gorge_interactives(terreno)


func _cleanup(root: Node) -> void:
	for child in root.get_children():
		if _should_remove(child.name):
			child.queue_free()
			continue
		_cleanup(child)


func _should_remove(node_name: String) -> bool:
	if REMOVE_EXACT.has(node_name):
		return true
	for prefix in REMOVE_PREFIXES:
		if node_name.begins_with(prefix):
			return true
	return false


func _spawn_gorge_interactives(terreno: Node) -> void:
	var top := terreno.find_child("Sp_Rope_Top", true, false) as Node3D
	var bottom := terreno.find_child("Sp_Rope_Bottom", true, false) as Node3D
	if top != null and bottom != null:
		_add_interactive_area(
			"RopeDescent",
			top.global_position,
			ROPE_SCRIPT,
			{"bottom_position": bottom.global_position}
		)

	var machete_marker := terreno.find_child("Sp_Machete", true, false) as Node3D
	if machete_marker != null:
		_add_interactive_area("MachetePickup", machete_marker.global_position, MACHETE_SCRIPT)


func _add_interactive_area(
	area_name: String,
	world_pos: Vector3,
	script: Script,
	extra_props: Dictionary = {}
) -> void:
	var area := Area3D.new()
	area.name = area_name
	area.script = script
	for key in extra_props:
		area.set(key, extra_props[key])

	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 1.2
	cylinder.height = 2.0
	shape.shape = cylinder
	shape.position = Vector3(0.0, 1.0, 0.0)
	area.add_child(shape)

	# current_scene may still be setting up its children during _ready;
	# attach deferred so add_child never fails (see runtime error log)
	_attach_area.call_deferred(area, world_pos)


func _attach_area(area: Area3D, world_pos: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_parent()
	var host := scene.get_node_or_null("InteractiveObjects")
	if host == null:
		host = scene
	host.add_child(area)
	area.global_position = world_pos
