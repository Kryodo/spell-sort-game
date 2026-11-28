extends "res://scripts/test_tube_renderer_base_fantasy_bottle.gd"

## One complete illustration per vial. The transparent inner chamber is analysed
## once per texture; every essence layer then shares the resulting body profile.

const DEFAULT_VIAL_ART: Texture2D = preload("res://assets/environments/SpellSort_LabBottle_Glass.svg")
const BASE_REFRACTION_ART: Texture2D = preload("res://assets/environments/SpellSort_LabBottle_BaseRefraction.svg")

# The SVG uses the same 160x365 aspect as the working renderer's original art.
# Its hand-authored profile below replaces texture-alpha chamber detection.
const BOTTLE_BODY_WIDTH_RATIO := 0.70
const BOTTLE_BODY_TOP_RATIO := 0.055
const BOTTLE_BODY_HEIGHT_RATIO := 0.89

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
		# The lab bottle has a compact rolled mouth near the top of its SVG.
		# This crop isolates the lower/front lip so the stream remains behind it.
		var source_rect := Rect2(
			texture_size.x * 0.33,
			texture_size.y * 0.075,
			texture_size.x * 0.34,
			texture_size.y * 0.029
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



# The new SVG owns the glass appearance; this layer draws that artwork only.
class VialArtworkLayer extends Control:
	var _bottle: Control

	func configure(bottle: Control) -> void:
		_bottle = bottle
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(_bottle):
			return
		var art: Texture2D = _bottle.get("vial_art")
		if art == null:
			return
		var rect: Rect2 = _bottle.call("_get_vessel_rect")
		draw_texture_rect(art, rect, false, Color.WHITE)


# The custom bottle's far-base Fresnel is a separate, liquid-aware pass.
# It remains part of this copied renderer, not the live main-scene script.
class BaseRefractionLayer extends Control:
	var _bottle: Control
	var _art: Texture2D

	func configure(bottle: Control, art: Texture2D) -> void:
		_bottle = bottle
		_art = art
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 1
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(_bottle) or _art == null:
			return
		if float(_bottle.get("_liquid_level")) > 0.001:
			return
		if not bool(_bottle.get("_pour_refraction_visible")):
			return
		draw_texture_rect(_art, Rect2(Vector2.ZERO, size), false, Color.WHITE)


static var _texture_analysis_cache: Dictionary = {}
static var _bubble_sprite_cache: Dictionary = {}

var vial_art: Texture2D = DEFAULT_VIAL_ART
var _window_profile := PackedVector3Array()
var _window_top_ratio: float = 0.28
var _window_bottom_ratio: float = 0.76
var _mouth_y_ratio: float = 0.065
var _mouth_width_ratio: float = 0.15
var _front_mouth_lip_overlay: FrontMouthLipOverlay
var _artwork_transform: Control
var _artwork_layer: VialArtworkLayer
var _base_refraction_layer: BaseRefractionLayer
var _pour_refraction_visible: bool = true

# Stable liquid body geometry is cached per vial and rebuilt only when its
# contents, fill preview, artwork profile or control size changes.
var _cached_liquid_bands: Array[Dictionary] = []
var _cached_liquid_rect := Rect2()
var _liquid_geometry_dirty: bool = true


func _ready() -> void:
	super._ready()
	_build_inner_window_profile()
	_front_mouth_lip_overlay = FrontMouthLipOverlay.new()
	_front_mouth_lip_overlay.name = "FrontMouthLipOverlay"
	add_child(_front_mouth_lip_overlay)
	_front_mouth_lip_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_front_mouth_lip_overlay.configure(self, vial_art)

	_artwork_transform = Control.new()
	_artwork_transform.name = "VialArtworkTransform"
	_artwork_transform.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_artwork_transform.size = size
	add_child(_artwork_transform)

	_artwork_layer = VialArtworkLayer.new()
	_artwork_layer.name = "VialArtwork"
	_artwork_layer.size = size
	_artwork_transform.add_child(_artwork_layer)
	_artwork_layer.configure(self)

	_base_refraction_layer = BaseRefractionLayer.new()
	_base_refraction_layer.name = "EmptyBottleBaseRefraction"
	_artwork_transform.add_child(_base_refraction_layer)
	_base_refraction_layer.configure(self, BASE_REFRACTION_ART)

	if not resized.is_connected(_on_vial_resized):
		resized.connect(_on_vial_resized)
	_update_artwork_transform()
	_invalidate_liquid_geometry()


func _update_artwork_transform() -> void:
	if not is_instance_valid(_artwork_transform):
		return
	var pivot := Vector2(size.x * 0.5, size.y * 0.86)
	_artwork_transform.position = (
		pivot
		+ Vector2(0.0, -_lift)
		- pivot.rotated(_tilt) * _draw_scale
	)
	_artwork_transform.rotation = _tilt
	_artwork_transform.scale = Vector2(_draw_scale, _draw_scale)
	_artwork_transform.size = size
	if is_instance_valid(_artwork_layer):
		_artwork_layer.size = size


func _on_vial_resized() -> void:
	_update_artwork_transform()
	_invalidate_liquid_geometry()
	if is_instance_valid(_artwork_layer):
		_artwork_layer.queue_redraw()
	if is_instance_valid(_base_refraction_layer):
		_base_refraction_layer.queue_redraw()


func _invalidate_liquid_geometry() -> void:
	_liquid_geometry_dirty = true
	queue_redraw()


func setup(index: int, label: String, variant: int, palette: Dictionary, contents: Array) -> void:
	super.setup(index, label, variant, palette, contents)
	_invalidate_liquid_geometry()


func set_contents(contents: Array) -> void:
	super.set_contents(contents)
	_invalidate_liquid_geometry()
	if is_instance_valid(_base_refraction_layer):
		_base_refraction_layer.queue_redraw()


func set_preview(contents: Array, level: float) -> void:
	super.set_preview(contents, level)
	_invalidate_liquid_geometry()
	if is_instance_valid(_base_refraction_layer):
		_base_refraction_layer.queue_redraw()


func _process(delta: float) -> void:
	super._process(delta)
	_update_artwork_transform()
	if is_instance_valid(_front_mouth_lip_overlay) and _front_mouth_lip_overlay.visible:
		_front_mouth_lip_overlay.queue_redraw()


func set_front_mouth_lip_active(active: bool) -> void:
	if not is_instance_valid(_front_mouth_lip_overlay):
		return
	_front_mouth_lip_overlay.visible = active
	_front_mouth_lip_overlay.queue_redraw()


func set_pour_refraction_visible(visible: bool) -> void:
	if _pour_refraction_visible == visible:
		return
	_pour_refraction_visible = visible
	if is_instance_valid(_base_refraction_layer):
		_base_refraction_layer.queue_redraw()


func set_vial_art(texture: Texture2D) -> void:
	if texture == null:
		push_warning("Vial renderer: cannot assign a null illustration.")
		return
	vial_art = texture
	if is_instance_valid(_front_mouth_lip_overlay):
		_front_mouth_lip_overlay.set_art(texture)
	if is_node_ready():
		_build_inner_window_profile()
		_liquid_geometry_dirty = true
		if is_instance_valid(_artwork_layer):
			_artwork_layer.queue_redraw()
	queue_redraw()


func _build_inner_window_profile() -> void:
	_window_profile.clear()

	# Use the new bottle's hand-authored silhouette instead of scanning the
	# SVG pixels. The profile is mapped into the same normalized full-art
	# coordinates used by the working renderer's cached liquid pipeline.
	for sample_index in range(PROFILE_SAMPLES):
		var t: float = float(sample_index) / float(PROFILE_SAMPLES - 1)
		var profile_point: Vector2 = _get_profile_at(t)
		var y_ratio: float = BOTTLE_BODY_TOP_RATIO + BOTTLE_BODY_HEIGHT_RATIO * t
		var half_width_ratio: float = profile_point.y * BOTTLE_BODY_WIDTH_RATIO
		var left_ratio: float = 0.5 - half_width_ratio
		var right_ratio: float = 0.5 + half_width_ratio
		var sample := Vector3(y_ratio, left_ratio, right_ratio)
		_window_profile.append(sample)

	_window_top_ratio = (
		BOTTLE_BODY_TOP_RATIO + BOTTLE_BODY_HEIGHT_RATIO * LIQUID_TOP_RATIO
	)
	_window_bottom_ratio = (
		BOTTLE_BODY_TOP_RATIO + BOTTLE_BODY_HEIGHT_RATIO * LIQUID_BOTTOM_RATIO
	)
	_mouth_y_ratio = 23.0 / 365.0
	_mouth_width_ratio = 56.0 / 160.0

	if is_instance_valid(_artwork_layer):
		_artwork_layer.queue_redraw()


func _profile_points() -> Array[Vector2]:
	# Short neck, relaxed shoulder, broad body and a full curved glass foot.
	return [
		Vector2(0.000, 0.190),
		Vector2(0.035, 0.192),
		Vector2(0.075, 0.200),
		Vector2(0.110, 0.225),
		Vector2(0.145, 0.285),
		Vector2(0.190, 0.360),
		Vector2(0.245, 0.435),
		Vector2(0.295, 0.470),
		Vector2(0.345, 0.480),
		Vector2(0.735, 0.480),
		Vector2(0.815, 0.475),
		Vector2(0.875, 0.455),
		Vector2(0.920, 0.425),
		Vector2(0.955, 0.385),
		Vector2(0.980, 0.335),
		Vector2(1.000, 0.280)
	]


func _get_profile_at(y_norm: float) -> Vector2:
	var profile := _profile_points()
	var y: float = clampf(y_norm, 0.0, 1.0)
	for index in range(profile.size() - 1):
		var first: Vector2 = profile[index]
		var second: Vector2 = profile[index + 1]
		if y <= second.x:
			var span: float = maxf(0.0001, second.x - first.x)
			return Vector2(
				y,
				lerpf(
					first.y,
					second.y,
					clampf((y - first.x) / span, 0.0, 1.0)
				)
			)
	return profile.back()


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

	# Profile samples are generated at nearly uniform vertical intervals.
	# Estimate the lower sample directly, then correct the bracket against the
	# actual profile values. This preserves the exact interpolation segment
	# while avoiding a binary search for every point in every animated band.
	var profile_span: float = maxf(0.000001, last.x - first.x)
	var normalized_position: float = clampf(
		(y_ratio - first.x) / profile_span,
		0.0,
		1.0
	)
	var low_index: int = clampi(
		floori(normalized_position * float(profile_count - 1)),
		0,
		profile_count - 2
	)
	if _window_profile[low_index].x > y_ratio:
		while low_index > 0 and _window_profile[low_index].x > y_ratio:
			low_index -= 1
	else:
		while (
			low_index < profile_count - 2
			and _window_profile[low_index + 1].x <= y_ratio
		):
			low_index += 1

	first = _window_profile[low_index]
	last = _window_profile[low_index + 1]
	var span: float = maxf(0.000001, last.x - first.x)
	var weight: float = clampf((y_ratio - first.x) / span, 0.0, 1.0)
	return Vector2(
		lerpf(first.y, last.y, weight),
		lerpf(first.z, last.z, weight)
	)


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
	if _liquid_geometry_dirty or rect != _cached_liquid_rect:
		_rebuild_cached_liquid_geometry(rect)
	if _cached_liquid_bands.is_empty():
		return

	var visible_layers: int = mini(int(ceil(_liquid_level)), _visual_contents.size())
	for band in _cached_liquid_bands:
		var polygon: PackedVector2Array = band["polygon"]
		var vertex_colors: PackedColorArray = band["vertex_colors"]
		draw_polygon(polygon, vertex_colors)
		if bool(band["is_surface"]):
			_draw_cached_liquid_surface(band)

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


func _rebuild_cached_liquid_geometry(rect: Rect2) -> void:
	_cached_liquid_bands.clear()
	_cached_liquid_rect = rect
	_liquid_geometry_dirty = false

	if _window_profile.size() < 8 or _visual_contents.is_empty() or _liquid_level <= 0.001:
		return

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
		liquid_color.a *= smoothstep(0.0, LIQUID_APPEARANCE_FADE_LEVEL, amount)

		var band: Dictionary = _build_cached_liquid_band(
			rect,
			top_ratio,
			bottom_ratio,
			liquid_color,
			layer_index == visible_layers - 1,
			layer_index == 0
		)
		if not band.is_empty():
			_cached_liquid_bands.append(band)


func _build_cached_liquid_band(
	rect: Rect2,
	top_ratio: float,
	bottom_ratio: float,
	liquid_color: Color,
	is_surface: bool,
	is_bottom: bool
) -> Dictionary:
	var bottom_y: float = rect.position.y + rect.size.y * bottom_ratio
	if not is_bottom:
		bottom_y += 0.8
	var top_y: float = rect.position.y + rect.size.y * top_ratio
	var band_height: float = bottom_y - top_y
	if band_height <= LIQUID_MIN_BAND_HEIGHT:
		return {}

	var band_alpha: float = smoothstep(
		LIQUID_MIN_BAND_HEIGHT,
		LIQUID_BAND_FADE_HEIGHT,
		band_height
	)

	# The top edge is horizontal, so resolve its chamber bounds once.
	var body_ratio: float = clampf(
		(top_y - rect.position.y) / rect.size.y,
		_window_top_ratio,
		_window_bottom_ratio
	)
	var body_bounds := _window_bounds_at(body_ratio)
	var body_left_x: float = rect.position.x + rect.size.x * body_bounds.x + LIQUID_WALL_INSET
	var body_right_x: float = rect.position.x + rect.size.x * body_bounds.y - LIQUID_WALL_INSET
	var body_top_edge := PackedVector2Array()
	for sample_index in range(LIQUID_SURFACE_SAMPLES + 1):
		var t: float = float(sample_index) / float(LIQUID_SURFACE_SAMPLES)
		body_top_edge.append(Vector2(lerpf(body_left_x, body_right_x, t), top_y))

	if body_top_edge.size() < 2:
		return {}

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

	# Cache the colour field for a shallow elliptical free surface.
	# Its geometry can then move every frame without rebuilding its palette.
	var surface_colours := PackedColorArray()
	if is_surface:
		for sample_index in range(LIQUID_SURFACE_SAMPLES):
			var angle: float = TAU * float(sample_index) / float(LIQUID_SURFACE_SAMPLES)
			var front_weight: float = 0.5 + 0.5 * sin(angle)
			var surface_color: Color = edge_color.lerp(center_color, front_weight)
			surface_colours.append(surface_color)

	return {
		"polygon": polygon,
		"vertex_colors": vertex_colors,
		"body_top_edge": body_top_edge,
		"surface_colours": surface_colours,
		"fill_color": fill_color,
		"liquid_alpha": liquid_color.a,
		"surface_depth": clampf(rect.size.y * 0.026, 4.0, 8.0),
		"is_surface": is_surface,
		"top_y": top_y
	}


func _draw_cached_liquid_surface(band: Dictionary) -> void:
	var body_top_edge: PackedVector2Array = band["body_top_edge"]
	if body_top_edge.size() < 2:
		return

	var left_x: float = body_top_edge[0].x
	var right_x: float = body_top_edge[body_top_edge.size() - 1].x
	var centre_x: float = (left_x + right_x) * 0.5
	var radius_x: float = maxf(0.0, (right_x - left_x) * 0.5 - 1.5)
	var radius_y: float = float(band["surface_depth"])
	var top_y: float = float(band["top_y"])
	if radius_x <= 4.0:
		return

	# The cached working body remains profile-conforming. This independent
	# surface pass adds the shallow oval plane, with only its wave points moving.
	var surface_polygon := PackedVector2Array()
	for sample_index in range(LIQUID_SURFACE_SAMPLES):
		var angle: float = TAU * float(sample_index) / float(LIQUID_SURFACE_SAMPLES)
		var normalized_x: float = cos(angle)
		var wave: float = _get_surface_wave_offset(normalized_x) * 0.24
		surface_polygon.append(Vector2(
			centre_x + normalized_x * radius_x,
			top_y + sin(angle) * radius_y + wave
		))

	var surface_colours: PackedColorArray = band["surface_colours"]
	draw_polygon(surface_polygon, surface_colours)

	# The rear meniscus is darker; the near edge catches a delicate highlight.
	var rear_edge := PackedVector2Array()
	var front_edge := PackedVector2Array()
	for sample_index in range(LIQUID_SURFACE_SAMPLES / 2 + 1):
		var t: float = float(sample_index) / float(LIQUID_SURFACE_SAMPLES / 2)
		var rear_angle: float = PI + PI * t
		var front_angle: float = PI * t
		rear_edge.append(Vector2(
			centre_x + cos(rear_angle) * radius_x,
			top_y + sin(rear_angle) * radius_y
		))
		front_edge.append(Vector2(
			centre_x + cos(front_angle) * radius_x,
			top_y + sin(front_angle) * radius_y
		))

	var liquid_color: Color = band["fill_color"]
	var liquid_alpha: float = float(band["liquid_alpha"])
	var rear_color: Color = liquid_color.darkened(0.30)
	rear_color.a = 0.42 * liquid_alpha
	draw_polyline(rear_edge, rear_color, 1.1, true)
	draw_polyline(
		front_edge,
		Color(0.96, 1.0, 0.94, 0.24 * liquid_alpha),
		1.2,
		true
	)


func _get_cached_bubble_sprite(
	base_color: Color,
	core_color: Color,
	core_radius_ratio: float,
	halo_alpha: float,
	core_alpha: float,
	include_glint: bool
) -> Texture2D:
	var cache_key: String = "%s|%s|%.4f|%.4f|%.4f|%s" % [
		base_color.to_html(true),
		core_color.to_html(true),
		core_radius_ratio,
		halo_alpha,
		core_alpha,
		str(include_glint)
	]
	if _bubble_sprite_cache.has(cache_key):
		return _bubble_sprite_cache[cache_key] as Texture2D

	const TEXTURE_SIZE := 48
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var outer_radius: float = float(TEXTURE_SIZE) * 0.5 - 1.0
	var core_radius: float = outer_radius * core_radius_ratio
	var glint_centre := Vector2(-0.30 / 2.35, -0.34 / 2.35) * outer_radius
	var glint_radius: float = outer_radius * (0.22 / 2.35)

	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var local := Vector2(
				float(x) + 0.5 - float(TEXTURE_SIZE) * 0.5,
				float(y) + 0.5 - float(TEXTURE_SIZE) * 0.5
			)
			var distance: float = local.length()
			var outer_coverage: float = clampf(outer_radius - distance + 0.5, 0.0, 1.0)
			if outer_coverage <= 0.0:
				continue

			var alpha: float = halo_alpha * outer_coverage
			var pixel_color: Color = base_color
			var core_coverage: float = clampf(core_radius - distance + 0.5, 0.0, 1.0)
			var effective_core_alpha: float = core_alpha * core_coverage
			if effective_core_alpha > 0.0:
				var combined_alpha: float = effective_core_alpha + alpha * (1.0 - effective_core_alpha)
				pixel_color = (
					core_color * effective_core_alpha
					+ base_color * (alpha * (1.0 - effective_core_alpha))
				) / maxf(0.0001, combined_alpha)
				alpha = combined_alpha

			if include_glint:
				var glint_coverage: float = clampf(
					glint_radius - local.distance_to(glint_centre) + 0.5,
					0.0,
					1.0
				)
				var glint_alpha: float = 0.95 * glint_coverage
				if glint_alpha > 0.0:
					var combined_alpha: float = glint_alpha + alpha * (1.0 - glint_alpha)
					pixel_color = (
						Color.WHITE * glint_alpha
						+ pixel_color * (alpha * (1.0 - glint_alpha))
					) / maxf(0.0001, combined_alpha)
					alpha = combined_alpha

			image.set_pixel(
				x,
				y,
				Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha)
			)

	var texture := ImageTexture.create_from_image(image)
	_bubble_sprite_cache[cache_key] = texture
	return texture


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

	# Four reusable sprites retain the layered bubble look without issuing
	# three separately tessellated circles for every moving bubble.
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
		var core_color: Color = bubble_color.lightened(0.56)
		var bubble_texture := _get_cached_bubble_sprite(
			bubble_color,
			core_color,
			1.0 / 2.35,
			0.34,
			0.52,
			true
		)
		var bubble_diameter: float = bubble_size * 4.70
		draw_texture_rect(
			bubble_texture,
			Rect2(bubble_position - Vector2.ONE * (bubble_diameter * 0.5), Vector2.ONE * bubble_diameter),
			false,
			Color(1.0, 1.0, 1.0, bubble_alpha)
		)

	# Tiny motes use the same one-draw approach, with a tighter bright centre.
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
		var mote_texture := _get_cached_bubble_sprite(
			mote_color,
			Color(0.95, 1.0, 0.92, 1.0),
			0.75 / 2.2,
			0.24,
			0.72,
			false
		)
		var mote_diameter := 4.4
		draw_texture_rect(
			mote_texture,
			Rect2(mote_position - Vector2.ONE * (mote_diameter * 0.5), Vector2.ONE * mote_diameter),
			false,
			Color(1.0, 1.0, 1.0, mote_alpha)
		)


func _draw_glass_back(_rect: Rect2) -> void:
	# The complete SVG illustration is drawn once, above the live liquid.
	pass


func _draw_glass_overlay() -> void:
	# The complete new-vial artwork is drawn by its retained child CanvasItem.
	# This parent redraw now contains only liquid and interaction effects.
	pass
