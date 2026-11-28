extends "res://scripts/dark_sorting_slots_prototype.gd"

const TestTubeVialScript = preload("res://scripts/test_tube_vial.gd")
const ATELIER_SCENE := "res://scenes/atelier_hub.tscn"


func _ready() -> void:
	super._ready()
	if is_instance_valid(_back_button):
		_back_button.tooltip_text = "Return to the Atelier"


func _add_minimal_vial(index: int, position_value: Vector2, size_value: Vector2, markers: Array) -> void:
	var vial: Control = TestTubeVialScript.new()
	vial.name = "LaboratoryBottleVial%02d" % (index + 1)
	vial.position = position_value
	vial.size = size_value
	vial.z_index = 2
	vial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vial_contents: Array = bottle_contents[index]
	vial.call(
		"setup",
		index,
		"",
		index % 4,
		PALETTE,
		vial_contents
	)
	add_child(vial)
	bottle_nodes.append(vial)
	slot_positions.append(position_value)

	var foot := Vector2(
		position_value.x + size_value.x * 0.5,
		position_value.y + _vial_base_offset(size_value)
	)
	var slot_glow_color: Color = Color(0.54, 0.84, 0.72, 1.0)
	if not vial_contents.is_empty():
		slot_glow_color = PALETTE.get(String(vial_contents.back()), slot_glow_color)
	markers.append({
		"centre": foot,
		"radius": Vector2(size_value.x * 0.27, size_value.x * 0.075),
		"scale": size_value.x / TEST_VIAL_SOURCE_SIZE.x,
		"has_contents": not vial_contents.is_empty(),
		"glow_color": slot_glow_color
	})

	if index == int(level_data.get("locked_vial", -1)):
		locked_label = _make_label(
			"SEALED",
			position_value + Vector2(4.0, size_value.y * 0.54),
			Vector2(size_value.x - 8.0, 24.0),
			11,
			Color("#f5d69a")
		)
		locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked_label.z_index = 8
		locked_label.add_to_group("direction_level_overlay")
		add_child(locked_label)


func _refresh_hud() -> void:
	super._refresh_hud()
	if is_instance_valid(_chapter_label):
		_chapter_label.text = "BOTTLE DESIGN  ·  GLASS SHAPE STUDY"
	if is_instance_valid(level_label):
		if round_complete:
			level_label.text = "BOTTLE STUDY  ·  EXPERIMENT COMPLETE"
		else:
			level_label.text = "BOTTLE STUDY  ·  LEVEL %02d / 10" % (current_level + 1)


func _return_to_world() -> void:
	if is_animating:
		return
	SceneTransition.transition_to(ATELIER_SCENE)
