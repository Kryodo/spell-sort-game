extends Control

const BottleScript = preload("res://scripts/alchemy_bottle.gd")
const BOTTLE_SHEET_PATH := "res://assets/bottles/bottles_sheet.png"
const BACKGROUND_PATH := "res://assets/environments/laboratory_background.png"
const BOTTLE_COLUMNS := 4
const BOTTLE_ROWS := 4
const CAPACITY := 4

const PALETTE: Dictionary = {
	"tide": Color(0.24, 0.77, 0.76, 1.0),
	"moon": Color(0.66, 0.54, 0.91, 1.0),
	"ember": Color(0.96, 0.51, 0.24, 1.0)
}

const INITIAL_CONTENTS: Array = [
	["tide", "moon", "ember"],
	["moon", "tide", "moon"],
	["ember", "tide", "ember"],
	[]
]

var bottle_controls: Array = []
var bottle_contents: Array = []
var slot_positions: Array[Vector2] = []
var generated_images: Array = []
var generated_textures: Array = []

var status_label: Label
var move_label: Label
var reset_button: Button

var _drag_index: int = -1
var _hover_index: int = -1
var _drag_origin: Vector2 = Vector2.ZERO
var _grab_offset: Vector2 = Vector2.ZERO
var _drag_start_pointer: Vector2 = Vector2.ZERO
var _is_animating: bool = false

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
var _move_count: int = 0

var _stream_glow: Line2D
var _stream_core: Line2D
var _stream_spark: Line2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_interface()
	_load_bottle_variants()
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

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.024, 0.034, 0.43)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := _make_label("ALCHEMY INTERACTION TEST", 29, Color(0.97, 0.85, 0.65, 1.0))
	title.position = Vector2(28.0, 35.0)
	title.size = Vector2(664.0, 42.0)
	add_child(title)

	var subtitle := _make_label("BOTTLE ARTWORK  vs  PROCEDURAL GLASS", 13, Color(0.82, 0.88, 0.85, 0.96))
	subtitle.position = Vector2(31.0, 83.0)
	subtitle.size = Vector2(658.0, 26.0)
	add_child(subtitle)

	var instruction_panel := _make_panel(
		Rect2(28.0, 142.0, 664.0, 112.0),
		Color(0.025, 0.047, 0.060, 0.88),
		Color(0.74, 0.61, 0.42, 0.65)
	)
	add_child(instruction_panel)

	var instruction := _make_label(
		"HOLD A BOTTLE, LIFT IT AND DRAG OVER A MATCHING OR EMPTY VIAL. RELEASE TO POUR.",
		15,
		Color(0.95, 0.93, 0.84, 1.0)
	)
	instruction.position = Vector2(48.0, 161.0)
	instruction.size = Vector2(624.0, 44.0)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_panel.add_child(instruction)

	var note := _make_label("LIQUID SHAPE, GLASS FIT, LIFT AND POUR ARE ALL LIVE TESTS", 11, Color(0.72, 0.82, 0.81, 0.96))
	note.position = Vector2(48.0, 211.0)
	note.size = Vector2(624.0, 22.0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_panel.add_child(note)

	var stage_label := _make_label("TRY MOVING ESSENCE BETWEEN DIFFERENT BOTTLE TYPES", 12, Color(0.93, 0.84, 0.68, 0.95))
	stage_label.position = Vector2(28.0, 303.0)
	stage_label.size = Vector2(664.0, 26.0)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(stage_label)

	var status_panel := _make_panel(
		Rect2(28.0, 947.0, 664.0, 235.0),
		Color(0.025, 0.047, 0.060, 0.91),
		Color(0.74, 0.61, 0.42, 0.72)
	)
	add_child(status_panel)

	status_label = _make_label("Grab a bottle and try a pour.", 17, Color(0.96, 0.94, 0.86, 1.0))
	status_label.position = Vector2(49.0, 970.0)
	status_label.size = Vector2(620.0, 44.0)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_panel.add_child(status_label)

	move_label = _make_label("MOVES 00", 12, Color(0.91, 0.75, 0.51, 1.0))
	move_label.position = Vector2(49.0, 1030.0)
	move_label.size = Vector2(180.0, 24.0)
	status_panel.add_child(move_label)

	var hint := _make_label("Generated shells use the sheet's alpha silhouette. Procedural shells use editable shape profiles. Both share the same liquid renderer.", 12, Color(0.72, 0.80, 0.80, 0.95))
	hint.position = Vector2(49.0, 1062.0)
	hint.size = Vector2(420.0, 79.0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_panel.add_child(hint)

	reset_button = Button.new()
	reset_button.text = "RESET TEST"
	reset_button.position = Vector2(505.0, 1088.0)
	reset_button.size = Vector2(156.0, 56.0)
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.add_theme_font_size_override("font_size", 13)
	reset_button.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82, 1.0))
	reset_button.add_theme_stylebox_override("normal", _button_style(Color(0.37, 0.27, 0.17, 1.0)))
	reset_button.add_theme_stylebox_override("hover", _button_style(Color(0.50, 0.37, 0.22, 1.0)))
	reset_button.pressed.connect(_reset_test)
	status_panel.add_child(reset_button)


