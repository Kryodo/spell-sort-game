extends "res://scripts/dark_sorting_slots_prototype.gd"

const ATELIER_SCENE := "res://scenes/atelier_hub.tscn"
const PROGRESS_PATH := "user://spell_sort_progress.cfg"

@export var journey_step: String = "intro"


func _ready() -> void:
	super._ready()
	if is_instance_valid(_menu_button):
		_menu_button.visible = false
	if is_instance_valid(_back_button):
		_back_button.tooltip_text = "Return to the Atelier"


func _refresh_hud() -> void:
	super._refresh_hud()

	if is_instance_valid(_menu_button):
		_menu_button.visible = false

	if journey_step == "garden":
		if is_instance_valid(_chapter_label):
			_chapter_label.text = "BOTANICAL GARDEN  ·  THE OVERGROWN ENTRANCE"
		if is_instance_valid(_experiment_title):
			_experiment_title.text = "The First Garden Challenge"
		if is_instance_valid(level_label):
			level_label.text = "FIRST JOURNEY  ·  CHALLENGE 01"
	else:
		if is_instance_valid(_chapter_label):
			_chapter_label.text = "THE ATELIER  ·  FIRST LESSONS"
		if is_instance_valid(level_label):
			level_label.text = "LESSON %02d / 03" % (current_level + 1)

	if round_complete and is_instance_valid(next_level_action_button):
		var final_intro_lesson := journey_step == "intro" and current_level >= 2
		next_level_action_button.configure(
			"continue",
			"Return" if final_intro_lesson or journey_step == "garden" else "Continue"
		)


func _continue_from_completion() -> void:
	if is_animating or not round_complete:
		return

	if journey_step == "intro":
		if current_level < 2:
			_next_level()
			return
		_save_progress_flag("first_lessons_complete")
		_return_to_world()
		return

	if journey_step == "garden":
		_save_progress_flag("garden_first_challenge_complete")
		_return_to_world()
		return

	_return_to_world()


func _return_to_world() -> void:
	if is_animating:
		return
	SceneTransition.transition_to(ATELIER_SCENE)


func _save_progress_flag(flag_name: String) -> void:
	var progress := ConfigFile.new()
	var load_error := progress.load(PROGRESS_PATH)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning("SpellSort progress could not be loaded before saving: %d" % load_error)

	progress.set_value("progress", flag_name, true)
	var save_error := progress.save(PROGRESS_PATH)
	if save_error != OK:
		push_warning("SpellSort progress could not be saved: %d" % save_error)
