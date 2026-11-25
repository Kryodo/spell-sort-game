extends Control

const BottleScript = preload("res://scripts/alchemy_bottle.gd")
const BACKGROUND_PATH := "res://assets/environments/laboratory_background.png"
const CAPACITY := 4
const BOTTLE_SIZE := Vector2(140.0, 430.0)
const BOTTLE_GAP := 14.0
const BOTTLE_ROW_Y := 423.0

const ESSENCE_NAMES: Array[String] = ["tide", "moon", "ember"]
const PALETTE: Dictionary = {
	"tide": Color(0.24, 0.77, 0.76, 1.0),
	"moon": Color(0.66, 0.54, 0.91, 1.0),
	"ember": Color(0.96, 0.51, 0.24, 1.0)
}

# Array order is bottom-to-top. The last item is the essence at the open mouth.
const INITIAL_CONTENTS: Array = [
	["moon", "tide", "ember", "moon"],
	["tide", "ember", "moon", "tide"],
	["ember", "moon", "tide", "ember"],
	[]
]

var bottle_controls: Array = []
var bottle_contents: Array = []
var slot_positions: Array[Vector2] = []
var move_history: Array[Dictionary] = []

var status_label: Label
var move_label: Label
var purity_label: Label
var undo_button: Button
var reset_button: Button
var completion_panel: Panel
var objective_chips: Array[Panel] = []
var objective_chip_labels: Array[Label] = []

var _drag_index: int = -1
var _hover_index: int = -1
var _drag_origin: Vector2 = Vector2.ZERO
var _grab_offset: Vector2 = Vector2.ZERO
var _drag_start_pointer: Vector2 = Vector2.ZERO
var _last_drag_pointer: Vector2 = Vector2.ZERO
var _is_animating: bool = false
var _round_complete: bool = false
var _move_count: int = 0

var _pour_source: int = -1
var _pour_target: int = -1
var _pour_source_preview: Array = []
var _pour_target_preview: Array = []
var _pour_source_start: float = 0.0
var _pour_target_start: float = 0.0
var _pour_amount: int = 0
var _pour_progress: float = 0.0
var _pour_color: Color = Color.WHITE
var _pour_stream_active: bool = false
var _stream_phase: float = 0.0

var _stream_shape: Polygon2D
var _stream_highlight: Line2D
var _stream_drops: Array[Polygon2D] = []
var _splash_ring: Line2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_interface()
	_build_bottles()
	_build_stream_layers()
	_reset_test()


