extends Control

const CAPACITY := 4
const LIQUID_BOTTOM_RATIO := 0.938
const LIQUID_TOP_RATIO := 0.31
const LIQUID_BAND_STRIPS := 18
const LIQUID_SURFACE_COLUMNS := 64
const LIQUID_WALL_INSET_PIXELS := 4.5
const LIQUID_FLOOR_INSET_PIXELS := 5.0
const LIQUID_BAND_OVERLAP_PIXELS := 1.2

const GLASS_OVERLAY_PATHS: Array[String] = [
	"res://assets/environments/SpellSort_Vial_01.svg",
	"res://assets/environments/SpellSort_Vial_02.svg",
	"res://assets/environments/SpellSort_Vial_03.svg",
	"res://assets/environments/SpellSort_Vial_04.svg"
]

var vial_index: int = 0
var display_name: String = ""
var procedural_variant: int = 0

var _contents: Array = []
var _visual_contents: Array = []
var _palette: Dictionary = {}
var _glass_overlay: Texture2D = null
var _liquid_level: float = 0.0

var _selected: bool = false
var _targeted: bool = false
var _dragging: bool = false
var _drag_motion: bool = false
var _drag_motion_release_timer: float = 0.0
var _surface_activity: float = 0.0
var _lift: float = 0.0
var _tilt: float = 0.0
var _draw_scale: float = 1.0

var _slosh: float = 0.0
var _slosh_velocity: float = 0.0
var _wave_time: float = 0.0
var _surface_wave_phase: float = 0.0
var _max_half_width: float = 0.44


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_process(true)


func setup(index: int, label: String, variant: int, palette: Dictionary, contents: Array) -> void:
	vial_index = index
	display_name = label
	procedural_variant = variant
	_glass_overlay = load(GLASS_OVERLAY_PATHS[clampi(variant, 0, GLASS_OVERLAY_PATHS.size() - 1)]) as Texture2D
	_palette = palette
	_contents = contents.duplicate()
	_visual_contents = contents.duplicate()
	_liquid_level = float(contents.size())
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

func set_pour_refraction_visible(_visible: bool) -> void:
	# Optional vessel-specific optical detail; standard vessels have none.
	pass




func set_feedback(selected: bool, targeted: bool, dragging: bool) -> void:
	_selected = selected
	_targeted = targeted
	_dragging = dragging
	if not dragging:
		_drag_motion = false
		_drag_motion_release_timer = 0.0
	queue_redraw()


func set_drag_motion(active: bool) -> void:
	if not _dragging:
		_drag_motion = false
		_drag_motion_release_timer = 0.0
		return
	if active:
		_drag_motion = true
		_drag_motion_release_timer = 0.14

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
	_drag_motion_release_timer = 0.0
	_slosh = 0.0
	_slosh_velocity = 0.0
	_drag_motion = false
	_surface_activity = 0.0
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


func get_drag_anchor_local(local_point: Vector2, pose: Vector2 = Vector2.ZERO, draw_scale: float = -1.0) -> Vector2:
	# Keep the touch point attached to the finger while retaining the visual lift offset.
	var pivot := Vector2(size.x * 0.5, size.y * 0.86)
	var applied_scale: float = _draw_scale if draw_scale < 0.0 else draw_scale
	return pivot + (local_point - pivot).rotated(pose.y) * applied_scale


func get_liquid_surface_position_in_parent() -> Vector2:
	var rect := _get_vessel_rect()
	var layer_height: float = (LIQUID_BOTTOM_RATIO - LIQUID_TOP_RATIO) / float(CAPACITY)
	var surface_ratio: float = LIQUID_BOTTOM_RATIO - layer_height * clampf(_liquid_level, 0.0, float(CAPACITY))
	var surface_y: float = rect.position.y + rect.size.y * surface_ratio
	surface_y += _get_surface_wave_offset(0.0)
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
	if _drag_motion:
		_drag_motion_release_timer = maxf(0.0, _drag_motion_release_timer - delta)
		if _drag_motion_release_timer <= 0.0:
			_drag_motion = false

	var target_activity: float = 0.18
	if _dragging:
		target_activity = 0.82 if _drag_motion else 0.42
	elif _selected:
		target_activity = 0.28

	# Ease state changes over a longer interval so crossing the pointer-speed
	# threshold does not cause a visible jump in the liquid animation.
	_surface_activity = move_toward(_surface_activity, target_activity, delta * 2.8)
	_wave_time += delta * lerpf(1.25, 2.65, _surface_activity)
	# Integrate wave frequency into its own phase; never multiply a changing
	# frequency by total elapsed time, which creates a phase spike on activity changes.
	_surface_wave_phase += delta * lerpf(1.8, 3.2, _surface_activity)

	_slosh_velocity += (-_slosh * 15.0 - _slosh_velocity * 5.2) * delta
	_slosh += _slosh_velocity * delta
	_slosh = clampf(_slosh, -1.0, 1.0)

	if absf(_slosh) > 0.001 or absf(_slosh_velocity) > 0.001 or _selected or _targeted or _liquid_level > 0.001:
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


