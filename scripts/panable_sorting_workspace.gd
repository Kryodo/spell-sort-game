extends "res://scripts/sorting_direction_prototype.gd"


class WorkspaceSurface extends Control:
	var slot_markers: Array = []

	func configure(markers: Array) -> void:
		slot_markers = markers.duplicate(true)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#091114"))

		for radius_step in range(10, 0, -1):
			var radius := float(radius_step) * 82.0
			var alpha := 0.0035 + float(10 - radius_step) * 0.001
			draw_circle(Vector2(size.x * 0.51, size.y * 0.47), radius, Color(0.17, 0.39, 0.34, alpha))

		for marker in slot_markers:
			var centre: Vector2 = marker["centre"]
			var radius: Vector2 = marker["radius"]
			var occupied: bool = bool(marker["occupied"])
			var highlighted: bool = bool(marker["highlighted"])

			var shadow := _ellipse_points(centre + Vector2(0.0, 5.0), radius.x * 1.13, radius.y * 1.28, 40)
			draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.42))

			var inset := _ellipse_points(centre, radius.x, radius.y, 40)
			var fill := Color(0.012, 0.026, 0.029, 0.72)
			if highlighted:
				fill = Color(0.035, 0.105, 0.087, 0.78)
			draw_colored_polygon(inset, fill)

			var edge_color := Color(0.39, 0.60, 0.53, 0.23) if occupied else Color(0.42, 0.59, 0.54, 0.14)
			if highlighted:
				edge_color = Color(0.54, 0.83, 0.69, 0.54)
			draw_polyline(_closed_points(inset), edge_color, 1.5, true)

			var inner := _ellipse_points(centre + Vector2(0.0, -1.0), radius.x * 0.80, radius.y * 0.68, 40)
			draw_polyline(
				_closed_points(inner),
				Color(0.73, 0.88, 0.78, 0.10 if occupied else 0.07),
				1.0,
				true
			)

	func _ellipse_points(centre: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
		var points := PackedVector2Array()
		for index in range(segments):
			var angle := TAU * float(index) / float(segments)
			points.append(centre + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
		return points

	func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
		var closed := points.duplicate()
		if not closed.is_empty():
			closed.append(closed[0])
		return closed


const WORKSPACE_SIZE := Vector2(1720.0, 1500.0)
const SLOT_COLUMNS := [260.0, 660.0, 1060.0, 1460.0]
const SLOT_ROWS := [390.0, 850.0, 1310.0]
const VIAL_SCALE := 0.86
const MIN_ZOOM := 0.64
const MAX_ZOOM := 1.08
const INITIAL_ZOOM := 0.75
const SLOT_DROP_RADIUS := 166.0

var _workspace_view: Control
var _workspace_content: Control
var _workspace_surface: WorkspaceSurface
var _workspace_offset := Vector2.ZERO
var _workspace_zoom := INITIAL_ZOOM
var _workspace_slot_positions: Array[Vector2] = []
var _vial_slot_indices: Array[int] = []

var _arrange_mode := false
var _drag_started_in_arrange_mode := false
var _arrange_button: Button
var _zoom_label: Label
var _mode_hint_label: Label

var _pan_active := false
var _pan_pointer := Vector2.ZERO
var _active_pointer_source := ""
var _active_touch_index := -1

var _touch_points: Dictionary = {}
var _pinch_active := false
var _pinch_start_distance := 1.0
var _pinch_start_zoom := INITIAL_ZOOM
var _pinch_anchor_world := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	current_track = "B"
	current_level = clampi(launch_level, 0, 9)
	_build_interface()
	_build_workspace()
	_set_initial_camera()
	_load_level()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(720.0, 1280.0)), Color("#070d10"))
	draw_rect(Rect2(0.0, 0.0, 720.0, 190.0), Color("#0a1215"))
	draw_line(Vector2(22.0, 187.0), Vector2(698.0, 187.0), Color(0.42, 0.64, 0.55, 0.10), 1.0, true)


