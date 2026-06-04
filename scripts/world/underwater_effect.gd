extends CanvasLayer

@onready var _overlay: ColorRect = $Overlay

func _ready() -> void:
	_overlay.visible = false


func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_overlay.visible = false
		return
	var player: Node = players[0]
	var in_deep: bool = player.get("is_in_water") and player.get("_water_is_deep")
	var surface_y: float = float(player.get("_water_surface_y"))
	var submerged: bool = in_deep and (player as Node3D).global_position.y < surface_y - 0.3
	_overlay.visible = submerged
