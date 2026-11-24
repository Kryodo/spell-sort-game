extends Control

const CAPACITY := 4
const LIQUID_BOTTOM_RATIO := 0.968
const LIQUID_TOP_RATIO := 0.31
const PROFILE_SAMPLES := 128
const BOUNDS_SAMPLES := 101
const LIQUID_COLUMNS := 64
const LIQUID_BAND_OVERLAP_PIXELS := 1.2

var vial_index: int = 0
var display_name: String = ""
var procedural_variant: int = 0

var _contents: Array = []
var _visual_contents: Array = []
var _palette: Dictionary = {}
var _liquid_level: float = 0.0

var _selected: bool = false
var _targeted: bool = false
var _dragging: bool = false
var _lift: float = 0.0
var _tilt: float = 0.0
var _draw_scale: float = 1.0

var _slosh: float = 0.0
var _slosh_velocity: float = 0.0
var _wave_time: float = 0.0
var _max_half_width: float = 0.44
var _vertical_bounds: Array[Vector2] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_process(true)


func setup(index: int, label: String, variant: int, palette: Dictionary, contents: Array) -> void:
	vial_index = index
	display_name = label
	procedural_variant = variant
	_palette = palette
	_contents = contents.duplicate()
	_visual_contents = contents.duplicate()
	_liquid_level = float(contents.size())
	_build_vertical_bounds()
	queue_redraw()


func get_contents() -> Array:
	return _contents.duplicate()


func set_contents(contents: Array) -> void:
	_contents = contents.duplicate()
	_visual_contents = contents.duplicate()
	_liquid_level = float(contents.size())
	queue_redraw()


func set_preview(contents: Array, level: float) -> void:
	_visual_contents = contents.duplicate()
	_liquid_level = clampf(level, 0.0, float(CAPACITY))
	queue_redraw()


func set_feedback(selected: bool, targeted: bool, dragging: bool) -> void:
	_selected = selected
	_targeted = targeted
	_dragging = dragging
	queue_redraw()


func set_pose(pose: Vector2) -> void:
	var tilt_change: float = pose.y - _tilt
	_slosh_velocity += tilt_change * 1.65
	_lift = pose.x
	_tilt = pose.y
	queue_redraw()


func get_pose() -> Vector2:
	return Vector2(_lift, _tilt)


func set_draw_scale(value: float) -> void:
	_draw_scale = clampf(value, 0.60, 1.15)
	queue_redraw()


func get_draw_scale() -> float:
	return _draw_scale


func reset_motion() -> void:
	_lift = 0.0
	_tilt = 0.0
	_draw_scale = 1.0
	_slosh = 0.0
	_slosh_velocity = 0.0
	queue_redraw()


func trigger_slosh(strength: float = 0.12) -> void:
	_slosh_velocity += strength
	queue_redraw()


func get_mouth_local() -> Vector2:
	var rect := _get_vessel_rect()
	return Vector2(size.x * 0.5, rect.position.y + 2.0)



func get_mouth_local_for_pose(pose: Vector2, draw_scale: float = -1.0) -> Vector2:
	return get_point_local_for_pose(get_mouth_local(), pose, draw_scale)


func get_mouth_position_in_parent(pose: Vector2 = Vector2.ZERO) -> Vector2:
	return position + get_mouth_local_for_pose(pose)


func get_point_local_for_pose(local_point: Vector2, pose: Vector2 = Vector2.ZERO, draw_scale: float = -1.0) -> Vector2:
	var pivot := Vector2(size.x * 0.5, size.y * 0.86)
	var applied_scale: float = _draw_scale if draw_scale < 0.0 else draw_scale
	return pivot + Vector2(0.0, -pose.x) + (local_point - pivot).rotated(pose.y) * applied_scale


func get_liquid_surface_position_in_parent() -> Vector2:
	var rect := _get_vessel_rect()
	var layer_height: float = (LIQUID_BOTTOM_RATIO - LIQUID_TOP_RATIO) / float(CAPACITY)
	var surface_ratio: float = LIQUID_BOTTOM_RATIO - layer_height * clampf(_liquid_level, 0.0, float(CAPACITY))
	var surface_y: float = rect.position.y + rect.size.y * surface_ratio
	surface_y += sin(_wave_time * 2.1) * (1.3 + absf(_slosh) * 3.2)
	var local_surface := Vector2(rect.get_center().x, surface_y)
	return position + get_point_local_for_pose(local_surface, Vector2(_lift, _tilt), _draw_scale)

