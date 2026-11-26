extends "res://scripts/fantasy_alchemy_bottle.gd"

## One complete illustration per vial. The transparent inner chamber is analysed
## once per texture; every essence layer then shares the resulting body profile.

const DEFAULT_VIAL_ART: Texture2D = preload("res://assets/bottles/SpellSort_Vial__3.png")

const ALPHA_CUTOFF := 0.14
const SCAN_TOP_RATIO := 0.16
const SCAN_BOTTOM_RATIO := 0.88
const SCAN_LEFT_RATIO := 0.28
const SCAN_RIGHT_RATIO := 0.72
const CHAMBER_WIDTH_RATIO := 0.62
const PROFILE_SAMPLES := 160
const PROFILE_SMOOTH_RADIUS := 14
const REFLECTION_BRIDGE_RATIO := 0.035
const CENTRE_SEED_SEARCH_RATIO := 0.12
const LIQUID_SURFACE_SAMPLES := 48
const LIQUID_SIDE_SAMPLES := 32
const LIQUID_WALL_INSET := -0.9

# Preserve the generated vessel artwork exactly; reflections are added as a
# separate liquid-aware Godot pass after the illustration and liquid.
const GLASS_MODULATE := Color.WHITE

static var _texture_analysis_cache: Dictionary = {}

var vial_art: Texture2D = DEFAULT_VIAL_ART
var _window_profile := PackedVector3Array()
var _window_top_ratio: float = 0.28
var _window_bottom_ratio: float = 0.76
var _mouth_y_ratio: float = 0.065
var _mouth_width_ratio: float = 0.15
# Static chamber highlight paths are built once per vial instance, not every draw.
var _glass_halo_left := PackedVector2Array()
var _glass_main_left := PackedVector2Array()
var _glass_core_left := PackedVector2Array()
var _glass_bounce_right := PackedVector2Array()


func _ready() -> void:
	super._ready()
	_build_inner_window_profile()


func set_vial_art(texture: Texture2D) -> void:
	if texture == null:
		push_warning("Vial renderer: cannot assign a null illustration.")
		return
	vial_art = texture
	if is_node_ready():
		_build_inner_window_profile()
	queue_redraw()


