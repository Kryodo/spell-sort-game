extends "res://scripts/sorting_direction_prototype.gd"


class SlotMarkerSurface extends Control:
	var slot_markers: Array = []

	func configure(markers: Array) -> void:
		slot_markers = markers.duplicate(true)
		queue_redraw()

	func _draw() -> void:
		for marker in slot_markers:
			var centre: Vector2 = marker["centre"]
			var radius: Vector2 = marker["radius"]
			var scale_value: float = float(marker["scale"])

			var shadow := _ellipse_points(
				centre + Vector2(0.0, 5.0),
				radius.x * 1.12,
				radius.y * 1.28,
				48
			)
			draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.42))

			var inset := _ellipse_points(
				centre,
				radius.x,
				radius.y,
				48
			)
			draw_colored_polygon(inset, Color(0.012, 0.025, 0.026, 0.76))
			draw_polyline(
				_closed_points(inset),
				Color(0.38, 0.60, 0.54, 0.31),
				maxf(1.0, 1.5 * scale_value),
				true
			)

			var inner := _ellipse_points(
				centre + Vector2(0.0, -1.0),
				radius.x * 0.82,
				radius.y * 0.72,
				48
			)
			draw_polyline(
				_closed_points(inner),
				Color(0.72, 0.80, 0.69, 0.12),
				1.0,
				true
			)

	func _ellipse_points(centre: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
		var points := PackedVector2Array()
		for index in range(segments):
			var angle: float = TAU * float(index) / float(segments)
			points.append(centre + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
		return points

	func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
		var closed := points.duplicate()
		if not closed.is_empty():
			closed.append(closed[0])
		return closed


const VIAL_LEVELS := {
	4: 0,
	6: 4,
	8: 8
}
const LAYOUT_LABELS := {
	"line": "LINE",
	"arc": "ARC",
	"rows": "TWO ROWS"
}
const LAYOUT_NOTES := {
	"line": "Vessels share one horizontal line wherever the screen can comfortably fit them.",
	"arc": "Vessels follow a shallow curve, keeping the central positions slightly lower.",
	"rows": "Vessels use two aligned rows with a clear gap between the upper and lower groups."
}

var _selected_layout: String = "line"
var _selected_vial_count: int = 4
var _slot_surface: SlotMarkerSurface
var _layout_buttons: Dictionary = {}
var _count_buttons: Dictionary = {}


func _draw() -> void:
	# A dark, quiet play space with a small amount of atmospheric depth.
	# No table, rack, apparatus, scenery, or decorative props are drawn.
	draw_rect(Rect2(0.0, 0.0, 720.0, 1280.0), Color("#080e11"))
	draw_rect(Rect2(0.0, 0.0, 720.0, 286.0), Color("#0c1518"))

	for radius_step in range(9, 0, -1):
		var radius: float = float(radius_step) * 54.0
		var alpha: float = 0.006 + float(9 - radius_step) * 0.002
		draw_circle(Vector2(360.0, 620.0), radius, Color(0.19, 0.39, 0.34, alpha))

	# Faint edge lighting frames the playable area without competing with the vials.
	draw_line(Vector2(22.0, 292.0), Vector2(22.0, 928.0), Color(0.45, 0.67, 0.58, 0.055), 1.0, true)
	draw_line(Vector2(698.0, 292.0), Vector2(698.0, 928.0), Color(0.45, 0.67, 0.58, 0.055), 1.0, true)
	draw_line(Vector2(22.0, 928.0), Vector2(698.0, 928.0), Color(0.45, 0.67, 0.58, 0.075), 1.0, true)


func _build_interface() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var title := _make_label(
		"SPELL SORT",
		Vector2(26.0, 15.0),
		Vector2(360.0, 39.0),
		27,
		Color("#f0dfc5")
	)
	add_child(title)

	var subtitle := _make_label(
		"DARK PLAY SPACE  /  SLOT ARRANGEMENT STUDY",
		Vector2(29.0, 53.0),
		Vector2(440.0, 22.0),
		11,
		Color("#91a49c")
	)
	add_child(subtitle)

	level_label = _make_label(
		"TRIAL 01 / 10",
		Vector2(453.0, 53.0),
		Vector2(245.0, 22.0),
		11,
		Color("#c4b18e")
	)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(level_label)

	var return_button := _make_button(
		"RETURN TO WORLD",
		Vector2(528.0, 15.0),
		Vector2(170.0, 34.0),
		Callable(self, "_return_to_world")
	)
	return_button.add_theme_font_size_override("font_size", 10)
	add_child(return_button)

	var selector_panel := _make_panel(
		Rect2(18.0, 88.0, 684.0, 112.0),
		Color(0.018, 0.031, 0.034, 0.94),
		Color(0.42, 0.58, 0.52, 0.34),
		14
	)
	add_child(selector_panel)

	var layout_label := _make_label(
		"SLOT LAYOUT",
		Vector2(29.0, 91.0),
		Vector2(120.0, 18.0),
		9,
		Color("#9eafa3")
	)
	add_child(layout_label)

	var layout_specs := [
		{"id": "line", "label": "LINE", "x": 28.0},
		{"id": "arc", "label": "ARC", "x": 257.0},
		{"id": "rows", "label": "TWO ROWS", "x": 486.0}
	]
	for spec in layout_specs:
		var layout_id: String = spec["id"]
		var button := _make_button(
			String(spec["label"]),
			Vector2(float(spec["x"]), 111.0),
			Vector2(206.0, 32.0),
			Callable(self, "_select_layout").bind(layout_id)
		)
		button.add_theme_font_size_override("font_size", 11)
		add_child(button)
		_layout_buttons[layout_id] = button

	var count_label := _make_label(
		"VIAL COUNT",
		Vector2(29.0, 155.0),
		Vector2(90.0, 25.0),
		9,
		Color("#9eafa3")
	)
	add_child(count_label)

	for count_index in range(3):
		var vial_count: int = [4, 6, 8][count_index]
		var button := _make_button(
			"%d VIALS" % vial_count,
			Vector2(130.0 + float(count_index) * 120.0, 151.0),
			Vector2(108.0, 31.0),
			Callable(self, "_select_vial_count").bind(vial_count)
		)
		button.add_theme_font_size_override("font_size", 10)
		add_child(button)
		_count_buttons[vial_count] = button

	description_label = _make_label(
		"",
		Vector2(30.0, 215.0),
		Vector2(660.0, 62.0),
		14,
		Color("#d5ddd2"),
		true
	)
	add_child(description_label)

	_slot_surface = SlotMarkerSurface.new()
	_slot_surface.name = "MinimalSlotMarkers"
	_slot_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_surface.z_index = 1
	add_child(_slot_surface)

	var status_panel := _make_panel(
		Rect2(20.0, 951.0, 680.0, 122.0),
		Color(0.018, 0.031, 0.034, 0.95),
		Color(0.42, 0.58, 0.52, 0.34),
		14
	)
	status_panel.z_index = 12
	add_child(status_panel)

	status_label = _make_label(
		"",
		Vector2(38.0, 963.0),
		Vector2(510.0, 48.0),
		14,
		Color("#e4e5d9"),
		true
	)
	status_label.z_index = 13
	add_child(status_label)

	move_label = _make_label(
		"",
		Vector2(548.0, 967.0),
		Vector2(130.0, 28.0),
		12,
		Color("#c2b18d")
	)
	move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	move_label.z_index = 13
	add_child(move_label)

	objective_label = _make_label(
		"",
		Vector2(38.0, 1017.0),
		Vector2(644.0, 45.0),
		11,
		Color("#aebdb2"),
		true
	)
	objective_label.z_index = 13
	add_child(objective_label)

	var action_panel := _make_panel(
		Rect2(18.0, 1091.0, 684.0, 150.0),
		Color(0.018, 0.031, 0.034, 0.96),
		Color(0.42, 0.58, 0.52, 0.34),
		14
	)
	action_panel.z_index = 12
	add_child(action_panel)

	restart_button = _make_button(
		"RESTART",
		Vector2(27.0, 1111.0),
		Vector2(124.0, 48.0),
		Callable(self, "_restart_level")
	)
	restart_button.z_index = 13
	add_child(restart_button)

	undo_button = _make_button(
		"UNDO",
		Vector2(159.0, 1111.0),
		Vector2(124.0, 48.0),
		Callable(self, "_undo_move")
	)
	undo_button.z_index = 13
	add_child(undo_button)

	pipette_button = _make_button(
		"PIPETTE",
		Vector2(291.0, 1111.0),
		Vector2(124.0, 48.0),
		Callable(self, "_toggle_pipette")
	)
	pipette_button.z_index = 13
	add_child(pipette_button)

	transmute_button = _make_button(
		"TRANSMUTE",
		Vector2(423.0, 1111.0),
		Vector2(124.0, 48.0),
		Callable(self, "_transmute_selected")
	)
	transmute_button.z_index = 13
	add_child(transmute_button)

	next_level_action_button = _make_button(
		"NEXT TRIAL",
		Vector2(555.0, 1111.0),
		Vector2(138.0, 48.0),
		Callable(self, "_next_level")
	)
	next_level_action_button.z_index = 13
	add_child(next_level_action_button)

	var gesture_hint := _make_label(
		"DRAG A VIAL ONTO ANOTHER TO POUR  ·  TAP RESTART TO RESET THE TRIAL",
		Vector2(33.0, 1171.0),
		Vector2(654.0, 30.0),
		10,
		Color("#84978e")
	)
	gesture_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gesture_hint.z_index = 13
	add_child(gesture_hint)

	# The shared HUD refresh routine also updates these controls. They remain
	# unattached because this focused test has no track or previous-level tabs.
	track_a_button = Button.new()
	track_b_button = Button.new()
	previous_button = Button.new()
	next_button = Button.new()


func _build_vial_layout() -> void:
	var count: int = bottle_contents.size()
	var markers: Array = []

	match _selected_layout:
		"arc":
			if count <= 6:
				var scale_value: float = 1.0 if count == 4 else 0.84
				_place_vial_row(0, count, scale_value, 856.0, markers, 0.0, 48.0)
			else:
				_place_vial_row(0, 4, 0.80, 565.0, markers, 0.0, 22.0)
				_place_vial_row(4, 4, 0.80, 884.0, markers, 0.0, 22.0)
		"rows":
			_place_two_rows(count, markers, false)
		_:
			if count <= 6:
				var scale_value: float = 1.0 if count == 4 else 0.84
				_place_vial_row(0, count, scale_value, 856.0, markers)
			else:
				_place_vial_row(0, 4, 0.80, 565.0, markers)
				_place_vial_row(4, 4, 0.80, 884.0, markers)

	_slot_surface.configure(markers)


func _place_two_rows(count: int, markers: Array, staggered: bool) -> void:
	var columns: int = int(ceil(float(count) * 0.5))
	var upper_count: int = columns
	var lower_count: int = count - upper_count
	var scale_value: float
	match count:
		4:
			scale_value = 0.96
		6:
			scale_value = 0.88
		_:
			scale_value = 0.80

	_place_vial_row(0, upper_count, scale_value, 565.0, markers, 20.0 if staggered else 0.0)
	if lower_count > 0:
		_place_vial_row(upper_count, lower_count, scale_value, 884.0, markers, -20.0 if staggered else 0.0)


func _place_vial_row(
	start_index: int,
	row_count: int,
	scale_value: float,
	base_y: float,
	markers: Array,
	horizontal_shift: float = 0.0,
	arc_strength: float = 0.0
) -> void:
	var size_value: Vector2 = BOTTLE_SOURCE_SIZE * scale_value
	var gap: float = (720.0 - float(row_count) * size_value.x) / float(row_count + 1)

	for column in range(row_count):
		var x_position: float = gap + float(column) * (size_value.x + gap) + horizontal_shift
		var normalized_x: float = (x_position + size_value.x * 0.5 - 360.0) / 330.0
		var foot_y: float = base_y - pow(absf(normalized_x), 1.45) * arc_strength
		var position_value := Vector2(
			x_position,
			foot_y - _vial_base_offset(size_value)
		)
		var vial_index: int = start_index + column
		_add_minimal_vial(vial_index, position_value, size_value, markers)


func _add_minimal_vial(index: int, position_value: Vector2, size_value: Vector2, markers: Array) -> void:
	var vial: Control = BottleScript.new()
	vial.name = "SortingVial%02d" % (index + 1)
	vial.position = position_value
	vial.size = size_value
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
	add_child(vial)
	bottle_nodes.append(vial)
	slot_positions.append(position_value)

	var foot := Vector2(
		position_value.x + size_value.x * 0.5,
		position_value.y + _vial_base_offset(size_value)
	)
	markers.append({
		"centre": foot,
		"radius": Vector2(size_value.x * 0.47, size_value.x * 0.125),
		"scale": size_value.x / BOTTLE_SOURCE_SIZE.x
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


func _vial_base_offset(size_value: Vector2) -> float:
	return 72.0 + size_value.y * 0.735 * 0.975


func _refresh_hud() -> void:
	super._refresh_hud()
	if not is_instance_valid(level_label):
		return

	level_label.text = "TRIAL %02d / 10" % (current_level + 1)
	for layout_id in _layout_buttons:
		var button: Button = _layout_buttons[layout_id]
		button.text = "•  " + String(LAYOUT_LABELS[layout_id]) if layout_id == _selected_layout else String(LAYOUT_LABELS[layout_id])
	for vial_count in _count_buttons:
		var button: Button = _count_buttons[vial_count]
		button.text = "•  %d VIALS" % int(vial_count) if int(vial_count) == _selected_vial_count else "%d VIALS" % int(vial_count)


func _select_layout(layout_id: String) -> void:
	if layout_id == _selected_layout or is_animating:
		return
	_selected_layout = layout_id
	_load_level()
	_set_status(String(LAYOUT_NOTES[layout_id]) + " The vial positions change; the sorting rules stay the same.")


func _select_vial_count(vial_count: int) -> void:
	if is_animating or not VIAL_LEVELS.has(vial_count):
		return
	_selected_vial_count = vial_count
	current_track = "B"
	current_level = int(VIAL_LEVELS[vial_count])
	_load_level()
	_set_status("Showing %d playable vials. Change the slot layout above to compare their spacing." % vial_count)