func _get_vessel_rect() -> Rect2:
	var width: float = size.x * 0.91
	var height: float = size.y * 0.735
	return Rect2(Vector2((size.x - width) * 0.5, 72.0), Vector2(width, height))


func _draw() -> void:
	var center_x: float = size.x * 0.5
	var pivot := Vector2(center_x, size.y * 0.86)
	# Keep the vessel shadow flat and oval, matching the perspective of its slot.
	var shadow_center := Vector2(center_x, size.y * 0.953)
	var shadow_shape := _ellipse_points(shadow_center, size.x * 0.47, size.x * 0.125, 48)
	draw_colored_polygon(shadow_shape, Color(0.012, 0.022, 0.027, 0.30))

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
	_draw_glass_overlay()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(0.0, size.y - 5.0),
		display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		15,
		Color(0.96, 0.88, 0.70, 0.96)
	)



func _draw_glass_overlay() -> void:
	if _glass_overlay == null:
		return
	# SVG overlay supplies the sculpted glass edges, metal neck ferrule,
	# open lip, thick foot and layered reflections. The liquid remains live
	# and is drawn underneath this texture.
	draw_texture_rect(_glass_overlay, Rect2(Vector2.ZERO, size), false, Color.WHITE)


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

	# Draw from the bottom upward so a small overlap is covered by the next essence.
	for layer_index in range(visible_layers):
		var amount: float = clampf(_liquid_level - float(layer_index), 0.0, 1.0)
		if amount <= 0.001:
			continue

		var bottom_ratio: float = LIQUID_BOTTOM_RATIO - float(layer_index) * layer_height
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


func _get_min_profile_width(top_ratio: float, bottom_ratio: float) -> float:
	var low_ratio: float = clampf(minf(top_ratio, bottom_ratio), 0.0, 1.0)
	var high_ratio: float = clampf(maxf(top_ratio, bottom_ratio), 0.0, 1.0)
	var minimum_width: float = minf(
		_get_profile_at(low_ratio).y,
		_get_profile_at(high_ratio).y
	)

	# The vessel profile is piecewise linear, so its exact minimum over this
	# interval can only occur at an interval end or an authored profile point.
	for profile_point in _profile_points():
		if profile_point.x > low_ratio and profile_point.x < high_ratio:
			minimum_width = minf(minimum_width, profile_point.y)

	return minimum_width





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
		bottom_y += LIQUID_BAND_OVERLAP_PIXELS

	var surface_depth: float = 0.0
	if is_surface:
		surface_depth = minf(12.0, maxf(0.0, bottom_y - top_y) * 0.34)

	var body_top: float = top_y + surface_depth - 0.6 if is_surface else top_y
	var strip_height: float = (bottom_y - body_top) / float(LIQUID_BAND_STRIPS)
	if strip_height <= 0.5:
		return

	if is_surface:
		var first_strip_bottom: float = body_top + strip_height + 1.5
		_draw_wavy_surface_fill(rect, top_y, body_top + 0.8, first_strip_bottom, liquid_color)

	var left_contour := PackedVector2Array()
	var right_contour := PackedVector2Array()

	for strip_index in range(LIQUID_BAND_STRIPS):
		var strip_top: float = body_top + strip_height * float(strip_index)
		var strip_bottom: float = minf(bottom_y, body_top + strip_height * float(strip_index + 1) + 1.5)
		var strip_top_ratio: float = (strip_top - rect.position.y) / rect.size.y
		var strip_bottom_ratio: float = (strip_bottom - rect.position.y) / rect.size.y
		var half_width_ratio: float = _get_min_profile_width(strip_top_ratio, strip_bottom_ratio)
		var half_width: float = rect.size.x * half_width_ratio - LIQUID_WALL_INSET_PIXELS
		if half_width <= 2.0:
			continue

		var strip_rect := Rect2(
			rect.get_center().x - half_width,
			strip_top,
			half_width * 2.0,
			strip_bottom - strip_top
		)
		if left_contour.is_empty():
			left_contour.append(Vector2(strip_rect.position.x, strip_top))
			right_contour.append(Vector2(strip_rect.end.x, strip_top))
		left_contour.append(Vector2(strip_rect.position.x, strip_bottom))
		right_contour.append(Vector2(strip_rect.end.x, strip_bottom))

		var depth_factor: float = 0.07 + 0.08 * sin(PI * (float(strip_index) + 0.5) / float(LIQUID_BAND_STRIPS))
		var fill_color: Color = liquid_color.lerp(liquid_color.lightened(0.15), depth_factor)
		draw_rect(strip_rect, fill_color, true, -1.0, false)

		var side_width: float = minf(2.2, half_width * 0.08)
		draw_rect(
			Rect2(strip_rect.position.x, strip_rect.position.y, side_width, strip_rect.size.y),
			liquid_color.darkened(0.18),
			true,
			-1.0,
			false
		)
		draw_rect(
			Rect2(strip_rect.end.x - side_width, strip_rect.position.y, side_width, strip_rect.size.y),
			liquid_color.darkened(0.24),
			true,
			-1.0,
			false
		)

	if left_contour.size() >= 2:
		var soft_edge: Color = liquid_color.darkened(0.20)
		soft_edge.a = 0.20
		draw_polyline(left_contour, soft_edge, 1.15, true)
		draw_polyline(right_contour, soft_edge, 1.15, true)