func get_mouth_hit_radius() -> Vector2:
	var rect := _get_vessel_rect()
	var neck_half_width: float = rect.size.x * _get_profile_at(0.03).y
	return Vector2(maxf(26.0, neck_half_width * 1.85), 28.0)


func is_pointer_over_mouth(pointer_local: Vector2) -> bool:
	var mouth := get_mouth_local()
	var radii := get_mouth_hit_radius()
	var dx: float = (pointer_local.x - mouth.x) / radii.x
	var dy: float = (pointer_local.y - mouth.y) / radii.y
	return dx * dx + dy * dy <= 1.0


func _process(delta: float) -> void:
	_wave_time += delta * 2.4
	_slosh_velocity += (-_slosh * 15.0 - _slosh_velocity * 5.2) * delta
	_slosh += _slosh_velocity * delta
	_slosh = clampf(_slosh, -1.0, 1.0)
	if absf(_slosh) > 0.001 or absf(_slosh_velocity) > 0.001 or _selected or _targeted:
		queue_redraw()


func _profile_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	match procedural_variant:
		1: # Tall, narrow-necked flask.
			points = [
				Vector2(0.00, 0.145), Vector2(0.08, 0.155), Vector2(0.16, 0.215),
				Vector2(0.24, 0.285), Vector2(0.36, 0.305), Vector2(0.72, 0.305),
				Vector2(0.86, 0.285), Vector2(0.96, 0.225), Vector2(1.00, 0.15)
			]
		2: # Squared shoulders with soft, rounded corners.
			points = [
				Vector2(0.00, 0.17), Vector2(0.10, 0.18), Vector2(0.19, 0.30),
				Vector2(0.26, 0.405), Vector2(0.32, 0.425), Vector2(0.76, 0.425),
				Vector2(0.88, 0.39), Vector2(0.96, 0.305), Vector2(1.00, 0.245)
			]
		3: # Bulbous-bottomed apothecary vessel.
			points = [
				Vector2(0.00, 0.14), Vector2(0.09, 0.16), Vector2(0.19, 0.27),
				Vector2(0.30, 0.39), Vector2(0.48, 0.46), Vector2(0.70, 0.47),
				Vector2(0.86, 0.40), Vector2(0.96, 0.28), Vector2(1.00, 0.18)
			]
		_: # Round, classic potion flask.
			points = [
				Vector2(0.00, 0.16), Vector2(0.09, 0.18), Vector2(0.19, 0.29),
				Vector2(0.31, 0.405), Vector2(0.55, 0.435), Vector2(0.76, 0.39),
				Vector2(0.90, 0.31), Vector2(0.97, 0.255), Vector2(1.00, 0.195)
			]
	return points


func _get_profile_at(y_norm: float) -> Vector2:
	var profile := _profile_points()
	var y: float = clampf(y_norm, 0.0, 1.0)
	for index in range(profile.size() - 1):
		var first: Vector2 = profile[index]
		var second: Vector2 = profile[index + 1]
		if y <= second.x:
			var span: float = maxf(0.0001, second.x - first.x)
			return Vector2(y, lerpf(first.y, second.y, clampf((y - first.x) / span, 0.0, 1.0)))
	return profile.back()


func _build_vertical_bounds() -> void:
	_vertical_bounds.clear()
	_max_half_width = 0.0
	for point in _profile_points():
		_max_half_width = maxf(_max_half_width, point.y)

	for column_index in range(BOUNDS_SAMPLES):
		var x_ratio: float = lerpf(-_max_half_width, _max_half_width, float(column_index) / float(BOUNDS_SAMPLES - 1))
		var first_y: float = -1.0
		var last_y: float = -1.0
		for sample_index in range(PROFILE_SAMPLES + 1):
			var y_norm: float = float(sample_index) / float(PROFILE_SAMPLES)
			if _get_profile_at(y_norm).y >= absf(x_ratio) - 0.0005:
				if first_y < 0.0:
					first_y = y_norm
				last_y = y_norm
		_vertical_bounds.append(Vector2(first_y, last_y))