func _build_inner_window_profile() -> void:
	_window_profile.clear()
	if vial_art == null:
		return

	var cache_key: int = vial_art.get_instance_id()
	if _texture_analysis_cache.has(cache_key):
		_apply_cached_analysis(_texture_analysis_cache[cache_key])
		_build_static_reflection_geometry()
		return

	var source_image: Image = vial_art.get_image()
	if source_image == null or source_image.is_empty():
		push_warning("Vial renderer: illustration pixels are unavailable.")
		return

	var image_width: int = source_image.get_width()
	var image_height: int = source_image.get_height()
	if image_width < 16 or image_height < 16:
		push_warning("Vial renderer: illustration is too small to analyse.")
		return

	var x_min: int = int(round(float(image_width) * SCAN_LEFT_RATIO))
	var x_max: int = int(round(float(image_width) * SCAN_RIGHT_RATIO))
	var centre_x: int = int(image_width / 2)
	var top_scan: int = int(round(float(image_height) * SCAN_TOP_RATIO))
	var bottom_scan: int = int(round(float(image_height) * SCAN_BOTTOM_RATIO))
	var search_radius: int = maxi(2, int(round(float(image_width) * 0.025)))

	var row_left := PackedInt32Array()
	var row_right := PackedInt32Array()
	var row_width := PackedInt32Array()
	row_left.resize(image_height)
	row_right.resize(image_height)
	row_width.resize(image_height)
	row_left.fill(-1)
	row_right.fill(-1)
	row_width.fill(0)

	var peak_width: int = 0
	var peak_row: int = -1
	for row in range(top_scan, bottom_scan + 1):
		var run := _find_centre_transparent_span(
			source_image,
			row,
			centre_x,
			x_min,
			x_max,
			search_radius
		)
		if run.x < 0:
			continue

		var width: int = run.y - run.x + 1
		row_left[row] = run.x
		row_right[row] = run.y
		row_width[row] = width
		if width > peak_width:
			peak_width = width
			peak_row = row

	if peak_row < 0 or peak_width < 12:
		push_warning("Vial renderer: no transparent central chamber was found; liquid is disabled for this image.")
		return

	# The neck and foot are also transparent, but narrower than the main body.
	# Keeping only the broad central region prevents liquid from climbing into
	# the neck or appearing in the narrow decorative base.
	var top_chamber_width: int = maxi(12, int(round(float(peak_width) * CHAMBER_WIDTH_RATIO)))
	var bottom_chamber_width: int = maxi(10, int(round(float(peak_width) * 0.08)))
	var chamber_top: int = peak_row
	var chamber_bottom: int = peak_row
	while chamber_top > top_scan and row_width[chamber_top - 1] >= top_chamber_width:
		chamber_top -= 1
	while chamber_bottom < bottom_scan and row_width[chamber_bottom + 1] >= bottom_chamber_width:
		chamber_bottom += 1

	if float(chamber_bottom - chamber_top) < float(image_height) * 0.22:
		push_warning("Vial renderer: detected transparent region is not a usable liquid chamber.")
		return

	for sample_index in range(PROFILE_SAMPLES):
		var t: float = float(sample_index) / float(PROFILE_SAMPLES - 1)
		var sample_row: int = roundi(lerpf(float(chamber_top), float(chamber_bottom), t))
		var sum_left: float = 0.0
		var sum_right: float = 0.0
		var sample_count: int = 0
		for row in range(
			maxi(chamber_top, sample_row - PROFILE_SMOOTH_RADIUS),
			mini(chamber_bottom, sample_row + PROFILE_SMOOTH_RADIUS) + 1
		):
			if row_width[row] <= 0:
				continue
			sum_left += float(row_left[row])
			sum_right += float(row_right[row] + 1)
			sample_count += 1

		if sample_count == 0:
			continue
		_window_profile.append(Vector3(
			float(sample_row) / float(image_height),
			(sum_left / float(sample_count)) / float(image_width),
			(sum_right / float(sample_count)) / float(image_width)
		))

	if _window_profile.size() < 8:
		_window_profile.clear()
		push_warning("Vial renderer: chamber profile could not be sampled reliably.")
		return

	# Extend slightly past the first/last transparent sample so the fill reaches
	# underneath the anti-aliased chamber rim instead of leaving a hairline gap.
	_window_top_ratio = maxf(0.0, _window_profile[0].x - 1.25 / float(image_height))
	_window_bottom_ratio = minf(1.0, _window_profile[-1].x + 1.25 / float(image_height))
	_detect_mouth(source_image, x_min, x_max, centre_x, search_radius)
	_build_static_reflection_geometry()

	_texture_analysis_cache[cache_key] = {
		"profile": _window_profile,
		"top": _window_top_ratio,
		"bottom": _window_bottom_ratio,
		"mouth_y": _mouth_y_ratio,
		"mouth_width": _mouth_width_ratio
	}


func _apply_cached_analysis(analysis: Dictionary) -> void:
	_window_profile = analysis["profile"]
	_window_top_ratio = float(analysis["top"])
	_window_bottom_ratio = float(analysis["bottom"])
	_mouth_y_ratio = float(analysis["mouth_y"])
	_mouth_width_ratio = float(analysis["mouth_width"])


func _find_centre_transparent_run(
	source_image: Image,
	row: int,
	centre_x: int,
	x_min: int,
	x_max: int,
	search_radius: int
) -> Vector2i:
	var seed_x: int = -1
	for offset in range(search_radius + 1):
		var left_candidate: int = centre_x - offset
		if left_candidate >= x_min:
			if source_image.get_pixel(left_candidate, row).a <= ALPHA_CUTOFF:
				seed_x = left_candidate
				break

		if offset > 0:
			var right_candidate: int = centre_x + offset
			if right_candidate <= x_max:
				if source_image.get_pixel(right_candidate, row).a <= ALPHA_CUTOFF:
					seed_x = right_candidate
					break

	if seed_x < 0:
		return Vector2i(-1, -1)

	var left_x: int = seed_x
	while left_x > x_min:
		if source_image.get_pixel(left_x - 1, row).a > ALPHA_CUTOFF:
			break
		left_x -= 1

	var right_x: int = seed_x
	while right_x < x_max:
		if source_image.get_pixel(right_x + 1, row).a > ALPHA_CUTOFF:
			break
		right_x += 1

	return Vector2i(left_x, right_x)