func _build_interface() -> void:
	var title := _make_label(
		"SPELL SORT",
		Vector2(25.0, 13.0),
		Vector2(360.0, 38.0),
		27,
		Color("#f0dfc5")
	)
	add_child(title)

	var subtitle := _make_label(
		"SPATIAL WORKSPACE  /  FIXED SLOT STUDY",
		Vector2(28.0, 49.0),
		Vector2(450.0, 20.0),
		11,
		Color("#91a49c")
	)
	add_child(subtitle)

	var return_button := _make_button(
		"RETURN TO WORLD",
		Vector2(528.0, 15.0),
		Vector2(170.0, 34.0),
		Callable(self, "_return_to_world")
	)
	return_button.add_theme_font_size_override("font_size", 10)
	add_child(return_button)

	level_label = _make_label(
		"TRIAL 08 / 10",
		Vector2(28.0, 78.0),
		Vector2(180.0, 22.0),
		11,
		Color("#c4b18e")
	)
	add_child(level_label)

	description_label = _make_label(
		"",
		Vector2(28.0, 101.0),
		Vector2(470.0, 66.0),
		13,
		Color("#d5ddd2"),
		true
	)
	add_child(description_label)

	_arrange_button = _make_button(
		"SWAP MODE: OFF",
		Vector2(514.0, 91.0),
		Vector2(184.0, 43.0),
		Callable(self, "_toggle_arrange_mode")
	)
	_arrange_button.add_theme_font_size_override("font_size", 11)
	add_child(_arrange_button)

	_zoom_label = _make_label(
		"ZOOM 78%",
		Vector2(518.0, 151.0),
		Vector2(82.0, 25.0),
		10,
		Color("#aebdb2")
	)
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_zoom_label)

	var zoom_out_button := _make_button(
		"−",
		Vector2(610.0, 148.0),
		Vector2(40.0, 30.0),
		Callable(self, "_zoom_out")
	)
	zoom_out_button.add_theme_font_size_override("font_size", 17)
	add_child(zoom_out_button)

	var zoom_in_button := _make_button(
		"+",
		Vector2(655.0, 148.0),
		Vector2(42.0, 30.0),
		Callable(self, "_zoom_in")
	)
	zoom_in_button.add_theme_font_size_override("font_size", 17)
	add_child(zoom_in_button)

	var workspace_heading := _make_label(
		"WORKSPACE  /  12 FIXED POSITIONS",
		Vector2(25.0, 190.0),
		Vector2(360.0, 18.0),
		9,
		Color("#82968d")
	)
	add_child(workspace_heading)

	var status_panel := _make_panel(
		Rect2(20.0, 916.0, 680.0, 108.0),
		Color(0.018, 0.031, 0.034, 0.95),
		Color(0.42, 0.58, 0.52, 0.34),
		14
	)
	status_panel.z_index = 12
	add_child(status_panel)

	status_label = _make_label(
		"",
		Vector2(38.0, 928.0),
		Vector2(500.0, 43.0),
		14,
		Color("#e4e5d9"),
		true
	)
	status_label.z_index = 13
	add_child(status_label)

	move_label = _make_label(
		"",
		Vector2(545.0, 930.0),
		Vector2(133.0, 28.0),
		12,
		Color("#c2b18d")
	)
	move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	move_label.z_index = 13
	add_child(move_label)

	objective_label = _make_label(
		"",
		Vector2(38.0, 974.0),
		Vector2(642.0, 38.0),
		11,
		Color("#aebdb2"),
		true
	)
	objective_label.z_index = 13
	add_child(objective_label)

	var action_panel := _make_panel(
		Rect2(18.0, 1040.0, 684.0, 216.0),
		Color(0.018, 0.031, 0.034, 0.96),
		Color(0.42, 0.58, 0.52, 0.34),
		14
	)
	action_panel.z_index = 12
	add_child(action_panel)

	restart_button = _make_button(
		"RESTART",
		Vector2(27.0, 1057.0),
		Vector2(124.0, 48.0),
		Callable(self, "_restart_level")
	)
	restart_button.z_index = 13
	add_child(restart_button)

	undo_button = _make_button(
		"UNDO",
		Vector2(159.0, 1057.0),
		Vector2(124.0, 48.0),
		Callable(self, "_undo_move")
	)
	undo_button.z_index = 13
	add_child(undo_button)

	pipette_button = _make_button(
		"PIPETTE",
		Vector2(291.0, 1057.0),
		Vector2(124.0, 48.0),
		Callable(self, "_toggle_pipette")
	)
	pipette_button.z_index = 13
	add_child(pipette_button)

	transmute_button = _make_button(
		"TRANSMUTE",
		Vector2(423.0, 1057.0),
		Vector2(124.0, 48.0),
		Callable(self, "_transmute_selected")
	)
	transmute_button.z_index = 13
	add_child(transmute_button)

	next_level_action_button = _make_button(
		"NEXT TRIAL",
		Vector2(555.0, 1057.0),
		Vector2(138.0, 48.0),
		Callable(self, "_next_level")
	)
	next_level_action_button.z_index = 13
	add_child(next_level_action_button)

	_mode_hint_label = _make_label(
		"DRAG EMPTY SPACE TO PAN  ·  PINCH OR USE + / − TO ZOOM",
		Vector2(31.0, 1120.0),
		Vector2(658.0, 25.0),
		10,
		Color("#84978e")
	)
	_mode_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_hint_label.z_index = 13
	add_child(_mode_hint_label)

	var arrangement_hint := _make_label(
		"TURN ON SWAP MODE TO MOVE A VIAL INTO ANOTHER POSITION OR SWAP TWO VIALS",
		Vector2(30.0, 1154.0),
		Vector2(660.0, 31.0),
		10,
		Color("#84978e"),
		true
	)
	arrangement_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrangement_hint.z_index = 13
	add_child(arrangement_hint)

	# The inherited HUD refresh also updates controls that are not part of this
	# focused workspace experiment.
	track_a_button = Button.new()
	track_b_button = Button.new()
	previous_button = Button.new()
	next_button = Button.new()


