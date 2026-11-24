extends Control

const PotionVialScript = preload("res://scripts/potion_vial.gd")
const CAPACITY: int = 4
const BOTTLE_SHEET_PATH: String = "res://assets/bottles/bottles_sheet.png"
const ESSENCE_NAMES: Array[String] = ["tide", "moon", "ember"]
const PALETTE: Dictionary = {
	"tide": Color(0.30, 0.77, 0.75, 1.0),
	"moon": Color(0.65, 0.53, 0.83, 1.0),
	"ember": Color(0.91, 0.62, 0.29, 1.0)
}
const INITIAL_LAYOUT: Array = [
	["moon", "tide", "ember", "moon"],
	["tide", "ember", "moon", "tide"],
	["ember", "moon", "tide", "ember"],
	[]
]

var bottles: Array = []
var move_history: Array[Dictionary] = []
var vial_controls: Array = []
var selected_vial: int = -1
var move_count: int = 0
var round_complete: bool = false
var bottle_texture: Texture2D
var is_animating: bool = false

var _pour_source: int = -1
var _pour_target: int = -1
var _pour_progress: float = 0.0
var _stream_phase: float = 0.0
var _pour_stream_active: bool = false
var _pour_essence_color: Color = Color.WHITE
var _pour_source_contents: Array = []
var _pour_target_contents: Array = []
var _pour_source_start: float = 0.0
var _pour_target_start: float = 0.0
var _pour_amount: int = 0
var pour_stream_glow: Line2D
var pour_stream_core: Line2D
var pour_stream_spark: Line2D

var move_count_label: Label
var message_label: Label
var undo_button: Button
var restart_button: Button
var vial_row: HBoxContainer


func _ready() -> void:
	bottle_texture = _load_bottle_texture()
	_build_interface()
	_load_initial_puzzle()


func _load_bottle_texture() -> Texture2D:
	var sheet := Image.load_from_file(BOTTLE_SHEET_PATH)
	if sheet.is_empty():
		push_warning("Bottle sheet could not be loaded. Using the procedural vial fallback.")
		return null

	# The source sheet contains 16 bottle designs in a 4 x 4 contact sheet.
	# Crop the first design to its non-transparent bounds for clean scaling.
	var cell_width: int = int(sheet.get_width() / 4)
	var cell_height: int = int(sheet.get_height() / 4)
	if cell_width <= 0 or cell_height <= 0:
		push_warning("Bottle sheet dimensions are invalid. Using the procedural vial fallback.")
		return null

	var bottle_image := sheet.get_region(Rect2i(0, 0, cell_width, cell_height))
	var used_bounds := bottle_image.get_used_rect()
	if used_bounds.size.x <= 0 or used_bounds.size.y <= 0:
		push_warning("The first bottle cell is empty. Using the procedural vial fallback.")
		return null

	bottle_image = bottle_image.get_region(used_bounds)
	return ImageTexture.create_from_image(bottle_image)


func _build_pour_effects() -> void:
	pour_stream_glow = Line2D.new()
	pour_stream_glow.width = 11.0
	pour_stream_glow.antialiased = true
	pour_stream_glow.z_index = 100
	pour_stream_glow.visible = false
	add_child(pour_stream_glow)

	pour_stream_core = Line2D.new()
	pour_stream_core.width = 3.0
	pour_stream_core.antialiased = true
	pour_stream_core.z_index = 101
	pour_stream_core.visible = false
	add_child(pour_stream_core)

	pour_stream_spark = Line2D.new()
	pour_stream_spark.width = 4.5
	pour_stream_spark.antialiased = true
	pour_stream_spark.z_index = 102
	pour_stream_spark.visible = false
	add_child(pour_stream_spark)


