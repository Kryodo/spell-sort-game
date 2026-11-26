extends "res://scripts/fantasy_alchemy_bottle.gd"

# Current composition candidate: Qwen's second transparent-front vessel.
# The silhouette/style remains provisional pending its in-environment review.
const VIAL_ART: Texture2D = preload("res://assets/bottles/SpellSort_Vial_2.png")

const WINDOW_SCAN_TOP := 0.18
const WINDOW_SCAN_BOTTOM := 0.88
const WINDOW_CENTER_ALPHA_MAX := 0.985
const WINDOW_EDGE_ALPHA_MIN := 0.78
const WINDOW_EDGE_OPAQUE_RUN := 3
const WINDOW_MAX_HALF_WIDTH := 0.31
const WINDOW_WALL_INSET := 1.0
const WINDOW_SCAN_STEP := 2
const LIQUID_SURFACE_SAMPLES := 64
const LIQUID_SIDE_SAMPLES := 48

var _window_profile: Array[Vector3] = []
var _window_top_ratio: float = 0.265
var _window_bottom_ratio: float = 0.79


func _ready() -> void:
	super._ready()
	_build_inner_window_profile()


func _build_inner_window_profile() -> void:
	_window_profile.clear()
	var source_image: Image = VIAL_ART.get_image()
	if source_image == null or source_image.is_empty():
		push_warning("Vial 2: unable to read source image alpha for the liquid window.")
		return

	var image_width: int = source_image.get_width()
	var image_height: int = source_image.get_height()
	var center_x: int = image_width / 2
	var max_distance: int = int(float(image_width) * WINDOW_MAX_HALF_WIDTH)
	var first_row: int = int(float(image_height) * WINDOW_SCAN_TOP)
	var last_row: int = int(float(image_height) * WINDOW_SCAN_BOTTOM)

	# The transparent front window is identified directly from the PNG alpha.
	# At each row, scan outwards from the centre until the glass wall forms a
	# short continuous run of sufficiently opaque pixels. This ignores small
	# isolated front highlights while retaining the actual inner glass boundary.
	for row in range(first_row, last_row + 1, WINDOW_SCAN_STEP):
		if source_image.get_pixel(center_x, row).a >= WINDOW_CENTER_ALPHA_MAX:
			continue

		var left_ratio: float = _find_window_edge_ratio(
			source_image,
			row,
			center_x,
			-1,
			max_distance
		)
		var right_ratio: float = _find_window_edge_ratio(
			source_image,
			row,
			center_x,
			1,
			max_distance
		)

		if left_ratio >= 0.5 or right_ratio <= 0.5 or right_ratio - left_ratio < 0.012:
			continue

		_window_profile.append(Vector3(
			float(row) / float(image_height),
			left_ratio,
			right_ratio
		))

	if _window_profile.size() < 8:
		_window_profile.clear()
		push_warning(
			"Vial 2: only %d transparent-window scan lines found; liquid will use the fallback bounds."
			% _window_profile.size()
		)
		return

	# Keep the fill just inside the first and last detected transparent rows.
	var edge_margin: float = 2.0 / float(image_height)
	_window_top_ratio = _window_profile[0].x + edge_margin
	_window_bottom_ratio = _window_profile[-1].x - edge_margin


func _find_window_edge_ratio(
	source_image: Image,
	row: int,
	center_x: int,
	direction: int,
	max_distance: int
) -> float:
	var opaque_run: int = 0
	for distance in range(1, max_distance + 1):
		var sample_x: int = center_x + direction * distance
		var alpha: float = source_image.get_pixel(sample_x, row).a
		if alpha >= WINDOW_EDGE_ALPHA_MIN:
			opaque_run += 1
		else:
			opaque_run = 0

		if opaque_run >= WINDOW_EDGE_OPAQUE_RUN:
			var first_opaque_distance: int = distance - WINDOW_EDGE_OPAQUE_RUN + 1
			var last_clear_distance: int = maxi(0, first_opaque_distance - 1)
			return float(center_x + direction * last_clear_distance) / float(source_image.get_width())

	return float(center_x + direction * max_distance) / float(source_image.get_width())


func _window_bounds_at(y_ratio: float) -> Vector2:
	if _window_profile.is_empty():
		return Vector2(0.39, 0.61)

	if y_ratio <= _window_profile[0].x:
		return Vector2(_window_profile[0].y, _window_profile[0].z)

	for index in range(_window_profile.size() - 1):
		var first: Vector3 = _window_profile[index]
		var second: Vector3 = _window_profile[index + 1]
		if y_ratio <= second.x:
			var span: float = maxf(0.0001, second.x - first.x)
			var weight: float = clampf((y_ratio - first.x) / span, 0.0, 1.0)
			return Vector2(
				lerpf(first.y, second.y, weight),
				lerpf(first.z, second.z, weight)
			)

	var last: Vector3 = _window_profile.back()
	return Vector2(last.y, last.z)


