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


func _ready() -> void:
	var terreno := get_parent().get_node_or_null("Terreno_Finca")
	if terreno == null:
		return
	_cleanup(terreno)


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