func _build_interface() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load("res://assets/environments/laboratory_background.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var atmosphere := ColorRect.new()
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.color = Color(0.018, 0.027, 0.043, 0.38)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(atmosphere)

	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 26)
	margins.add_theme_constant_override("margin_top", 28)
	margins.add_theme_constant_override("margin_right", 26)
	margins.add_theme_constant_override("margin_bottom", 28)
	add_child(margins)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	margins.add_child(column)

	column.add_child(_build_header())
	column.add_child(_build_goal_card())
	column.add_child(_build_instruction_bar())

	var board_center := CenterContainer.new()
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_center.custom_minimum_size = Vector2(0.0, 350.0)
	column.add_child(board_center)

	vial_row = HBoxContainer.new()
	vial_row.add_theme_constant_override("separation", 8)
	vial_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_center.add_child(vial_row)

	for index in range(4):
		var vial = PotionVialScript.new()
		vial.custom_minimum_size = Vector2(122.0, 340.0)
		vial.tapped.connect(_on_vial_tapped)
		vial_row.add_child(vial)
		vial_controls.append(vial)

	column.add_child(_build_footer())
	_build_pour_effects()


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, 72.0)
	header.add_theme_constant_override("separation", 12)

	var brand_stack := VBoxContainer.new()
	brand_stack.add_theme_constant_override("separation", 0)
	brand_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := _make_label("SPELL SORT", 31, Color(0.96, 0.85, 0.65, 1.0))
	brand_stack.add_child(title)
	var subtitle := _make_label("THE LOST ALCHEMY LAB", 12, Color(0.82, 0.86, 0.87, 0.88))
	brand_stack.add_child(subtitle)
	header.add_child(brand_stack)

	var badge := _make_panel(
		Color(0.055, 0.085, 0.105, 0.90),
		Color(0.77, 0.62, 0.39, 0.72),
		15
	)
	badge.custom_minimum_size = Vector2(88.0, 42.0)
	var badge_label := _make_label("LAB 01", 13, Color(0.95, 0.83, 0.61, 1.0))
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(badge_label)
	header.add_child(badge)

	return header


