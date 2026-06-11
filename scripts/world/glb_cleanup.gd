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
	"Bridge_Part_01",
]

const REMOVE_PREFIXES := [
	"MudTrap_",
	"MudPuddle_",
	"Charco_Pequeno_",
	"Monticulo_20ha_",
	"Lake_",
	"Lake_Reed",
	"Dock_",
	"Pasto_Alto_",
]


const ROPE_SCRIPT := preload("res://scripts/interactives/rope_descent.gd")
const MACHETE_SCRIPT := preload("res://scripts/collectibles/machete_pickup.gd")

## Logs de validación de la colocación del machete.
const DEBUG_QA := false
## Capa de colisión del terreno caminable (TerrainCollision).
const WORLD_LAYER := 2


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
		_add_interactive_area(
			"MachetePickup", machete_marker.global_position, MACHETE_SCRIPT,
			{}, true)


func _add_interactive_area(
	area_name: String,
	world_pos: Vector3,
	script: Script,
	extra_props: Dictionary = {},
	machete_visual: bool = false
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

	if machete_visual:
		area.add_child(_build_machete_visual())

	# current_scene may still be setting up its children during _ready;
	# attach deferred so add_child never fails (see runtime error log)
	_attach_area.call_deferred(area, world_pos, machete_visual)


func _attach_area(area: Area3D, world_pos: Vector3, snap_to_ground: bool = false) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_parent()
	var host := scene.get_node_or_null("InteractiveObjects")
	if host == null:
		host = scene
	host.add_child(area)
	area.global_position = world_pos
	if snap_to_ground:
		_snap_area_to_ground(area, world_pos)


## Ajusta el Area3D al suelo real con raycast vertical contra la capa World.
## Espera dos frames de física para que TerrainCollision ya exista.
func _snap_area_to_ground(area: Area3D, marker_pos: Vector3) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(area):
		return
	var world := area.get_world_3d()
	if world == null:
		return
	var from := marker_pos + Vector3.UP * 6.0
	var to := marker_pos + Vector3.DOWN * 120.0
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		if DEBUG_QA:
			print("[QA-MACHETE] marker=%v raycast SIN hit; queda en marcador" % marker_pos)
		return
	var ground: Vector3 = hit["position"]
	var collider_name := "?"
	if hit.has("collider") and hit["collider"] != null:
		collider_name = String((hit["collider"] as Node).name)
	area.global_position = ground + Vector3.UP * 0.1
	if DEBUG_QA:
		print("[QA-MACHETE] marker=%v hit=%v collider=%s final=%v" % [
			marker_pos, ground, collider_name, area.global_position])


## Machete visual tirado en el suelo: hoja + mango low poly, sin texturas.
func _build_machete_visual() -> Node3D:
	var holder := Node3D.new()
	holder.name = "Visual"
	# Acostado: la hoja corre sobre el plano del suelo, con leve inclinación.
	holder.rotation_degrees = Vector3(-86.0, 35.0, 0.0)
	holder.position = Vector3(0.0, 0.08, 0.0)

	var handle_mat := StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.18, 0.12, 0.06)
	handle_mat.roughness = 1.0
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.75, 0.78, 0.84)
	blade_mat.metallic = 0.6
	blade_mat.roughness = 0.3
	# Brillo leve para que se lea en el fondo oscuro del cráter.
	blade_mat.emission_enabled = true
	blade_mat.emission = Color(0.45, 0.5, 0.6)
	blade_mat.emission_energy_multiplier = 0.35

	var handle := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.06, 0.22, 0.06)
	handle.mesh = hb
	handle.material_override = handle_mat
	handle.position = Vector3(0.0, 0.11, 0.0)
	holder.add_child(handle)

	var blade := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.09, 0.78, 0.02)
	blade.mesh = bb
	blade.material_override = blade_mat
	blade.position = Vector3(0.0, 0.61, 0.0)
	holder.add_child(blade)
	return holder