func _get_vertical_bounds_at_x(x_ratio: float) -> Vector2:
	if _vertical_bounds.is_empty():
		return Vector2(-1.0, -1.0)
	var scaled: float = clampf(absf(x_ratio) / _max_half_width, 0.0, 1.0) * float(_vertical_bounds.size() - 1)
	var lower: int = clampi(int(floor(scaled)), 0, _vertical_bounds.size() - 1)
	var upper: int = mini(lower + 1, _vertical_bounds.size() - 1)
	var first: Vector2 = _vertical_bounds[lower]
	var second: Vector2 = _vertical_bounds[upper]
	if first.x < 0.0 or second.x < 0.0:
		return Vector2(-1.0, -1.0)
	return first.lerp(second, scaled - float(lower))


func _get_vessel_rect() -> Rect2:
	var width: float = size.x * 0.91
	var height: float = size.y * 0.735
	return Rect2(Vector2((size.x - width) * 0.5, 72.0), Vector2(width, height))


func _draw() -> void:
	var center_x: float = size.x * 0.5
	var pivot := Vector2(center_x, size.y * 0.86)
	draw_circle(Vector2(center_x, size.y * 0.87), size.x * 0.34, Color(0.012, 0.022, 0.027, 0.30))

	var draw_origin := pivot + Vector2(0.0, -_lift) - pivot.rotated(_tilt) * _draw_scale
	draw_set_transform(draw_origin, _tilt, Vector2(_draw_scale, _draw_scale))

	if _selected or _targeted or _dragging:
		var pulse: float = 0.5 + 0.5 * sin(_wave_time * 1.5)
		var glow := Color(0.96, 0.76, 0.43, 0.075 + pulse * 0.075) if _selected or _dragging else Color(0.46, 0.91, 0.76, 0.08 + pulse * 0.075)
		draw_circle(Vector2(center_x, size.y * 0.46), size.x * 0.43, glow)
		draw_arc(Vector2(center_x, size.y * 0.46), size.x * 0.43, 0.0, TAU, 48, Color(glow.r, glow.g, glow.b, 0.40), 2.0, true)

	var vessel_rect := _get_vessel_rect()
	_draw_glass_back(vessel_rect)
	_draw_liquid(vessel_rect)
	_draw_glass_front(vessel_rect)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(0.0, size.y - 5.0),
		display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		12,
		Color(0.96, 0.88, 0.70, 0.96)
	)


func _draw_glass_back(rect: Rect2) -> void:
	const STRIPS := 54
	for strip_index in range(STRIPS):
		var y0: float = float(strip_index) / float(STRIPS)
		var y1: float = float(strip_index + 1) / float(STRIPS)
		var profile0 := _get_profile_at(y0)
		var profile1 := _get_profile_at(y1)
		var left0 := Vector2(rect.position.x + rect.size.x * (0.5 - profile0.y), rect.position.y + rect.size.y * y0)
		var right0 := Vector2(rect.position.x + rect.size.x * (0.5 + profile0.y), rect.position.y + rect.size.y * y0)
		var right1 := Vector2(rect.position.x + rect.size.x * (0.5 + profile1.y), rect.position.y + rect.size.y * y1)
		var left1 := Vector2(rect.position.x + rect.size.x * (0.5 - profile1.y), rect.position.y + rect.size.y * y1)
		var quad := PackedVector2Array([left0, right0, right1, left1])
		if not _is_safe_convex_quad(quad):
			continue
		var side_alpha: float = 0.13 + (1.0 - absf(y0 - 0.5) * 1.3) * 0.035
		var colours := PackedColorArray([
			Color(0.80, 0.94, 0.98, side_alpha),
			Color(0.54, 0.76, 0.84, 0.055),
			Color(0.54, 0.76, 0.84, 0.055),
			Color(0.80, 0.94, 0.98, side_alpha)
		])
		draw_polygon(quad, colours)


