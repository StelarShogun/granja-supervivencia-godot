@tool
extends SceneTree

const SFX := [
	"res://assets/audio/sfx/salto.wav",
	"res://assets/audio/sfx/machete_swing.wav",
	"res://assets/audio/sfx/machete_hit.wav",
	"res://assets/audio/sfx/pickup.wav",
	"res://assets/audio/sfx/dano.wav",
	"res://assets/audio/sfx/victoria.wav",
	"res://assets/audio/sfx/derrota.wav",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	print("---- SFX import check ----")
	for p in SFX:
		print("  ", p, " exists=", ResourceLoader.exists(p))

	print("---- player machete check ----")
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	var player := packed.instantiate()
	root.add_child(player)
	await process_frame
	await process_frame
	var attach := player.find_child("MacheteAttach", true, false)
	print("  MacheteAttach found=", attach != null)
	if attach != null:
		print("    bone_name=", attach.bone_name,
			" bone_idx=", attach.bone_idx,
			" children=", attach.get_child_count())
	var ap := player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		print("  has Attack anim=", ap.has_animation("Attack"),
			" Attack len=", (ap.get_animation("Attack").length if ap.has_animation("Attack") else -1.0))
	print("  has_machete before=", player.has_machete)
	player.equip_machete()
	var holder := attach.get_child(0) if attach != null and attach.get_child_count() > 0 else null
	print("  after equip: has_machete=", player.has_machete,
		" visual_visible=", (holder.visible if holder != null else "n/a"))
	player.queue_free()
	await process_frame
	quit()
