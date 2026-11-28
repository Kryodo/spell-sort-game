extends "res://scripts/test_tube_sorting_board.gd"

## Side-by-side comparison variant. The original bottle study remains available
## in test_tube_sorting_board.tscn with its original renderer.

const TestTubeCachedLiquidVialScript = preload("res://scripts/test_tube_cached_liquid_vial.gd")
const LIQUID_TEST_VIAL_SOURCE_SIZE := Vector2(160.0, 365.0)


func _add_minimal_vial(
	index: int,
	position_value: Vector2,
	size_value: Vector2,
	markers: Array
) -> void:
	var vial: Control = TestTubeCachedLiquidVialScript.new()
	vial.name = "CachedProfileLiquidVial%02d" % (index + 1)
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
		"scale": size_value.x / LIQUID_TEST_VIAL_SOURCE_SIZE.x,
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
		_chapter_label.text = "CACHED PROFILE LIQUID  ·  WORKING PIPELINE TRANSFER"
	if is_instance_valid(_experiment_title):
		_experiment_title.text = "CACHED CURVED LIQUID STUDY"
	if is_instance_valid(level_label):
		if round_complete:
			level_label.text = "CACHED PROFILE LIQUID  ·  EXPERIMENT COMPLETE"
		else:
			level_label.text = "CACHED PROFILE LIQUID  ·  LEVEL %02d / 10" % (current_level + 1)