func _load_bottle_variants() -> void:
	generated_images.clear()
	generated_textures.clear()
	var sheet := Image.load_from_file(BOTTLE_SHEET_PATH)
	if sheet.is_empty():
		push_warning("Bottle sheet could not be read. The test will still run with procedural bottles.")
		return

	var cell_width: int = int(sheet.get_width() / BOTTLE_COLUMNS)
	var cell_height: int = int(sheet.get_height() / BOTTLE_ROWS)
	if cell_width <= 0 or cell_height <= 0:
		push_warning("Bottle sheet dimensions are invalid.")
		return

	for cell_index in range(2):
		var column: int = cell_index % BOTTLE_COLUMNS
		var row: int = int(cell_index / BOTTLE_COLUMNS)
		var cell := sheet.get_region(Rect2i(column * cell_width, row * cell_height, cell_width, cell_height))
		var used_bounds := cell.get_used_rect()
		if used_bounds.size.x <= 0 or used_bounds.size.y <= 0:
			generated_images.append(null)
			generated_textures.append(null)
			continue
		var cropped := cell.get_region(used_bounds)
		generated_images.append(cropped)
		generated_textures.append(ImageTexture.create_from_image(cropped))


func _build_bottles() -> void:
	var viewport_size := get_viewport_rect().size
	var bottle_size := Vector2(140.0, 430.0)
	var gap: float = 17.0
	var total_width: float = bottle_size.x * 4.0 + gap * 3.0
	var start_x: float = (viewport_size.x - total_width) * 0.5
	var row_y: float = 390.0

	var labels: Array[String] = ["SHEET A", "SHEET B", "ROUND", "TALL"]
	var modes: Array[int] = [
		BottleScript.MODE_GENERATED,
		BottleScript.MODE_GENERATED,
		BottleScript.MODE_PROCEDURAL,
		BottleScript.MODE_PROCEDURAL
	]
	var variants: Array[int] = [0, 1, 0, 1]

	for i in range(4):
		var x: float = start_x + float(i) * (bottle_size.x + gap)
		var slot := Panel.new()
		slot.position = Vector2(x + 4.0, row_y + 8.0)
		slot.size = bottle_size - Vector2(8.0, 12.0)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.025, 0.043, 0.052, 0.18)
		slot_style.border_color = Color(0.78, 0.67, 0.49, 0.22)
		slot_style.set_border_width_all(1)
		slot_style.set_corner_radius_all(22)
		slot.add_theme_stylebox_override("panel", slot_style)
		add_child(slot)

		var vial = BottleScript.new()
		vial.position = Vector2(x, row_y)
		vial.size = bottle_size
		vial.setup(
			i,
			labels[i],
			modes[i],
			variants[i],
			generated_textures[mini(i, 1)] if modes[i] == BottleScript.MODE_GENERATED and generated_textures.size() > 0 else null,
			generated_images[mini(i, 1)] if modes[i] == BottleScript.MODE_GENERATED and generated_images.size() > 0 else null,
			PALETTE,
			INITIAL_CONTENTS[i]
		)
		add_child(vial)
		bottle_controls.append(vial)
		slot_positions.append(Vector2(x, row_y))
		bottle_contents.append(INITIAL_CONTENTS[i].duplicate())


func _build_stream_layers() -> void:
	_stream_glow = _make_stream_line(12.0, Color(0.2, 0.9, 0.8, 0.25), 100)
	_stream_core = _make_stream_line(3.5, Color(0.6, 1.0, 0.95, 0.95), 101)
	_stream_spark = _make_stream_line(5.0, Color(1.0, 1.0, 1.0, 0.9), 102)


func _make_stream_line(width: float, tint: Color, order: int) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = tint
	line.antialiased = true
	line.z_index = order
	line.visible = false
	add_child(line)
	return line