func _draw_glass_front(rect: Rect2) -> void:
	var left_edge := PackedVector2Array()
	var right_edge := PackedVector2Array()
	var left_reflection := PackedVector2Array()
	var right_reflection := PackedVector2Array()
	const EDGE_SAMPLES := 44

	for index in range(EDGE_SAMPLES + 1):
		var y_norm: float = float(index) / float(EDGE_SAMPLES)
		var profile := _get_profile_at(y_norm)
		var y: float = rect.position.y + rect.size.y * y_norm
		var left_x: float = rect.position.x + rect.size.x * (0.5 - profile.y)
		var right_x: float = rect.position.x + rect.size.x * (0.5 + profile.y)
		left_edge.append(Vector2(left_x, y))
		right_edge.append(Vector2(right_x, y))
		left_reflection.append(Vector2(left_x + rect.size.x * 0.055, y))
		right_reflection.append(Vector2(right_x - rect.size.x * 0.055, y))

	draw_polyline(left_edge, Color(0.83, 0.95, 0.98, 0.78), 2.8, true)
	draw_polyline(right_edge, Color(0.42, 0.67, 0.76, 0.46), 2.2, true)
	draw_polyline(left_reflection, Color(1.0, 1.0, 1.0, 0.36), 4.5, true)
	draw_polyline(right_reflection, Color(0.67, 0.84, 0.91, 0.20), 3.0, true)

	# Short bevel facets catch the light near the shoulders.
	var facet_y: float = rect.position.y + rect.size.y * 0.23
	var facet_left := PackedVector2Array([
		Vector2(rect.position.x + rect.size.x * 0.18, facet_y - 5.0),
		Vector2(rect.position.x + rect.size.x * 0.27, facet_y + 21.0),
		Vector2(rect.position.x + rect.size.x * 0.34, facet_y + 28.0)
	])
	var facet_right := PackedVector2Array([
		Vector2(rect.position.x + rect.size.x * 0.82, facet_y - 5.0),
		Vector2(rect.position.x + rect.size.x * 0.73, facet_y + 21.0),
		Vector2(rect.position.x + rect.size.x * 0.66, facet_y + 28.0)
	])
	draw_colored_polygon(facet_left, Color(0.94, 0.99, 1.0, 0.17))
	draw_colored_polygon(facet_right, Color(0.52, 0.72, 0.79, 0.13))

	# The thicker bottom gives the glass a visible, dimensional foot.
	var bottom_center := Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.975)
	var bottom_rx: float = rect.size.x * _get_profile_at(0.96).y * 0.93
	var outer_base := _ellipse_points(bottom_center, bottom_rx, 7.0, 32)
	draw_colored_polygon(outer_base, Color(0.68, 0.85, 0.91, 0.30))
	var base_highlight := _ellipse_points(bottom_center + Vector2(0.0, -1.5), bottom_rx * 0.78, 2.1, 32)
	draw_polyline(_closed_points(base_highlight), Color(0.97, 1.0, 1.0, 0.52), 1.6, true)

	_draw_open_mouth(rect)


func _draw_open_mouth(rect: Rect2) -> void:
	var mouth := Vector2(rect.get_center().x, rect.position.y + 1.0)
	var neck_half_width: float = rect.size.x * _get_profile_at(0.025).y
	var outer_rx: float = neck_half_width * 1.16
	var outer_ry: float = 7.8
	var inner_rx: float = outer_rx * 0.72
	var inner_ry: float = outer_ry * 0.54

	var outer_rim := _ellipse_points(mouth, outer_rx, outer_ry, 36)
	draw_colored_polygon(outer_rim, Color(0.64, 0.83, 0.90, 0.72))
	draw_polyline(_closed_points(outer_rim), Color(0.90, 0.98, 1.0, 0.95), 2.2, true)

	var inner_opening := _ellipse_points(mouth + Vector2(0.0, 0.5), inner_rx, inner_ry, 36)
	draw_colored_polygon(inner_opening, Color(0.012, 0.025, 0.035, 0.92))
	draw_polyline(_closed_points(inner_opening), Color(0.49, 0.70, 0.78, 0.72), 1.0, true)

	var front_rim := PackedVector2Array()
	for index in range(19):
		var angle: float = lerpf(0.0, PI, float(index) / 18.0)
		front_rim.append(mouth + Vector2(cos(angle) * outer_rx, sin(angle) * outer_ry))
	draw_polyline(front_rim, Color(1.0, 1.0, 1.0, 0.85), 2.0, true)