func _find_centre_transparent_span(
	source_image: Image,
	row: int,
	centre_x: int,
	x_min: int,
	x_max: int,
	search_radius: int
) -> Vector2i:
	# Short opaque interruptions are glass reflections, not chamber walls.
	# Bridge those gaps and stop only at the thicker continuous glass wall.
	var seed_x: int = -1
	var seed_radius: int = maxi(
		search_radius,
		int(round(float(source_image.get_width()) * CENTRE_SEED_SEARCH_RATIO))
	)
	for offset in range(seed_radius + 1):
		var left_candidate: int = centre_x - offset
		if left_candidate >= x_min and source_image.get_pixel(left_candidate, row).a <= ALPHA_CUTOFF:
			seed_x = left_candidate
			break
		if offset > 0:
			var right_candidate: int = centre_x + offset
			if right_candidate <= x_max and source_image.get_pixel(right_candidate, row).a <= ALPHA_CUTOFF:
				seed_x = right_candidate
				break

	if seed_x < 0:
		return Vector2i(-1, -1)

	var bridge_limit: int = maxi(
		8,
		int(round(float(source_image.get_width()) * REFLECTION_BRIDGE_RATIO))
	)
	var left_x: int = seed_x
	var cursor: int = seed_x - 1
	while cursor >= x_min:
		if source_image.get_pixel(cursor, row).a <= ALPHA_CUTOFF:
			left_x = cursor
			cursor -= 1
			continue
		var gap_start: int = cursor
		while cursor >= x_min and source_image.get_pixel(cursor, row).a > ALPHA_CUTOFF:
			cursor -= 1
		var gap_width: int = gap_start - cursor
		if gap_width > bridge_limit or cursor < x_min:
			break
		if source_image.get_pixel(cursor, row).a > ALPHA_CUTOFF:
			break
		left_x = cursor
		cursor -= 1

	var right_x: int = seed_x
	cursor = seed_x + 1
	while cursor <= x_max:
		if source_image.get_pixel(cursor, row).a <= ALPHA_CUTOFF:
			right_x = cursor
			cursor += 1
			continue
		var gap_start: int = cursor
		while cursor <= x_max and source_image.get_pixel(cursor, row).a > ALPHA_CUTOFF:
			cursor += 1
		var gap_width: int = cursor - gap_start
		if gap_width > bridge_limit or cursor > x_max:
			break
		if source_image.get_pixel(cursor, row).a > ALPHA_CUTOFF:
			break
		right_x = cursor
		cursor += 1

	if right_x - left_x < 8:
		return Vector2i(-1, -1)
	return Vector2i(left_x, right_x)


func _detect_mouth(
	source_image: Image,
	x_min: int,
	x_max: int,
	centre_x: int,
	search_radius: int
) -> void:
	var image_height: int = source_image.get_height()
	var image_width: int = source_image.get_width()
	var search_end: int = int(round(float(image_height) * 0.18))

	for row in range(maxi(1, int(round(float(image_height) * 0.01))), search_end):
		var run := _find_centre_transparent_run(
			source_image,
			row,
			centre_x,
			x_min,
			x_max,
			search_radius
		)
		if run.x < 0:
			continue
		var width_ratio: float = float(run.y - run.x + 1) / float(image_width)
		if width_ratio < 0.035 or width_ratio > 0.32:
			continue
		_mouth_y_ratio = float(row) / float(image_height)
		_mouth_width_ratio = width_ratio
		return