func _profile_points() -> Array[Vector2]:
	# Preserve the base liquid/bubble helpers' profile API, but derive it from
	# the measured transparent window rather than a hand-authored silhouette.
	if _window_profile.is_empty():
		return super._profile_points()

	var points: Array[Vector2] = []
	for bounds in _window_profile:
		points.append(Vector2(bounds.x, (bounds.z - bounds.y) * 0.5))
	return points


func _get_vessel_rect() -> Rect2:
	# Use the exact same image-to-control mapping as the glass sprite. Liquid
	# coordinates and sampled alpha boundaries therefore share one pixel space.
	var source_size: Vector2 = Vector2(VIAL_ART.get_size())
	var draw_scale: float = size.y / source_size.y
	var draw_size: Vector2 = source_size * draw_scale
	var draw_position := (size - draw_size) * 0.5
	return Rect2(draw_position, draw_size)


func get_mouth_local() -> Vector2:
	var rect := _get_vessel_rect()
	return Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.065)


func get_mouth_hit_radius() -> Vector2:
	return Vector2(size.y * 0.105, size.y * 0.04)


func get_liquid_surface_position_in_parent() -> Vector2:
	var rect := _get_vessel_rect()
	var window_top: float = _window_top_ratio
	var window_bottom: float = _window_bottom_ratio
	var layer_height: float = (window_bottom - window_top) / float(CAPACITY)
	var surface_ratio: float = window_bottom - layer_height * clampf(
		_liquid_level,
		0.0,
		float(CAPACITY)
	)
	var surface_y: float = rect.position.y + rect.size.y * surface_ratio
	surface_y += _get_surface_wave_offset(0.0)
	var local_surface := Vector2(rect.get_center().x, surface_y)
	return position + get_point_local_for_pose(
		local_surface,
		Vector2(_lift, _tilt),
		_draw_scale
	)


func _draw_liquid(rect: Rect2) -> void:
	if _visual_contents.is_empty() or _liquid_level <= 0.001:
		return

	var window_span: float = _window_bottom_ratio - _window_top_ratio
	if window_span <= 0.01:
		return

	var layer_height: float = window_span / float(CAPACITY)
	var visible_layers: int = mini(int(ceil(_liquid_level)), _visual_contents.size())

	for layer_index in range(visible_layers):
		var amount: float = clampf(_liquid_level - float(layer_index), 0.0, 1.0)
		if amount <= 0.001:
			continue

		var bottom_ratio: float = _window_bottom_ratio - float(layer_index) * layer_height
		var top_ratio: float = bottom_ratio - layer_height * amount
		var essence: String = String(_visual_contents[layer_index])
		var liquid_color: Color = _palette.get(essence, Color(0.45, 0.78, 0.75, 1.0))
		_draw_liquid_band(
			rect,
			top_ratio,
			bottom_ratio,
			liquid_color,
			layer_index == visible_layers - 1,
			layer_index == 0
		)

	_draw_window_bubbles(rect, visible_layers)


func _draw_liquid_band(
	rect: Rect2,
	top_ratio: float,
	bottom_ratio: float,
	liquid_color: Color,
	is_surface: bool,
	is_bottom: bool
) -> void:
	var top_y: float = rect.position.y + rect.size.y * top_ratio
	var bottom_y: float = rect.position.y + rect.size.y * bottom_ratio
	if not is_bottom:
		bottom_y += 0.65

	var top_bounds := _window_bounds_at(top_ratio)
	var top_left_x: float = rect.position.x + rect.size.x * top_bounds.x + WINDOW_WALL_INSET
	var top_right_x: float = rect.position.x + rect.size.x * top_bounds.y - WINDOW_WALL_INSET
	if top_right_x - top_left_x <= 2.0:
		return

	var top_edge := PackedVector2Array()
	for sample_index in range(LIQUID_SURFACE_SAMPLES + 1):
		var t: float = float(sample_index) / float(LIQUID_SURFACE_SAMPLES)
		var normalized_x: float = t * 2.0 - 1.0
		var x: float = lerpf(top_left_x, top_right_x, t)
		var wave: float = _get_surface_wave_offset(normalized_x) if is_surface else 0.0
		top_edge.append(Vector2(x, top_y + wave))

	var left_edge := PackedVector2Array()
	var right_edge := PackedVector2Array()
	for sample_index in range(LIQUID_SIDE_SAMPLES + 1):
		var t: float = float(sample_index) / float(LIQUID_SIDE_SAMPLES)
		var y: float = lerpf(top_y, bottom_y, t)
		var y_ratio: float = clampf(
			(y - rect.position.y) / maxf(1.0, rect.size.y),
			0.0,
			1.0
		)
		var bounds := _window_bounds_at(y_ratio)
		var left_x: float = rect.position.x + rect.size.x * bounds.x + WINDOW_WALL_INSET
		var right_x: float = rect.position.x + rect.size.x * bounds.y - WINDOW_WALL_INSET
		if right_x - left_x <= 2.0:
			continue
		left_edge.append(Vector2(left_x, y))
		right_edge.append(Vector2(right_x, y))

	if left_edge.size() < 2 or right_edge.size() != left_edge.size():
		return

	var liquid_polygon := top_edge.duplicate()
	for index in range(1, right_edge.size()):
		liquid_polygon.append(right_edge[index])
	liquid_polygon.append(left_edge[-1])
	for index in range(left_edge.size() - 2, -1, -1):
		liquid_polygon.append(left_edge[index])

	var fill_color: Color = liquid_color.lerp(liquid_color.lightened(0.14), 0.09)
	draw_colored_polygon(liquid_polygon, fill_color)

	var edge_color: Color = liquid_color.darkened(0.24)
	edge_color.a = 0.12
	draw_polyline(left_edge, edge_color, 0.85, true)
	draw_polyline(right_edge, edge_color, 0.85, true)

	if is_surface:
		var surface_color: Color = fill_color.lightened(0.30)
		surface_color.a = 0.12 + _surface_activity * 0.065 + absf(_slosh) * 0.03
		draw_polyline(top_edge, surface_color, 1.2, true)


