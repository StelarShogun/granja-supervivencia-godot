extends CanvasLayer

@onready var _label_lives: Label = $LabelLives
@onready var _label_animals: Label = $LabelAnimals
@onready var _label_progress: Label = $LabelProgress
@onready var _label_message: Label = $LabelMessage


func update_status(
	lives: int,
	score: int,
	animals_in_corral: int,
	animal_goal: int,
	current_progress: int,
	max_progress: int,
	message: String
) -> void:
	_label_lives.text = "Vidas: %d" % lives
	_label_animals.text = "Animales en corral: %d / %d" % [animals_in_corral, animal_goal]
	_label_progress.text = "Progresión: %d / %d" % [current_progress, max_progress]
	_label_message.text = message