func _build_workspace() -> void:
	var frame := _make_panel(
		Rect2(17.0, 209.0, 686.0, 696.0),
		Color("#111b1e"),
		Color(0.44, 0.62, 0.55, 0.34),
		16
	)
	frame.z_index = 0
	add_child(frame)

	_workspace_view = Control.new()
	_workspace_view.name = "WorkspaceViewport"
	_workspace_view.position = Vector2(20.0, 212.0)
	_workspace_view.size = Vector2(680.0, 690.0)
	_workspace_view.clip_contents = true
	_workspace_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_workspace_view.z_index = 1
	add_child(_workspace_view)

	_workspace_content = Control.new()
	_workspace_content.name = "WorkspaceCanvas"
	_workspace_content.size = WORKSPACE_SIZE
	_workspace_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_workspace_view.add_child(_workspace_content)

	_workspace_surface = WorkspaceSurface.new()
	_workspace_surface.name = "WorkspaceSurface"
	_workspace_surface.size = WORKSPACE_SIZE
	_workspace_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_workspace_content.add_child(_workspace_surface)

	_workspace_slot_positions.clear()
	var vial_size := BOTTLE_SOURCE_SIZE * VIAL_SCALE
	for row_y in SLOT_ROWS:
		for column_x in SLOT_COLUMNS:
			var vial_position := Vector2(
				column_x - vial_size.x * 0.5,
				row_y - _vial_base_offset(vial_size)
			)
			_workspace_slot_positions.append(vial_position)