func _make_label(text_value: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_panel(rect: Rect2, background_color: Color, border_color: Color) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(19)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _button_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = Color(0.88, 0.70, 0.47, 0.90)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	return style


func _gui_input(event: InputEvent) -> void:
	if _is_animating:
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
	if _drag_index >= 0:
		return
	for i in range(bottle_controls.size()):
		var vial = bottle_controls[i]
		if Rect2(vial.position, vial.size).has_point(pointer):
			if bottle_contents[i].is_empty():
				_set_status("That vial is empty. Pick up one containing an essence.")
				return
			_drag_index = i
			_drag_origin = slot_positions[i]
			_grab_offset = pointer - vial.position
			_drag_start_pointer = pointer
			vial.z_index = 50
			vial.set_feedback(true, false, true)
			vial.set_pose(Vector2(27.0, 0.0))
			_set_status("Bottle lifted. Drag it over a matching or empty vial.")
			return


func _update_drag(pointer: Vector2) -> void:
	if _drag_index < 0:
		return
	var source = bottle_controls[_drag_index]
	source.position = pointer - _grab_offset
	var horizontal_motion: float = pointer.x - _drag_start_pointer.x
	var tilt: float = clampf(horizontal_motion * 0.0015, -0.28, 0.28)
	source.set_pose(Vector2(27.0, tilt))

	var next_hover: int = _find_target_at(pointer, _drag_index)
	if next_hover != _hover_index:
		if _hover_index >= 0:
			bottle_controls[_hover_index].set_feedback(false, false, false)
		_hover_index = next_hover
		if _hover_index >= 0:
			bottle_controls[_hover_index].set_feedback(false, true, false)

	if _hover_index >= 0:
		_set_status("Valid destination. Release to pour.")
	else:
		_set_status("Move over a matching essence or an empty vial.")


func _find_target_at(pointer: Vector2, source_index: int) -> int:
	for i in range(bottle_controls.size()):
		if i == source_index:
			continue
		var vial = bottle_controls[i]
		if Rect2(slot_positions[i], vial.size).has_point(pointer) and _can_pour(source_index, i):
			return i
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
		_return_to_slot(source_index)


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
	for i in range(source.size() - 1, -1, -1):
		if String(source[i]) == essence:
			run_length += 1
		else:
			break
	return mini(run_length, CAPACITY - target.size())


func _return_to_slot(source_index: int) -> void:
	_is_animating = true
	var source = bottle_controls[source_index]
	if _hover_index >= 0:
		bottle_controls[_hover_index].set_feedback(false, false, false)
	_hover_index = -1
	var tween := create_tween().set_parallel(true)
	tween.tween_property(source, "position", _drag_origin, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(Callable(source, "set_pose"), source.get_pose(), Vector2.ZERO, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	source.z_index = 0
	source.set_feedback(false, false, false)
	source.set_pose(Vector2.ZERO)
	_drag_index = -1
	_is_animating = false
	_set_status("Bottle returned. Try another destination.")


func _perform_pour(source_index: int, target_index: int) -> void:
	_is_animating = true
	_pour_source = source_index
	_pour_target = target_index
	_pour_amount = _get_pour_amount(source_index, target_index)
	_pour_progress = 0.0
	_pour_source_preview = bottle_contents[source_index].duplicate()
	_pour_target_preview = bottle_contents[target_index].duplicate()

	var essence: String = String(_pour_source_preview.back())
	_pour_color = PALETTE[essence]
	for _i in range(_pour_amount):
		_pour_target_preview.append(essence)
	_pour_source_start = float(_pour_source_preview.size())
	_pour_target_start = float(bottle_contents[target_index].size())

	var source = bottle_controls[source_index]
	var target = bottle_controls[target_index]
	var source_origin: Vector2 = _drag_origin
	var direction: float = 1.0 if slot_positions[target_index].x > source_origin.x else -1.0
	var staging_offset := Vector2(-64.0 * direction, -110.0)
	var staging_position: Vector2 = slot_positions[target_index] + staging_offset
	var target_slot: Vector2 = slot_positions[target_index]
	var tilt_angle: float = deg_to_rad(28.0 * direction)

	if _hover_index >= 0:
		bottle_controls[_hover_index].set_feedback(false, true, false)
	_hover_index = -1
	_drag_index = -1
	source.set_preview(_pour_source_preview, _pour_source_start)
	target.set_preview(_pour_target_preview, _pour_target_start)
	_set_status("Pouring %s essence..." % essence.capitalize())

	var approach := create_tween().set_parallel(true)
	approach.tween_property(source, "position", staging_position, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	approach.tween_method(Callable(source, "set_pose"), source.get_pose(), Vector2(24.0, tilt_angle), 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await approach.finished

	_pour_stream_active = true
	_stream_glow.visible = true
	_stream_core.visible = true
	_stream_spark.visible = true
	_update_stream()

	var pour_tween := create_tween()
	pour_tween.tween_method(Callable(self, "_set_pour_progress"), 0.0, 1.0, 0.92).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await pour_tween.finished

	_pour_stream_active = false
	_stream_glow.visible = false
	_stream_core.visible = false
	_stream_spark.visible = false

	var return_tween := create_tween().set_parallel(true)
	return_tween.tween_property(source, "position", source_origin, 0.23).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_method(Callable(source, "set_pose"), Vector2(24.0, tilt_angle), Vector2.ZERO, 0.23).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await return_tween.finished

	for _i in range(_pour_amount):
		bottle_contents[source_index].pop_back()
		bottle_contents[target_index].append(essence)
	source.set_contents(bottle_contents[source_index])
	target.set_contents(bottle_contents[target_index])
	source.z_index = 0
	source.set_feedback(false, false, false)
	target.set_feedback(false, false, false)

	_move_count += 1
	move_label.text = "MOVES %02d" % _move_count
	_set_status("Essence transferred. Try another bottle or reset the test.")
	_pour_source = -1
	_pour_target = -1
	_pour_progress = 0.0
	_is_animating = false
	reset_button.disabled = false


func _set_pour_progress(progress: float) -> void:
	_pour_progress = progress
	var source_level: float = lerpf(_pour_source_start, _pour_source_start - float(_pour_amount), progress)
	var target_level: float = lerpf(_pour_target_start, _pour_target_start + float(_pour_amount), progress)
	bottle_controls[_pour_source].set_preview(_pour_source_preview, source_level)
	bottle_controls[_pour_target].set_preview(_pour_target_preview, target_level)
	_update_stream()


func _process(delta: float) -> void:
	if _pour_stream_active:
		_stream_phase = fposmod(_stream_phase + delta * 2.3, 1.0)
		_update_stream()


func _update_stream() -> void:
	if not _pour_stream_active or _pour_source < 0 or _pour_target < 0:
		return
	var source = bottle_controls[_pour_source]
	var target = bottle_controls[_pour_target]
	var inverse: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var start: Vector2 = inverse * source.get_global_spout_position()
	var finish: Vector2 = inverse * target.get_global_spout_position()
	var span: float = finish.x - start.x
	var control_one := start + Vector2(span * 0.28, 35.0)
	var control_two := finish - Vector2(span * 0.28, -35.0)
	var points := PackedVector2Array()
	for i in range(25):
		var t: float = float(i) / 24.0
		points.append(start.bezier_interpolate(control_one, control_two, finish, t))
	var alpha: float = 0.55 + 0.35 * sin(PI * _pour_progress)
	_stream_glow.points = points
	_stream_glow.default_color = Color(_pour_color.r, _pour_color.g, _pour_color.b, alpha * 0.28)
	_stream_core.points = points
	_stream_core.default_color = Color(_pour_color.r, _pour_color.g, _pour_color.b, alpha)
	var spark_t: float = fposmod(_stream_phase, 1.0)
	var spark_points := PackedVector2Array()
	for offset in [-0.035, 0.0, 0.035]:
		var sample_t: float = clampf(spark_t + offset, 0.0, 1.0)
		spark_points.append(start.bezier_interpolate(control_one, control_two, finish, sample_t))
	_stream_spark.points = spark_points
	_stream_spark.default_color = Color(1.0, 1.0, 1.0, alpha * 0.90)


func _reset_test() -> void:
	if _is_animating:
		return
	for i in range(bottle_contents.size()):
		bottle_contents[i] = INITIAL_CONTENTS[i].duplicate()
		bottle_controls[i].position = slot_positions[i]
		bottle_controls[i].z_index = 0
		bottle_controls[i].set_pose(Vector2.ZERO)
		bottle_controls[i].set_feedback(false, false, false)
		bottle_controls[i].set_contents(bottle_contents[i])
	_drag_index = -1
	_hover_index = -1
	_move_count = 0
	move_label.text = "MOVES 00"
	status_label.text = "Grab a bottle and try a pour."
	reset_button.disabled = false


func _set_status(value: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = value
