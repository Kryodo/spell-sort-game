extends "res://scripts/test_tube_renderer_base_fantasy_bottle.gd"

## One complete illustration per vial. A hand-authored inner chamber profile
## drives the cached liquid body, curved interfaces and gravity response.

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
const LIQUID_BOUNDARY_SAMPLES := 96
const LIQUID_CHAMBER_SIDE_SAMPLES := 112
const LIQUID_FLOOR_SAMPLES := 32
const LIQUID_FLOOR_DEPTH_RATIO := 0.021
const LIQUID_INTERFACE_CURVE_DEPTH := 1.8
const POUR_CHANNEL_SHOULDER_START := 0.56
const POUR_WALL_CLEARANCE_BASE := 0.85
const POUR_WALL_CLEARANCE_STEP := 0.75
const LIQUID_GRAVITY_SOLVE_STEPS := 12
const LIQUID_TILT_CACHE_EPSILON := 0.004
const LIQUID_SURFACE_EXTENT_SAMPLES := 96

# The SVG is the sole source of glass highlights. This experiment draws no
# inherited glass-reflection strokes over the new artwork.

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
var _cached_chamber_polygon := PackedVector2Array()
var _cached_pour_wall_profile := PackedVector2Array()
var _cached_liquid_floor_depth: float = 0.0
var _cached_liquid_tilt: float = 999.0
var _pour_outflow_active: bool = false
var _pour_outflow_color: Color = Color.WHITE
var _pour_visual_weight: float = 0.0


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


func get_pouring_visual_weight() -> float:
	return _pour_visual_weight


func set_pouring_visual_weight(weight: float) -> void:
	var next_weight: float = clampf(weight, 0.0, 1.0)
	if absf(next_weight - _pour_visual_weight) <= 0.001:
		return
	_pour_visual_weight = next_weight
	_invalidate_liquid_geometry()


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
	_cached_chamber_polygon = PackedVector2Array()
	_cached_pour_wall_profile = PackedVector2Array()

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
	# Bridge only narrow opaque interruptions inside the source artwork.
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


func set_pour_outflow_active(active: bool, color: Color = Color.WHITE) -> void:
	_pour_outflow_active = active
	_pour_outflow_color = color
	queue_redraw()


func _get_pour_outlet_local(rect: Rect2) -> Vector2:
	var mouth_bounds: Vector2 = _window_bounds_at(_mouth_y_ratio)
	var mouth_half_width: float = (
		rect.size.x * (mouth_bounds.y - mouth_bounds.x) * 0.5
	)
	# Gravity selects the lower lip of the tilted opening: right when tilted
	# clockwise, left when tilted counter-clockwise.
	var lower_side: float = 1.0 if sin(_tilt) >= 0.0 else -1.0
	return Vector2(
		rect.get_center().x + lower_side * mouth_half_width * 0.78,
		rect.position.y + rect.size.y * _mouth_y_ratio + 1.0
	)


func get_pour_outlet_position_in_parent() -> Vector2:
	var rect := _get_vessel_rect()
	var frame: Dictionary = _get_liquid_gravity_frame(rect, _tilt)
	var normal: Vector2 = frame["normal"]
	var outlet_local: Vector2 = _get_pour_outlet_local(rect) + normal * 2.1
	return position + get_point_local_for_pose(
		outlet_local,
		Vector2(_lift, _tilt),
		_draw_scale
	)


func get_liquid_surface_position_in_parent() -> Vector2:
	var rect := _get_vessel_rect()
	if (
		_liquid_geometry_dirty
		or rect != _cached_liquid_rect
		or absf(_tilt - _cached_liquid_tilt) > LIQUID_TILT_CACHE_EPSILON
	):
		_rebuild_cached_liquid_geometry(rect)
	if _cached_liquid_bands.is_empty():
		return position + get_point_local_for_pose(
			Vector2(rect.get_center().x, rect.position.y + rect.size.y * _window_bottom_ratio),
			Vector2(_lift, _tilt),
			_draw_scale
		)

	var top_band: Dictionary = _cached_liquid_bands.back()
	var surface_center: Vector2 = top_band["surface_center"]
	var surface_normal: Vector2 = top_band["surface_normal"]
	surface_center += surface_normal * _get_liquid_surface_wave(0.0) * 0.16
	return position + get_point_local_for_pose(
		surface_center,
		Vector2(_lift, _tilt),
		_draw_scale
	)


func _draw_liquid(_rect: Rect2) -> void:
	if _window_profile.size() < 8 or _visual_contents.is_empty() or _liquid_level <= 0.001:
		return

	var rect := _get_vessel_rect()
	if (
		_liquid_geometry_dirty
		or rect != _cached_liquid_rect
		or absf(_tilt - _cached_liquid_tilt) > LIQUID_TILT_CACHE_EPSILON
	):
		_rebuild_cached_liquid_geometry(rect)
	if _cached_liquid_bands.is_empty():
		return

	var visible_layers: int = mini(int(ceil(_liquid_level)), _visual_contents.size())
	var surface_band: Dictionary = {}
	for band in _cached_liquid_bands:
		var polygon: PackedVector2Array = band["polygon"]
		var vertex_colors: PackedColorArray = band["vertex_colors"]
		# Both states use the complete chamber. Pouring changes shared
		# interface geometry, not the chamber mask or the stream artwork.
		_draw_triangulated_liquid_polygon(polygon, vertex_colors)
		if bool(band["is_surface"]):
			surface_band = band

	if not surface_band.is_empty():
		_draw_cached_liquid_surface(surface_band)

	_draw_pour_outflow(rect)
	_draw_window_bubbles(rect, visible_layers)
	_draw_surface_bubble_activity(rect)