func _draw_window_bubbles(rect: Rect2, visible_layers: int) -> void:
	if visible_layers <= 0 or _window_profile.is_empty():
		return

	var surface_ratio: float = _window_bottom_ratio - (
		(_window_bottom_ratio - _window_top_ratio)
		/ float(CAPACITY)
		* clampf(_liquid_level, 0.0, float(CAPACITY))
	)
	var surface_y: float = rect.position.y + rect.size.y * surface_ratio
	var bottom_y: float = rect.position.y + rect.size.y * _window_bottom_ratio
	var layer_span: float = (_window_bottom_ratio - _window_top_ratio) / float(CAPACITY)

	for bubble_index in range(8):
		var phase: float = fposmod(
			_wave_time * (0.13 + float(bubble_index) * 0.011)
			+ float(bubble_index) * 0.137,
			1.0
		)
		var bubble_y: float = lerpf(bottom_y - 5.0, surface_y + 4.0, phase)
		var normalized_y: float = clampf(
			(bubble_y - rect.position.y) / rect.size.y,
			_window_top_ratio,
			_window_bottom_ratio
		)
		var bounds := _window_bounds_at(normalized_y)
		var left_x: float = rect.position.x + rect.size.x * bounds.x + 5.0
		var right_x: float = rect.position.x + rect.size.x * bounds.y - 5.0
		if right_x - left_x <= 5.0:
			continue

		var sway: float = sin(_wave_time * 0.72 + float(bubble_index) * 1.71)
		var bubble_position := Vector2(
			lerpf(left_x, right_x, 0.5 + sway * 0.28),
			bubble_y
		)
		var bubble_size: float = 1.15 + fposmod(float(bubble_index) * 0.73, 1.8)
		var bubble_alpha: float = 0.13 + 0.09 * (
			0.5 + 0.5 * sin(_wave_time * 1.6 + float(bubble_index))
		)
		var fill_depth: float = (_window_bottom_ratio - normalized_y) / maxf(0.001, layer_span)
		var layer_index: int = clampi(int(floor(fill_depth)), 0, _visual_contents.size() - 1)
		var bubble_essence: String = String(_visual_contents[layer_index])
		var bubble_color: Color = _palette.get(bubble_essence, Color.WHITE)

		draw_circle(
			bubble_position,
			bubble_size * 2.0,
			Color(bubble_color.r, bubble_color.g, bubble_color.b, bubble_alpha * 0.15)
		)
		draw_circle(
			bubble_position,
			bubble_size,
			Color(0.91, 1.0, 0.98, bubble_alpha * 0.52)
		)
		draw_arc(
			bubble_position + Vector2(-0.2, -0.2),
			bubble_size,
			deg_to_rad(205.0),
			deg_to_rad(325.0),
			12,
			Color(1.0, 1.0, 1.0, bubble_alpha * 0.80),
			0.85,
			true
		)


func _draw_glass_back(_rect: Rect2) -> void:
	# The Qwen asset supplies its rear glass and painted reflections.
	pass


func _draw_glass_overlay() -> void:
	# Draw the exact same source rectangle used by the alpha-derived liquid mask.
	draw_texture_rect(VIAL_ART, _get_vessel_rect(), false, Color.WHITE)