func _build_interface() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load(BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var atmosphere := ColorRect.new()
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.color = Color(0.012, 0.024, 0.034, 0.47)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(atmosphere)

	_build_header()
	_build_experiment_card()
	_build_instruction_bar()
	_build_workbench()
	_build_status_panel()
	_build_completion_panel()


func _build_header() -> void:
	var title := _make_label("SPELL SORT", 32, Color(0.98, 0.86, 0.66, 1.0))
	title.position = Vector2(30.0, 26.0)
	title.size = Vector2(390.0, 43.0)
	add_child(title)

	var subtitle := _make_label("THE LOST ALCHEMY LAB", 12, Color(0.77, 0.85, 0.84, 0.96))
	subtitle.position = Vector2(33.0, 69.0)
	subtitle.size = Vector2(360.0, 22.0)
	add_child(subtitle)

	var badge := _make_panel(
		Rect2(500.0, 32.0, 188.0, 48.0),
		Color(0.045, 0.073, 0.084, 0.92),
		Color(0.80, 0.66, 0.43, 0.72),
		14
	)
	add_child(badge)

	var badge_kicker := _make_label("FIELD STUDY", 10, Color(0.74, 0.82, 0.78, 0.95))
	badge_kicker.position = Vector2(12.0, 4.0)
	badge_kicker.size = Vector2(100.0, 17.0)
	badge.add_child(badge_kicker)

	var badge_number := _make_label("NO. 01", 15, Color(0.98, 0.84, 0.61, 1.0))
	badge_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge_number.position = Vector2(91.0, 3.0)
	badge_number.size = Vector2(82.0, 29.0)
	badge.add_child(badge_number)


func _build_experiment_card() -> void:
	var panel := _make_panel(
		Rect2(24.0, 112.0, 672.0, 174.0),
		Color(0.026, 0.047, 0.059, 0.92),
		Color(0.77, 0.61, 0.39, 0.76),
		20
	)
	add_child(panel)

	var kicker := _make_label("EXPERIMENT 01  /  PURIFICATION", 11, Color(0.84, 0.68, 0.45, 1.0))
	kicker.position = Vector2(22.0, 16.0)
	kicker.size = Vector2(400.0, 20.0)
	panel.add_child(kicker)

	var heading := _make_label("Separation of Essences", 25, Color(0.98, 0.94, 0.84, 1.0))
	heading.position = Vector2(20.0, 43.0)
	heading.size = Vector2(420.0, 37.0)
	panel.add_child(heading)

	var description := _make_label(
		"Distil three tangled essences into pure four-measure vials.",
		13,
		Color(0.77, 0.84, 0.83, 0.98)
	)
	description.position = Vector2(22.0, 84.0)
	description.size = Vector2(420.0, 27.0)
	panel.add_child(description)

	var divider := ColorRect.new()
	divider.position = Vector2(22.0, 119.0)
	divider.size = Vector2(410.0, 1.0)
	divider.color = Color(0.73, 0.63, 0.46, 0.28)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(divider)

	var note := _make_label("Combine matching top layers. Keep each vessel below capacity.", 11, Color(0.72, 0.80, 0.79, 0.94))
	note.position = Vector2(22.0, 126.0)
	note.size = Vector2(430.0, 23.0)
	panel.add_child(note)

	_add_essence_reference_chip(panel, Rect2(470.0, 24.0, 174.0, 34.0), "TIDE", PALETTE["tide"])
	_add_essence_reference_chip(panel, Rect2(470.0, 68.0, 174.0, 34.0), "MOON", PALETTE["moon"])
	_add_essence_reference_chip(panel, Rect2(470.0, 112.0, 174.0, 34.0), "EMBER", PALETTE["ember"])


func _add_essence_reference_chip(parent: Control, rect: Rect2, label_text: String, tint: Color) -> void:
	var chip := _make_panel(
		rect,
		Color(tint.r * 0.13, tint.g * 0.13, tint.b * 0.13, 0.88),
		Color(tint.r, tint.g, tint.b, 0.48),
		10
	)
	parent.add_child(chip)

	var swatch := ColorRect.new()
	swatch.position = Vector2(12.0, 11.0)
	swatch.size = Vector2(11.0, 11.0)
	swatch.color = tint
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(swatch)

	var label := _make_label(label_text, 11, Color(0.94, 0.92, 0.84, 1.0))
	label.position = Vector2(34.0, 5.0)
	label.size = Vector2(120.0, 23.0)
	chip.add_child(label)


func _build_instruction_bar() -> void:
	var panel := _make_panel(
		Rect2(24.0, 301.0, 672.0, 66.0),
		Color(0.028, 0.060, 0.070, 0.88),
		Color(0.52, 0.71, 0.68, 0.48),
		14
	)
	add_child(panel)

	var instruction := _make_label(
		"HOLD A VIAL  ·  GUIDE ITS OPENING  ·  RELEASE TO POUR",
		13,
		Color(0.97, 0.92, 0.81, 1.0)
	)
	instruction.position = Vector2(15.0, 8.0)
	instruction.size = Vector2(642.0, 24.0)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(instruction)

	var detail := _make_label(
		"Only an empty vial or a matching top essence can receive a pour.",
		11,
		Color(0.70, 0.81, 0.79, 0.96)
	)
	detail.position = Vector2(15.0, 34.0)
	detail.size = Vector2(642.0, 20.0)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(detail)


func _build_workbench() -> void:
	var bench := _make_panel(
		Rect2(18.0, 382.0, 684.0, 498.0),
		Color(0.025, 0.040, 0.047, 0.62),
		Color(0.72, 0.60, 0.42, 0.50),
		24
	)
	add_child(bench)

	var bench_label := _make_label("THE WORKBENCH", 11, Color(0.84, 0.72, 0.52, 0.96))
	bench_label.position = Vector2(20.0, 11.0)
	bench_label.size = Vector2(190.0, 22.0)
	bench.add_child(bench_label)

	var vessel_note := _make_label("FOUR OPEN VESSELS  ·  FOUR MEASURES EACH", 10, Color(0.65, 0.77, 0.75, 0.90))
	vessel_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vessel_note.position = Vector2(300.0, 11.0)
	vessel_note.size = Vector2(360.0, 22.0)
	bench.add_child(vessel_note)


func _build_status_panel() -> void:
	var panel := _make_panel(
		Rect2(24.0, 897.0, 672.0, 272.0),
		Color(0.026, 0.047, 0.059, 0.94),
		Color(0.76, 0.61, 0.40, 0.73),
		20
	)
	add_child(panel)

	var section_label := _make_label("EXPERIMENT NOTES", 10, Color(0.83, 0.68, 0.46, 1.0))
	section_label.position = Vector2(20.0, 13.0)
	section_label.size = Vector2(220.0, 19.0)
	panel.add_child(section_label)

	move_label = _make_label("MOVES 00", 12, Color(0.88, 0.82, 0.68, 1.0))
	move_label.position = Vector2(20.0, 34.0)
	move_label.size = Vector2(150.0, 23.0)
	panel.add_child(move_label)

	purity_label = _make_label("PURE VIALS 0 / 3", 12, Color(0.85, 0.91, 0.84, 1.0))
	purity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	purity_label.position = Vector2(450.0, 34.0)
	purity_label.size = Vector2(200.0, 23.0)
	panel.add_child(purity_label)

	for index in range(ESSENCE_NAMES.size()):
		var essence_name: String = ESSENCE_NAMES[index]
		var essence_color: Color = PALETTE[essence_name]
		var chip := _make_panel(
			Rect2(20.0 + float(index) * 210.0, 66.0, 198.0, 34.0),
			Color(0.045, 0.065, 0.071, 0.92),
			Color(essence_color.r, essence_color.g, essence_color.b, 0.30),
			9
		)
		panel.add_child(chip)
		objective_chips.append(chip)

		var chip_label := _make_label(essence_name.to_upper(), 10, Color(0.73, 0.80, 0.77, 0.95))
		chip_label.position = Vector2(10.0, 4.0)
		chip_label.size = Vector2(175.0, 25.0)
		chip.add_child(chip_label)
		objective_chip_labels.append(chip_label)

	status_label = _make_label("Grip a vial and guide its opening to a receiving vial.", 14, Color(0.94, 0.93, 0.86, 1.0))
	status_label.position = Vector2(20.0, 111.0)
	status_label.size = Vector2(632.0, 43.0)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(status_label)

	var hint := _make_label(
		"A pour transfers the complete matching run at the top of the source vial.",
		10,
		Color(0.67, 0.77, 0.75, 0.94)
	)
	hint.position = Vector2(20.0, 157.0)
	hint.size = Vector2(630.0, 22.0)
	panel.add_child(hint)

	undo_button = _make_action_button("UNDO", false)
	undo_button.position = Vector2(398.0, 200.0)
	undo_button.size = Vector2(118.0, 48.0)
	undo_button.pressed.connect(_on_undo_pressed)
	panel.add_child(undo_button)

	reset_button = _make_action_button("RESET", true)
	reset_button.position = Vector2(528.0, 200.0)
	reset_button.size = Vector2(122.0, 48.0)
	reset_button.pressed.connect(_reset_test)
	panel.add_child(reset_button)


func _build_completion_panel() -> void:
	completion_panel = _make_panel(
		Rect2(96.0, 535.0, 528.0, 190.0),
		Color(0.025, 0.052, 0.057, 0.97),
		Color(0.91, 0.75, 0.47, 0.96),
		22
	)
	completion_panel.z_index = 150
	completion_panel.visible = false
	add_child(completion_panel)

	var kicker := _make_label("EXPERIMENT 01  ·  COMPLETE", 11, Color(0.91, 0.75, 0.48, 1.0))
	kicker.position = Vector2(25.0, 22.0)
	kicker.size = Vector2(478.0, 20.0)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_panel.add_child(kicker)

	var heading := _make_label("The essences are pure.", 25, Color(0.98, 0.94, 0.83, 1.0))
	heading.position = Vector2(20.0, 54.0)
	heading.size = Vector2(488.0, 39.0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_panel.add_child(heading)

	var detail := _make_label("Your first alchemical separation is complete.", 12, Color(0.75, 0.85, 0.81, 1.0))
	detail.position = Vector2(20.0, 96.0)
	detail.size = Vector2(488.0, 25.0)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_panel.add_child(detail)

	var repeat_button := _make_action_button("REPEAT EXPERIMENT", true)
	repeat_button.position = Vector2(154.0, 137.0)
	repeat_button.size = Vector2(220.0, 40.0)
	repeat_button.pressed.connect(_reset_test)
	completion_panel.add_child(repeat_button)


func _build_bottles() -> void:
	var total_width: float = BOTTLE_SIZE.x * 4.0 + BOTTLE_GAP * 3.0
	var start_x: float = (720.0 - total_width) * 0.5
	var labels: Array[String] = ["VIAL I", "VIAL II", "VIAL III", "VIAL IV"]

	for index in range(4):
		var slot_position := Vector2(start_x + float(index) * (BOTTLE_SIZE.x + BOTTLE_GAP), BOTTLE_ROW_Y)
		var slot := _make_panel(
			Rect2(slot_position.x + 5.0, slot_position.y + 30.0, BOTTLE_SIZE.x - 10.0, 376.0),
			Color(0.020, 0.037, 0.044, 0.30),
			Color(0.77, 0.66, 0.47, 0.20),
			17
		)
		add_child(slot)

		var pedestal := _make_panel(
			Rect2(slot_position.x + 12.0, slot_position.y + 389.0, BOTTLE_SIZE.x - 24.0, 35.0),
			Color(0.075, 0.073, 0.060, 0.70),
			Color(0.75, 0.61, 0.41, 0.30),
			10
		)
		add_child(pedestal)

		var vial = BottleScript.new()
		vial.position = slot_position
		vial.size = BOTTLE_SIZE
		vial.z_index = 2
		vial.setup(index, labels[index], index, PALETTE, INITIAL_CONTENTS[index])
		add_child(vial)
		bottle_controls.append(vial)
		slot_positions.append(slot_position)
		bottle_contents.append(INITIAL_CONTENTS[index].duplicate())


func _build_stream_layers() -> void:
	_stream_shape = Polygon2D.new()
	_stream_shape.color = Color.WHITE
	_stream_shape.z_index = 25
	_stream_shape.visible = false
	add_child(_stream_shape)

	_stream_highlight = Line2D.new()
	_stream_highlight.width = 1.15
	_stream_highlight.default_color = Color(1.0, 1.0, 1.0, 0.62)
	_stream_highlight.z_index = 26
	_stream_highlight.visible = false
	add_child(_stream_highlight)

	for index in range(3):
		var drop := Polygon2D.new()
		drop.polygon = _make_drop_shape()
		drop.color = Color(1.0, 1.0, 1.0, 0.82)
		drop.z_index = 27
		drop.visible = false
		add_child(drop)
		_stream_drops.append(drop)

	_splash_ring = Line2D.new()
	_splash_ring.width = 2.0
	_splash_ring.default_color = Color(1.0, 1.0, 1.0, 0.55)
	_splash_ring.z_index = 28
	_splash_ring.visible = false
	add_child(_splash_ring)


func _make_drop_shape() -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(Vector2(0.0, -4.5))
	points.append(Vector2(2.5, -0.5))
	points.append(Vector2(2.0, 3.0))
	points.append(Vector2(0.0, 4.2))
	points.append(Vector2(-2.0, 3.0))
	points.append(Vector2(-2.5, -0.5))
	return points


func _make_label(text_value: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_panel(rect: Rect2, background_color: Color, border_color: Color, radius: int) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0.0, 2.0)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_action_button(button_text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = button_text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.90, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.58, 0.63, 0.62, 0.65))

	var normal := Color(0.37, 0.27, 0.17, 0.98) if primary else Color(0.075, 0.12, 0.13, 0.96)
	var hover := Color(0.49, 0.36, 0.22, 1.0) if primary else Color(0.13, 0.19, 0.19, 1.0)
	var border := Color(0.90, 0.72, 0.45, 0.94) if primary else Color(0.59, 0.73, 0.70, 0.58)
	button.add_theme_stylebox_override("normal", _button_style(normal, border))
	button.add_theme_stylebox_override("hover", _button_style(hover, border))
	button.add_theme_stylebox_override("pressed", _button_style(normal.darkened(0.16), border))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.10, 0.13, 0.13, 0.66), Color(0.34, 0.41, 0.39, 0.42)))
	return button


