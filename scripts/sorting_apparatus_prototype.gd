extends "res://scripts/sorting_experiment_interface.gd"


class ApparatusStudySurface extends Control:
	var design: String = "aperture"
	var anchors: Array = []

	func configure(next_design: String, next_anchors: Array) -> void:
		design = next_design
		anchors = next_anchors.duplicate(true)
		queue_redraw()

	func _draw() -> void:
		match design:
			"rail":
				_draw_modular_rail()
			"constellation":
				_draw_runic_array()
			_:
				_draw_aperture_ring()

	func _draw_aperture_ring() -> void:
		var centre := Vector2(360.0, 770.0)
		_draw_ellipse(
			centre,
			326.0,
			190.0,
			Color(0.018, 0.044, 0.039, 0.34),
			Color(0.58, 0.43, 0.27, 0.72),
			5.0
		)
		_draw_ellipse(
			centre,
			286.0,
			153.0,
			Color(0.018, 0.055, 0.049, 0.24),
			Color(0.83, 0.66, 0.39, 0.46),
			2.0
		)
		_draw_ellipse(
			centre,
			250.0,
			126.0,
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.25, 0.55, 0.47, 0.26),
			1.5
		)

		# Short radial engravings make the ring read as an instrument, not a tray.
		for index in range(16):
			var angle: float = TAU * float(index) / 16.0
			var outer_point := centre + Vector2(cos(angle) * 306.0, sin(angle) * 176.0)
			var inner_point := centre + Vector2(cos(angle) * 291.0, sin(angle) * 161.0)
			draw_line(outer_point, inner_point, Color(0.88, 0.69, 0.41, 0.48), 1.4, true)

		# The central opening stays visually open: it is the working heart of the device.
		_draw_ellipse(
			centre,
			116.0,
			65.0,
			Color(0.008, 0.025, 0.026, 0.72),
			Color(0.42, 0.77, 0.65, 0.62),
			3.0
		)
		_draw_ellipse(
			centre,
			91.0,
			48.0,
			Color(0.035, 0.115, 0.094, 0.52),
			Color(0.87, 0.70, 0.43, 0.36),
			1.2
		)
		_draw_diamond(centre, Vector2(20.0, 30.0), Color(0.80, 0.88, 0.66, 0.52))

		for anchor in anchors:
			var foot: Vector2 = anchor["foot"]
			var size_value: Vector2 = anchor["size"]
			_draw_ellipse(
				foot + Vector2(0.0, 5.0),
				size_value.x * 0.53,
				maxf(9.0, size_value.x * 0.105),
				Color(0.012, 0.025, 0.024, 0.48),
				Color(0.78, 0.60, 0.35, 0.66),
				2.0
			)
			_draw_ellipse(
				foot,
				size_value.x * 0.42,
				maxf(6.0, size_value.x * 0.075),
				Color(0.13, 0.17, 0.13, 0.40),
				Color(0.91, 0.74, 0.48, 0.42),
				1.0
			)

	func _draw_modular_rail() -> void:
		var rows: Dictionary = {}
		for anchor in anchors:
			var row_key := "rear" if bool(anchor.get("rear", false)) else "front"
			if not rows.has(row_key):
				rows[row_key] = []
			rows[row_key].append(anchor)

		for row_key in rows:
			var row: Array = rows[row_key]
			if row.is_empty():
				continue
			var left_x := 720.0
			var right_x := 0.0
			var rail_y := 0.0
			for anchor in row:
				var foot: Vector2 = anchor["foot"]
				var size_value: Vector2 = anchor["size"]
				left_x = minf(left_x, foot.x - size_value.x * 0.55)
				right_x = maxf(right_x, foot.x + size_value.x * 0.55)
				rail_y += foot.y
			rail_y /= float(row.size())

			left_x = maxf(18.0, left_x - 18.0)
			right_x = minf(702.0, right_x + 18.0)
			var rail := PackedVector2Array([
				Vector2(left_x + 12.0, rail_y + 3.0),
				Vector2(right_x - 12.0, rail_y + 3.0),
				Vector2(right_x, rail_y + 28.0),
				Vector2(left_x, rail_y + 28.0)
			])
			draw_colored_polygon(rail, Color("#493728"))
			draw_polyline(_closed_points(rail), Color(0.76, 0.56, 0.34, 0.78), 2.0, true)
			draw_line(
				Vector2(left_x + 15.0, rail_y + 24.0),
				Vector2(right_x - 15.0, rail_y + 24.0),
				Color(0.12, 0.085, 0.061, 0.82),
				3.0,
				true
			)

			# Each vessel gets its own sliding saddle and two small retaining arms.
			for anchor in row:
				var foot: Vector2 = anchor["foot"]
				var size_value: Vector2 = anchor["size"]
				var half_bracket: float = size_value.x * 0.39
				_draw_ellipse(
					foot + Vector2(0.0, 5.0),
					size_value.x * 0.48,
					maxf(9.0, size_value.x * 0.10),
					Color(0.025, 0.035, 0.032, 0.54),
					Color(0.72, 0.56, 0.35, 0.78),
					2.0
				)
				draw_line(
					Vector2(foot.x - half_bracket, foot.y - 12.0),
					Vector2(foot.x - half_bracket, foot.y + 12.0),
					Color("#c09a60"),
					3.0,
					true
				)
				draw_line(
					Vector2(foot.x + half_bracket, foot.y - 12.0),
					Vector2(foot.x + half_bracket, foot.y + 12.0),
					Color("#c09a60"),
					3.0,
					true
				)
				draw_circle(foot + Vector2(-half_bracket, 13.0), 3.0, Color("#e0bd7b"))
				draw_circle(foot + Vector2(half_bracket, 13.0), 3.0, Color("#e0bd7b"))

		# The rear tier is visibly raised, but remains a separate, repeatable rail.
		if rows.has("rear"):
			var rear: Array = rows["rear"]
			if not rear.is_empty():
				var first_foot: Vector2 = rear[0]["foot"]
				var last_foot: Vector2 = rear[rear.size() - 1]["foot"]
				for support_x in [first_foot.x - 34.0, last_foot.x + 34.0]:
					draw_line(
						Vector2(support_x, first_foot.y + 27.0),
						Vector2(support_x, first_foot.y + 54.0),
						Color("#4c3929"),
						7.0,
					true
					)
					draw_line(
						Vector2(support_x - 7.0, first_foot.y + 54.0),
						Vector2(support_x + 7.0, first_foot.y + 54.0),
						Color("#98724a"),
						3.0,
					true
					)

	func _draw_runic_array() -> void:
		var nexus := Vector2(360.0, 666.0)
		# Connections are deliberately fine and low-contrast, so each station
		# remains visually independent instead of reading as a fixed rack.
		for anchor in anchors:
			var foot: Vector2 = anchor["foot"]
			draw_line(nexus, foot + Vector2(0.0, 7.0), Color(0.48, 0.78, 0.65, 0.22), 3.0, true)
			draw_line(nexus, foot + Vector2(0.0, 7.0), Color(0.82, 0.74, 0.50, 0.22), 1.0, true)

		_draw_ellipse(
			nexus,
			60.0,
			31.0,
			Color(0.018, 0.045, 0.041, 0.76),
			Color(0.77, 0.61, 0.39, 0.72),
			2.0
		)
		_draw_ellipse(
			nexus,
			42.0,
			21.0,
			Color(0.06, 0.15, 0.12, 0.68),
			Color(0.46, 0.80, 0.67, 0.54),
			1.4
		)
		_draw_diamond(nexus, Vector2(13.0, 20.0), Color(0.88, 0.76, 0.50, 0.76))

		for anchor in anchors:
			var foot: Vector2 = anchor["foot"]
			var size_value: Vector2 = anchor["size"]
			var half_width: float = size_value.x * 0.48
			var plate := PackedVector2Array([
				foot + Vector2(-half_width * 0.78, -7.0),
				foot + Vector2(-half_width * 0.58, -15.0),
				foot + Vector2(half_width * 0.58, -15.0),
				foot + Vector2(half_width * 0.78, -7.0),
				foot + Vector2(half_width * 0.68, 10.0),
				foot + Vector2(-half_width * 0.68, 10.0)
			])
			draw_colored_polygon(plate, Color(0.045, 0.075, 0.064, 0.70))
			draw_polyline(_closed_points(plate), Color(0.77, 0.64, 0.42, 0.66), 2.0, true)
			_draw_ellipse(
				foot + Vector2(0.0, -3.0),
				size_value.x * 0.37,
				maxf(7.0, size_value.x * 0.07),
				Color(0.10, 0.19, 0.15, 0.44),
				Color(0.47, 0.80, 0.65, 0.58),
				1.5
			)
			for side in [-1.0, 1.0]:
				var rune_position := foot + Vector2(side * half_width * 0.60, -4.0)
				draw_line(
					rune_position + Vector2(-3.0, -4.0),
					rune_position + Vector2(3.0, 4.0),
					Color(0.85, 0.75, 0.51, 0.68),
					1.5,
					true
				)

	func _draw_ellipse(
		centre: Vector2,
		radius_x: float,
		radius_y: float,
		fill: Color,
		outline: Color,
		line_width: float
	) -> void:
		var points := _ellipse_points(centre, radius_x, radius_y, 72)
		if fill.a > 0.001:
			draw_colored_polygon(points, fill)
		if outline.a > 0.001:
			draw_polyline(_closed_points(points), outline, line_width, true)

	func _draw_diamond(centre: Vector2, dimensions: Vector2, tint: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			centre + Vector2(0.0, -dimensions.y),
			centre + Vector2(dimensions.x, 0.0),
			centre + Vector2(0.0, dimensions.y),
			centre + Vector2(-dimensions.x, 0.0)
		]), tint)

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
const APPARATUS_LABELS := {
	"aperture": "APERTURE RING",
	"rail": "MODULAR RAIL",
	"constellation": "RUNIC ARRAY"
}
const APPARATUS_NOTES := {
	"aperture": "A shared circular instrument with an open central well and vessel stations around its outer ring.",
	"rail": "A practical adjustable cradle: each vessel has its own sliding saddle and retaining arms.",
	"constellation": "Independent runic pedestals linked by a faint magical circuit rather than a continuous rack."
}

