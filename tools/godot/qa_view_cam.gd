extends Camera3D
## QA fly-camera: cycles through fixed corral/gate/animal viewpoints so the
## running game can be screenshotted from gameplay-relevant angles.

const VIEWS := [
	# [position, look_at, label]
	[Vector3(121, 75, -128), Vector3(121, 7, -130), "corral full aerial"],
	[Vector3(80, 12, -114), Vector3(90, 6.8, -125), "gate close-up"],
	[Vector3(106, 13, -134), Vector3(90.5, 6.8, -124.5), "gate from inside"],
	[Vector3(48, 24, -10), Vector3(44, 17, -31), "rural animals"],
]
const VIEW_SECONDS := 9.0

var _t := 0.0
var _idx := -1


func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	# freeze daylight so QA shots are consistent
	var sky := get_tree().root.find_child("Sky3D", true, false)
	if sky != null:
		sky.set("current_time", 10.0)
		sky.set("minutes_per_day", 100000.0)
	make_current()
	_apply(0)


func _process(delta: float) -> void:
	if not current:
		return
	_t += delta
	var idx := int(_t / VIEW_SECONDS) % VIEWS.size()
	if idx != _idx:
		_apply(idx)


func _apply(idx: int) -> void:
	_idx = idx
	global_position = VIEWS[idx][0]
	look_at(VIEWS[idx][1])
	print("QA_VIEW: ", VIEWS[idx][2])