func _set_initial_camera() -> void:
	_workspace_zoom = INITIAL_ZOOM
	var initial_world_centre := Vector2(660.0, 550.0)
	_workspace_offset = _workspace_view.size * 0.5 - initial_world_centre * _workspace_zoom
	_apply_workspace_camera()


func _apply_workspace_camera() -> void:
	if not is_instance_valid(_workspace_content):
		return
	_clamp_workspace_offset()
	_workspace_content.position = _workspace_offset
	_workspace_content.scale = Vector2.ONE * _workspace_zoom
	if is_instance_valid(_zoom_label):
		_zoom_label.text = "ZOOM %d%%" % roundi(_workspace_zoom * 100.0)


func _clamp_workspace_offset() -> void:
	var scaled_size := WORKSPACE_SIZE * _workspace_zoom
	var minimum_offset := _workspace_view.size - scaled_size
	_workspace_offset.x = clampf(_workspace_offset.x, minf(minimum_offset.x, 0.0), 0.0)
	_workspace_offset.y = clampf(_workspace_offset.y, minf(minimum_offset.y, 0.0), 0.0)


func _screen_to_workspace(screen_position: Vector2) -> Vector2:
	var viewport_position := screen_position - _workspace_view.position
	return (viewport_position - _workspace_offset) / _workspace_zoom


func _point_inside_workspace(screen_position: Vector2) -> bool:
	return Rect2(_workspace_view.position, _workspace_view.size).has_point(screen_position)


func _zoom_at(next_zoom: float, screen_position: Vector2) -> void:
	var local_position := screen_position - _workspace_view.position
	var anchored_world_position := (local_position - _workspace_offset) / _workspace_zoom
	_workspace_zoom = clampf(next_zoom, MIN_ZOOM, MAX_ZOOM)
	_workspace_offset = local_position - anchored_world_position * _workspace_zoom
	_apply_workspace_camera()


func _zoom_in() -> void:
	_zoom_at(_workspace_zoom * 1.12, _workspace_view.position + _workspace_view.size * 0.5)


func _zoom_out() -> void:
	_zoom_at(_workspace_zoom / 1.12, _workspace_view.position + _workspace_view.size * 0.5)


func _refresh_workspace_markers() -> void:
	if not is_instance_valid(_workspace_surface):
		return
	var markers: Array = []
	var vial_size := BOTTLE_SOURCE_SIZE * VIAL_SCALE
	for slot_index in range(_workspace_slot_positions.size()):
		var slot_position: Vector2 = _workspace_slot_positions[slot_index]
		var occupied := _get_vial_in_slot(slot_index) >= 0
		var foot := Vector2(
			slot_position.x + vial_size.x * 0.5,
			slot_position.y + _vial_base_offset(vial_size)
		)
		markers.append({
			"centre": foot,
			"radius": Vector2(vial_size.x * 0.48, vial_size.x * 0.13),
			"occupied": occupied,
			"highlighted": _arrange_mode and not occupied
		})
	_workspace_surface.configure(markers)


func _vial_base_offset(size_value: Vector2) -> float:
	return 72.0 + size_value.y * 0.735 * 0.975


func _build_vial_layout() -> void:
	_vial_slot_indices.clear()
	var vial_size := BOTTLE_SOURCE_SIZE * VIAL_SCALE

	for index in range(bottle_contents.size()):
		var slot_index := index
		_vial_slot_indices.append(slot_index)
		var vial_position: Vector2 = _workspace_slot_positions[slot_index]
		var vial := BottleScript.new()
		vial.name = "WorkspaceVial%02d" % (index + 1)
		vial.position = vial_position
		vial.size = vial_size
		vial.z_index = 2
		vial.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vial.call(
			"setup",
			index,
			"%02d" % (index + 1),
			index % 4,
			PALETTE,
			bottle_contents[index]
		)
		_workspace_content.add_child(vial)
		bottle_nodes.append(vial)
		slot_positions.append(vial_position)

		if index == int(level_data.get("locked_vial", -1)):
			locked_label = _make_label(
				"SEALED",
				vial_position + Vector2(4.0, vial_size.y * 0.54),
				Vector2(vial_size.x - 8.0, 24.0),
				10,
				Color("#f5d69a")
			)
			locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			locked_label.z_index = 8
			locked_label.add_to_group("direction_level_overlay")
			_workspace_content.add_child(locked_label)

	_refresh_workspace_markers()


