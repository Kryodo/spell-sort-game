extends "res://scripts/fantasy_alchemy_bottle.gd"

# Current composition candidate: Qwen's second transparent-front vessel.
# The silhouette/style remains provisional pending its in-environment review.
const VIAL_ART: Texture2D = preload("res://assets/bottles/SpellSort_Vial_2.png")

const WINDOW_ALPHA_THRESHOLD := 0.02
const WINDOW_ROI_LEFT := 0.20
const WINDOW_ROI_RIGHT := 0.80
const WINDOW_ROI_TOP := 0.18
const WINDOW_ROI_BOTTOM := 0.88
const WINDOW_MAX_COMPONENT_FRACTION := 0.23
const WINDOW_PROFILE_SAMPLES := 96
const WINDOW_PROFILE_SMOOTH_RADIUS := 5
const WINDOW_WALL_INSET := 0.55
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
	var roi_left: int = int(float(image_width) * WINDOW_ROI_LEFT)
	var roi_right: int = int(float(image_width) * WINDOW_ROI_RIGHT)
	var roi_top: int = int(float(image_height) * WINDOW_ROI_TOP)
	var roi_bottom: int = int(float(image_height) * WINDOW_ROI_BOTTOM)

	# Vial 2's transparent centre is a distinct enclosed alpha component.
	# Flood-fill from that component instead of stopping at the first bright
	# reflection on every scan line. This prevents front highlights from being
	# mistaken for the left/right liquid walls.
	var seed := Vector2i(image_width / 2, image_height / 2)
	if source_image.get_pixel(seed.x, seed.y).a > WINDOW_ALPHA_THRESHOLD:
		var found_seed := false
		for radius in range(2, 49, 2):
			for offset_y in range(-radius, radius + 1, 2):
				for offset_x in range(-radius, radius + 1, 2):
					var candidate_x: int = seed.x + offset_x
					var candidate_y: int = seed.y + offset_y
					if candidate_x < roi_left or candidate_x > roi_right:
						continue
					if candidate_y < roi_top or candidate_y > roi_bottom:
						continue
					if source_image.get_pixel(candidate_x, candidate_y).a <= WINDOW_ALPHA_THRESHOLD:
						seed = Vector2i(candidate_x, candidate_y)
						found_seed = true
						break
				if found_seed:
					break
			if found_seed:
				break
		if not found_seed:
			push_warning("Vial 2: no transparent seed pixel found inside the central glass window.")
			return

	var visited := PackedByteArray()
	visited.resize(image_width * image_height)
	var row_left := PackedInt32Array()
	var row_right := PackedInt32Array()
	row_left.resize(image_height)
	row_right.resize(image_height)
	row_left.fill(image_width)
	row_right.fill(-1)

	var queue := PackedInt32Array()
	var seed_index: int = seed.y * image_width + seed.x
	queue.append(seed_index)
	visited[seed_index] = 1
	var cursor: int = 0
	var maximum_pixels: int = int(float(image_width * image_height) * WINDOW_MAX_COMPONENT_FRACTION)
	var component_overflow := false

	while cursor < queue.size():
		var pixel_index: int = queue[cursor]
		cursor += 1
		var pixel_x: int = pixel_index % image_width
		var pixel_y: int = int(pixel_index / image_width)

		row_left[pixel_y] = mini(row_left[pixel_y], pixel_x)
		row_right[pixel_y] = maxi(row_right[pixel_y], pixel_x)

		# Four-connected flood fill preserves the narrow antialiased glass wall
		# instead of leaking diagonally into the fully transparent background.
		var neighbours := PackedInt32Array()
		if pixel_x > roi_left:
			neighbours.append(pixel_index - 1)
		if pixel_x < roi_right:
			neighbours.append(pixel_index + 1)
		if pixel_y > roi_top:
			neighbours.append(pixel_index - image_width)
		if pixel_y < roi_bottom:
			neighbours.append(pixel_index + image_width)

		for neighbour_index in neighbours:
			if visited[neighbour_index] != 0:
				continue
			var neighbour_x: int = neighbour_index % image_width
			var neighbour_y: int = int(neighbour_index / image_width)
			if source_image.get_pixel(neighbour_x, neighbour_y).a > WINDOW_ALPHA_THRESHOLD:
				continue
			visited[neighbour_index] = 1
			queue.append(neighbour_index)

		if queue.size() > maximum_pixels:
			component_overflow = true
			break

	if component_overflow:
		push_warning("Vial 2: transparent component escaped the inner window ROI; alpha mask rejected.")
		return

	var peak_width: int = 0
	var peak_row: int = -1
	for row in range(roi_top, roi_bottom + 1):
		var row_width: int = row_right[row] - row_left[row] + 1
		if row_width > peak_width:
			peak_width = row_width
			peak_row = row

	if peak_row < 0 or peak_width < 12:
		push_warning("Vial 2: alpha flood-fill did not find a usable central chamber.")
		return

	# Ignore the narrow connecting neck/foot tails. The main liquid chamber is
	# the continuous broad region around the row with the largest transparent span.
	var minimum_chamber_width: int = maxi(4, int(float(peak_width) * 0.10))
	var chamber_top: int = peak_row
	var chamber_bottom: int = peak_row
	while chamber_top > roi_top and row_right[chamber_top - 1] - row_left[chamber_top - 1] + 1 >= minimum_chamber_width:
		chamber_top -= 1
	while chamber_bottom < roi_bottom and row_right[chamber_bottom + 1] - row_left[chamber_bottom + 1] + 1 >= minimum_chamber_width:
		chamber_bottom += 1

	if chamber_bottom - chamber_top < 32:
		push_warning("Vial 2: detected transparent chamber is too short to use as a liquid mask.")
		return

	# Smooth the pixel boundary lightly to remove one-pixel antialias noise while
	# retaining the authored curvature. Bounds are sampled into a compact profile.
	for sample_index in range(WINDOW_PROFILE_SAMPLES):
		var weight: float = float(sample_index) / float(WINDOW_PROFILE_SAMPLES - 1)
		var centre_row: int = roundi(lerpf(float(chamber_top), float(chamber_bottom), weight))
		var sum_left: float = 0.0
		var sum_right: float = 0.0
		var sample_count: int = 0
		for row in range(
			maxi(chamber_top, centre_row - WINDOW_PROFILE_SMOOTH_RADIUS),
			mini(chamber_bottom, centre_row + WINDOW_PROFILE_SMOOTH_RADIUS) + 1
		):
			if row_right[row] < row_left[row]:
				continue
			sum_left += float(row_left[row])
			sum_right += float(row_right[row] + 1)
			sample_count += 1
		if sample_count == 0:
			continue

		_window_profile.append(Vector3(
			float(centre_row) / float(image_height),
			(sum_left / float(sample_count)) / float(image_width),
			(sum_right / float(sample_count)) / float(image_width)
		))

	if _window_profile.size() < 8:
		_window_profile.clear()
		push_warning("Vial 2: smoothed alpha mask did not produce enough profile samples.")
		return

	var edge_margin: float = 1.0 / float(image_height)
	_window_top_ratio = _window_profile[0].x + edge_margin
	_window_bottom_ratio = _window_profile[-1].x - edge_margin
	print(
		"Vial 2 alpha mask: %d profile samples, peak width %d px, vertical %.3f–%.3f"
		% [_window_profile.size(), peak_width, _window_top_ratio, _window_bottom_ratio]
	)


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
	var bottom_y: float = rect.position.y + rect.size.y * bottom_ratio
	if not is_bottom:
		bottom_y += 0.8
	var top_y: float = rect.position.y + rect.size.y * top_ratio
	var surface_min_y: float = rect.position.y + rect.size.y * _window_top_ratio + 0.4

	# Build every point of the liquid surface from the boundary at its current
	# animated y-coordinate. This keeps the wave inside the real alpha window
	# instead of leaving triangular gaps at either side as the surface moves.
	var top_edge := PackedVector2Array()
	for sample_index in range(LIQUID_SURFACE_SAMPLES + 1):
		var t: float = float(sample_index) / float(LIQUID_SURFACE_SAMPLES)
		var normalized_x: float = t * 2.0 - 1.0
		var wave: float = _get_surface_wave_offset(normalized_x) * 0.36 if is_surface else 0.0
		var wave_y: float = clampf(top_y + wave, surface_min_y, bottom_y - 0.8)
		var bounds := _window_bounds_at(
			clampf((wave_y - rect.position.y) / rect.size.y, _window_top_ratio, _window_bottom_ratio)
		)
		var left_x: float = rect.position.x + rect.size.x * bounds.x + WINDOW_WALL_INSET
		var right_x: float = rect.position.x + rect.size.x * bounds.y - WINDOW_WALL_INSET
		var x: float = lerpf(left_x, right_x, t)
		top_edge.append(Vector2(x, wave_y))

	if top_edge.size() < 2:
		return

	var polygon := top_edge.duplicate()
	var right_top_y: float = top_edge[-1].y
	var left_top_y: float = top_edge[0].y
	var bottom_ratio_clamped: float = clampf(
		(bottom_y - rect.position.y) / rect.size.y,
		_window_top_ratio,
		_window_bottom_ratio
	)
	var bottom_bounds := _window_bounds_at(bottom_ratio_clamped)
	var bottom_left_x: float = rect.position.x + rect.size.x * bottom_bounds.x + WINDOW_WALL_INSET
	var bottom_right_x: float = rect.position.x + rect.size.x * bottom_bounds.y - WINDOW_WALL_INSET

	# Right wall: begin at the exact end of the animated surface and trace the
	# smoothed alpha boundary all the way to the bottom of this layer.
	for side_index in range(1, LIQUID_SIDE_SAMPLES + 1):
		var side_t: float = float(side_index) / float(LIQUID_SIDE_SAMPLES)
		var y: float = lerpf(right_top_y, bottom_y, side_t)
		var y_ratio: float = clampf(
			(y - rect.position.y) / rect.size.y,
			_window_top_ratio,
			_window_bottom_ratio
		)
		var bounds := _window_bounds_at(y_ratio)
		var right_x: float = rect.position.x + rect.size.x * bounds.y - WINDOW_WALL_INSET
		polygon.append(Vector2(right_x, y))

	# Close the bottom edge, then trace the left wall back to the first surface
	# point. No independent left/right arrays can drift out of sync.
	polygon.append(Vector2(bottom_left_x, bottom_y))
	for side_index in range(1, LIQUID_SIDE_SAMPLES):
		var side_t: float = float(side_index) / float(LIQUID_SIDE_SAMPLES)
		var y: float = lerpf(bottom_y, left_top_y, side_t)
		var y_ratio: float = clampf(
			(y - rect.position.y) / rect.size.y,
			_window_top_ratio,
			_window_bottom_ratio
		)
		var bounds := _window_bounds_at(y_ratio)
		var left_x: float = rect.position.x + rect.size.x * bounds.x + WINDOW_WALL_INSET
		polygon.append(Vector2(left_x, y))

	var fill_color: Color = liquid_color.lerp(liquid_color.lightened(0.14), 0.08)
	draw_colored_polygon(polygon, fill_color)

	if is_surface:
		var surface_color: Color = fill_color.lightened(0.30)
		surface_color.a = 0.10 + _surface_activity * 0.045 + absf(_slosh) * 0.02
		draw_polyline(top_edge, surface_color, 1.0, true)


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

	# Keep the bubbles deliberately sparse and low contrast so they read as
	# gentle internal movement rather than a flickering overlay.
	for bubble_index in range(4):
		var phase: float = fposmod(
			_wave_time * (0.085 + float(bubble_index) * 0.009)
			+ float(bubble_index) * 0.231,
			1.0
		)
		var bubble_y: float = lerpf(bottom_y - 5.0, surface_y + 5.0, phase)
		var normalized_y: float = clampf(
			(bubble_y - rect.position.y) / rect.size.y,
			_window_top_ratio,
			_window_bottom_ratio
		)
		var bounds := _window_bounds_at(normalized_y)
		var left_x: float = rect.position.x + rect.size.x * bounds.x + 5.0
		var right_x: float = rect.position.x + rect.size.x * bounds.y - 5.0
		if right_x - left_x <= 7.0:
			continue

		var sway: float = sin(_wave_time * 0.43 + float(bubble_index) * 1.71)
		var bubble_position := Vector2(
			lerpf(left_x, right_x, 0.5 + sway * 0.22),
			bubble_y
		)
		var bubble_size: float = 1.1 + fposmod(float(bubble_index) * 0.47, 1.0)
		var bubble_alpha: float = 0.07 + 0.045 * (
			0.5 + 0.5 * sin(_wave_time * 0.85 + float(bubble_index))
		)
		draw_circle(
			bubble_position,
			bubble_size * 1.8,
			Color(1.0, 1.0, 1.0, bubble_alpha * 0.16)
		)
		draw_arc(
			bubble_position,
			bubble_size,
			deg_to_rad(205.0),
			deg_to_rad(325.0),
			10,
			Color(1.0, 1.0, 1.0, bubble_alpha * 0.50),
			0.75,
			true
		)


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