func _build_goal_card() -> Control:
	var panel := _make_panel(
		Color(0.035, 0.055, 0.075, 0.88),
		Color(0.73, 0.59, 0.38, 0.72),
		20
	)
	panel.custom_minimum_size = Vector2(0.0, 126.0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var text_stack := VBoxContainer.new()
	text_stack.add_theme_constant_override("separation", 5)
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_child(_make_label("Separate the essences", 22, Color(0.98, 0.94, 0.85, 1.0)))

	var description := _make_label(
		"Sort each colour into its own pure vial.",
		14,
		Color(0.78, 0.83, 0.84, 0.96)
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_stack.add_child(description)
	row.add_child(text_stack)

	var chip_column := VBoxContainer.new()
	chip_column.add_theme_constant_override("separation", 5)
	chip_column.add_child(_make_essence_chip("TIDE", PALETTE["tide"]))
	chip_column.add_child(_make_essence_chip("MOON", PALETTE["moon"]))
	chip_column.add_child(_make_essence_chip("EMBER", PALETTE["ember"]))
	row.add_child(chip_column)

	return panel


func _build_instruction_bar() -> Control:
	var panel := _make_panel(
		Color(0.035, 0.065, 0.085, 0.82),
		Color(0.57, 0.69, 0.68, 0.42),
		14
	)
	panel.custom_minimum_size = Vector2(0.0, 48.0)

	var instruction := _make_label(
		"TAP A VIAL, THEN POUR INTO AN EMPTY OR MATCHING VIAL",
		12,
		Color(0.91, 0.90, 0.81, 0.98)
	)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(instruction)

	return panel


func _build_footer() -> Control:
	var panel := _make_panel(
		Color(0.035, 0.055, 0.075, 0.91),
		Color(0.73, 0.59, 0.38, 0.72),
		18
	)
	panel.custom_minimum_size = Vector2(0.0, 112.0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var information := VBoxContainer.new()
	information.add_theme_constant_override("separation", 5)
	information.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	move_count_label = _make_label("MOVES 00", 12, Color(0.90, 0.74, 0.49, 1.0))
	information.add_child(move_count_label)

	message_label = _make_label("Choose a vial to begin.", 15, Color(0.92, 0.93, 0.88, 1.0))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	information.add_child(message_label)
	row.add_child(information)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)

	undo_button = _make_button("UNDO", false)
	undo_button.pressed.connect(_on_undo_pressed)
	actions.add_child(undo_button)

	restart_button = _make_button("RESET", true)
	restart_button.pressed.connect(_on_restart_pressed)
	actions.add_child(restart_button)
	row.add_child(actions)

	return panel


func _make_essence_chip(label_text: String, essence_color: Color) -> Control:
	var tint := Color(
		essence_color.r * 0.20,
		essence_color.g * 0.20,
		essence_color.b * 0.20,
		0.94
	)
	var chip := _make_panel(tint, essence_color.darkened(0.18), 10)
	chip.custom_minimum_size = Vector2(90.0, 29.0)

	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 7)
	var swatch := ColorRect.new()
	swatch.color = essence_color
	swatch.custom_minimum_size = Vector2(9.0, 9.0)
	chip_row.add_child(swatch)

	var name_label := _make_label(label_text, 10, Color(0.95, 0.92, 0.84, 1.0))
	chip_row.add_child(name_label)
	chip.add_child(chip_row)

	return chip


func _make_label(label_text: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_panel(background_color: Color, border_color: Color, radius: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 15.0
	style.content_margin_top = 11.0
	style.content_margin_right = 15.0
	style.content_margin_bottom = 11.0
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_button(button_text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(91.0, 52.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)

	var normal_color := Color(0.40, 0.29, 0.17, 0.98) if primary else Color(0.10, 0.14, 0.17, 0.96)
	var hover_color := Color(0.51, 0.37, 0.21, 1.0) if primary else Color(0.16, 0.21, 0.23, 1.0)
	var border_color := Color(0.88, 0.70, 0.43, 0.94) if primary else Color(0.60, 0.70, 0.69, 0.65)

	button.add_theme_stylebox_override("normal", _button_style(normal_color, border_color))
	button.add_theme_stylebox_override("hover", _button_style(hover_color, border_color))
	button.add_theme_stylebox_override("pressed", _button_style(normal_color.darkened(0.16), border_color))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.12, 0.14, 0.15, 0.65), Color(0.34, 0.39, 0.39, 0.45)))
	button.add_theme_color_override("font_color", Color(0.97, 0.92, 0.82, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.88, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.60, 0.63, 0.61, 0.65))
	return button


func _button_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(13)
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style


func _load_initial_puzzle() -> void:
	bottles = _copy_layout(INITIAL_LAYOUT)
	_reset_round_state("Choose a vial to begin.")


func _load_random_puzzle() -> void:
	bottles = _create_random_layout()
	_reset_round_state("A fresh formula is ready. Separate the three essences.")
	

func _reset_round_state(status_text: String) -> void:
	move_history.clear()
	move_count = 0
	selected_vial = -1
	round_complete = false
	_set_status(status_text)
	_refresh_interface()


func _copy_layout(layout: Array) -> Array:
	var copied: Array = []
	for bottle in layout:
		copied.append(bottle.duplicate(true))
	return copied


func _create_random_layout() -> Array:
	var pieces: Array = []
	for essence_name in ESSENCE_NAMES:
		for _piece_index in range(CAPACITY):
			pieces.append(essence_name)

	for _attempt in range(40):
		pieces.shuffle()
		var candidate: Array = []
		for bottle_index in range(3):
			var bottle: Array = []
			for layer_index in range(CAPACITY):
				bottle.append(pieces[bottle_index * CAPACITY + layer_index])
			candidate.append(bottle)
		candidate.append([])

		var contains_finished_vial := false
		for bottle in candidate:
			if _is_full_and_uniform(bottle):
				contains_finished_vial = true
				break
		if not contains_finished_vial:
			return candidate

	return _copy_layout(INITIAL_LAYOUT)


func _is_full_and_uniform(bottle: Array) -> bool:
	if bottle.size() != CAPACITY:
		return false
	var first_essence: String = String(bottle[0])
	for layer in bottle:
		if String(layer) != first_essence:
			return false
	return true


func _on_vial_tapped(index: int) -> void:
	if round_complete or is_animating:
		return

	if selected_vial == -1:
		if bottles[index].is_empty():
			_set_status("That vial is empty. Choose one that contains an essence.")
		else:
			selected_vial = index
			_set_status("Now choose an empty vial or one topped with the same essence.")
		_refresh_interface()
		return

	if index == selected_vial:
		selected_vial = -1
		_set_status("Selection cleared. Choose another vial.")
		_refresh_interface()
		return

	if _can_pour(selected_vial, index):
		_start_pour(selected_vial, index)
		return

	if bottles[index].is_empty():
		_set_status("That pour is not available. Try a different destination.")
	else:
		selected_vial = index
		_set_status("Different essence. This vial is now selected as your source.")
	_refresh_interface()


func _can_pour(source_index: int, target_index: int) -> bool:
	var source: Array = bottles[source_index]
	var target: Array = bottles[target_index]

	if source.is_empty() or target.size() >= CAPACITY:
		return false

	if target.is_empty():
		return true

	return String(target.back()) == String(source.back())


func _get_pour_amount(source_index: int, target_index: int) -> int:
	var source: Array = bottles[source_index]
	var target: Array = bottles[target_index]
	if source.is_empty() or target.size() >= CAPACITY:
		return 0
	var essence_name: String = String(source.back())
	var matching_run: int = 0
	for layer_index in range(source.size() - 1, -1, -1):
		if String(source[layer_index]) == essence_name:
			matching_run += 1
		else:
			break
	return mini(matching_run, CAPACITY - target.size())


func _start_pour(source_index: int, target_index: int) -> void:
	if is_animating:
		return
	var amount: int = _get_pour_amount(source_index, target_index)
	if amount <= 0:
		return

	is_animating = true
	_save_history()
	selected_vial = -1
	_pour_source = source_index
	_pour_target = target_index
	_pour_progress = 0.0
	_pour_amount = amount
	_pour_source_contents = bottles[source_index].duplicate()
	_pour_target_contents = bottles[target_index].duplicate()

	var essence_name: String = String(_pour_source_contents.back())
	_pour_essence_color = PALETTE.get(essence_name, Color.WHITE)
	for _layer_index in range(amount):
		_pour_target_contents.append(essence_name)

	_pour_source_start = float(_pour_source_contents.size())
	_pour_target_start = float(bottles[target_index].size())
	_refresh_interface()

	var source_vial = vial_controls[source_index]
	var target_vial = vial_controls[target_index]
	source_vial.set_visual_contents(_pour_source_contents, _pour_source_start)
	target_vial.set_visual_contents(_pour_target_contents, _pour_target_start)
	source_vial.set_visual_state(true, false)
	target_vial.set_visual_state(false, true)

	_set_status("Pouring %s essence..." % essence_name.capitalize())
	var tilt_direction: float = 1.0 if target_vial.global_position.x > source_vial.global_position.x else -1.0
	var tilt_angle: float = deg_to_rad(tilt_direction * 17.0)

	var lift_tween := create_tween()
	lift_tween.tween_method(
		Callable(source_vial, "set_animation_pose"),
		Vector2.ZERO,
		Vector2(19.0, tilt_angle),
		0.22
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await lift_tween.finished

	_pour_stream_active = true
	pour_stream_glow.visible = true
	pour_stream_core.visible = true
	pour_stream_spark.visible = true
	_update_pour_stream()
	var pour_tween := create_tween()
	pour_tween.tween_method(Callable(self, "_set_pour_progress"), 0.0, 1.0, 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await pour_tween.finished
	_pour_stream_active = false
	pour_stream_glow.visible = false
	pour_stream_core.visible = false
	pour_stream_spark.visible = false

	var return_tween := create_tween()
	return_tween.tween_method(
		Callable(source_vial, "set_animation_pose"),
		Vector2(19.0, tilt_angle),
		Vector2.ZERO,
		0.22
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await return_tween.finished

	source_vial.set_visual_state(false, false)
	target_vial.set_visual_state(false, false)
	_pour(source_index, target_index)
	move_count += 1
	is_animating = false
	_pour_source = -1
	_pour_target = -1
	_pour_progress = 0.0

	if _is_puzzle_solved():
		round_complete = true
		_set_status("Formula restored. All three essences are pure.")
	else:
		_set_status("A successful pour. Keep separating the essences.")
	_refresh_interface()


func _set_pour_progress(progress: float) -> void:
	_pour_progress = progress
	var source_level: float = lerpf(_pour_source_start, _pour_source_start - float(_pour_amount), progress)
	var target_level: float = lerpf(_pour_target_start, _pour_target_start + float(_pour_amount), progress)
	vial_controls[_pour_source].set_visual_contents(_pour_source_contents, source_level)
	vial_controls[_pour_target].set_visual_contents(_pour_target_contents, target_level)
	queue_redraw()


func _process(delta: float) -> void:
	if _pour_stream_active:
		_stream_phase = fposmod(_stream_phase + delta * 2.8, 1.0)
		_update_pour_stream()


func _update_pour_stream() -> void:
	if not _pour_stream_active or _pour_source < 0 or _pour_target < 0:
		return
	var source_vial = vial_controls[_pour_source]
	var target_vial = vial_controls[_pour_target]
	var start: Vector2 = to_local(source_vial.get_global_spout_position())
	var finish: Vector2 = to_local(target_vial.get_global_spout_position())
	var span: float = finish.x - start.x
	var control_one := start + Vector2(span * 0.30, 34.0)
	var control_two := finish - Vector2(span * 0.30, -34.0)
	var stream_points := PackedVector2Array()
	for point_index in range(25):
		var t: float = float(point_index) / 24.0
		stream_points.append(start.bezier_interpolate(control_one, control_two, finish, t))
	var stream_alpha: float = 0.55 + 0.35 * sin(PI * _pour_progress)
	pour_stream_glow.points = stream_points
	pour_stream_glow.default_color = Color(_pour_essence_color.r, _pour_essence_color.g, _pour_essence_color.b, stream_alpha * 0.30)
	pour_stream_core.points = stream_points
	pour_stream_core.default_color = Color(_pour_essence_color.r, _pour_essence_color.g, _pour_essence_color.b, stream_alpha)
	var spark_t: float = fposmod(_stream_phase, 1.0)
	var spark_points := PackedVector2Array()
	for spark_offset in [-0.035, 0.0, 0.035]:
		var sample_t: float = clampf(spark_t + spark_offset, 0.0, 1.0)
		spark_points.append(start.bezier_interpolate(control_one, control_two, finish, sample_t))
	pour_stream_spark.points = spark_points
	pour_stream_spark.default_color = Color(1.0, 1.0, 1.0, stream_alpha * 0.90)


func _pour(source_index: int, target_index: int) -> void:
	var source: Array = bottles[source_index]
	var target: Array = bottles[target_index]
	var essence_name: String = String(source.back())
	var matching_run: int = 0

	for layer_index in range(source.size() - 1, -1, -1):
		if String(source[layer_index]) == essence_name:
			matching_run += 1
		else:
			break

	var available_space: int = CAPACITY - target.size()
	var amount_to_move: int = mini(matching_run, available_space)

	for _pour_index in range(amount_to_move):
		target.append(source.pop_back())


func _is_puzzle_solved() -> bool:
	for bottle in bottles:
		if bottle.is_empty():
			continue
		if not _is_full_and_uniform(bottle):
			return false
	return true


func _save_history() -> void:
	move_history.append({
		"bottles": _copy_layout(bottles),
		"move_count": move_count
	})


func _on_undo_pressed() -> void:
	if is_animating or move_history.is_empty() or round_complete:
		return

	var previous_state: Dictionary = move_history.pop_back()
	bottles = previous_state["bottles"]
	move_count = int(previous_state["move_count"])
	selected_vial = -1
	_set_status("Last pour undone.")
	_refresh_interface()


func _on_restart_pressed() -> void:
	if is_animating:
		return
	if round_complete:
		_load_random_puzzle()
	else:
		_load_initial_puzzle()


func _set_status(status_text: String) -> void:
	if is_instance_valid(message_label):
		message_label.text = status_text


func _refresh_interface() -> void:
	for index in range(vial_controls.size()):
		vial_controls[index].configure(
			index,
			bottles[index],
			PALETTE,
			selected_vial == index,
			bottle_texture
		)

	if is_instance_valid(move_count_label):
		move_count_label.text = "MOVES %02d" % move_count
	if is_instance_valid(undo_button):
		undo_button.disabled = move_history.is_empty() or round_complete or is_animating
	if is_instance_valid(restart_button):
		restart_button.text = "NEW MIX" if round_complete else "RESET"
		restart_button.disabled = is_animating