func _clear_level_nodes() -> void:
	for vial in bottle_nodes:
		if is_instance_valid(vial):
			var vial_parent := vial.get_parent()
			if vial_parent != null:
				vial_parent.remove_child(vial)
			vial.queue_free()
	bottle_nodes.clear()
	slot_positions.clear()
	_vial_slot_indices.clear()

	for child in _workspace_content.get_children():
		if child.is_in_group("direction_level_overlay"):
			_workspace_content.remove_child(child)
			child.queue_free()
	_refresh_workspace_markers()


func _get_vial_at(pointer: Vector2) -> int:
	for index in range(bottle_nodes.size() - 1, -1, -1):
		var vial: Control = bottle_nodes[index]
		if Rect2(slot_positions[index], vial.size).has_point(pointer):
			return index
	return -1


func _get_vial_in_slot(slot_index: int) -> int:
	for vial_index in range(_vial_slot_indices.size()):
		if _vial_slot_indices[vial_index] == slot_index:
			return vial_index
	return -1


func _get_slot_near_position(vial_position: Vector2) -> int:
	var nearest_slot := -1
	var nearest_distance := SLOT_DROP_RADIUS
	for slot_index in range(_workspace_slot_positions.size()):
		var distance := vial_position.distance_to(_workspace_slot_positions[slot_index])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_slot = slot_index
	return nearest_slot


func _begin_arrangement_drag(world_position: Vector2) -> void:
	if selected_vial >= 0 or is_animating:
		return
	var index := _get_vial_at(world_position)
	if index < 0:
		return

	selected_vial = index
	tool_selected_vial = -1
	is_dragging = true
	drag_origin = slot_positions[index]
	grab_offset = world_position - drag_origin
	var vial: Control = bottle_nodes[index]
	vial.z_index = 50
	vial.call("set_feedback", true, false, true)
	vial.call("set_pose", Vector2.ZERO)
	var pickup_anchor: Vector2 = vial.call("get_point_local_for_pose", grab_offset, Vector2.ZERO)
	vial.position = world_position - pickup_anchor


func _begin_workspace_pointer(screen_position: Vector2, source: String, touch_index: int = -1) -> void:
	if is_animating or round_complete and not _arrange_mode:
		return
	var world_position := _screen_to_workspace(screen_position)
	var vial_index := _get_vial_at(world_position)
	if vial_index >= 0:
		_drag_started_in_arrange_mode = _arrange_mode
		if _drag_started_in_arrange_mode:
			_begin_arrangement_drag(world_position)
		else:
			_begin_drag(world_position)
		if selected_vial >= 0:
			_active_pointer_source = source
			_active_touch_index = touch_index
	else:
		_pan_active = true
		_pan_pointer = screen_position
		_active_pointer_source = source
		_active_touch_index = touch_index


