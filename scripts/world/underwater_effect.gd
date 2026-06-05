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
	var submerged := false
	if player.has_method("is_submerged"):
		submerged = bool(player.is_submerged())
	_overlay.visible = submerged