func _get_surface_wave_offset(normalized_x: float) -> float:
	var maximum_wave: float = 0.90 + _surface_activity * 1.75 + absf(_slosh) * 1.20
	var secondary_wave: float = 0.18 + _surface_activity * 0.48 + absf(_slosh) * 0.50
	var edge_envelope: float = sin((normalized_x + 1.0) * PI * 0.5)
	edge_envelope = pow(maxf(0.0, edge_envelope), 0.55)

	# Frequency changes are accumulated into _surface_wave_phase in _process.
	# This keeps the wave continuous when activity rises or falls.
	var wave_one: float = sin(_surface_wave_phase + normalized_x * 3.1) * maximum_wave
	var wave_two: float = sin(_surface_wave_phase * 1.37 - normalized_x * 6.3) * secondary_wave
	var tilt_offset: float = clampf(-tan(_tilt) * normalized_x * 10.0 * 0.035, -3.0, 3.0)
	return (wave_one + wave_two) * edge_envelope + tilt_offset


func _draw_wavy_surface_fill(
	rect: Rect2,
	surface_y: float,
	fill_bottom: float,
	first_strip_bottom: float,
	liquid_color: Color
) -> void:
	if fill_bottom <= surface_y + 1.0:
		return

	var height: float = maxf(1.0, rect.size.y)
	var maximum_wave: float = 0.35 + _surface_activity * 2.25 + absf(_slosh) * 1.35
	var width_ratio: float = _get_min_profile_width(
		(surface_y - maximum_wave - 3.5 - rect.position.y) / height,
		(first_strip_bottom - rect.position.y) / height
	)
	var half_width: float = rect.size.x * width_ratio - LIQUID_WALL_INSET_PIXELS
	if half_width <= 2.0:
		return

	var top_edge := PackedVector2Array()
	var bottom_edge := PackedVector2Array()
	for point_index in range(LIQUID_SURFACE_COLUMNS + 1):
		var normalized_x: float = float(point_index) / float(LIQUID_SURFACE_COLUMNS) * 2.0 - 1.0
		var x: float = rect.get_center().x + normalized_x * half_width
		var moving_surface_y: float = surface_y + _get_surface_wave_offset(normalized_x)
		moving_surface_y = clampf(moving_surface_y, surface_y - maximum_wave - 3.5, fill_bottom - 1.5)
		top_edge.append(Vector2(x, moving_surface_y))
		bottom_edge.append(Vector2(x, fill_bottom))

	var surface_polygon := PackedVector2Array()
	for point in top_edge:
		surface_polygon.append(point)
	for index in range(bottom_edge.size() - 1, -1, -1):
		surface_polygon.append(bottom_edge[index])

	var surface_color: Color = liquid_color.lerp(liquid_color.lightened(0.18), 0.16)
	draw_colored_polygon(surface_polygon, surface_color)

	var highlight_color: Color = surface_color.lightened(0.35)
	highlight_color.a = 0.15 + _surface_activity * 0.07 + absf(_slosh) * 0.035
	draw_polyline(top_edge, highlight_color, 1.25, true)

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