func _button_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10.0
	style.content_margin_top = 7.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 7.0
	return style


func _gui_input(event: InputEvent) -> void:
	if _is_animating or _round_complete:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_finish_drag(event.position)
		accept_event()
	elif event is InputEventScreenDrag:
		_update_drag(event.position)
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_drag(event.position)
			else:
				_finish_drag(event.position)
			accept_event()
	elif event is InputEventMouseMotion:
		if _drag_index >= 0 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_update_drag(event.position)
			accept_event()


func _begin_drag(pointer: Vector2) -> void:
	if _drag_index >= 0 or _round_complete:
		return

	for index in range(bottle_controls.size()):
		var vial = bottle_controls[index]
		if Rect2(vial.position, vial.size).has_point(pointer):
			if bottle_contents[index].is_empty():
				_set_status("That vessel is empty. Choose one containing an essence.")
				return

			_drag_index = index
			_drag_origin = slot_positions[index]
			_grab_offset = pointer - vial.position
			_drag_start_pointer = pointer
			_last_drag_pointer = pointer
			vial.set_drag_motion(false)
			vial.z_index = 50
			vial.set_feedback(true, false, true)
			vial.set_pose(Vector2(28.0, 0.0))
			var anchored_grab_point: Vector2 = vial.get_drag_anchor_local(_grab_offset, vial.get_pose())
			vial.position = pointer - anchored_grab_point
			_set_status("Vial lifted. Guide its open mouth to a receiving vessel.")
			return