func _window_bounds_at(y_ratio: float) -> Vector2:
	if _window_profile.is_empty():
		return Vector2.ZERO
	var profile_count: int = _window_profile.size()
	var first: Vector3 = _window_profile[0]
	if y_ratio <= first.x:
		return Vector2(first.y, first.z)
	var last: Vector3 = _window_profile[profile_count - 1]
	if y_ratio >= last.x:
		return Vector2(last.y, last.z)

	# Binary search keeps mesh construction logarithmic. This lookup runs many
	# times per layer, per vial, on every animated frame.
	var low_index: int = 0
	var high_index: int = profile_count - 1
	while high_index - low_index > 1:
		var middle_index: int = (low_index + high_index) >> 1
		if _window_profile[middle_index].x <= y_ratio:
			low_index = middle_index
		else:
			high_index = middle_index

	first = _window_profile[low_index]
	last = _window_profile[high_index]
	var span: float = maxf(0.000001, last.x - first.x)
	var weight: float = clampf((y_ratio - first.x) / span, 0.0, 1.0)
	return Vector2(
		lerpf(first.y, last.y, weight),
		lerpf(first.z, last.z, weight)
	)


func _profile_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for bounds in _window_profile:
		points.append(Vector2(bounds.x, (bounds.z - bounds.y) * 0.5))
	return points


func _get_vessel_rect() -> Rect2:
	if vial_art == null:
		return super._get_vessel_rect()
	var source_size: Vector2 = Vector2(vial_art.get_size())
	var draw_scale: float = size.y / source_size.y
	var draw_size: Vector2 = source_size * draw_scale
	return Rect2((size - draw_size) * 0.5, draw_size)


func get_mouth_local() -> Vector2:
	var rect := _get_vessel_rect()
	return Vector2(rect.get_center().x, rect.position.y + rect.size.y * _mouth_y_ratio)


func get_mouth_hit_radius() -> Vector2:
	var rect := _get_vessel_rect()
	return Vector2(
		maxf(14.0, rect.size.x * _mouth_width_ratio * 0.65),
		rect.size.y * 0.035
	)