func _draw_liquid(rect: Rect2) -> void:
	if _visual_contents.is_empty() or _liquid_level <= 0.001:
		return

	var layer_height: float = (LIQUID_BOTTOM_RATIO - LIQUID_TOP_RATIO) / float(CAPACITY)
	var visible_layers: int = mini(int(ceil(_liquid_level)), _visual_contents.size())

	for layer_index in range(visible_layers):
		var amount: float = clampf(_liquid_level - float(layer_index), 0.0, 1.0)
		if amount <= 0.001:
			continue
		var bottom_ratio: float = LIQUID_BOTTOM_RATIO - float(layer_index) * layer_height
		var top_ratio: float = bottom_ratio - layer_height * amount
		# A tiny overlap between adjacent essence bands prevents hairline gaps.
		if layer_index > 0:
			bottom_ratio += 0.0018
		var essence: String = String(_visual_contents[layer_index])
		var liquid_color: Color = _palette.get(essence, Color(0.45, 0.78, 0.75, 1.0))
		_draw_liquid_band(rect, top_ratio, bottom_ratio, liquid_color, layer_index == visible_layers - 1)



func _draw_liquid_band(rect: Rect2, top_ratio: float, bottom_ratio: float, liquid_color: Color, is_surface: bool) -> void:
	var base_top: float = rect.position.y + rect.size.y * top_ratio
	var base_bottom: float = rect.position.y + rect.size.y * bottom_ratio
	var x_extent: float = _max_half_width * 0.995
	var overlap_ratio: float = LIQUID_BAND_OVERLAP_PIXELS / maxf(1.0, rect.size.y)
	if not is_surface:
		base_bottom += overlap_ratio * rect.size.y

	for column_index in range(LIQUID_COLUMNS):
		var x0_ratio: float = lerpf(-x_extent, x_extent, float(column_index) / float(LIQUID_COLUMNS))
		var x1_ratio: float = lerpf(-x_extent, x_extent, float(column_index + 1) / float(LIQUID_COLUMNS))
		var bounds0 := _get_vertical_bounds_at_x(x0_ratio)
		var bounds1 := _get_vertical_bounds_at_x(x1_ratio)
		if bounds0.x < 0.0 or bounds1.x < 0.0:
			continue

		var x0: float = rect.get_center().x + rect.size.x * x0_ratio
		var x1: float = rect.get_center().x + rect.size.x * x1_ratio
		var top0: float = maxf(base_top, rect.position.y + rect.size.y * (bounds0.x + 0.004))
		var top1: float = maxf(base_top, rect.position.y + rect.size.y * (bounds1.x + 0.004))
		var bottom0: float = minf(base_bottom, rect.position.y + rect.size.y * (bounds0.y - 0.004))
		var bottom1: float = minf(base_bottom, rect.position.y + rect.size.y * (bounds1.y - 0.004))

		if is_surface:
			var slope0: float = -tan(_tilt) * x0_ratio * 0.12
			var slope1: float = -tan(_tilt) * x1_ratio * 0.12
			var wave0: float = sin(_wave_time * 2.1 + x0_ratio * 8.0) * (1.3 + absf(_slosh) * 3.2)
			var wave1: float = sin(_wave_time * 2.1 + x1_ratio * 8.0) * (1.3 + absf(_slosh) * 3.2)
			top0 += slope0 * rect.size.y + wave0
			top1 += slope1 * rect.size.y + wave1
			top0 = clampf(top0, rect.position.y + rect.size.y * (bounds0.x + 0.010), bottom0 - 1.5)
			top1 = clampf(top1, rect.position.y + rect.size.y * (bounds1.x + 0.010), bottom1 - 1.5)

		if bottom0 - top0 < 0.65 or bottom1 - top1 < 0.65 or x1 - x0 < 0.5:
			continue

		var quad := PackedVector2Array([
			Vector2(x0, top0),
			Vector2(x1, top1),
			Vector2(x1, bottom1),
			Vector2(x0, bottom0)
		])
		var edge_ratio: float = absf((x0_ratio + x1_ratio) * 0.5) / maxf(0.001, _max_half_width)
		var shaded_color: Color = liquid_color.lerp(liquid_color.darkened(0.34), clampf(edge_ratio * 0.65, 0.0, 0.42))
		shaded_color = shaded_color.lerp(Color(0.10, 0.18, 0.21, 1.0), 0.08)
		_draw_liquid_quad(quad, Color(shaded_color.r, shaded_color.g, shaded_color.b, 0.98))

	if is_surface:
		_draw_liquid_surface(rect, base_top, liquid_color)