func _update_drag(pointer: Vector2) -> void:
	if _drag_index < 0:
		return

	var source = bottle_controls[_drag_index]
	var pointer_delta: Vector2 = pointer - _last_drag_pointer
	source.set_drag_motion(pointer_delta.length() > 0.65)
	_last_drag_pointer = pointer

	var movement: Vector2 = pointer - _drag_start_pointer
	var movement_factor: float = clampf(movement.length() / 115.0, 0.0, 1.0)
	var grip_factor: float = 1.0 - clampf(_grab_offset.y / maxf(1.0, source.size.y), 0.0, 1.0)
	var tilt_magnitude: float = lerpf(deg_to_rad(12.0), deg_to_rad(74.0), grip_factor) * movement_factor
	var tilt_direction: float = signf(movement.x)
	if is_zero_approx(tilt_direction):
		tilt_direction = _get_drag_tilt_direction(_drag_index)
	var drag_tilt: float = tilt_magnitude * tilt_direction

	source.set_pose(Vector2(28.0, drag_tilt))
	var anchored_grab_point: Vector2 = source.get_drag_anchor_local(_grab_offset, source.get_pose())
	source.position = pointer - anchored_grab_point

	var next_hover: int = _find_target_at(_drag_index)
	if next_hover != _hover_index:
		if _hover_index >= 0:
			bottle_controls[_hover_index].set_feedback(false, false, false)
		_hover_index = next_hover
		if _hover_index >= 0:
			bottle_controls[_hover_index].set_feedback(false, true, false)

	if _hover_index >= 0:
		_set_status("Open mouths aligned. Release to transfer the matching top layer.")
	else:
		_set_status("Guide the source vial's opening onto a valid receiving opening.")