func get_liquid_surface_position_in_parent() -> Vector2:
	var rect := _get_vessel_rect()
	var layer_height: float = (_window_bottom_ratio - _window_top_ratio) / float(CAPACITY)
	var surface_ratio: float = _window_bottom_ratio - layer_height * clampf(
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


func _draw_liquid(_rect: Rect2) -> void:
	if _window_profile.size() < 8 or _visual_contents.is_empty() or _liquid_level <= 0.001:
		return

	var rect := _get_vessel_rect()
	var chamber_span: float = _window_bottom_ratio - _window_top_ratio
	if chamber_span <= 0.01:
		return

	var layer_height: float = chamber_span / float(CAPACITY)
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
	if bottom_y - top_y <= 1.2:
		return

	var top_edge := PackedVector2Array()
	for sample_index in range(LIQUID_SURFACE_SAMPLES + 1):
		var t: float = float(sample_index) / float(LIQUID_SURFACE_SAMPLES)
		var normalized_x: float = t * 2.0 - 1.0
		var wave: float = _get_surface_wave_offset(normalized_x) * 0.36 if is_surface else 0.0
		var wave_y: float = clampf(top_y + wave, top_y - 2.0, bottom_y - 0.8)
		var bounds := _window_bounds_at(clampf(
			(wave_y - rect.position.y) / rect.size.y,
			_window_top_ratio,
			_window_bottom_ratio
		))
		var left_x: float = rect.position.x + rect.size.x * bounds.x + LIQUID_WALL_INSET
		var right_x: float = rect.position.x + rect.size.x * bounds.y - LIQUID_WALL_INSET
		top_edge.append(Vector2(lerpf(left_x, right_x, t), wave_y))

	if top_edge.size() < 2:
		return

	var polygon := top_edge.duplicate()
	var right_top_y: float = top_edge[-1].y
	var left_top_y: float = top_edge[0].y
	var bottom_bounds := _window_bounds_at(bottom_ratio)
	var bottom_left_x: float = rect.position.x + rect.size.x * bottom_bounds.x + LIQUID_WALL_INSET
	var bottom_right_x: float = rect.position.x + rect.size.x * bottom_bounds.y - LIQUID_WALL_INSET

	for side_index in range(1, LIQUID_SIDE_SAMPLES + 1):
		var t: float = float(side_index) / float(LIQUID_SIDE_SAMPLES)
		var y: float = lerpf(right_top_y, bottom_y, t)
		var bounds := _window_bounds_at(clampf(
			(y - rect.position.y) / rect.size.y,
			_window_top_ratio,
			_window_bottom_ratio
		))
		polygon.append(Vector2(
			rect.position.x + rect.size.x * bounds.y - LIQUID_WALL_INSET,
			y
		))

	polygon.append(Vector2(bottom_left_x, bottom_y))
	for side_index in range(1, LIQUID_SIDE_SAMPLES):
		var t: float = float(side_index) / float(LIQUID_SIDE_SAMPLES)
		var y: float = lerpf(bottom_y, left_top_y, t)
		var bounds := _window_bounds_at(clampf(
			(y - rect.position.y) / rect.size.y,
			_window_top_ratio,
			_window_bottom_ratio
		))
		polygon.append(Vector2(
			rect.position.x + rect.size.x * bounds.x + LIQUID_WALL_INSET,
			y
		))

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
		var travel_fade: float = sin(PI * phase)
		var bubble_alpha: float = (
			0.07 + 0.045 * (0.5 + 0.5 * sin(_wave_time * 0.85 + float(bubble_index)))
		) * travel_fade
		if bubble_alpha <= 0.005:
			continue
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


func _draw_glass_back(_rect: Rect2) -> void:
	# The complete PNG is drawn once, above the live liquid.
	pass


func _draw_glass_overlay() -> void:
	if vial_art == null:
		return
	var rect := _get_vessel_rect()
	# Keep the Qwen artwork at its original colour. It supplies the vessel's
	# identity and ornaments; Godot adds the live optical response afterwards.
	draw_texture_rect(vial_art, rect, false, GLASS_MODULATE)
	_draw_chamber_reflections(rect)


func _build_static_reflection_geometry() -> void:
	_glass_halo_left.clear()
	_glass_main_left.clear()
	_glass_core_left.clear()
	_glass_bounce_right.clear()
	if _window_profile.size() < 8 or vial_art == null:
		return

	var rect := _get_vessel_rect()
	# These paths belong to the glass silhouette. They never depend on fill
	# height or liquid-layer boundaries.
	_glass_halo_left = _chamber_edge_points(rect, true, 0.06, 0.94, rect.size.x * 0.040)
	_glass_main_left = _chamber_edge_points(rect, true, 0.08, 0.90, rect.size.x * 0.022)
	_glass_core_left = _chamber_edge_points(rect, true, 0.14, 0.58, rect.size.x * 0.008)
	_glass_bounce_right = _chamber_edge_points(rect, false, 0.18, 0.86, rect.size.x * 0.026)


func _draw_chamber_reflections(rect: Rect2) -> void:
	if _glass_main_left.size() < 8:
		return

	var reflection_color: Color = _get_liquid_reflection_color()
	var halo_color := Color(reflection_color.r, reflection_color.g, reflection_color.b, 0.20)
	var main_color := Color(reflection_color.r, reflection_color.g, reflection_color.b, 0.52)
	var right_color := Color(reflection_color.r, reflection_color.g, reflection_color.b, 0.30)

	# The same glass highlights remain visible at every fill level. Only their
	# tint responds to the mixture inside; the geometry is cached and fixed.
	draw_polyline(_glass_halo_left, halo_color, maxf(3.0, rect.size.x * 0.050), true)
	draw_polyline(_glass_main_left, main_color, maxf(1.8, rect.size.x * 0.022), true)
	draw_polyline(_glass_core_left, Color(0.96, 1.0, 0.98, 0.76), maxf(1.0, rect.size.x * 0.009), true)
	draw_polyline(_glass_bounce_right, right_color, maxf(1.4, rect.size.x * 0.016), true)

	# This separate, short glint is the liquid meniscus and correctly follows
	# the liquid surface. It is intentionally much softer than the glass edge.
	_draw_liquid_surface_reflection(rect)


func _get_liquid_reflection_color() -> Color:
	if _liquid_level <= 0.001 or _visual_contents.is_empty():
		return Color(0.66, 0.82, 0.86, 1.0)

	var accumulated := Vector3.ZERO
	var total_weight: float = 0.0
	var visible_layers: int = mini(int(ceil(_liquid_level)), _visual_contents.size())
	for layer_index in range(visible_layers):
		var weight: float = clampf(_liquid_level - float(layer_index), 0.0, 1.0)
		if weight <= 0.001:
			continue
		var essence: String = String(_visual_contents[layer_index])
		var essence_color: Color = _palette.get(essence, Color(0.45, 0.78, 0.75, 1.0))
		accumulated += Vector3(essence_color.r, essence_color.g, essence_color.b) * weight
		total_weight += weight

	if total_weight <= 0.001:
		return Color(0.66, 0.82, 0.86, 1.0)

	var average := accumulated / total_weight
	var liquid_tint := Color(average.x, average.y, average.z, 1.0).lightened(0.30)
	return Color(0.68, 0.84, 0.88, 1.0).lerp(liquid_tint, 0.38)


func _glass_reflection_color(liquid_color: Color) -> Color:
	# Lift the essence colour toward cool glass light while preserving enough
	# hue to remain visibly related to the liquid beneath it.
	return liquid_color.lightened(0.30).lerp(Color(0.82, 0.94, 0.94, 1.0), 0.28)


func _draw_liquid_surface_reflection(rect: Rect2) -> void:
	if _liquid_level <= 0.001 or _visual_contents.is_empty():
		return

	var chamber_span: float = _window_bottom_ratio - _window_top_ratio
	var surface_ratio: float = _window_bottom_ratio - chamber_span / float(CAPACITY) * clampf(
		_liquid_level,
		0.0,
		float(CAPACITY)
	)
	var surface_points := PackedVector2Array()
	const SURFACE_REFLECTION_SAMPLES := 32
	for index in range(SURFACE_REFLECTION_SAMPLES + 1):
		var t: float = float(index) / float(SURFACE_REFLECTION_SAMPLES)
		var normalized_x: float = t * 2.0 - 1.0
		var wave_y: float = rect.position.y + rect.size.y * surface_ratio + _get_surface_wave_offset(normalized_x) * 0.42
		var y_ratio: float = clampf(
			(wave_y - rect.position.y) / rect.size.y,
			_window_top_ratio,
			_window_bottom_ratio
		)
		var bounds: Vector2 = _window_bounds_at(y_ratio)
		var left_x: float = rect.position.x + rect.size.x * bounds.x + rect.size.x * 0.025
		var right_x: float = rect.position.x + rect.size.x * bounds.y - rect.size.x * 0.025
		surface_points.append(Vector2(lerpf(left_x, right_x, t), wave_y))

	var surface_color: Color = _glass_reflection_color(_get_top_liquid_color())
	draw_polyline(surface_points, Color(surface_color.r, surface_color.g, surface_color.b, 0.24), maxf(1.2, rect.size.x * 0.016), true)
	draw_polyline(surface_points, Color(0.97, 1.0, 0.97, 0.48), maxf(0.8, rect.size.x * 0.007), true)


func _chamber_edge_points(
	rect: Rect2,
	left_side: bool,
	start_ratio: float,
	end_ratio: float,
	inset: float
) -> PackedVector2Array:
	var points := PackedVector2Array()
	const SAMPLE_COUNT := 36
	for index in range(SAMPLE_COUNT):
		var amount: float = float(index) / float(SAMPLE_COUNT - 1)
		var profile_ratio: float = lerpf(start_ratio, end_ratio, amount)
		var y_ratio: float = lerpf(_window_top_ratio, _window_bottom_ratio, profile_ratio)
		var bounds: Vector2 = _window_bounds_at(y_ratio)
		var edge_ratio: float = bounds.x if left_side else bounds.y
		var x: float = rect.position.x + rect.size.x * edge_ratio
		x += inset if left_side else -inset
		var y: float = rect.position.y + rect.size.y * y_ratio
		points.append(Vector2(x, y))
	return points


func _get_top_liquid_color() -> Color:
	if _visual_contents.is_empty():
		return Color(0.45, 0.78, 0.75, 1.0)
	var top_index: int = clampi(int(floor(_liquid_level - 0.0001)), 0, _visual_contents.size() - 1)
	var essence: String = String(_visual_contents[top_index])
	return _palette.get(essence, Color(0.45, 0.78, 0.75, 1.0))
