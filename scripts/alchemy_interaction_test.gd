extends Control

const BottleScript = preload("res://scripts/alchemy_bottle.gd")
const BACKGROUND_PATH := "res://assets/environments/laboratory_background.png"
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

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.024, 0.034, 0.43)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := _make_label("ALCHEMY CORE INTERACTION", 28, Color(0.97, 0.85, 0.65, 1.0))
	title.position = Vector2(28.0, 35.0)
	title.size = Vector2(664.0, 42.0)
	add_child(title)

	var subtitle := _make_label("OPEN GLASS VIALS  ·  LIQUID GEOMETRY  ·  DRAG TO POUR", 12, Color(0.82, 0.88, 0.85, 0.96))
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
		"HOLD A VIAL, LIFT IT AND DRAG ITS OPENING OVER ANOTHER VIAL. RELEASE TO POUR.",
		15,
		Color(0.95, 0.93, 0.84, 1.0)
	)
	instruction.position = Vector2(20.0, 19.0)
	instruction.size = Vector2(624.0, 44.0)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_panel.add_child(instruction)

	var note := _make_label("FOUR PROCEDURAL GLASS PROFILES · ONE SHARED LIQUID SYSTEM", 11, Color(0.72, 0.82, 0.81, 0.96))
	note.position = Vector2(20.0, 69.0)
	note.size = Vector2(624.0, 22.0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_panel.add_child(note)

	var stage_label := _make_label("AIM FOR THE OPEN MOUTH — NOT THE BODY OF THE VIAL", 12, Color(0.93, 0.84, 0.68, 0.95))
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

	status_label = _make_label("Pick up a vial and pour into an open mouth.", 16, Color(0.96, 0.94, 0.86, 1.0))
	status_label.position = Vector2(21.0, 23.0)
	status_label.size = Vector2(620.0, 44.0)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_panel.add_child(status_label)

	move_label = _make_label("MOVES 00", 12, Color(0.91, 0.75, 0.51, 1.0))
	move_label.position = Vector2(21.0, 83.0)
	move_label.size = Vector2(180.0, 24.0)
	status_panel.add_child(move_label)

	var hint := _make_label("Round, tall, square and bulbous shapes share one continuous, profile-fitted liquid volume.", 12, Color(0.72, 0.80, 0.80, 0.95))
	hint.position = Vector2(21.0, 115.0)
	hint.size = Vector2(420.0, 79.0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_panel.add_child(hint)

	reset_button = Button.new()
	reset_button.text = "RESET TEST"
	reset_button.position = Vector2(477.0, 141.0)
	reset_button.size = Vector2(156.0, 56.0)
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.add_theme_font_size_override("font_size", 13)
	reset_button.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82, 1.0))
	reset_button.add_theme_stylebox_override("normal", _button_style(Color(0.37, 0.27, 0.17, 1.0)))
	reset_button.add_theme_stylebox_override("hover", _button_style(Color(0.50, 0.37, 0.22, 1.0)))
	reset_button.pressed.connect(_reset_test)
	status_panel.add_child(reset_button)


func _build_bottles() -> void:
	var bottle_size := Vector2(140.0, 430.0)
	var gap: float = 14.0
	var total_width: float = bottle_size.x * 4.0 + gap * 3.0
	var start_x: float = (720.0 - total_width) * 0.5
	var row_y: float = 390.0
	var labels: Array[String] = ["ROUND", "TALL", "SQUARE", "BULB"]

	for index in range(4):
		var slot_position := Vector2(start_x + float(index) * (bottle_size.x + gap), row_y)
		var slot := Panel.new()
		slot.position = slot_position + Vector2(4.0, 8.0)
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
		vial.position = slot_position
		vial.size = bottle_size
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

	for index in range(bottle_controls.size()):
		var vial = bottle_controls[index]
		if Rect2(vial.position, vial.size).has_point(pointer):
			if bottle_contents[index].is_empty():
				_set_status("That vial is empty. Pick up one containing an essence.")
				return

			_drag_index = index
			_drag_origin = slot_positions[index]
			_grab_offset = pointer - vial.position
			_drag_start_pointer = pointer
			vial.z_index = 50
			vial.set_feedback(true, false, true)
			vial.set_pose(Vector2(28.0, 0.0))
			var anchored_grab_point: Vector2 = vial.get_drag_anchor_local(_grab_offset, vial.get_pose())
			vial.position = pointer - anchored_grab_point
			_set_status("Vial lifted. Guide its opening over a receiving vial.")
			return



