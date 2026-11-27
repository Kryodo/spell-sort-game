extends "res://scripts/fantasy_alchemy_bottle.gd"

## One complete illustration per vial. The transparent inner chamber is analysed
## once per texture; every essence layer then shares the resulting body profile.

const DEFAULT_VIAL_ART: Texture2D = preload("res://assets/bottles/SpellSort_Vial_Base_V1.2.png")

# Keep the animated meniscus separate from the static shaded liquid body.
const SURFACE_CAP_DEPTH := 22.0

const ALPHA_CUTOFF := 0.14
const SCAN_TOP_RATIO := 0.16
const SCAN_BOTTOM_RATIO := 0.90
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
const LIQUID_BOTTOM_WALL_OVERDRAW := 2.2
const LIQUID_BOTTOM_BLEND_START := 0.68
const LIQUID_APPEARANCE_FADE_LEVEL := 0.12
const LIQUID_MIN_BAND_HEIGHT := 0.05
const LIQUID_BAND_FADE_HEIGHT := 1.5

# Preserve the generated vessel artwork exactly; reflections are added as a
# separate liquid-aware Godot pass after the illustration and liquid.
const GLASS_MODULATE := Color.WHITE

# Draw only the near/front arc of the mouth after the pour stream.
# The rest of the illustration remains on the vial's normal draw layer.
class FrontMouthLipOverlay extends Control:
	var _bottle: Control
	var _art: Texture2D

	func configure(bottle: Control, art: Texture2D) -> void:
		_bottle = bottle
		_art = art
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 6
		z_as_relative = true
		visible = false
		queue_redraw()

	func set_art(art: Texture2D) -> void:
		_art = art
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(_bottle) or _art == null:
			return

		var pose: Vector2 = _bottle.call("get_pose")
		var applied_scale: float = float(_bottle.call("get_draw_scale"))
		var pivot := Vector2(_bottle.size.x * 0.5, _bottle.size.y * 0.86)
		var draw_origin := pivot + Vector2(0.0, -pose.x) - pivot.rotated(pose.y) * applied_scale
		var vessel_rect: Rect2 = _bottle.call("_get_vessel_rect")
		var texture_size: Vector2 = _art.get_size()

		# This normalized crop contains the lower/front half of the illustrated
		# mouth ring, not the upper/rear arc.
		var source_rect := Rect2(
			texture_size.x * 0.38,
			texture_size.y * 0.092,
			texture_size.x * 0.24,
			texture_size.y * 0.052
		)
		var destination_rect := Rect2(
			vessel_rect.position + Vector2(
				vessel_rect.size.x * source_rect.position.x / texture_size.x,
				vessel_rect.size.y * source_rect.position.y / texture_size.y
			),
			Vector2(
				vessel_rect.size.x * source_rect.size.x / texture_size.x,
				vessel_rect.size.y * source_rect.size.y / texture_size.y
			)
		)

		draw_set_transform(draw_origin, pose.y, Vector2(applied_scale, applied_scale))
		draw_texture_rect_region(_art, destination_rect, source_rect, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static var _texture_analysis_cache: Dictionary = {}

var vial_art: Texture2D = DEFAULT_VIAL_ART
var _window_profile := PackedVector3Array()
var _reflection_profile := PackedVector3Array()
var _window_top_ratio: float = 0.28
var _window_bottom_ratio: float = 0.76
var _reflection_bottom_ratio: float = 0.76
var _mouth_y_ratio: float = 0.065
var _mouth_width_ratio: float = 0.15
# Static chamber highlight paths are built once per vial instance, not every draw.
var _glass_layer_reflections: Array[Dictionary] = []
var _window_top_contour := PackedVector2Array()
var _front_mouth_lip_overlay: FrontMouthLipOverlay


func _ready() -> void:
	super._ready()
	_build_inner_window_profile()
	_front_mouth_lip_overlay = FrontMouthLipOverlay.new()
	_front_mouth_lip_overlay.name = "FrontMouthLipOverlay"
	add_child(_front_mouth_lip_overlay)
	_front_mouth_lip_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_front_mouth_lip_overlay.configure(self, vial_art)


func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(_front_mouth_lip_overlay) and _front_mouth_lip_overlay.visible:
		_front_mouth_lip_overlay.queue_redraw()


func set_front_mouth_lip_active(active: bool) -> void:
	if not is_instance_valid(_front_mouth_lip_overlay):
		return
	_front_mouth_lip_overlay.visible = active
	_front_mouth_lip_overlay.queue_redraw()


func set_vial_art(texture: Texture2D) -> void:
	if texture == null:
		push_warning("Vial renderer: cannot assign a null illustration.")
		return
	vial_art = texture
	if is_instance_valid(_front_mouth_lip_overlay):
		_front_mouth_lip_overlay.set_art(texture)
	if is_node_ready():
		_build_inner_window_profile()
	queue_redraw()


func _build_inner_window_profile() -> void:
	_window_profile.clear()
	_reflection_profile.clear()
	_window_top_contour.clear()
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
	# Keep a second, conservative endpoint for glass highlights. The liquid can
	# follow the narrower transparent foot, but reflections must stop at the
	# original broad-chamber boundary so they do not paint across the inner rim.
	var reflection_bottom_width: int = maxi(10, int(round(float(peak_width) * 0.08)))
	var reflection_chamber_bottom: int = peak_row
	while reflection_chamber_bottom < bottom_scan and row_width[reflection_chamber_bottom + 1] >= reflection_bottom_width:
		reflection_chamber_bottom += 1

	var bottom_chamber_width: int = maxi(4, int(round(float(peak_width) * 0.025)))
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
		# Keep the middle smooth, but let the final rounded rows follow their
		# actual silhouette instead of averaging across the narrowing base.
		var bottom_blend: float = smoothstep(0.78, 1.0, t)
		var sample_smooth_radius: int = roundi(lerpf(
			float(PROFILE_SMOOTH_RADIUS),
			0.0,
			bottom_blend
		))
		for row in range(
			maxi(chamber_top, sample_row - sample_smooth_radius),
			mini(chamber_bottom, sample_row + sample_smooth_radius) + 1
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

	# Rebuild the original conservative profile specifically for glass strokes:
	# original 8% lower-width cutoff and original 14-row smoothing throughout.
	for sample_index in range(PROFILE_SAMPLES):
		var t: float = float(sample_index) / float(PROFILE_SAMPLES - 1)
		var sample_row: int = roundi(lerpf(float(chamber_top), float(reflection_chamber_bottom), t))
		var sum_left: float = 0.0
		var sum_right: float = 0.0
		var sample_count: int = 0
		for row in range(
			maxi(chamber_top, sample_row - PROFILE_SMOOTH_RADIUS),
			mini(reflection_chamber_bottom, sample_row + PROFILE_SMOOTH_RADIUS) + 1
		):
			if row_width[row] <= 0:
				continue
			sum_left += float(row_left[row])
			sum_right += float(row_right[row] + 1)
			sample_count += 1
		if sample_count == 0:
			continue
		_reflection_profile.append(Vector3(
			float(sample_row) / float(image_height),
			(sum_left / float(sample_count)) / float(image_width),
			(sum_right / float(sample_count)) / float(image_width)
		))

	if _reflection_profile.size() < 8:
		_reflection_profile = _window_profile.duplicate()

	# Extend slightly past the first/last transparent sample so the fill reaches
	# underneath the anti-aliased chamber rim instead of leaving a hairline gap.
	_window_top_ratio = maxf(0.0, _window_profile[0].x - 1.25 / float(image_height))
	_window_bottom_ratio = minf(1.0, _window_profile[-1].x + 6.0 / float(image_height))
	_reflection_bottom_ratio = minf(
		1.0,
		float(reflection_chamber_bottom) / float(image_height) + 1.25 / float(image_height)
	)
	_window_top_contour = _detect_top_chamber_contour(source_image)
	_detect_mouth(source_image, x_min, x_max, centre_x, search_radius)
	_build_static_reflection_geometry()

	_texture_analysis_cache[cache_key] = {
		"profile": _window_profile,
		"reflection_profile": _reflection_profile,
		"top_contour": _window_top_contour,
		"top": _window_top_ratio,
		"bottom": _window_bottom_ratio,
		"reflection_bottom": _reflection_bottom_ratio,
		"mouth_y": _mouth_y_ratio,
		"mouth_width": _mouth_width_ratio
	}


func _apply_cached_analysis(analysis: Dictionary) -> void:
	_window_profile = analysis["profile"]
	_reflection_profile = analysis.get("reflection_profile", _window_profile).duplicate()
	_window_top_contour = analysis.get("top_contour", PackedVector2Array())
	_window_top_ratio = float(analysis["top"])
	_window_bottom_ratio = float(analysis["bottom"])
	_reflection_bottom_ratio = float(analysis.get("reflection_bottom", analysis["bottom"]))
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

	if right_x - left_x < 4:
		return Vector2i(-1, -1)
	return Vector2i(left_x, right_x)


func _detect_top_chamber_contour(source_image: Image) -> PackedVector2Array:
	var contour := PackedVector2Array()
	if _window_profile.size() < 8:
		return contour

	var image_width: int = source_image.get_width()
	var image_height: int = source_image.get_height()
	var first_profile: Vector3 = _window_profile[0]
	var left_column: int = clampi(
		floori(first_profile.y * float(image_width)),
		0,
		image_width - 1
	)
	var right_column: int = clampi(
		ceili(first_profile.z * float(image_width)) - 1,
		left_column + 1,
		image_width - 1
	)
	var scan_top: int = maxi(0, roundi(float(image_height) * SCAN_TOP_RATIO))
	var chamber_row: int = clampi(
		roundi(first_profile.x * float(image_height)),
		scan_top,
		image_height - 1
	)
	# Search only the upper chamber band. Within the measured left/right span,
	# the first transparent pixel in each column is the actual inner arch edge.
	var scan_bottom: int = mini(
		image_height - 1,
		chamber_row + maxi(4, roundi(float(image_height) * 0.035))
	)

	for column in range(left_column, right_column + 1, 2):
		var boundary_row: int = -1
		for row in range(scan_top, scan_bottom + 1):
			if source_image.get_pixel(column, row).a <= ALPHA_CUTOFF:
				boundary_row = row
				break
		if boundary_row >= 0:
			contour.append(Vector2(
				(float(column) + 0.5) / float(image_width),
				(float(boundary_row) + 0.5) / float(image_height)
			))

	if contour.size() < 8:
		return PackedVector2Array()

	# A small moving average removes single-pixel alpha noise without replacing
	# the detected silhouette with a guessed curve.
	var smoothed := PackedVector2Array()
	for index in range(contour.size()):
		var y_sum: float = 0.0
		var sample_count: int = 0
		for neighbour in range(maxi(0, index - 2), mini(contour.size() - 1, index + 2) + 1):
			y_sum += contour[neighbour].y
			sample_count += 1
		smoothed.append(Vector2(
			contour[index].x,
			y_sum / float(maxi(1, sample_count))
		))
	return smoothed


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
		# Each incoming layer fades in over its first fraction instead of
		# appearing at full opacity on the first non-zero preview value.
		liquid_color.a *= smoothstep(0.0, LIQUID_APPEARANCE_FADE_LEVEL, amount)
		_draw_liquid_band(
			rect,
			top_ratio,
			bottom_ratio,
			liquid_color,
			layer_index == visible_layers - 1,
			layer_index == 0
		)

	_draw_window_bubbles(rect, visible_layers)
	_draw_surface_bubble_activity(rect)


func _draw_surface_bubble_activity(rect: Rect2) -> void:
	if _liquid_level <= 0.02 or _visual_contents.is_empty():
		return

	const EVENT_PERIOD := 8.4
	const EVENT_DURATION := 1.15
	const EVENT_COUNT := 2
	var chamber_span: float = _window_bottom_ratio - _window_top_ratio
	var surface_ratio: float = _window_bottom_ratio - (
		chamber_span / float(CAPACITY) * clampf(_liquid_level, 0.0, float(CAPACITY))
	)
	var top_index: int = clampi(
		int(floor(_liquid_level - 0.0001)),
		0,
		_visual_contents.size() - 1
	)
	var top_amount: float = clampf(_liquid_level - float(top_index), 0.0, 1.0)
	var appearance_alpha: float = smoothstep(0.0, LIQUID_APPEARANCE_FADE_LEVEL, top_amount)
	if appearance_alpha <= 0.08:
		return

	var liquid_color: Color = _palette.get(
		String(_visual_contents[top_index]),
		Color(0.45, 0.78, 0.75, 1.0)
	)
	var pickup_blend: float = smoothstep(0.18, 0.42, _surface_activity)
	var movement_blend: float = smoothstep(0.42, 0.82, _surface_activity)
	var wave_strength: float = lerpf(1.20, 1.30, pickup_blend)
	wave_strength = lerpf(wave_strength, 1.75, movement_blend)
	var base_surface_y: float = rect.position.y + rect.size.y * surface_ratio
	var surface_bounds: Vector2 = _window_bounds_at(surface_ratio)
	var surface_half_width: float = (
		rect.size.x * (surface_bounds.y - surface_bounds.x) * 0.5 - 3.0
	)
	if surface_half_width <= 4.0:
		return

	for event_index in range(EVENT_COUNT):
		var event_phase: float = fposmod(
			_wave_time
			+ float(vial_index) * 1.71
			+ float(event_index) * EVENT_PERIOD * 0.5
			+ 1.35,
			EVENT_PERIOD
		)
		if event_phase > EVENT_DURATION:
			continue

		var progress: float = event_phase / EVENT_DURATION
		var side: float = -1.0 if event_index == 0 else 1.0
		var x_norm: float = side * (0.27 + 0.035 * float(vial_index % 3))
		x_norm += sin(_wave_time * 0.22 + float(vial_index)) * 0.025
		var surface_wave: float = _get_surface_wave_offset(x_norm) * wave_strength
		var surface_height: float = clampf(4.0 + surface_wave, 1.0, 8.0) * appearance_alpha
		var surface_y: float = base_surface_y - surface_height
		var surface_x: float = rect.get_center().x + x_norm * surface_half_width
		var centre := Vector2(surface_x, surface_y)

		if progress < 0.52:
			# A small coloured bubble swells through the existing meniscus, then
			# disappears as it breaks. Its centre is kept just above the surface.
			var swell: float = smoothstep(0.0, 0.46, progress)
			var bubble_radius: float = lerpf(0.95, 2.75, swell)
			var bubble_fade: float = 1.0 - smoothstep(0.34, 0.52, progress)
			var bubble_centre := centre + Vector2(0.0, -bubble_radius * 0.20)
			var bubble_tint: Color = liquid_color.lerp(
				Color(0.92, 1.0, 0.97, 1.0),
				0.46
			)
			draw_circle(
				bubble_centre,
				bubble_radius * 2.0,
				Color(bubble_tint.r, bubble_tint.g, bubble_tint.b, 0.14 * bubble_fade)
			)
			draw_circle(
				bubble_centre,
				bubble_radius,
				Color(bubble_tint.r, bubble_tint.g, bubble_tint.b, 0.66 * bubble_fade)
			)
			draw_arc(
				bubble_centre + Vector2(-0.25, -0.25),
				bubble_radius * 0.74,
				PI * 1.12,
				PI * 1.88,
				10,
				Color(0.96, 1.0, 0.96, 0.70 * bubble_fade),
				0.9,
				true
			)
		else:
			# The pop leaves one very shallow, quickly fading surface ripple.
			var pop_progress: float = (progress - 0.52) / 0.48
			var ripple_radius: float = lerpf(2.5, 8.5, pop_progress)
			var ripple_alpha: float = 0.30 * (1.0 - smoothstep(0.25, 1.0, pop_progress))
			var ripple_points := PackedVector2Array()
			const RIPPLE_SEGMENTS := 20
			for point_index in range(RIPPLE_SEGMENTS + 1):
				var angle: float = TAU * float(point_index) / float(RIPPLE_SEGMENTS)
				ripple_points.append(
					centre + Vector2(
						cos(angle) * ripple_radius,
						sin(angle) * ripple_radius * 0.28
					)
				)
			draw_polyline(
				ripple_points,
				Color(
					liquid_color.r,
					liquid_color.g,
					liquid_color.b,
					ripple_alpha * appearance_alpha
				),
				1.05,
				true
			)


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
	var band_height: float = bottom_y - top_y
	if band_height <= LIQUID_MIN_BAND_HEIGHT:
		return
	# Fade the first sub-pixel band in gradually instead of revealing it at
	# the old hard 1.2px cutoff.
	var band_alpha: float = smoothstep(
		LIQUID_MIN_BAND_HEIGHT,
		LIQUID_BAND_FADE_HEIGHT,
		band_height
	)

	# The animated surface is the actual top boundary of the liquid body.
	# Keeping one continuous body all the way to its floor prevents the
	# single-layer case from becoming a short, separately capped polygon.
	var body_top_y: float = top_y
	var body_top_edge := PackedVector2Array()
	# The top edge is horizontal, so every sample uses the same chamber bounds.
	# Resolve them once instead of repeating the identical profile lookup 49 times.
	var body_ratio: float = clampf(
		(body_top_y - rect.position.y) / rect.size.y,
		_window_top_ratio,
		_window_bottom_ratio
	)
	var body_bounds := _window_bounds_at(body_ratio)
	var body_left_x: float = rect.position.x + rect.size.x * body_bounds.x + LIQUID_WALL_INSET
	var body_right_x: float = rect.position.x + rect.size.x * body_bounds.y - LIQUID_WALL_INSET
	for sample_index in range(LIQUID_SURFACE_SAMPLES + 1):
		var t: float = float(sample_index) / float(LIQUID_SURFACE_SAMPLES)
		body_top_edge.append(Vector2(lerpf(body_left_x, body_right_x, t), body_top_y))

	if body_top_edge.size() < 2:
		return

	var wave_edge := PackedVector2Array()
	if is_surface:
		# Blend from resting to held to moving entirely through smoothed activity.
		# This avoids a visual step when pointer velocity crosses the drag threshold.
		var pickup_blend: float = smoothstep(0.18, 0.42, _surface_activity)
		var movement_blend: float = smoothstep(0.42, 0.82, _surface_activity)
		var wave_strength: float = lerpf(1.20, 1.30, pickup_blend)
		wave_strength = lerpf(wave_strength, 1.75, movement_blend)

		for sample_index in range(LIQUID_SURFACE_SAMPLES + 1):
			var t: float = float(sample_index) / float(LIQUID_SURFACE_SAMPLES)
			var normalized_x: float = t * 2.0 - 1.0
			var wave: float = _get_surface_wave_offset(normalized_x) * wave_strength
			# At the current maximum slosh/tilt this keeps the whole wave inside
			# the cap. It cannot fold over the base edge or create a self-crossing.
			# Let the top edge move in both directions while keeping the wave
			# within the current liquid band.
			# Keep the moving surface entirely above the stable body boundary.
			# This forms a simple, non-self-intersecting strip every frame.
			var wave_height: float = clampf(4.0 + wave, 1.0, 8.0) * liquid_color.a
			var wave_y: float = top_y - wave_height
			var base_point: Vector2 = body_top_edge[sample_index]
			wave_edge.append(Vector2(base_point.x, wave_y))

	# The body uses the stable chamber profile. The meniscus animates as a
	# separate highlight so changing wave triangulation cannot expose seams.
	var polygon := body_top_edge.duplicate()
	var right_top_y: float = body_top_edge[-1].y
	var left_top_y: float = body_top_edge[0].y
	var bottom_bounds := _window_bounds_at(bottom_ratio)
	var bottom_left_x: float = (
		rect.position.x
		+ rect.size.x * bottom_bounds.x
		+ LIQUID_WALL_INSET
		- LIQUID_BOTTOM_WALL_OVERDRAW
	)
	var bottom_right_x: float = (
		rect.position.x
		+ rect.size.x * bottom_bounds.y
		- LIQUID_WALL_INSET
		+ LIQUID_BOTTOM_WALL_OVERDRAW
	)

	for side_index in range(1, LIQUID_SIDE_SAMPLES + 1):
		var t: float = float(side_index) / float(LIQUID_SIDE_SAMPLES)
		var y: float = lerpf(right_top_y, bottom_y, t)
		var lower_blend: float = smoothstep(LIQUID_BOTTOM_BLEND_START, 1.0, t)
		var wall_inset: float = LIQUID_WALL_INSET - LIQUID_BOTTOM_WALL_OVERDRAW * lower_blend
		var bounds := _window_bounds_at(clampf(
			(y - rect.position.y) / rect.size.y,
			_window_top_ratio,
			_window_bottom_ratio
		))
		polygon.append(Vector2(
			rect.position.x + rect.size.x * bounds.y - wall_inset,
			y
		))

	polygon.append(Vector2(bottom_left_x, bottom_y))
	for side_index in range(1, LIQUID_SIDE_SAMPLES):
		var t: float = float(side_index) / float(LIQUID_SIDE_SAMPLES)
		var y: float = lerpf(bottom_y, left_top_y, t)
		var lower_blend: float = smoothstep(LIQUID_BOTTOM_BLEND_START, 1.0, 1.0 - t)
		var wall_inset: float = LIQUID_WALL_INSET - LIQUID_BOTTOM_WALL_OVERDRAW * lower_blend
		var bounds := _window_bounds_at(clampf(
			(y - rect.position.y) / rect.size.y,
			_window_top_ratio,
			_window_bottom_ratio
		))
		polygon.append(Vector2(
			rect.position.x + rect.size.x * bounds.x + wall_inset,
			y
		))

	var fill_color: Color = liquid_color.lerp(liquid_color.lightened(0.12), 0.10)
	fill_color.a *= band_alpha
	var edge_color: Color = fill_color.darkened(0.10)
	var bottom_color: Color = fill_color.darkened(0.045)
	var center_color: Color = fill_color.lightened(0.18)

	# The liquid body retains its stable horizontal centre/edge gradient.
	var vertex_colors := PackedColorArray()
	for sample_index in range(LIQUID_SURFACE_SAMPLES + 1):
		var t: float = float(sample_index) / float(LIQUID_SURFACE_SAMPLES)
		var center_weight: float = pow(maxf(0.0, sin(PI * t)), 0.85) * 0.42
		vertex_colors.append(edge_color.lerp(center_color, center_weight))
	for _side_index in range(LIQUID_SIDE_SAMPLES):
		vertex_colors.append(edge_color)
	vertex_colors.append(bottom_color)
	for _side_index in range(1, LIQUID_SIDE_SAMPLES):
		vertex_colors.append(edge_color)
	draw_polygon(polygon, vertex_colors)

	if is_surface and wave_edge.size() == body_top_edge.size():
		var surface_polygon := PackedVector2Array()
		var surface_colours := PackedColorArray()
		for sample_index in range(wave_edge.size()):
			var t: float = float(sample_index) / float(LIQUID_SURFACE_SAMPLES)
			surface_polygon.append(wave_edge[sample_index])
			surface_colours.append(_surface_gradient_colour(t, edge_color, center_color))
		for sample_index in range(body_top_edge.size() - 1, -1, -1):
			surface_polygon.append(body_top_edge[sample_index])
			# The lower edge uses the exact same gradient in reverse order.
			surface_colours.append(surface_colours[sample_index])
		draw_polygon(surface_polygon, surface_colours)

		var surface_color: Color = fill_color.lightened(0.34)
		surface_color.a = (0.12 + _surface_activity * 0.05 + absf(_slosh) * 0.025) * fill_color.a
		draw_polyline(wave_edge, surface_color, 1.1, true)


func _surface_gradient_colour(normalized_x: float, edge_color: Color, center_color: Color) -> Color:
	var center_weight: float = pow(maxf(0.0, sin(PI * normalized_x)), 0.85) * 0.42
	return edge_color.lerp(center_color, center_weight)

func _draw_window_bubbles(rect: Rect2, visible_layers: int) -> void:
	if visible_layers <= 0 or _window_profile.is_empty():
		return

	var appearance_alpha: float = smoothstep(0.0, LIQUID_APPEARANCE_FADE_LEVEL, _liquid_level)
	var chamber_span: float = _window_bottom_ratio - _window_top_ratio
	var layer_height: float = chamber_span / float(CAPACITY)
	var surface_ratio: float = _window_bottom_ratio - (
		layer_height * clampf(_liquid_level, 0.0, float(CAPACITY))
	)
	var surface_y: float = rect.position.y + rect.size.y * surface_ratio
	var bottom_y: float = rect.position.y + rect.size.y * _window_bottom_ratio

	# A small mix of bubbles rises at different speeds. Each particle borrows
	# the colour of the essence layer it is travelling through.
	const BUBBLE_SIZES := [1.65, 2.25, 1.85, 2.35]
	for bubble_index in range(BUBBLE_SIZES.size()):
		var speed: float = 0.082 + float(bubble_index % 3) * 0.021 + float(bubble_index / 3) * 0.008
		var phase: float = fposmod(
			_wave_time * speed + float(bubble_index) * 0.163,
			1.0
		)
		var bubble_y: float = lerpf(bottom_y - 5.0, surface_y + 3.0, phase)
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

		var sway: float = sin(_wave_time * (0.34 + float(bubble_index % 3) * 0.09) + float(bubble_index) * 1.71)
		var bubble_position := Vector2(
			lerpf(left_x, right_x, 0.5 + sway * 0.24),
			bubble_y
		)
		var bubble_size: float = BUBBLE_SIZES[bubble_index]
		var travel_fade: float = sin(PI * phase)
		var pulse: float = 0.55 + 0.45 * sin(_wave_time * 1.15 + float(bubble_index) * 1.37)
		var bubble_alpha: float = (0.18 + 0.06 * pulse) * travel_fade * appearance_alpha
		if bubble_alpha <= 0.004:
			continue

		var layer_index: int = clampi(
			int(floor((_window_bottom_ratio - normalized_y) / maxf(0.0001, layer_height))),
			0,
			mini(_visual_contents.size() - 1, CAPACITY - 1)
		)
		var essence: String = String(_visual_contents[layer_index])
		var bubble_color: Color = _palette.get(essence, Color(0.45, 0.78, 0.75, 1.0))
		var glow_color := Color(bubble_color.r, bubble_color.g, bubble_color.b, bubble_alpha * 0.34)
		var core_color: Color = bubble_color.lightened(0.56)
		core_color.a = bubble_alpha * 0.52

		# Soft coloured halo, translucent bubble body and a restrained glassy glint.
		draw_circle(bubble_position, bubble_size * 2.35, glow_color)
		draw_circle(bubble_position, bubble_size, core_color)
		draw_circle(
			bubble_position + Vector2(-bubble_size * 0.30, -bubble_size * 0.34),
			maxf(0.60, bubble_size * 0.22),
			Color(1.0, 1.0, 1.0, bubble_alpha * 0.95)
		)

	# A few much smaller alchemical motes add life between the larger bubbles.
	for mote_index in range(2):
		var mote_phase: float = fposmod(
			_wave_time * (0.055 + float(mote_index) * 0.012)
			+ float(mote_index) * 0.317,
			1.0
		)
		var mote_y: float = lerpf(bottom_y - 3.0, surface_y + 2.0, mote_phase)
		var mote_ratio: float = clampf(
			(mote_y - rect.position.y) / rect.size.y,
			_window_top_ratio,
			_window_bottom_ratio
		)
		var mote_bounds := _window_bounds_at(mote_ratio)
		var mote_half_width: float = maxf(0.0, rect.size.x * (mote_bounds.y - mote_bounds.x) * 0.32)
		if mote_half_width <= 2.0:
			continue
		var mote_x: float = rect.get_center().x + sin(_wave_time * 0.27 + float(mote_index) * 2.1) * mote_half_width
		var mote_position := Vector2(mote_x, mote_y)
		var mote_alpha: float = (0.065 + 0.035 * sin(_wave_time * 0.8 + float(mote_index))) * sin(PI * mote_phase) * appearance_alpha
		var mote_layer: int = clampi(
			int(floor((_window_bottom_ratio - mote_ratio) / maxf(0.0001, layer_height))),
			0,
			mini(_visual_contents.size() - 1, CAPACITY - 1)
		)
		var mote_essence: String = String(_visual_contents[mote_layer])
		var mote_color: Color = _palette.get(mote_essence, Color(0.45, 0.78, 0.75, 1.0))
		draw_circle(
			mote_position,
			2.2,
			Color(mote_color.r, mote_color.g, mote_color.b, mote_alpha * 0.24)
		)
		draw_circle(
			mote_position,
			0.75,
			Color(0.95, 1.0, 0.92, mote_alpha * 0.72)
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
	_glass_layer_reflections.clear()
	if _window_profile.size() < 8 or vial_art == null:
		return

	var rect := _get_vessel_rect()
	# Recreate the earlier layered reflection style for every fixed capacity
	# section. The original paths were tied to the changing liquid bands; these
	# copies use the same shapes and insets but are anchored to the vessel.
	for layer_index in range(CAPACITY):
		var section_top: float = 1.0 - float(layer_index + 1) / float(CAPACITY)
		var section_bottom: float = 1.0 - float(layer_index) / float(CAPACITY)
		var halo_inset: float = rect.size.x * 0.030
		var main_inset: float = rect.size.x * 0.016
		var core_inset: float = rect.size.x * 0.006
		var is_top_section: bool = layer_index == CAPACITY - 1

		var left_halo := _chamber_edge_points(rect, true, section_top, section_bottom, halo_inset)
		var left_main := _chamber_edge_points(rect, true, section_top, section_bottom, main_inset)
		var core_start: float = section_top if is_top_section else lerpf(section_top, section_bottom, 0.14)
		var left_core := _chamber_edge_points(rect, true, core_start, section_bottom, core_inset)
		var bounce_start: float = section_top if is_top_section else section_top + 0.10 / float(CAPACITY)
		var right_bounce := _chamber_edge_points(
			rect,
			false,
			bounce_start,
			section_bottom,
			rect.size.x * 0.020
		)
		var glint_start: float = section_top if is_top_section else lerpf(section_top, section_bottom, 0.18)
		var glint_end: float = lerpf(section_top, section_bottom, 0.48)
		var glint := _chamber_edge_points(rect, true, glint_start, glint_end, core_inset + 1.5)

		_glass_layer_reflections.append({
			"halo": left_halo,
			"main": left_main,
			"core": left_core,
			"bounce": right_bounce,
			"glint": glint
		})

	# Extend the existing side reflections up the actual inner arch. Keep the
	# two strokes separate: no line is drawn across or over the top of the vial.
	if _window_top_contour.size() >= 8 and not _glass_layer_reflections.is_empty():
		var top_geometry: Dictionary = _glass_layer_reflections[CAPACITY - 1]
		top_geometry["main"] = _extend_side_reflection_to_arch(
			top_geometry["main"],
			rect,
			true,
			rect.size.x * 0.016
		)
		top_geometry["bounce"] = _extend_side_reflection_to_arch(
			top_geometry["bounce"],
			rect,
			false,
			rect.size.x * 0.020
		)
		_glass_layer_reflections[CAPACITY - 1] = top_geometry


func _extend_side_reflection_to_arch(
	side_path: PackedVector2Array,
	rect: Rect2,
	left_side: bool,
	inset: float
) -> PackedVector2Array:
	if side_path.size() < 2 or _window_top_contour.size() < 8:
		return side_path

	# Locate the existing stroke endpoint on the measured arch contour.
	var anchor: Vector2 = side_path[0]
	var anchor_index: int = 0
	var nearest_distance: float = 1.0e20
	var apex_index: int = 0
	var highest_y: float = 1.0
	for index in range(_window_top_contour.size()):
		var contour_point: Vector2 = _window_top_contour[index]
		var screen_point := Vector2(
			rect.position.x + rect.size.x * contour_point.x,
			rect.position.y + rect.size.y * contour_point.y
		)
		var distance: float = screen_point.distance_squared_to(anchor)
		if distance < nearest_distance:
			nearest_distance = distance
			anchor_index = index
		if contour_point.y < highest_y:
			highest_y = contour_point.y
			apex_index = index

	# Leave a small gap at the crown so the left and right reflections never
	# become a new top-cap line.
	var crown_gap: int = maxi(2, roundi(float(_window_top_contour.size()) * 0.08))
	var stop_index: int = (
		maxi(anchor_index + 1, apex_index - crown_gap)
		if left_side
		else mini(anchor_index - 1, apex_index + crown_gap)
	)
	if left_side and stop_index <= anchor_index:
		return side_path
	if not left_side and stop_index >= anchor_index:
		return side_path

	var extended := PackedVector2Array()
	var contour_step: int = -1 if left_side else 1
	var contour_index: int = stop_index
	while (contour_index >= anchor_index if left_side else contour_index <= anchor_index):
		var current_point: Vector2 = _window_top_contour[contour_index]
		var previous_point: Vector2 = _window_top_contour[maxi(0, contour_index - 1)]
		var next_point: Vector2 = _window_top_contour[mini(
			_window_top_contour.size() - 1,
			contour_index + 1
		)]
		var tangent := Vector2(
			(next_point.x - previous_point.x) * rect.size.x,
			(next_point.y - previous_point.y) * rect.size.y
		)
		# The inward normal points down into the chamber on both sides.
		var inward_normal := Vector2(-tangent.y, tangent.x).normalized()
		var point := Vector2(
			rect.position.x + rect.size.x * current_point.x,
			rect.position.y + rect.size.y * current_point.y
		)
		extended.append(point + inward_normal * inset)
		contour_index += contour_step

	if extended.size() < 2:
		return side_path
	extended[extended.size() - 1] = anchor
	for index in range(1, side_path.size()):
		extended.append(side_path[index])
	return extended


func _draw_chamber_reflections(rect: Rect2) -> void:
	if _glass_layer_reflections.size() != CAPACITY:
		return

	# Geometry is constant. Each fixed chamber section takes the tint of its
	# own essence when occupied, and neutral glass when empty.
	for layer_index in range(CAPACITY):
		var geometry: Dictionary = _glass_layer_reflections[layer_index]
		var amount: float = clampf(_liquid_level - float(layer_index), 0.0, 1.0)
		var reflection_color := Color(0.66, 0.82, 0.86, 1.0)
		if layer_index < _visual_contents.size() and amount > 0.0:
			var essence: String = String(_visual_contents[layer_index])
			var liquid_color: Color = _palette.get(essence, Color(0.45, 0.78, 0.75, 1.0))
			var tint_blend: float = smoothstep(0.0, LIQUID_APPEARANCE_FADE_LEVEL, amount)
			reflection_color = reflection_color.lerp(
				_glass_reflection_color(liquid_color),
				tint_blend
			)

		var halo_color := Color(reflection_color.r, reflection_color.g, reflection_color.b, 0.25)
		var main_color := Color(reflection_color.r, reflection_color.g, reflection_color.b, 0.62)
		var right_color := Color(reflection_color.r, reflection_color.g, reflection_color.b, 0.34)
		draw_polyline(geometry["halo"], halo_color, maxf(3.0, rect.size.x * 0.045), true)
		draw_polyline(geometry["main"], main_color, maxf(1.8, rect.size.x * 0.018), true)
		draw_polyline(geometry["core"], Color(0.94, 0.98, 0.97, 0.78), maxf(1.0, rect.size.x * 0.010), true)
		draw_polyline(geometry["bounce"], right_color, maxf(1.4, rect.size.x * 0.014), true)
		draw_polyline(geometry["glint"], Color(0.98, 1.0, 0.96, 0.92), maxf(1.0, rect.size.x * 0.012), true)

	# Only the meniscus follows the fill level; the glass strokes above never move.
	_draw_liquid_surface_reflection(rect)



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

	# One restrained reflection that borrows the active top essence hue.
	# Avoid the separate white glow stroke, which reads like a hard divider.
	var surface_color: Color = _get_top_liquid_color().lightened(0.16)
	var appearance_alpha: float = smoothstep(0.0, LIQUID_APPEARANCE_FADE_LEVEL, _liquid_level)
	surface_color.a = 0.22 * appearance_alpha
	draw_polyline(surface_points, surface_color, maxf(1.0, rect.size.x * 0.012), true)


func _reflection_bounds_at(y_ratio: float) -> Vector2:
	if _reflection_profile.is_empty():
		return _window_bounds_at(y_ratio)
	var profile_count: int = _reflection_profile.size()
	var first: Vector3 = _reflection_profile[0]
	if y_ratio <= first.x:
		return Vector2(first.y, first.z)
	var last: Vector3 = _reflection_profile[profile_count - 1]
	if y_ratio >= last.x:
		return Vector2(last.y, last.z)

	var low_index: int = 0
	var high_index: int = profile_count - 1
	while high_index - low_index > 1:
		var middle_index: int = (low_index + high_index) >> 1
		if _reflection_profile[middle_index].x <= y_ratio:
			low_index = middle_index
		else:
			high_index = middle_index

	first = _reflection_profile[low_index]
	last = _reflection_profile[high_index]
	var span: float = maxf(0.000001, last.x - first.x)
	var weight: float = clampf((y_ratio - first.x) / span, 0.0, 1.0)
	return Vector2(
		lerpf(first.y, last.y, weight),
		lerpf(first.z, last.z, weight)
	)


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
		var y_ratio: float = lerpf(_window_top_ratio, _reflection_bottom_ratio, profile_ratio)
		var bounds: Vector2 = _reflection_bounds_at(y_ratio)
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