var _apparatus_design: String = "aperture"
var _selected_vial_count: int = 4
var _study_surface: ApparatusStudySurface
var _apparatus_buttons: Dictionary = {}
var _vial_count_buttons: Dictionary = {}


func _draw() -> void:
	# The chapter environment is the backdrop; the apparatus is a separate layer.
	pass


func _build_interface() -> void:
	super._build_interface()

	if is_instance_valid(_apparatus_surface):
		_apparatus_surface.visible = false

	_study_surface = ApparatusStudySurface.new()
	_study_surface.name = "ApparatusStudySurface"
	_study_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_study_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_study_surface.z_index = 1
	add_child(_study_surface)

	var selector_panel := _make_panel(
		Rect2(18.0, 258.0, 684.0, 88.0),
		Color(0.012, 0.027, 0.024, 0.88),
		Color(0.76, 0.59, 0.36, 0.48),
		14
	)
	selector_panel.z_index = 12
	add_child(selector_panel)

	var apparatus_label := _make_label(
		"APPARATUS",
		Vector2(28.0, 262.0),
		Vector2(95.0, 30.0),
		10,
		Color("#b7c3b2")
	)
	apparatus_label.z_index = 13
	add_child(apparatus_label)

	var design_specs := [
		{"id": "aperture", "label": "APERTURE RING", "x": 126.0},
		{"id": "rail", "label": "MODULAR RAIL", "x": 322.0},
		{"id": "constellation", "label": "RUNIC ARRAY", "x": 518.0}
	]
	for spec in design_specs:
		var design_id: String = spec["id"]
		var button := _make_button(
			String(spec["label"]),
			Vector2(float(spec["x"]), 260.0),
			Vector2(184.0, 34.0),
			Callable(self, "_select_apparatus").bind(design_id)
		)
		button.add_theme_font_size_override("font_size", 11)
		button.z_index = 14
		add_child(button)
		_apparatus_buttons[design_id] = button

	var count_label := _make_label(
		"VESSELS",
		Vector2(28.0, 305.0),
		Vector2(88.0, 28.0),
		10,
		Color("#b7c3b2")
	)
	count_label.z_index = 13
	add_child(count_label)

	for count_index in range(3):
		var vial_count: int = [4, 6, 8][count_index]
		var button := _make_button(
			"%d VIALS" % vial_count,
			Vector2(126.0 + float(count_index) * 124.0, 302.0),
			Vector2(112.0, 34.0),
			Callable(self, "_select_vial_count").bind(vial_count)
		)
		button.add_theme_font_size_override("font_size", 11)
		button.z_index = 14
		add_child(button)
		_vial_count_buttons[vial_count] = button

	var interaction_note := _make_label(
		"DRAG AND POUR AS NORMAL",
		Vector2(518.0, 305.0),
		Vector2(170.0, 28.0),
		9,
		Color("#9eae9f")
	)
	interaction_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	interaction_note.z_index = 13
	add_child(interaction_note)


