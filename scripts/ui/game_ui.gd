extends CanvasLayer

@onready var _label_animals: Label = $LabelAnimals
@onready var _label_progress: Label = $LabelProgress


func update_status(
	animals_in_corral: int,
	animal_goal: int,
	current_progress: int,
	_max_progress: int,
	message: String
) -> void:
	_label_animals.text = "Animales en corral: %d / %d" % [animals_in_corral, animal_goal]
	_label_progress.text = "Progresión: %d / %d" % [current_progress, _max_progress]
