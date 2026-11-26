extends "res://scripts/sorting_direction_prototype.gd"


class ApparatusSurface extends Control:
	var anchors: Array = []
	var rear_count: int = 0

	func configure(new_anchors: Array, new_rear_count: int) -> void:
		anchors = new_anchors.duplicate(true)
		rear_count = new_rear_count
		queue_redraw()

	func _draw() -> void:
		# A restrained engraved curve ties the loose vessels together without
		# turning the table into a fixed rack or a numbered grid.
		draw_arc(
			Vector2(360.0, 824.0),
			272.0,
			deg_to_rad(205.0),
			deg_to_rad(335.0),
			72,
			Color(0.90, 0.70, 0.42, 0.19),
			1.6,
			true
		)

		if rear_count > 0:
			_draw_rear_shelf()

		for anchor in anchors:
			var position_value: Vector2 = anchor["position"]
			var size_value: Vector2 = anchor["size"]
			var base_y: float = position_value.y + 72.0 + size_value.y * 0.735 * 0.975
			var centre := Vector2(position_value.x + size_value.x * 0.5, base_y - 3.0)
			var radius_x: float = maxf(30.0, size_value.x * 0.47)
			var radius_y: float = maxf(7.0, size_value.x * 0.13)

			draw_colored_polygon(
				_ellipse_points(centre + Vector2(0.0, 3.0), radius_x, radius_y, 36),
				Color(0.012, 0.021, 0.019, 0.34)
			)
			draw_arc(
				centre,
				radius_x,
				deg_to_rad(8.0),
				deg_to_rad(172.0),
				32,
				Color(0.89, 0.70, 0.43, 0.43),
				1.5,
				true
			)
			draw_arc(
				centre + Vector2(0.0, 2.0),
				radius_x * 0.80,
				deg_to_rad(195.0),
				deg_to_rad(345.0),
				28,
				Color(0.82, 0.65, 0.39, 0.22),
				1.0,
				true
			)

	func _draw_rear_shelf() -> void:
		var left_x := 720.0
		var right_x := 0.0
		var shelf_y := 0.0
		for index in range(mini(rear_count, anchors.size())):
			var anchor: Dictionary = anchors[index]
			var position_value: Vector2 = anchor["position"]
			var size_value: Vector2 = anchor["size"]
			var base_y: float = position_value.y + 72.0 + size_value.y * 0.735 * 0.975
			left_x = minf(left_x, position_value.x)
			right_x = maxf(right_x, position_value.x + size_value.x)
			shelf_y = maxf(shelf_y, base_y)

		left_x = maxf(24.0, left_x - 26.0)
		right_x = minf(696.0, right_x + 26.0)
		shelf_y -= 12.0

		var shelf := PackedVector2Array([
			Vector2(left_x + 12.0, shelf_y),
			Vector2(right_x - 12.0, shelf_y),
			Vector2(right_x, shelf_y + 27.0),
			Vector2(left_x, shelf_y + 27.0)
		])
		draw_colored_polygon(shelf, Color("#4d3526"))
		draw_polyline(
			_closed_points(shelf),
			Color(0.77, 0.56, 0.33, 0.70),
			2.0,
			true
		)
		draw_line(
			Vector2(left_x + 10.0, shelf_y + 24.0),
			Vector2(right_x - 10.0, shelf_y + 24.0),
			Color(0.13, 0.085, 0.058, 0.72),
			3.0,
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


var _apparatus_surface: ApparatusSurface


func _draw() -> void:
	# The greenhouse environment is a child scene behind this interface.
	# Deliberately do not paint an opaque gameplay-screen background here.
	pass


func _build_interface() -> void:
	_apparatus_surface = ApparatusSurface.new()
	_apparatus_surface.name = "AdaptiveApparatusSurface"
	_apparatus_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apparatus_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apparatus_surface.z_index = 1
	add_child(_apparatus_surface)

	var header := _make_panel(
		Rect2(18.0, 18.0, 684.0, 116.0),
		Color(0.012, 0.027, 0.024, 0.88),
		Color(0.76, 0.59, 0.36, 0.58),
		18
	)
	header.z_index = 12
	add_child(header)

	var kicker := _make_label(
		"CHAPTER 01  /  THE OVERGROWN GREENHOUSE",
		Vector2(38.0, 29.0),
		Vector2(430.0, 20.0),
		11,
		Color("#b9c5ae")
	)
	kicker.z_index = 13
	add_child(kicker)

	var title := _make_label(
		"A PURE FORMULA",
		Vector2(36.0, 51.0),
		Vector2(430.0, 44.0),
		29,
		Color("#f3dfbd")
	)
	title.z_index = 13
	add_child(title)

	level_label = _make_label(
		"",
		Vector2(477.0, 30.0),
		Vector2(202.0, 24.0),
		11,
		Color("#e2bf82")
	)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.z_index = 13
	add_child(level_label)

	var return_button := _make_button(
		"RETURN TO WORLD",
		Vector2(522.0, 76.0),
		Vector2(158.0, 38.0),
		Callable(self, "_return_to_world")
	)
	return_button.add_theme_font_size_override("font_size", 11)
	return_button.z_index = 13
	add_child(return_button)

	var instruction_panel := _make_panel(
		Rect2(22.0, 148.0, 676.0, 100.0),
		Color(0.015, 0.032, 0.028, 0.78),
		Color(0.70, 0.60, 0.42, 0.30),
		14
	)
	instruction_panel.z_index = 12
	add_child(instruction_panel)

	description_label = _make_label(
		"",
		Vector2(40.0, 157.0),
		Vector2(640.0, 52.0),
		14,
		Color("#e0e3d5"),
		true
	)
	description_label.z_index = 13
	add_child(description_label)

	objective_label = _make_label(
		"",
		Vector2(40.0, 211.0),
		Vector2(500.0, 25.0),
		11,
		Color("#d7b77b")
	)
	objective_label.z_index = 13
	add_child(objective_label)

	move_label = _make_label(
		"",
		Vector2(546.0, 211.0),
		Vector2(100.0, 25.0),
		11,
		Color("#d7c8a9")
	)
	move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	move_label.z_index = 13
	add_child(move_label)

	var status_panel := _make_panel(
		Rect2(20.0, 986.0, 680.0, 112.0),
		Color(0.012, 0.027, 0.024, 0.88),
		Color(0.76, 0.59, 0.36, 0.42),
		16
	)
	status_panel.z_index = 12
	add_child(status_panel)

	status_label = _make_label(
		"",
		Vector2(39.0, 1000.0),
		Vector2(642.0, 82.0),
		15,
		Color("#eee3ce"),
		true
	)
	status_label.z_index = 13
	add_child(status_label)

	var dock := _make_panel(
		Rect2(18.0, 1117.0, 684.0, 140.0),
		Color(0.012, 0.027, 0.024, 0.92),
		Color(0.76, 0.59, 0.36, 0.58),
		18
	)
	dock.z_index = 12
	add_child(dock)

	restart_button = _make_button(
		"RESTART",
		Vector2(28.0, 1143.0),
		Vector2(128.0, 50.0),
		Callable(self, "_restart_level")
	)
	restart_button.z_index = 13
	add_child(restart_button)

	undo_button = _make_button(
		"UNDO",
		Vector2(162.0, 1143.0),
		Vector2(128.0, 50.0),
		Callable(self, "_undo_move")
	)
	undo_button.z_index = 13
	add_child(undo_button)

	pipette_button = _make_button(
		"PIPETTE",
		Vector2(296.0, 1143.0),
		Vector2(128.0, 50.0),
		Callable(self, "_toggle_pipette")
	)
	pipette_button.z_index = 13
	add_child(pipette_button)

	transmute_button = _make_button(
		"TRANSMUTE",
		Vector2(430.0, 1143.0),
		Vector2(128.0, 50.0),
		Callable(self, "_transmute_selected")
	)
	transmute_button.z_index = 13
	add_child(transmute_button)

	next_level_action_button = _make_button(
		"NEXT TRIAL",
		Vector2(564.0, 1143.0),
		Vector2(128.0, 50.0),
		Callable(self, "_next_level")
	)
	next_level_action_button.z_index = 13
	add_child(next_level_action_button)

	var gesture_hint := _make_label(
		"DRAG A VIAL ONTO ANOTHER TO POUR  ·  SELECT A VIAL TO USE A SPECIAL TOOL",
		Vector2(35.0, 1202.0),
		Vector2(650.0, 26.0),
		10,
		Color("#9faf9c")
	)
	gesture_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gesture_hint.z_index = 13
	add_child(gesture_hint)


func _build_vial_layout() -> void:
	var count := bottle_contents.size()
	var anchors: Array = []
	var rear_count := 0

	if count <= 6:
		var scale_value := 1.0
		match count:
			5:
				scale_value = 0.92
			6:
				scale_value = 0.82
		var size_value: Vector2 = BOTTLE_SOURCE_SIZE * scale_value
		var gap: float = (720.0 - float(count) * size_value.x) / float(count + 1)
		var base_y: float = 592.0 if count <= 4 else (610.0 if count == 5 else 628.0)

		for index in range(count):
			var centre_offset: float = absf(float(index) - (float(count) - 1.0) * 0.5)
			var position_value := Vector2(
				gap + float(index) * (size_value.x + gap),
				base_y + centre_offset * 5.0
			)
			_add_experiment_vial(index, position_value, size_value, false)
			anchors.append({"position": position_value, "size": size_value, "rear": false})
	else:
		rear_count = 4
		var rear_size: Vector2 = BOTTLE_SOURCE_SIZE * 0.72
		var rear_gap: float = (720.0 - 4.0 * rear_size.x) / 5.0
		for index in range(rear_count):
			var centre_offset: float = absf(float(index) - 1.5)
			var position_value := Vector2(
				rear_gap + float(index) * (rear_size.x + rear_gap),
				330.0 + centre_offset * 3.0
			)
			_add_experiment_vial(index, position_value, rear_size, true)
			anchors.append({"position": position_value, "size": rear_size, "rear": true})

		var front_count: int = count - rear_count
		var front_scale: float = 0.82 if front_count == 4 else 0.90
		var front_size: Vector2 = BOTTLE_SOURCE_SIZE * front_scale
		var front_gap: float = (720.0 - float(front_count) * front_size.x) / float(front_count + 1)
		var front_base_y: float = 640.0 if front_count == 4 else 620.0

		for column in range(front_count):
			var centre_offset: float = absf(float(column) - (float(front_count) - 1.0) * 0.5)
			var position_value := Vector2(
				front_gap + float(column) * (front_size.x + front_gap),
				front_base_y + centre_offset * 5.0
			)
			var vial_index: int = rear_count + column
			_add_experiment_vial(vial_index, position_value, front_size, false)
			anchors.append({"position": position_value, "size": front_size, "rear": false})

	_apparatus_surface.configure(anchors, rear_count)


func _add_experiment_vial(index: int, position_value: Vector2, size_value: Vector2, rear: bool) -> void:
	var vial: Control = BottleScript.new()
	vial.name = "ExperimentVial%02d" % (index + 1)
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
	if not is_instance_valid(level_label):
		return

	level_label.text = "BENCH TRIAL  %02d / 10" % (current_level + 1)
	description_label.text = String(level_data.get("description", ""))
	move_label.text = "MOVES  %02d" % move_count

	var special := String(level_data.get("special", "classic"))
	var objective := "GOAL  ·  Consolidate each essence into its own pure vial."
	if special == "seal":
		objective = "GOAL  ·  Break the rune seal, then purify all three essences."
	elif special == "recipe":
		objective = "GOAL  ·  Follow the recipe sequence, then purify the remaining essences."
	elif special == "transmute":
		objective = "GOAL  ·  Transmute Tide + Ember into Dusk, then sort."
	elif special == "master":
		objective = "GOAL  ·  Transmute Tide + Ember, use the pipette, then sort."
	elif special == "pipette":
		objective = "GOAL  ·  Use the precision pipette once, then sort."
	objective_label.text = objective

	pipette_button.visible = special == "pipette" or special == "master"
	pipette_button.disabled = precision_used or is_animating
	pipette_button.text = "PIPETTE USED" if precision_used else ("PIPETTE ARMED" if precision_armed else "PIPETTE")
	transmute_button.visible = special == "transmute" or special == "master"
	transmute_button.disabled = transmute_used or is_animating
	transmute_button.text = "TRANSMUTED" if transmute_used else "TRANSMUTE"

	undo_button.disabled = move_history.is_empty() or is_animating
	restart_button.disabled = is_animating
	next_level_action_button.disabled = current_level >= 9 or is_animating


func _set_status(value: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = value