func _build_vial_layout() -> void:
	var count := bottle_contents.size()
	var anchors: Array = []

	if _apparatus_design == "constellation":
		_build_constellation_layout(count, anchors)
	elif count <= 6:
		_build_single_row_layout(count, anchors)
	else:
		_build_two_row_layout(anchors)

	_study_surface.configure(_apparatus_design, anchors)


func _build_single_row_layout(count: int, anchors: Array) -> void:
	var scale_value := 1.0 if count <= 4 else 0.82
	var size_value: Vector2 = BOTTLE_SOURCE_SIZE * scale_value
	var gap: float = (720.0 - float(count) * size_value.x) / float(count + 1)

	for index in range(count):
		var x_position: float = gap + float(index) * (size_value.x + gap)
		var normalized_x: float = (x_position + size_value.x * 0.5 - 360.0) / 310.0
		var curve: float = sqrt(maxf(0.0, 1.0 - normalized_x * normalized_x))
		var foot_y: float = 878.0
		if _apparatus_design == "aperture":
			foot_y += curve * 18.0
		var position_value := Vector2(
			x_position,
			foot_y - _vial_base_offset(size_value)
		)
		_add_study_vial(index, position_value, size_value, anchors, false)


func _build_two_row_layout(anchors: Array) -> void:
	var rear_size: Vector2 = BOTTLE_SOURCE_SIZE * 0.68
	var front_size: Vector2 = BOTTLE_SOURCE_SIZE * 0.72
	var rear_gap: float = (720.0 - 4.0 * rear_size.x) / 5.0
	var front_gap: float = (720.0 - 4.0 * front_size.x) / 5.0

	for column in range(4):
		var rear_position := Vector2(
			rear_gap + float(column) * (rear_size.x + rear_gap),
			642.0 - _vial_base_offset(rear_size)
		)
		_add_study_vial(column, rear_position, rear_size, anchors, true)

		var front_position := Vector2(
			front_gap + float(column) * (front_size.x + front_gap),
			888.0 - _vial_base_offset(front_size)
		)
		_add_study_vial(4 + column, front_position, front_size, anchors, false)