func _draw_pour_outflow(rect: Rect2) -> void:
	if (
		not _pour_outflow_active
		or absf(_tilt) < 0.55
		or _cached_liquid_bands.is_empty()
		or _cached_chamber_polygon.is_empty()
	):
		return

	var top_band_index: int = _cached_liquid_bands.size() - 1
	var top_band: Dictionary = _cached_liquid_bands[top_band_index]
	var centre: Vector2 = top_band["surface_center"]
	var tangent: Vector2 = top_band["surface_tangent"]
	var normal: Vector2 = top_band["surface_normal"]
	var surface_offset: float = float(top_band["surface_boundary_offset"])
	var curve_depth: float = float(top_band["surface_curve_depth"])
	var gravity_frame: Dictionary = _get_liquid_gravity_frame(rect, _tilt)
	var tangent_span: float = float(gravity_frame["tangent_span"])
	var outlet: Vector2 = _get_pour_outlet_local(rect)

	var outlet_distance: float = (outlet - rect.get_center()).dot(tangent)
	var surface_radius: float = float(top_band["surface_radius_x"])
	var surface_mid_distance: float = (centre - rect.get_center()).dot(tangent)
	outlet_distance = clampf(
		outlet_distance,
		surface_mid_distance - surface_radius * 0.96,
		surface_mid_distance + surface_radius * 0.96
	)
	var normalized_distance: float = outlet_distance / maxf(1.0, tangent_span)
	var interface_curve: float = curve_depth * maxf(
		0.0,
		1.0 - normalized_distance * normalized_distance
	)
	var surface_wave: float = _get_liquid_surface_wave(normalized_distance) * 0.16
	var surface_point: Vector2 = (
		rect.get_center()
		+ tangent * outlet_distance
		+ normal * (surface_offset + interface_curve + surface_wave)
	)

	var flow_delta: Vector2 = outlet - surface_point
	if flow_delta.length() < 1.4:
		return

	var flow_direction: Vector2 = flow_delta.normalized()
	var flow_side := Vector2(-flow_direction.y, flow_direction.x)
	var centreline := PackedVector2Array()
	var left_edge := PackedVector2Array()
	var right_edge := PackedVector2Array()
	const FLOW_SAMPLES := 24

	for sample_index in range(FLOW_SAMPLES):
		var t: float = float(sample_index) / float(FLOW_SAMPLES - 1)
		var eased_t: float = smoothstep(0.0, 1.0, t)
		var lateral_motion: float = (
			sin(PI * t) * (0.55 + _surface_activity * 0.55)
			+ sin(_wave_time * 2.2 + t * 5.4) * sin(PI * t) * 0.28
		)
		var point: Vector2 = (
			surface_point.lerp(outlet, eased_t)
			+ flow_side * lateral_motion
		)
		centreline.append(point)
		var half_width: float = lerpf(1.7, 2.4, t)
		left_edge.append(point + flow_side * half_width)
		right_edge.append(point - flow_side * half_width)

	var flow_polygon := PackedVector2Array()
	for point in left_edge:
		flow_polygon.append(point)
	for index in range(right_edge.size() - 1, -1, -1):
		flow_polygon.append(right_edge[index])

	# The connector can occupy the top essence and the empty neck above it,
	# but it must never be painted across any lower essence layer.
	var clipped_flow: Array = _clip_pour_shape_to_top_essence(
		flow_polygon,
		top_band_index
	)
	var flow_color: Color = _pour_outflow_color.lerp(
		_pour_outflow_color.lightened(0.15),
		0.12
	)
	for flow_piece in clipped_flow:
		var piece: PackedVector2Array = _sanitize_liquid_polygon(flow_piece)
		_draw_triangulated_solid_liquid_polygon(piece, flow_color)

	# Keep the internal glint inside the exact same unobstructed corridor.
	var glint_left := PackedVector2Array()
	var glint_right := PackedVector2Array()
	for sample_index in range(3, FLOW_SAMPLES - 3):
		var glint_point: Vector2 = centreline[sample_index] + normal * 0.85
		glint_left.append(glint_point + flow_side * 0.48)
		glint_right.append(glint_point - flow_side * 0.48)
	var glint_polygon := PackedVector2Array()
	for point in glint_left:
		glint_polygon.append(point)
	for index in range(glint_right.size() - 1, -1, -1):
		glint_polygon.append(glint_right[index])
	var clipped_glint: Array = _clip_pour_shape_to_top_essence(
		glint_polygon,
		top_band_index
	)
	for glint_piece in clipped_glint:
		var piece: PackedVector2Array = _sanitize_liquid_polygon(glint_piece)
		_draw_triangulated_solid_liquid_polygon(piece, Color(1.0, 1.0, 1.0, 0.13))


func _clip_pour_shape_to_top_essence(
	pour_polygon: PackedVector2Array,
	top_band_index: int
) -> Array:
	# First keep the ribbon inside the bottle, including the narrow neck.
	var remaining_pieces: Array = Geometry2D.intersect_polygons(
		pour_polygon,
		_cached_chamber_polygon
	)
	if remaining_pieces.is_empty():
		return remaining_pieces

	# The active essence is one continuous partition band. Subtract only
	# lower colour regions; the top colour keeps its widened outlet corridor.
	var first_top_essence_piece: int = top_band_index
	while first_top_essence_piece > 0:
		var previous_band: Dictionary = _cached_liquid_bands[first_top_essence_piece - 1]
		if bool(previous_band["is_top_essence"]):
			first_top_essence_piece -= 1
		else:
			break

	for lower_index in range(first_top_essence_piece):
		var lower_band: Dictionary = _cached_liquid_bands[lower_index]
		var lower_polygon: PackedVector2Array = lower_band["polygon"]
		var unobstructed_pieces: Array = []
		for current_piece_value in remaining_pieces:
			var current_piece: PackedVector2Array = current_piece_value
			var outside_lower_band: Array = Geometry2D.clip_polygons(
				current_piece,
				lower_polygon
			)
			for outside_piece_value in outside_lower_band:
				var outside_piece: PackedVector2Array = outside_piece_value
				if outside_piece.size() >= 3:
					unobstructed_pieces.append(outside_piece)
		remaining_pieces = unobstructed_pieces
		if remaining_pieces.is_empty():
			break

	return remaining_pieces