func _get_drag_tilt_direction(source_index: int) -> float:
	var source = bottle_controls[source_index]
	var source_center_x: float = _drag_origin.x + source.size.x * 0.5
	var closest_delta: float = 0.0
	var closest_distance: float = INF

	for index in range(bottle_controls.size()):
		if index == source_index or not _can_pour(source_index, index):
			continue
		var target = bottle_controls[index]
		var delta_x: float = target.position.x + target.size.x * 0.5 - source_center_x
		if absf(delta_x) < closest_distance:
			closest_distance = absf(delta_x)
			closest_delta = delta_x

	if is_zero_approx(closest_delta):
		return 1.0
	return signf(closest_delta)


func _find_target_at(source_index: int) -> int:
	var source = bottle_controls[source_index]
	var source_mouth: Vector2 = source.get_mouth_position_in_parent(source.get_pose())
	var source_radius: Vector2 = source.get_mouth_hit_radius()

	for index in range(bottle_controls.size()):
		if index == source_index or not _can_pour(source_index, index):
			continue

		var target = bottle_controls[index]
		var target_mouth: Vector2 = target.get_mouth_position_in_parent()
		var target_radius: Vector2 = target.get_mouth_hit_radius()
		var tolerance := Vector2(
			maxf(20.0, (source_radius.x + target_radius.x) * 0.48),
			maxf(18.0, (source_radius.y + target_radius.y) * 0.50)
		)
		var delta: Vector2 = source_mouth - target_mouth
		var normalized_distance: float = pow(delta.x / tolerance.x, 2.0) + pow(delta.y / tolerance.y, 2.0)
		if normalized_distance <= 1.0:
			return index

	return -1


func _finish_drag(pointer: Vector2) -> void:
	if _drag_index < 0:
		return

	_update_drag(pointer)
	var source_index: int = _drag_index
	var target_index: int = _hover_index

	if target_index >= 0 and _can_pour(source_index, target_index):
		_perform_pour(source_index, target_index)
	else:
		_return_to_slot(source_index, "No valid receiving vial was aligned. Try an empty vessel or a matching top essence.")


func _can_pour(source_index: int, target_index: int) -> bool:
	var source: Array = bottle_contents[source_index]
	var target: Array = bottle_contents[target_index]

	if source.is_empty() or target.size() >= CAPACITY:
		return false
	if target.is_empty():
		return true
	return String(target.back()) == String(source.back())