func _build_constellation_layout(count: int, anchors: Array) -> void:
	var columns: int = int(count / 2)
	var scale_value: float = 0.88 if count == 4 else (0.76 if count == 6 else 0.68)
	var size_value: Vector2 = BOTTLE_SOURCE_SIZE * scale_value
	var gap: float = (720.0 - float(columns) * size_value.x) / float(columns + 1)
	var upper_foot_y: float = 640.0
	var lower_scale: float = 0.88 if count == 4 else (0.76 if count == 6 else 0.72)
	var lower_size: Vector2 = BOTTLE_SOURCE_SIZE * lower_scale
	var lower_gap: float = (720.0 - float(columns) * lower_size.x) / float(columns + 1)
	var lower_foot_y: float = 928.0 if count == 4 else (920.0 if count == 6 else 900.0)

	for column in range(columns):
		var upper_position := Vector2(
			gap + float(column) * (size_value.x + gap),
			upper_foot_y - _vial_base_offset(size_value)
		)
		_add_study_vial(column, upper_position, size_value, anchors, true)

		var lower_position := Vector2(
			lower_gap + float(column) * (lower_size.x + lower_gap),
			lower_foot_y - _vial_base_offset(lower_size)
		)
		_add_study_vial(columns + column, lower_position, lower_size, anchors, false)


func _add_study_vial(
	index: int,
	position_value: Vector2,
	size_value: Vector2,
	anchors: Array,
	rear: bool
) -> void:
	_add_experiment_vial(index, position_value, size_value)
	var foot := Vector2(
		position_value.x + size_value.x * 0.5,
		position_value.y + _vial_base_offset(size_value)
	)
	anchors.append({
		"position": position_value,
		"size": size_value,
		"foot": foot,
		"rear": rear
	})


func _vial_base_offset(size_value: Vector2) -> float:
	return 72.0 + size_value.y * 0.735 * 0.975


func _refresh_hud() -> void:
	super._refresh_hud()
	if not is_instance_valid(level_label):
		return

	level_label.text = "APPARATUS STUDY  ·  %d VIALS" % _selected_vial_count
	for design_id in _apparatus_buttons:
		var button: Button = _apparatus_buttons[design_id]
		button.text = "•  " + String(APPARATUS_LABELS[design_id]) if design_id == _apparatus_design else String(APPARATUS_LABELS[design_id])
	for vial_count in _vial_count_buttons:
		var button: Button = _vial_count_buttons[vial_count]
		button.text = "•  %d VIALS" % vial_count if int(vial_count) == _selected_vial_count else "%d VIALS" % int(vial_count)


func _select_apparatus(design_id: String) -> void:
	if design_id == _apparatus_design:
		return
	_apparatus_design = design_id
	_load_level()
	_set_status(String(APPARATUS_NOTES[design_id]) + " The vial rules and drag interaction are unchanged.")


func _select_vial_count(vial_count: int) -> void:
	if vial_count == _selected_vial_count or not VIAL_LEVELS.has(vial_count):
		return
	_selected_vial_count = vial_count
	current_track = "B"
	current_level = int(VIAL_LEVELS[vial_count])
	_load_level()
	_set_status("Showing %d vessels. Select another apparatus above to compare the same puzzle size." % vial_count)