func _draw_surface_bubble_activity(rect: Rect2) -> void:
	if _liquid_level <= 0.02 or _visual_contents.is_empty() or _cached_liquid_bands.is_empty():
		return

	const EVENT_PERIOD := 8.4
	const EVENT_DURATION := 1.15
	const EVENT_COUNT := 2
	var top_band: Dictionary = _cached_liquid_bands.back()
	var surface_center: Vector2 = top_band["surface_center"]
	var surface_tangent: Vector2 = top_band["surface_tangent"]
	var surface_normal: Vector2 = top_band["surface_normal"]
	var surface_half_width: float = float(top_band["surface_radius_x"])
	if surface_half_width <= 4.0:
		return

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
		var surface_wave: float = _get_liquid_surface_wave(x_norm) * wave_strength
		var centre := (
			surface_center
			+ surface_tangent * (x_norm * surface_half_width)
			+ surface_normal * surface_wave
		)

		if progress < 0.52:
			var swell: float = smoothstep(0.0, 0.46, progress)
			var bubble_radius: float = lerpf(0.95, 2.75, swell)
			var bubble_fade: float = 1.0 - smoothstep(0.34, 0.52, progress)
			var bubble_centre: Vector2 = centre - surface_normal * bubble_radius * 0.20
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
				bubble_centre - surface_normal * 0.25,
				bubble_radius * 0.74,
				PI * 1.12,
				PI * 1.88,
				10,
				Color(0.96, 1.0, 0.96, 0.70 * bubble_fade),
				0.9,
				true
			)
		else:
			var pop_progress: float = (progress - 0.52) / 0.48
			var ripple_radius: float = lerpf(2.5, 8.5, pop_progress)
			var ripple_alpha: float = 0.30 * (1.0 - smoothstep(0.25, 1.0, pop_progress))
			var ripple_points := PackedVector2Array()
			const RIPPLE_SEGMENTS := 20
			for point_index in range(RIPPLE_SEGMENTS + 1):
				var angle: float = TAU * float(point_index) / float(RIPPLE_SEGMENTS)
				ripple_points.append(
					centre
					+ surface_tangent * (cos(angle) * ripple_radius)
					+ surface_normal * (sin(angle) * ripple_radius * 0.28)
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
	var rect_changed: bool = rect != _cached_liquid_rect
	_cached_liquid_bands.clear()
	_cached_liquid_tilt = _tilt
	_liquid_geometry_dirty = false

	if _window_profile.size() < 8 or _visual_contents.is_empty() or _liquid_level <= 0.001:
		_cached_liquid_rect = rect
		return

	if rect_changed or _cached_chamber_polygon.is_empty():
		_cached_chamber_polygon = _build_liquid_chamber_polygon(rect)
	if _cached_chamber_polygon.size() < 8:
		_cached_liquid_rect = rect
		return

	_cached_liquid_rect = rect
	var gravity_frame: Dictionary = _get_liquid_gravity_frame(rect, _tilt)
	_cached_pour_wall_profile.clear()
	if _pour_visual_weight > 0.001 and absf(_tilt) >= deg_to_rad(30.0):
		_cached_pour_wall_profile = _build_pour_wall_profile(rect, gravity_frame)
	var boundary_offsets: Dictionary = {}
	var visible_layers: int = mini(int(ceil(_liquid_level)), _visual_contents.size())
	var layer_index: int = 0

	# Every unique adjacent essence is a band in one shared partition.
	# Each interface is reused by both neighbouring colours.
	while layer_index < visible_layers:
		var group_start: int = layer_index
		var essence: String = String(_visual_contents[group_start])
		var liquid_color: Color = _palette.get(
			essence,
			Color(0.45, 0.78, 0.75, 1.0)
		)
		var group_end: int = group_start + 1
		while group_end < visible_layers:
			var next_essence: String = String(_visual_contents[group_end])
			var next_color: Color = _palette.get(
				next_essence,
				Color(0.45, 0.78, 0.75, 1.0)
			)
			if not _same_liquid_colour(liquid_color, next_color):
				break
			group_end += 1

		var bottom_units: float = float(group_start)
		var top_units: float = minf(float(group_end), _liquid_level)
		var visible_amount: float = top_units - bottom_units
		if visible_amount > 0.001:
			var appearance_color: Color = liquid_color
			appearance_color.a *= smoothstep(
				0.0,
				LIQUID_APPEARANCE_FADE_LEVEL,
				visible_amount
			)
			var is_top_group: bool = group_end >= visible_layers
			var bands: Array[Dictionary] = _build_cached_liquid_band(
				rect,
				_cached_chamber_polygon,
				_cached_chamber_polygon,
				gravity_frame,
				boundary_offsets,
				boundary_offsets,
				bottom_units,
				top_units,
				appearance_color,
				is_top_group
			)
			if not bands.is_empty():
				_cached_liquid_bands.append_array(bands)

		layer_index = group_end


func _same_liquid_colour(first: Color, second: Color) -> bool:
	return (
		absf(first.r - second.r) <= 0.002
		and absf(first.g - second.g) <= 0.002
		and absf(first.b - second.b) <= 0.002
		and absf(first.a - second.a) <= 0.002
	)


func _build_liquid_chamber_polygon(
	rect: Rect2,
	top_ratio: float = BOTTLE_BODY_TOP_RATIO
) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var left_wall := PackedVector2Array()
	var right_wall := PackedVector2Array()
	# One continuous chamber follows the actual inner glass from mouth to base.
	# The coordinated layer partition, not a neck mask, controls colour placement.
	var top_y: float = rect.position.y + rect.size.y * top_ratio
	var bottom_y: float = rect.position.y + rect.size.y * _window_bottom_ratio
	_cached_liquid_floor_depth = clampf(
		rect.size.y * LIQUID_FLOOR_DEPTH_RATIO,
		5.0,
		9.5
	)

	for sample_index in range(LIQUID_CHAMBER_SIDE_SAMPLES + 1):
		var t: float = float(sample_index) / float(LIQUID_CHAMBER_SIDE_SAMPLES)
		var y: float = lerpf(top_y, bottom_y, t)
		var y_ratio: float = clampf(
			(y - rect.position.y) / rect.size.y,
			top_ratio,
			_window_bottom_ratio
		)
		var bounds: Vector2 = _window_bounds_at(y_ratio)
		var bottom_blend: float = smoothstep(0.70, 1.0, t)
		var left_x: float = (
			rect.position.x
			+ rect.size.x * bounds.x
			+ LIQUID_WALL_INSET
			- LIQUID_BOTTOM_WALL_OVERDRAW * bottom_blend
		)
		var right_x: float = (
			rect.position.x
			+ rect.size.x * bounds.y
			- LIQUID_WALL_INSET
			+ LIQUID_BOTTOM_WALL_OVERDRAW * bottom_blend
		)
		left_wall.append(Vector2(left_x, y))
		right_wall.append(Vector2(right_x, y))

	for point in left_wall:
		polygon.append(point)

	var floor_left_x: float = left_wall[left_wall.size() - 1].x
	var floor_right_x: float = right_wall[right_wall.size() - 1].x
	for sample_index in range(1, LIQUID_FLOOR_SAMPLES + 1):
		var t: float = float(sample_index) / float(LIQUID_FLOOR_SAMPLES)
		var floor_y: float = bottom_y + sin(PI * t) * _cached_liquid_floor_depth
		polygon.append(Vector2(
			lerpf(floor_left_x, floor_right_x, t),
			floor_y
		))

	for sample_index in range(LIQUID_CHAMBER_SIDE_SAMPLES - 1, -1, -1):
		polygon.append(right_wall[sample_index])

	return polygon


func _get_pour_boundary_sample_distance(
	rect: Rect2,
	frame: Dictionary,
	sample_index: int
) -> float:
	var tangent_span: float = float(frame["tangent_span"])
	var margin: float = maxf(rect.size.length() * 2.5, 120.0)
	var extended_span: float = tangent_span + margin
	return lerpf(
		-extended_span,
		extended_span,
		float(sample_index) / float(LIQUID_BOUNDARY_SAMPLES)
	)


func _build_pour_wall_profile(
	rect: Rect2,
	frame: Dictionary
) -> PackedVector2Array:
	var profile := PackedVector2Array()
	for sample_index in range(LIQUID_BOUNDARY_SAMPLES + 1):
		var tangent_distance: float = _get_pour_boundary_sample_distance(
			rect,
			frame,
			sample_index
		)
		var wall_offset: float = _get_lower_inner_wall_normal_offset(
			frame,
			tangent_distance
		)
		profile.append(Vector2(tangent_distance, wall_offset))

	return profile


func _get_lower_inner_wall_normal_offset(
	frame: Dictionary,
	tangent_distance: float
) -> float:
	var centre: Vector2 = frame["centre"]
	var tangent: Vector2 = frame["tangent"]
	var normal: Vector2 = frame["normal"]
	var greatest_normal_offset: float = -1.0e20

	for edge_index in range(_cached_chamber_polygon.size()):
		var first: Vector2 = _cached_chamber_polygon[edge_index]
		var second: Vector2 = _cached_chamber_polygon[
			(edge_index + 1) % _cached_chamber_polygon.size()
		]
		var first_tangent: float = (first - centre).dot(tangent)
		var second_tangent: float = (second - centre).dot(tangent)
		var first_normal: float = (first - centre).dot(normal)
		var second_normal: float = (second - centre).dot(normal)

		var tangent_delta: float = second_tangent - first_tangent
		if absf(tangent_delta) <= 0.0001:
			if absf(tangent_distance - first_tangent) <= 0.75:
				greatest_normal_offset = maxf(
					greatest_normal_offset,
					maxf(first_normal, second_normal)
				)
			continue

		var edge_min: float = minf(first_tangent, second_tangent)
		var edge_max: float = maxf(first_tangent, second_tangent)
		if tangent_distance < edge_min - 0.001 or tangent_distance > edge_max + 0.001:
			continue

		var edge_weight: float = clampf(
			(tangent_distance - first_tangent) / tangent_delta,
			0.0,
			1.0
		)
		var wall_point: Vector2 = first.lerp(second, edge_weight)
		greatest_normal_offset = maxf(
			greatest_normal_offset,
			(wall_point - centre).dot(normal)
		)

	return greatest_normal_offset


func _get_pouring_taper_progress(
	rect: Rect2,
	frame: Dictionary,
	tangent_distance: float
) -> float:
	var mouth_direction: float = 1.0 if sin(_tilt) >= 0.0 else -1.0
	var centre: Vector2 = frame["centre"]
	var tangent: Vector2 = frame["tangent"]
	var tangent_span: float = float(frame["tangent_span"])
	var mouth_center := Vector2(
		rect.get_center().x,
		rect.position.y + rect.size.y * _mouth_y_ratio
	)
	var mouth_distance: float = (
		(mouth_center - centre).dot(tangent) * mouth_direction
	)
	var shoulder_distance: float = tangent_span * POUR_CHANNEL_SHOULDER_START
	var mouth_end_distance: float = maxf(
		shoulder_distance + 8.0,
		mouth_distance
	)
	var current_distance: float = tangent_distance * mouth_direction
	return smoothstep(
		shoulder_distance,
		mouth_end_distance,
		current_distance
	)


func _get_liquid_gravity_frame(rect: Rect2, angle: float) -> Dictionary:
	var tangent := Vector2(cos(angle), -sin(angle))
	var normal := Vector2(sin(angle), cos(angle))
	var tangent_span: float = (
		absf(tangent.x) * rect.size.x * 0.5
		+ absf(tangent.y) * rect.size.y * 0.5
		+ 8.0
	)
	return {
		"centre": rect.get_center(),
		"tangent": tangent,
		"normal": normal,
		"tangent_span": tangent_span
	}


func _build_gravity_half_plane(
	rect: Rect2,
	frame: Dictionary,
	offset: float,
	keep_below: bool,
	curve_depth: float,
	pour_channel_weight: float = 0.0,
	pour_wall_clearance: float = 0.0
) -> PackedVector2Array:
	var centre: Vector2 = frame["centre"]
	var tangent: Vector2 = frame["tangent"]
	var normal: Vector2 = frame["normal"]
	var tangent_span: float = float(frame["tangent_span"])
	var margin: float = maxf(rect.size.length() * 2.5, 120.0)
	var boundary := PackedVector2Array()

	for sample_index in range(LIQUID_BOUNDARY_SAMPLES + 1):
		var tangent_distance: float = _get_pour_boundary_sample_distance(
			rect,
			frame,
			sample_index
		)
		var u: float = tangent_distance / tangent_span
		var curve: float = curve_depth * maxf(0.0, 1.0 - u * u)
		var normal_offset: float = offset + curve

		if (
			pour_channel_weight > 0.001
			and pour_wall_clearance > 0.0
			and _cached_pour_wall_profile.size() == LIQUID_BOUNDARY_SAMPLES + 1
		):
			var wall_offset: float = _cached_pour_wall_profile[sample_index].y
			if wall_offset > -1.0e19:
				var taper_progress: float = _get_pouring_taper_progress(
					rect,
					frame,
					tangent_distance
				)
				# Remain just inside the inner wall to avoid coincident polygon
				# edges; lower colour opacity handles the final disappearance.
				var target_wall_offset: float = wall_offset - pour_wall_clearance
				normal_offset = lerpf(
					normal_offset,
					target_wall_offset,
					taper_progress * pour_channel_weight
				)

		boundary.append(
			centre
			+ tangent * tangent_distance
			+ normal * normal_offset
		)

	var half_plane := PackedVector2Array()
	if keep_below:
		for point in boundary:
			half_plane.append(point)
		half_plane.append(boundary[boundary.size() - 1] + normal * margin * 2.0)
		half_plane.append(boundary[0] + normal * margin * 2.0)
	else:
		for index in range(boundary.size() - 1, -1, -1):
			half_plane.append(boundary[index])
		half_plane.append(boundary[0] - normal * margin * 2.0)
		half_plane.append(boundary[boundary.size() - 1] - normal * margin * 2.0)

	return half_plane


func _polygon_area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0
	var twice_area: float = 0.0
	for index in range(polygon.size()):
		var first: Vector2 = polygon[index]
		var second: Vector2 = polygon[(index + 1) % polygon.size()]
		twice_area += first.x * second.y - second.x * first.y
	return absf(twice_area) * 0.5


func _polygons_area(polygons: Array) -> float:
	var total_area: float = 0.0
	for item in polygons:
		var polygon: PackedVector2Array = item
		total_area += _polygon_area(polygon)
	return total_area


func _sanitize_liquid_polygon(source_polygon: PackedVector2Array) -> PackedVector2Array:
	var cleaned := PackedVector2Array()
	const DUPLICATE_DISTANCE_SQUARED := 0.0004

	for point in source_polygon:
		if (
			cleaned.is_empty()
			or point.distance_squared_to(cleaned[cleaned.size() - 1])
				> DUPLICATE_DISTANCE_SQUARED
		):
			cleaned.append(point)

	if (
		cleaned.size() > 2
		and cleaned[0].distance_squared_to(cleaned[cleaned.size() - 1])
			<= DUPLICATE_DISTANCE_SQUARED
	):
		cleaned.remove_at(cleaned.size() - 1)

	# Remove zero-length and forward-collinear edges left by polygon clipping.
	var changed: bool = true
	var remaining_passes: int = cleaned.size() * 2
	while changed and cleaned.size() >= 3 and remaining_passes > 0:
		changed = false
		remaining_passes -= 1
		for index in range(cleaned.size()):
			var previous: Vector2 = cleaned[(index - 1 + cleaned.size()) % cleaned.size()]
			var current: Vector2 = cleaned[index]
			var following: Vector2 = cleaned[(index + 1) % cleaned.size()]
			var incoming: Vector2 = current - previous
			var outgoing: Vector2 = following - current
			if (
				incoming.length_squared() <= DUPLICATE_DISTANCE_SQUARED
				or outgoing.length_squared() <= DUPLICATE_DISTANCE_SQUARED
			):
				cleaned.remove_at(index)
				changed = true
				break
			var cross_magnitude: float = absf(incoming.cross(outgoing))
			var collinear_tolerance: float = maxf(
				0.0001,
				incoming.length() * outgoing.length() * 0.00001
			)
			if cross_magnitude <= collinear_tolerance and incoming.dot(outgoing) >= 0.0:
				cleaned.remove_at(index)
				changed = true
				break

	if cleaned.size() < 3 or _polygon_area(cleaned) <= 0.05:
		return PackedVector2Array()
	return cleaned


func _draw_triangulated_liquid_polygon(
	polygon: PackedVector2Array,
	vertex_colors: PackedColorArray
) -> void:
	if polygon.size() < 3 or vertex_colors.size() != polygon.size():
		return

	var triangle_indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	if triangle_indices.is_empty() or triangle_indices.size() % 3 != 0:
		return

	for triangle_start in range(0, triangle_indices.size(), 3):
		var triangle_points := PackedVector2Array()
		var triangle_colors := PackedColorArray()
		var triangle_is_valid: bool = true
		for vertex_offset in range(3):
			var source_index: int = triangle_indices[triangle_start + vertex_offset]
			if source_index < 0 or source_index >= polygon.size():
				triangle_is_valid = false
				break
			triangle_points.append(polygon[source_index])
			triangle_colors.append(vertex_colors[source_index])

		if not triangle_is_valid:
			continue
		if absf(
			(triangle_points[1] - triangle_points[0]).cross(
				triangle_points[2] - triangle_points[0]
			)
		) <= 0.001:
			continue
		draw_primitive(
			triangle_points,
			triangle_colors,
			PackedVector2Array(),
			null
		)


func _draw_triangulated_solid_liquid_polygon(
	polygon: PackedVector2Array,
	color: Color
) -> void:
	var vertex_colors := PackedColorArray()
	for _point in polygon:
		vertex_colors.append(color)
	_draw_triangulated_liquid_polygon(polygon, vertex_colors)


func _valid_liquid_polygons(polygons: Array) -> Array[PackedVector2Array]:
	# Keep every valid fragment returned by Geometry2D. Selecting only the
	# largest one can silently discard shoulder/body sections after clipping.
	var valid_polygons: Array[PackedVector2Array] = []
	for polygon_value in polygons:
		var polygon: PackedVector2Array = _sanitize_liquid_polygon(polygon_value)
		if polygon.size() < 3:
			continue
		var triangle_indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
		if triangle_indices.is_empty() or triangle_indices.size() % 3 != 0:
			continue
		valid_polygons.append(polygon)
	return valid_polygons


func _get_pouring_boundary_weight(fill_units: float) -> float:
	if _pour_visual_weight <= 0.001 or absf(_tilt) < deg_to_rad(30.0):
		return 0.0

	var boundary_index: int = roundi(fill_units)
	if absf(fill_units - float(boundary_index)) > 0.001:
		return 0.0

	var visible_layers: int = mini(int(ceil(_liquid_level)), _visual_contents.size())
	if boundary_index <= 0 or boundary_index >= visible_layers:
		return 0.0

	# Only actual boundaries between differently coloured groups converge.
	# Matching neighbouring essences have already been merged into one band.
	var lower_color: Color = _palette.get(
		String(_visual_contents[boundary_index - 1]),
		Color(0.45, 0.78, 0.75, 1.0)
	)
	var upper_color: Color = _palette.get(
		String(_visual_contents[boundary_index]),
		Color(0.45, 0.78, 0.75, 1.0)
	)
	if _same_liquid_colour(lower_color, upper_color):
		return 0.0

	var angle_weight: float = smoothstep(
		deg_to_rad(30.0),
		deg_to_rad(78.0),
		absf(_tilt)
	)
	return angle_weight * _pour_visual_weight


func _get_pouring_boundary_clearance(fill_units: float) -> float:
	var boundary_index: int = roundi(fill_units)
	if (
		absf(fill_units - float(boundary_index)) > 0.001
		or _get_pouring_boundary_weight(fill_units) <= 0.001
	):
		return 0.0
	return (
		POUR_WALL_CLEARANCE_BASE
		+ float(boundary_index - 1) * POUR_WALL_CLEARANCE_STEP
	)


func _get_reference_liquid_area(
	rect: Rect2,
	chamber_polygon: PackedVector2Array,
	fill_units: float,
	curve_depth: float
) -> float:
	if fill_units <= 0.0:
		return 0.0
	var frame: Dictionary = _get_liquid_gravity_frame(rect, 0.0)
	var bottom_y: float = rect.position.y + rect.size.y * _window_bottom_ratio
	var top_y: float = rect.position.y + rect.size.y * _window_top_ratio
	var effective_bottom_y: float = bottom_y + _cached_liquid_floor_depth
	var reference_y: float = effective_bottom_y - (
		(effective_bottom_y - top_y) * fill_units / float(CAPACITY)
	)
	var offset: float = reference_y - rect.get_center().y - curve_depth
	var half_plane := _build_gravity_half_plane(
		rect,
		frame,
		offset,
		true,
		curve_depth
	)
	return _polygons_area(Geometry2D.intersect_polygons(chamber_polygon, half_plane))


func _get_gravity_boundary_offset(
	rect: Rect2,
	chamber_polygon: PackedVector2Array,
	frame: Dictionary,
	fill_units: float,
	curve_depth: float,
	pour_channel_weight: float = 0.0,
	pour_wall_clearance: float = 0.0
) -> float:
	var centre: Vector2 = frame["centre"]
	var normal: Vector2 = frame["normal"]
	var margin: float = maxf(rect.size.length() * 2.5, 120.0)

	if fill_units <= 0.0:
		var lowest_projection: float = -INF
		for point in chamber_polygon:
			lowest_projection = maxf(lowest_projection, (point - centre).dot(normal))
		return lowest_projection + margin

	var target_area: float = _get_reference_liquid_area(
		rect,
		chamber_polygon,
		fill_units,
		curve_depth
	)

	if absf(_tilt) < 0.0005:
		var bottom_y: float = rect.position.y + rect.size.y * _window_bottom_ratio
		var top_y: float = rect.position.y + rect.size.y * _window_top_ratio
		var effective_bottom_y: float = bottom_y + _cached_liquid_floor_depth
		var reference_y: float = effective_bottom_y - (
			(effective_bottom_y - top_y) * fill_units / float(CAPACITY)
		)
		return reference_y - centre.y - curve_depth

	var min_projection: float = INF
	var max_projection: float = -INF
	for point in chamber_polygon:
		var projection: float = (point - centre).dot(normal)
		min_projection = minf(min_projection, projection)
		max_projection = maxf(max_projection, projection)

	var low: float = min_projection - curve_depth - margin
	var high: float = max_projection + margin
	for _iteration in range(LIQUID_GRAVITY_SOLVE_STEPS):
		var middle: float = (low + high) * 0.5
		var half_plane := _build_gravity_half_plane(
			rect,
			frame,
			middle,
			true,
			curve_depth,
			pour_channel_weight,
			pour_wall_clearance
		)
		var area: float = _polygons_area(
			Geometry2D.intersect_polygons(chamber_polygon, half_plane)
		)
		if area > target_area:
			low = middle
		else:
			high = middle

	return (low + high) * 0.5


func _get_liquid_boundary_curve_depth(fill_units: float) -> float:
	# A full upright vial reaches the chamber's actual top edge, where the
	# projected meniscus should span the complete neck-to-shoulder opening.
	if fill_units >= float(CAPACITY) - 0.0001:
		return 0.0
	return LIQUID_INTERFACE_CURVE_DEPTH


func _get_cached_boundary_offset(
	rect: Rect2,
	chamber_polygon: PackedVector2Array,
	frame: Dictionary,
	fill_units: float,
	curve_depth: float,
	offset_cache: Dictionary
) -> float:
	var pour_channel_weight: float = _get_pouring_boundary_weight(fill_units)
	var pour_wall_clearance: float = _get_pouring_boundary_clearance(fill_units)
	var key: String = "%0.4f|%0.3f|%0.3f" % [
		fill_units,
		pour_channel_weight,
		pour_wall_clearance
	]
	if offset_cache.has(key):
		return float(offset_cache[key])
	var offset: float = _get_gravity_boundary_offset(
		rect,
		chamber_polygon,
		frame,
		fill_units,
		curve_depth,
		pour_channel_weight,
		pour_wall_clearance
	)
	offset_cache[key] = offset
	return offset


func _build_cached_liquid_band(
	rect: Rect2,
	chamber_polygon: PackedVector2Array,
	bottom_boundary_polygon: PackedVector2Array,
	frame: Dictionary,
	top_offset_cache: Dictionary,
	bottom_offset_cache: Dictionary,
	bottom_units: float,
	top_units: float,
	liquid_color: Color,
	is_surface: bool
) -> Array[Dictionary]:
	var top_curve_depth: float = _get_liquid_boundary_curve_depth(top_units)
	var top_channel_weight: float = _get_pouring_boundary_weight(top_units)
	var top_wall_clearance: float = _get_pouring_boundary_clearance(top_units)
	var top_offset: float = _get_cached_boundary_offset(
		rect,
		chamber_polygon,
		frame,
		top_units,
		top_curve_depth,
		top_offset_cache
	)
	var top_half_plane := _build_gravity_half_plane(
		rect,
		frame,
		top_offset,
		true,
		top_curve_depth,
		top_channel_weight,
		top_wall_clearance
	)
	var clipped_polygons: Array = Geometry2D.intersect_polygons(
		chamber_polygon,
		top_half_plane
	)

	if bottom_units > 0.0001 and not clipped_polygons.is_empty():
		var bottom_curve_depth: float = _get_liquid_boundary_curve_depth(bottom_units)
		var bottom_channel_weight: float = _get_pouring_boundary_weight(bottom_units)
		var bottom_wall_clearance: float = _get_pouring_boundary_clearance(bottom_units)
		var bottom_offset: float = _get_cached_boundary_offset(
			rect,
			bottom_boundary_polygon,
			frame,
			bottom_units,
			bottom_curve_depth,
			bottom_offset_cache
		)
		var bottom_half_plane := _build_gravity_half_plane(
			rect,
			frame,
			bottom_offset,
			false,
			bottom_curve_depth,
			bottom_channel_weight,
			bottom_wall_clearance
		)
		var band_polygons: Array = []
		for current_polygon in clipped_polygons:
			var lower_clipped: Array = Geometry2D.intersect_polygons(
				current_polygon,
				bottom_half_plane
			)
			for output_polygon in lower_clipped:
				band_polygons.append(output_polygon)
		clipped_polygons = band_polygons

	var render_pieces: Array[PackedVector2Array] = _valid_liquid_polygons(
		clipped_polygons
	)
	if render_pieces.is_empty():
		return []

	var band_amount: float = maxf(0.001, top_units - bottom_units)
	var band_alpha: float = smoothstep(
		LIQUID_MIN_BAND_HEIGHT,
		LIQUID_BAND_FADE_HEIGHT,
		band_amount * rect.size.y / float(CAPACITY)
	)
	var fill_color: Color = liquid_color.lerp(liquid_color.lightened(0.12), 0.10)
	fill_color.a *= band_alpha
	var edge_color: Color = fill_color.darkened(0.10)
	var bottom_color: Color = fill_color.darkened(0.045)
	var center_color: Color = fill_color.lightened(0.18)

	var centre: Vector2 = frame["centre"]
	var normal: Vector2 = frame["normal"]
	var tangent: Vector2 = frame["tangent"]
	var tangent_range: Vector2 = _get_surface_tangent_range(
		chamber_polygon,
		frame,
		top_offset,
		top_curve_depth
	)
	var surface_radius_x: float = maxf(
		0.0,
		(tangent_range.y - tangent_range.x) * 0.5 - 1.5
	)
	var surface_center: Vector2 = (
		centre
		+ tangent * ((tangent_range.x + tangent_range.y) * 0.5)
		+ normal * (top_offset + top_curve_depth)
	)
	var output_bands: Array[Dictionary] = []
	for piece_index in range(render_pieces.size()):
		var polygon: PackedVector2Array = render_pieces[piece_index]
		var min_y: float = INF
		var max_y: float = -INF
		for point in polygon:
			min_y = minf(min_y, point.y)
			max_y = maxf(max_y, point.y)

		var vertex_colors := PackedColorArray()
		for point in polygon:
			var horizontal_distance: float = absf(point.x - rect.get_center().x)
			var horizontal_weight: float = 1.0 - clampf(
				horizontal_distance / maxf(1.0, rect.size.x * 0.5),
				0.0,
				1.0
			)
			var center_weight: float = pow(horizontal_weight, 0.85) * 0.42
			var vertical_weight: float = clampf(
				(point.y - min_y) / maxf(1.0, max_y - min_y),
				0.0,
				1.0
			)
			var shaded_color: Color = edge_color.lerp(center_color, center_weight)
			shaded_color = shaded_color.lerp(bottom_color, vertical_weight * 0.08)
			vertex_colors.append(shaded_color)

		output_bands.append({
			"polygon": polygon,
			"vertex_colors": vertex_colors,
			"fill_color": fill_color,
			"liquid_alpha": liquid_color.a * band_alpha,
			"surface_center": surface_center,
			"surface_tangent": tangent,
			"surface_normal": normal,
			"surface_radius_x": surface_radius_x,
			"surface_boundary_offset": top_offset,
			"surface_curve_depth": top_curve_depth,
			"surface_depth": clampf(rect.size.y * 0.032, 5.0, 10.0),
			"is_surface": is_surface and piece_index == 0,
			"is_top_essence": is_surface
		})

	return output_bands


func _get_surface_tangent_range(
	chamber_polygon: PackedVector2Array,
	frame: Dictionary,
	boundary_offset: float,
	curve_depth: float
) -> Vector2:
	var centre: Vector2 = frame["centre"]
	var tangent: Vector2 = frame["tangent"]
	var normal: Vector2 = frame["normal"]
	var tangent_span: float = float(frame["tangent_span"])
	var first_inside: float = INF
	var last_inside: float = -INF

	# The surface line can cross the vessel away from its centre when the
	# bottle is heavily tilted. Sample both directions instead of guessing
	# the opening width from a single horizontal profile row.
	for sample_index in range(LIQUID_SURFACE_EXTENT_SAMPLES + 1):
		var distance: float = lerpf(
			-tangent_span,
			tangent_span,
			float(sample_index) / float(LIQUID_SURFACE_EXTENT_SAMPLES)
		)
		var normalized_distance: float = distance / tangent_span
		var curve: float = curve_depth * maxf(
			0.0,
			1.0 - normalized_distance * normalized_distance
		)
		var candidate: Vector2 = (
			centre
			+ tangent * distance
			+ normal * (boundary_offset + curve + 0.25)
		)
		if Geometry2D.is_point_in_polygon(candidate, chamber_polygon):
			first_inside = minf(first_inside, distance)
			last_inside = maxf(last_inside, distance)

	if first_inside == INF or last_inside <= first_inside:
		return Vector2.ZERO
	return Vector2(first_inside, last_inside)


func _get_liquid_surface_wave(normalized_x: float) -> float:
	var maximum_wave: float = 0.35 + _surface_activity * 2.25 + absf(_slosh) * 1.35
	var secondary_wave: float = 0.18 + _surface_activity * 0.48 + absf(_slosh) * 0.50
	var edge_envelope: float = pow(
		maxf(0.0, 1.0 - normalized_x * normalized_x),
		0.55
	)
	var wave_one: float = sin(_surface_wave_phase + normalized_x * 3.1) * maximum_wave
	var wave_two: float = sin(_surface_wave_phase * 1.37 - normalized_x * 6.3) * secondary_wave
	return (wave_one + wave_two) * edge_envelope


func _draw_cached_liquid_surface(band: Dictionary) -> void:
	var centre: Vector2 = band["surface_center"]
	var tangent: Vector2 = band["surface_tangent"]
	var normal: Vector2 = band["surface_normal"]
	var radius_x: float = float(band["surface_radius_x"])
	var radius_y: float = float(band["surface_depth"])
	if radius_x <= 4.0:
		return

	var surface_polygon := PackedVector2Array()
	var liquid_color: Color = band["fill_color"]
	var surface_colours := PackedColorArray()
	for sample_index in range(LIQUID_SURFACE_SAMPLES):
		var angle: float = TAU * float(sample_index) / float(LIQUID_SURFACE_SAMPLES)
		var normalized_x: float = cos(angle)
		var wave: float = _get_liquid_surface_wave(normalized_x) * 0.20
		surface_polygon.append(
			centre
			+ tangent * (normalized_x * radius_x)
			+ normal * (sin(angle) * radius_y + wave)
		)
		var front_weight: float = 0.5 + 0.5 * sin(angle)
		surface_colours.append(
			liquid_color.darkened(0.07).lerp(
				liquid_color.lightened(0.18),
				front_weight
			)
		)
	_draw_triangulated_liquid_polygon(surface_polygon, surface_colours)

	var rear_edge := PackedVector2Array()
	var front_edge := PackedVector2Array()
	for sample_index in range(LIQUID_SURFACE_SAMPLES / 2 + 1):
		var t: float = float(sample_index) / float(LIQUID_SURFACE_SAMPLES / 2)
		var rear_angle: float = PI + PI * t
		var front_angle: float = PI * t
		rear_edge.append(
			centre
			+ tangent * (cos(rear_angle) * radius_x)
			+ normal * (
				sin(rear_angle) * radius_y
				+ _get_liquid_surface_wave(cos(rear_angle)) * 0.20
			)
		)
		front_edge.append(
			centre
			+ tangent * (cos(front_angle) * radius_x)
			+ normal * (
				sin(front_angle) * radius_y
				+ _get_liquid_surface_wave(cos(front_angle)) * 0.20
			)
		)

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
	if visible_layers <= 0 or _window_profile.is_empty() or _cached_liquid_bands.is_empty():
		return

	var appearance_alpha: float = smoothstep(0.0, LIQUID_APPEARANCE_FADE_LEVEL, _liquid_level)
	var top_band: Dictionary = _cached_liquid_bands.back()
	var surface_center: Vector2 = top_band["surface_center"]
	var tangent: Vector2 = top_band["surface_tangent"]
	var normal: Vector2 = top_band["surface_normal"]
	var surface_half_width: float = float(top_band["surface_radius_x"])
	if surface_half_width <= 4.0:
		return

	var gravity_normal: Vector2 = top_band["surface_normal"]
	var vessel_centre: Vector2 = rect.get_center()
	var lowest_chamber_projection: float = -INF
	for chamber_point in _cached_chamber_polygon:
		lowest_chamber_projection = maxf(
			lowest_chamber_projection,
			(chamber_point - vessel_centre).dot(gravity_normal)
		)
	var surface_projection: float = (surface_center - vessel_centre).dot(gravity_normal)
	var liquid_depth: float = maxf(0.0, lowest_chamber_projection - surface_projection)

	const BUBBLE_SIZES := [1.65, 2.25, 1.85, 2.35]
	for bubble_index in range(BUBBLE_SIZES.size()):
		var speed: float = 0.082 + float(bubble_index % 3) * 0.021 + float(bubble_index / 3) * 0.008
		var phase: float = fposmod(
			_wave_time * speed + float(bubble_index) * 0.163,
			1.0
		)
		var sway: float = sin(
			_wave_time * (0.34 + float(bubble_index % 3) * 0.09)
			+ float(bubble_index) * 1.71
		)
		var bubble_position: Vector2 = (
			surface_center
			+ normal * (liquid_depth * (1.0 - phase))
			+ tangent * (sway * surface_half_width * 0.24)
		)
		if not Geometry2D.is_point_in_polygon(bubble_position, _cached_chamber_polygon):
			continue

		var bubble_size: float = BUBBLE_SIZES[bubble_index]
		var travel_fade: float = sin(PI * phase)
		var pulse: float = 0.55 + 0.45 * sin(_wave_time * 1.15 + float(bubble_index) * 1.37)
		var bubble_alpha: float = (0.18 + 0.06 * pulse) * travel_fade * appearance_alpha
		if bubble_alpha <= 0.004:
			continue

		var layer_index: int = clampi(
			int(floor(phase * maxf(1.0, _liquid_level))),
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

	for mote_index in range(2):
		var mote_phase: float = fposmod(
			_wave_time * (0.055 + float(mote_index) * 0.012)
			+ float(mote_index) * 0.317,
			1.0
		)
		var mote_y: float = liquid_depth * (1.0 - mote_phase)
		var mote_position: Vector2 = (
			surface_center
			+ normal * mote_y
			+ tangent * sin(_wave_time * 0.27 + float(mote_index) * 2.1) * surface_half_width * 0.38
		)
		var mote_alpha: float = (
			(0.065 + 0.035 * sin(_wave_time * 0.8 + float(mote_index)))
			* sin(PI * mote_phase)
			* appearance_alpha
		)
		if not Geometry2D.is_point_in_polygon(mote_position, _cached_chamber_polygon):
			continue
		var mote_layer: int = clampi(
			int(floor(mote_phase * maxf(1.0, _liquid_level))),
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