func _update_drag(pointer: Vector2) -> void:
	if _drag_index < 0:
		return

	var source = bottle_controls[_drag_index]
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
		_set_status("Open mouths aligned. Release to pour.")
	else:
		_set_status("Guide the source vial's opening onto the receiving opening.")


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
	for index in range(source.size() - 1, -1, -1):
		if String(source[index]) == essence:
			run_length += 1
		else:
			break
	return mini(run_length, CAPACITY - target.size())


func _return_to_slot(source_index: int) -> void:
	_is_animating = true
	reset_button.disabled = true
	var source = bottle_controls[source_index]

	if _hover_index >= 0:
		bottle_controls[_hover_index].set_feedback(false, false, false)
	_hover_index = -1

	var return_tween := create_tween().set_parallel(true)
	return_tween.tween_property(source, "position", _drag_origin, 0.23).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return_tween.tween_method(Callable(source, "set_pose"), source.get_pose(), Vector2.ZERO, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await return_tween.finished

	source.z_index = 0
	source.set_feedback(false, false, false)
	source.reset_motion()
	_drag_index = -1
	_is_animating = false
	reset_button.disabled = false
	_set_status("Vial returned. Try another destination.")


func _perform_pour(source_index: int, target_index: int) -> void:
	_is_animating = true
	reset_button.disabled = true
	_pour_source = source_index
	_pour_target = target_index
	_pour_amount = _get_pour_amount(source_index, target_index)
	_pour_progress = 0.0
	_pour_source_preview = bottle_contents[source_index].duplicate()
	_pour_target_preview = bottle_contents[target_index].duplicate()

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
	var pour_angle: float = deg_to_rad(103.0) * direction
	var pour_pose := Vector2(24.0, pour_angle)
	const POUR_DRAW_SCALE := 0.82

	var target_mouth: Vector2 = target.get_mouth_position_in_parent()
	var desired_source_mouth: Vector2 = target_mouth + Vector2(-direction * 8.0, -6.0)
	var source_staging_position: Vector2 = desired_source_mouth - source.get_mouth_local_for_pose(pour_pose, POUR_DRAW_SCALE)

	if _hover_index >= 0:
		bottle_controls[_hover_index].set_feedback(false, true, false)
	_hover_index = -1
	_drag_index = -1
	source.set_feedback(false, false, false)

	source.set_preview(_pour_source_preview, _pour_source_start)
	target.set_preview(_pour_target_preview, _pour_target_start)
	_set_status("Aligning the open mouths...")

	var approach := create_tween().set_parallel(true)
	approach.tween_property(source, "position", source_staging_position, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	approach.tween_method(Callable(source, "set_pose"), source.get_pose(), pour_pose, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	approach.tween_method(Callable(source, "set_draw_scale"), source.get_draw_scale(), POUR_DRAW_SCALE, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await approach.finished

	source.trigger_slosh(0.24)
	target.trigger_slosh(0.12)
	_pour_stream_active = true
	_stream_shape.visible = true
	_stream_highlight.visible = true
	_splash_ring.visible = true
	for drop in _stream_drops:
		drop.visible = true
	_update_stream()

	_set_status("Pouring %s essence..." % essence.capitalize())
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

	for _index in range(_pour_amount):
		bottle_contents[source_index].pop_back()
		bottle_contents[target_index].append(essence)

	source.set_contents(bottle_contents[source_index])
	target.set_contents(bottle_contents[target_index])
	source.set_pose(Vector2.ZERO)
	target.trigger_slosh(0.20)
	source.z_index = 0
	source.set_feedback(false, false, false)
	target.set_feedback(false, false, false)

	_move_count += 1
	move_label.text = "MOVES %02d" % _move_count
	_set_status("Essence transferred. The liquid settles.")
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


func _reset_test() -> void:
	if _is_animating:
		return

	for index in range(bottle_contents.size()):
		bottle_contents[index] = INITIAL_CONTENTS[index].duplicate()
		bottle_controls[index].position = slot_positions[index]
		bottle_controls[index].z_index = 0
		bottle_controls[index].reset_motion()
		bottle_controls[index].set_feedback(false, false, false)
		bottle_controls[index].set_contents(bottle_contents[index])
		bottle_controls[index].trigger_slosh(0.0)

	_drag_index = -1
	_hover_index = -1
	_move_count = 0
	move_label.text = "MOVES 00"
	status_label.text = "Pick up a vial and pour into an open mouth."
	reset_button.disabled = false

	_pour_stream_active = false
	_stream_shape.visible = false
	_stream_highlight.visible = false
	_splash_ring.visible = false
	for drop in _stream_drops:
		drop.visible = false


func _set_status(value: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = value