func _finish_arrangement_drag(world_position: Vector2) -> void:
	if selected_vial < 0 or not is_dragging:
		return

	var source_index := selected_vial
	var requested_position := world_position - grab_offset
	var target_slot := _get_slot_near_position(requested_position)
	is_dragging = false

	if target_slot < 0:
		_return_vial(source_index, "No fixed position nearby. The vial has returned to its original slot.")
		return

	var source_slot := _vial_slot_indices[source_index]
	if target_slot == source_slot:
		_return_vial(source_index, "Vial returned to its existing position.")
		return

	var target_index := _get_vial_in_slot(target_slot)
	_save_history()

	if target_index >= 0:
		_vial_slot_indices[source_index] = target_slot
		_vial_slot_indices[target_index] = source_slot
		slot_positions[source_index] = _workspace_slot_positions[target_slot]
		slot_positions[target_index] = _workspace_slot_positions[source_slot]
	else:
		_vial_slot_indices[source_index] = target_slot
		slot_positions[source_index] = _workspace_slot_positions[target_slot]

	is_animating = true
	var source_vial: Control = bottle_nodes[source_index]
	var movement := create_tween().set_parallel(true)
	movement.tween_property(
		source_vial,
		"position",
		slot_positions[source_index],
		0.22
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	movement.tween_method(
		Callable(source_vial, "set_pose"),
		source_vial.call("get_pose"),
		Vector2.ZERO,
		0.20
	)

	if target_index >= 0:
		var target_vial: Control = bottle_nodes[target_index]
		movement.tween_property(
			target_vial,
			"position",
			slot_positions[target_index],
			0.22
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await movement.finished

	source_vial.z_index = 2
	source_vial.call("set_feedback", false, false, false)
	source_vial.call("reset_motion")
	if target_index >= 0:
		var moved_target: Control = bottle_nodes[target_index]
		moved_target.z_index = 2
		moved_target.call("reset_motion")
		moved_target.call("set_feedback", false, false, false)

	move_count += 1
	selected_vial = -1
	tool_selected_vial = -1
	is_animating = false
	_refresh_workspace_markers()
	_set_status(
		"Vials swapped. Their contents and sorting rules stayed with each vessel."
		if target_index >= 0
		else "Vial moved into an empty fixed position."
	)
	_refresh_hud()


func _toggle_arrange_mode() -> void:
	if is_animating or is_dragging:
		return
	_arrange_mode = not _arrange_mode
	if tool_selected_vial >= 0 and tool_selected_vial < bottle_nodes.size():
		bottle_nodes[tool_selected_vial].call("set_feedback", false, false, false)
	tool_selected_vial = -1
	_refresh_workspace_markers()
	_set_status(
		"Swap mode is active. Drag a vial onto another slot to swap, or onto an empty slot to move it."
		if _arrange_mode
		else "Pour mode is active. Drag a vial onto another vial to transfer its top essence group."
	)
	_refresh_hud()


func _refresh_hud() -> void:
	super._refresh_hud()
	if not is_instance_valid(_arrange_button):
		return
	_arrange_button.text = "SWAP MODE: ON" if _arrange_mode else "SWAP MODE: OFF"
	_zoom_label.text = "ZOOM %d%%" % roundi(_workspace_zoom * 100.0)
	_mode_hint_label.text = (
		"SWAP MODE  ·  DRAG TO AN OCCUPIED OR EMPTY POSITION"
		if _arrange_mode
		else "DRAG EMPTY SPACE TO PAN  ·  PINCH OR USE + / − TO ZOOM"
	)


func _save_history() -> void:
	super._save_history()
	if not move_history.is_empty():
		move_history.back()["slot_indices"] = _vial_slot_indices.duplicate()


func _undo_move() -> void:
	if is_animating or move_history.is_empty():
		return
	var snapshot: Dictionary = move_history.back()
	if snapshot.has("slot_indices"):
		_vial_slot_indices.clear()
		for slot_index in snapshot["slot_indices"]:
			_vial_slot_indices.append(int(slot_index))
		for vial_index in range(_vial_slot_indices.size()):
			slot_positions[vial_index] = _workspace_slot_positions[_vial_slot_indices[vial_index]]
	super._undo_move()
	_refresh_workspace_markers()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _point_inside_workspace(event.position):
					_begin_workspace_pointer(event.position, "mouse")
					if _active_pointer_source == "mouse":
						get_viewport().set_input_as_handled()
			elif _active_pointer_source == "mouse":
				if selected_vial >= 0:
					var world_position := _screen_to_workspace(event.position)
					if _drag_started_in_arrange_mode:
						_finish_arrangement_drag(world_position)
					else:
						_finish_drag(world_position)
				_pan_active = false
				_active_pointer_source = ""
				_active_touch_index = -1
				get_viewport().set_input_as_handled()
		elif event.pressed and _point_inside_workspace(event.position):
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(_workspace_zoom * 1.10, event.position)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(_workspace_zoom / 1.10, event.position)
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if _active_pointer_source == "mouse":
			if selected_vial >= 0 and is_dragging:
				_update_drag(_screen_to_workspace(event.position))
				get_viewport().set_input_as_handled()
			elif _pan_active:
				_workspace_offset += event.position - _pan_pointer
				_pan_pointer = event.position
				_apply_workspace_camera()
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenTouch:
		if event.pressed:
			if not _point_inside_workspace(event.position):
				return
			_touch_points[event.index] = event.position
			if _touch_points.size() == 1:
				_begin_workspace_pointer(event.position, "touch", event.index)
			elif _touch_points.size() == 2 and selected_vial < 0:
				_start_pinch()
			get_viewport().set_input_as_handled()
		else:
			if not _touch_points.has(event.index):
				return
			if selected_vial >= 0 and _active_pointer_source == "touch" and _active_touch_index == event.index:
				var world_position := _screen_to_workspace(event.position)
				if _drag_started_in_arrange_mode:
					_finish_arrangement_drag(world_position)
				else:
					_finish_drag(world_position)
			_touch_points.erase(event.index)
			if _touch_points.size() < 2:
				_pinch_active = false
			if _touch_points.size() == 1 and selected_vial < 0:
				var remaining_index = _touch_points.keys()[0]
				_active_pointer_source = "touch"
				_active_touch_index = int(remaining_index)
				_pan_pointer = _touch_points[remaining_index]
				_pan_active = true
			elif _touch_points.is_empty():
				_pan_active = false
				_active_pointer_source = ""
				_active_touch_index = -1
			get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		if not _touch_points.has(event.index):
			return
		_touch_points[event.index] = event.position
		if selected_vial >= 0 and _active_pointer_source == "touch" and _active_touch_index == event.index:
			_update_drag(_screen_to_workspace(event.position))
		elif _pinch_active and _touch_points.size() >= 2:
			_update_pinch()
		elif _pan_active and _active_pointer_source == "touch" and _active_touch_index == event.index:
			_workspace_offset += event.position - _pan_pointer
			_pan_pointer = event.position
			_apply_workspace_camera()
		get_viewport().set_input_as_handled()


func _start_pinch() -> void:
	if _touch_points.size() < 2:
		return
	var points := _get_first_two_touch_points()
	var midpoint := (points[0] + points[1]) * 0.5
	_pinch_start_distance = maxf(1.0, points[0].distance_to(points[1]))
	_pinch_start_zoom = _workspace_zoom
	_pinch_anchor_world = _screen_to_workspace(midpoint)
	_pinch_active = true
	_pan_active = false
	_active_pointer_source = "touch"


func _update_pinch() -> void:
	var points := _get_first_two_touch_points()
	if points.size() < 2:
		return
	var midpoint := (points[0] + points[1]) * 0.5
	var next_distance := maxf(1.0, points[0].distance_to(points[1]))
	_workspace_zoom = clampf(
		_pinch_start_zoom * next_distance / _pinch_start_distance,
		MIN_ZOOM,
		MAX_ZOOM
	)
	var local_midpoint := midpoint - _workspace_view.position
	_workspace_offset = local_midpoint - _pinch_anchor_world * _workspace_zoom
	_apply_workspace_camera()


func _get_first_two_touch_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for touch_index in _touch_points:
		points.append(_touch_points[touch_index])
		if points.size() == 2:
			break
	return points


func _return_to_world() -> void:
	if is_animating or is_dragging:
		return
	get_tree().change_scene_to_file("res://scenes/greenhouse_journey.tscn")
