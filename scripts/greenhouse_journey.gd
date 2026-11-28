extends Control

const EXPERIMENT_SCENE := "res://scenes/chapter_experiment_03.tscn"


func _ready() -> void:
	var journey_hud: Control = $JourneyHUD
	journey_hud.connect("experiment_requested", Callable(self, "_on_experiment_requested"))


func _on_experiment_requested() -> void:
	get_tree().change_scene_to_file(EXPERIMENT_SCENE)