func _draw_liquid_quad(points: PackedVector2Array, liquid_color: Color) -> void:
	if points.size() != 4:
		return
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(points)
	if indices.size() >= 3:
		for index in range(0, indices.size(), 3):
			var triangle := PackedVector2Array([
				points[indices[index]],
				points[indices[index + 1]],
				points[indices[index + 2]]
			])
			_draw_liquid_triangle(triangle, liquid_color)
	else:
		# Defensive fallback for nearly-collinear cells at the vessel silhouette.
		_draw_liquid_triangle(PackedVector2Array([points[0], points[1], points[2]]), liquid_color)
		_draw_liquid_triangle(PackedVector2Array([points[0], points[2], points[3]]), liquid_color)


func _draw_liquid_triangle(points: PackedVector2Array, liquid_color: Color) -> void:
	if points.size() != 3:
		return
	var area_twice: float = absf((points[1] - points[0]).cross(points[2] - points[0]))
	if area_twice < 0.06:
		return
	draw_colored_polygon(points, liquid_color)


func _draw_liquid_surface(rect: Rect2, base_top: float, liquid_color: Color) -> void:
	var surface_ratio: float = clampf((base_top - rect.position.y) / maxf(1.0, rect.size.y), 0.0, 1.0)
	# The exposed line follows the vessel width at the actual liquid level,
	# instead of spanning the widest part of the entire bottle.
	var surface_half_width: float = minf(_get_profile_at(surface_ratio).y * 0.985, _max_half_width * 0.995)
	var surface_line := PackedVector2Array()

	for point_index in range(33):
		var x_ratio: float = lerpf(-surface_half_width, surface_half_width, float(point_index) / 32.0)
		var x: float = rect.get_center().x + rect.size.x * x_ratio
		var bounds := _get_vertical_bounds_at_x(x_ratio)
		if bounds.x < 0.0:
			continue
		var y: float = base_top - tan(_tilt) * x_ratio * rect.size.y * 0.12
		y += sin(_wave_time * 2.1 + x_ratio * 8.0) * (1.3 + absf(_slosh) * 3.2)
		y = clampf(y, rect.position.y + rect.size.y * (bounds.x + 0.010), rect.position.y + rect.size.y * bounds.y - 2.0)
		surface_line.append(Vector2(x, y))

	if surface_line.size() >= 2:
		draw_polyline(surface_line, Color(1.0, 1.0, 1.0, 0.48), 1.8, true)
		var shimmer := PackedVector2Array()
		for index in range(9, 24):
			if index < surface_line.size():
				shimmer.append(surface_line[index] + Vector2(0.0, 2.5))
		if shimmer.size() >= 2:
			draw_polyline(shimmer, Color(1.0, 1.0, 1.0, 0.19), 1.0, true)

func _is_safe_convex_quad(points: PackedVector2Array) -> bool:
	if points.size() != 4:
		return false

	var signed_area: float = 0.0
	var cross_sign: int = 0
	for index in range(4):
		var current: Vector2 = points[index]
		var next: Vector2 = points[(index + 1) % 4]
		var after_next: Vector2 = points[(index + 2) % 4]
		signed_area += current.x * next.y - next.x * current.y
		var cross_value: float = (next - current).cross(after_next - next)
		if absf(cross_value) < 0.0001:
			return false
		var this_sign: int = 1 if cross_value > 0.0 else -1
		if cross_sign != 0 and this_sign != cross_sign:
			return false
		cross_sign = this_sign

	return absf(signed_area) > 0.8


func _ellipse_points(center: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle: float = TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	if not closed.is_empty():
		closed.append(closed[0])
	return closed