func _get_pour_amount(source_index: int, target_index: int) -> int:
	var source: Array = bottle_contents[source_index]
	var target: Array = bottle_contents[target_index]
	if source.is_empty() or target.size() >= CAPACITY:
		return 0

	var essence: String = String(source.back())
	var run_length: int = 0
	for index in range(source.size() - 1, -1, -1):
		if String(source[index]) == essence:
			run_length += 1
		else:
			break

	return mini(run_length, CAPACITY - target.size())


func _copy_layout(layout: Array) -> Array:
	var copied: Array = []
	for contents in layout:
		copied.append(contents.duplicate(true))
	return copied


func _save_history() -> void:
	move_history.append({
		"contents": _copy_layout(bottle_contents),
		"moves": _move_count
	})


func _return_to_slot(source_index: int, status_text: String) -> void:
	_is_animating = true
	_refresh_hud()

	var source = bottle_controls[source_index]
	if _hover_index >= 0:
		bottle_controls[_hover_index].set_feedback(false, false, false)
	_hover_index = -1

	var return_tween := create_tween().set_parallel(true)
	return_tween.tween_property(source, "position", _drag_origin, 0.23).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return_tween.tween_method(Callable(source, "set_pose"), source.get_pose(), Vector2.ZERO, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await return_tween.finished

	source.z_index = 2
	source.set_feedback(false, false, false)
	source.reset_motion()
	_drag_index = -1
	_is_animating = false
	_refresh_hud()
	_set_status(status_text)


func _perform_pour(source_index: int, target_index: int) -> void:
	_is_animating = true
	_refresh_hud()

	_save_history()
	_pour_source = source_index
	_pour_target = target_index
	_pour_amount = _get_pour_amount(source_index, target_index)
	_pour_progress = 0.0
	_pour_source_preview = bottle_contents[source_index].duplicate()
	_pour_target_preview = bottle_contents[target_index].duplicate()

	if _pour_amount <= 0:
		_is_animating = false
		_return_to_slot(source_index, "That vial cannot accept the selected essence.")
		return

	var essence: String = String(_pour_source_preview.back())
	_pour_color = PALETTE[essence]
	for _index in range(_pour_amount):
		_pour_target_preview.append(essence)

	_pour_source_start = float(_pour_source_preview.size())
	_pour_target_start = float(bottle_contents[target_index].size())

	var source = bottle_controls[source_index]
	var target = bottle_controls[target_index]
	var direction: float = signf(target.position.x + target.size.x * 0.5 - (_drag_origin.x + source.size.x * 0.5))
	if is_zero_approx(direction):
		direction = 1.0

	var pour_pose := Vector2(24.0, deg_to_rad(103.0) * direction)
	const POUR_DRAW_SCALE := 0.82

	var target_mouth: Vector2 = target.get_mouth_position_in_parent()
	var desired_source_mouth: Vector2 = target_mouth + Vector2(-direction * 8.0, -6.0)
	var source_staging_position: Vector2 = desired_source_mouth - source.get_mouth_local_for_pose(pour_pose, POUR_DRAW_SCALE)

	if _hover_index >= 0:
		bottle_controls[_hover_index].set_feedback(false, true, false)
	_hover_index = -1
	_drag_index = -1
	source.set_feedback(false, false, false)
	source.set_drag_motion(false)

	source.set_preview(_pour_source_preview, _pour_source_start)
	target.set_preview(_pour_target_preview, _pour_target_start)
	target.set_feedback(false, true, false)

	_set_status("Aligning the source mouth with the receiving vessel...")
	var approach := create_tween().set_parallel(true)
	approach.tween_property(source, "position", source_staging_position, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	approach.tween_method(Callable(source, "set_pose"), source.get_pose(), pour_pose, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	approach.tween_method(Callable(source, "set_draw_scale"), source.get_draw_scale(), POUR_DRAW_SCALE, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await approach.finished

	source.trigger_slosh(0.24)
	target.trigger_slosh(0.12)
	_set_status("Pouring %s essence..." % essence.capitalize())
	_pour_stream_active = true
	_stream_shape.visible = true
	_stream_highlight.visible = true
	_splash_ring.visible = true
	for drop in _stream_drops:
		drop.visible = true
	_update_stream()

	var pour_tween := create_tween()
	pour_tween.tween_method(Callable(self, "_set_pour_progress"), 0.0, 1.0, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await pour_tween.finished

	_pour_stream_active = false
	_stream_shape.visible = false
	_stream_highlight.visible = false
	_splash_ring.visible = false
	for drop in _stream_drops:
		drop.visible = false

	var return_tween := create_tween().set_parallel(true)
	return_tween.tween_property(source, "position", _drag_origin, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_method(Callable(source, "set_pose"), pour_pose, Vector2.ZERO, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_method(Callable(source, "set_draw_scale"), POUR_DRAW_SCALE, 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await return_tween.finished

	var next_source: Array = bottle_contents[source_index].duplicate()
	var next_target: Array = bottle_contents[target_index].duplicate()
	for _index in range(_pour_amount):
		next_source.pop_back()
		next_target.append(essence)
	bottle_contents[source_index] = next_source
	bottle_contents[target_index] = next_target

	source.set_contents(next_source)
	target.set_contents(next_target)
	source.reset_motion()
	target.trigger_slosh(0.20)
	source.z_index = 2
	source.set_feedback(false, false, false)
	target.set_feedback(false, false, false)

	_move_count += 1
	_round_complete = _is_puzzle_solved()
	_pour_source = -1
	_pour_target = -1
	_pour_progress = 0.0
	_is_animating = false

	if _round_complete:
		_set_status("All three essences are pure. The first experiment is complete.")
	else:
		_set_status("Transfer complete. The liquid settles into its new vessel.")
	_refresh_hud()


func _set_pour_progress(progress: float) -> void:
	_pour_progress = progress
	var source_level: float = lerpf(_pour_source_start, _pour_source_start - float(_pour_amount), progress)
	var target_level: float = lerpf(_pour_target_start, _pour_target_start + float(_pour_amount), progress)
	bottle_controls[_pour_source].set_preview(_pour_source_preview, source_level)
	bottle_controls[_pour_target].set_preview(_pour_target_preview, target_level)
	_update_stream()


func _process(delta: float) -> void:
	if _pour_stream_active:
		_stream_phase = fposmod(_stream_phase + delta * 1.9, 1.0)
		_update_stream()


func _update_stream() -> void:
	if not _pour_stream_active or _pour_source < 0 or _pour_target < 0:
		return

	var source = bottle_controls[_pour_source]
	var target = bottle_controls[_pour_target]
	var start: Vector2 = source.get_mouth_position_in_parent(source.get_pose())
	var finish: Vector2 = target.get_liquid_surface_position_in_parent()
	var span: Vector2 = finish - start
	if span.length() < 1.0:
		return

	var horizontal_bend: float = clampf(span.x * 0.18, -42.0, 42.0)
	var vertical_fall: float = maxf(28.0, span.y * 0.36)
	var control_one := start + Vector2(horizontal_bend, vertical_fall * 0.28)
	var control_two := finish - Vector2(horizontal_bend, -vertical_fall * 0.28)
	var centers := PackedVector2Array()
	var left_edge := PackedVector2Array()
	var right_edge := PackedVector2Array()
	var point_count: int = 27

	for index in range(point_count):
		var t: float = float(index) / float(point_count - 1)
		var point: Vector2 = start.bezier_interpolate(control_one, control_two, finish, t)
		centers.append(point)
		var before: Vector2 = start.bezier_interpolate(control_one, control_two, finish, maxf(0.0, t - 0.015))
		var after: Vector2 = start.bezier_interpolate(control_one, control_two, finish, minf(1.0, t + 0.015))
		var tangent: Vector2 = (after - before).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var pulse_width: float = sin(PI * t)
		var irregularity: float = 0.72 + 0.18 * sin(t * 19.0 + _stream_phase * TAU)
		var half_width: float = (0.95 + pulse_width * 2.6) * irregularity
		left_edge.append(point + normal * half_width)
		right_edge.append(point - normal * half_width)

	var ribbon := PackedVector2Array()
	for point in left_edge:
		ribbon.append(point)
	for index in range(right_edge.size() - 1, -1, -1):
		ribbon.append(right_edge[index])

	_stream_shape.polygon = ribbon
	_stream_shape.color = Color(_pour_color.r, _pour_color.g, _pour_color.b, 0.94)
	_stream_highlight.points = centers
	_stream_highlight.default_color = Color(1.0, 1.0, 1.0, 0.40 + 0.22 * sin(PI * _pour_progress))

	for index in range(_stream_drops.size()):
		var travel: float = fposmod(_stream_phase + float(index) / float(_stream_drops.size()), 1.0)
		var drop_position: Vector2 = start.bezier_interpolate(control_one, control_two, finish, travel)
		var drop := _stream_drops[index]
		drop.position = drop_position
		drop.rotation = atan2(span.y, span.x) + PI * 0.5
		drop.scale = Vector2(0.75 + 0.25 * sin(PI * travel), 0.90 + 0.4 * sin(PI * travel))

	var ring_radius: float = 10.0 + 9.0 * _pour_progress
	var ring_points := PackedVector2Array()
	for index in range(25):
		var angle: float = TAU * float(index) / 24.0
		ring_points.append(finish + Vector2(cos(angle) * ring_radius, sin(angle) * ring_radius * 0.42))
	_splash_ring.points = ring_points
	_splash_ring.default_color = Color(1.0, 1.0, 1.0, 0.12 + 0.38 * sin(PI * _pour_progress))


func _get_pure_essences() -> Array[String]:
	var pure: Array[String] = []
	for contents in bottle_contents:
		if contents.size() != CAPACITY:
			continue
		var essence: String = String(contents[0])
		var is_uniform := true
		for layer in contents:
			if String(layer) != essence:
				is_uniform = false
				break
		if is_uniform and not pure.has(essence):
			pure.append(essence)
	return pure


func _is_puzzle_solved() -> bool:
	return _get_pure_essences().size() == ESSENCE_NAMES.size()


func _refresh_hud() -> void:
	if is_instance_valid(move_label):
		move_label.text = "MOVES %02d" % _move_count
	if is_instance_valid(purity_label):
		var pure_count: int = _get_pure_essences().size()
		purity_label.text = "PURE VIALS %d / %d" % [pure_count, ESSENCE_NAMES.size()]

	for index in range(objective_chips.size()):
		var essence_name: String = ESSENCE_NAMES[index]
		var completed: bool = _get_pure_essences().has(essence_name)
		var essence_color: Color = PALETTE[essence_name]
		var background := Color(essence_color.r * 0.12, essence_color.g * 0.12, essence_color.b * 0.12, 0.94)
		var border := Color(essence_color.r, essence_color.g, essence_color.b, 0.32)
		var label_color := Color(0.72, 0.79, 0.76, 0.96)
		if completed:
			background = Color(essence_color.r * 0.25, essence_color.g * 0.25, essence_color.b * 0.25, 0.96)
			border = Color(essence_color.r, essence_color.g, essence_color.b, 0.92)
			label_color = Color(0.98, 0.95, 0.86, 1.0)
		var style := _panel_style(background, border, 9)
		objective_chips[index].add_theme_stylebox_override("panel", style)
		objective_chip_labels[index].text = "✓  " + essence_name.to_upper() if completed else "○  " + essence_name.to_upper()
		objective_chip_labels[index].add_theme_color_override("font_color", label_color)

	if is_instance_valid(undo_button):
		undo_button.disabled = move_history.is_empty() or _is_animating
	if is_instance_valid(reset_button):
		reset_button.disabled = _is_animating
	if is_instance_valid(completion_panel):
		completion_panel.visible = _round_complete


func _panel_style(background_color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _on_undo_pressed() -> void:
	if _is_animating or move_history.is_empty():
		return

	var snapshot: Dictionary = move_history.pop_back()
	bottle_contents = _copy_layout(snapshot["contents"])
	_move_count = int(snapshot["moves"])
	_round_complete = _is_puzzle_solved()

	for index in range(bottle_controls.size()):
		var vial = bottle_controls[index]
		vial.position = slot_positions[index]
		vial.z_index = 2
		vial.reset_motion()
		vial.set_feedback(false, false, false)
		vial.set_contents(bottle_contents[index])
		vial.trigger_slosh(0.14)

	_set_status("Last pour reversed. Continue separating the essences.")
	_refresh_hud()


func _reset_test() -> void:
	if _is_animating:
		return

	bottle_contents = _copy_layout(INITIAL_CONTENTS)
	move_history.clear()
	_drag_index = -1
	_hover_index = -1
	_move_count = 0
	_round_complete = false
	_pour_source = -1
	_pour_target = -1
	_pour_progress = 0.0
	_is_animating = false
	_pour_stream_active = false

	_stream_shape.visible = false
	_stream_highlight.visible = false
	_splash_ring.visible = false
	for drop in _stream_drops:
		drop.visible = false

	for index in range(bottle_controls.size()):
		var vial = bottle_controls[index]
		vial.position = slot_positions[index]
		vial.z_index = 2
		vial.reset_motion()
		vial.set_feedback(false, false, false)
		vial.set_contents(bottle_contents[index])

	_set_status("Begin the separation. Drag a vial and align its mouth with another.")
	_refresh_hud()


func _set_status(value: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = value
