extends Control

const MODE_GENERATED := 0
const MODE_PROCEDURAL := 1
const CAPACITY := 4

var vial_index: int = 0
var display_name: String = ""
var render_mode: int = MODE_PROCEDURAL
var procedural_variant: int = 0

var _bottle_texture: Texture2D
var _source_image: Image
var _alpha_profile: PackedVector2Array = PackedVector2Array()
var _contents: Array = []
var _visual_contents: Array = []
var _palette: Dictionary = {}

var _liquid_level: float = 0.0
var _selected: bool = false
var _targeted: bool = false
var _dragging: bool = false
var _lift: float = 0.0
var _tilt: float = 0.0
var _slosh: float = 0.0
var _slosh_velocity: float = 0.0
var _wave_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_process(true)


func setup(
	index: int,
	label: String,
	mode: int,
	variant: int,
	texture: Texture2D,
	image: Image,
	palette: Dictionary,
	contents: Array
) -> void:
	vial_index = index
	display_name = label
	render_mode = mode
	procedural_variant = variant
	_bottle_texture = texture
	_source_image = image
	_palette = palette
	_contents = contents.duplicate()
	_visual_contents = contents.duplicate()
	_liquid_level = float(contents.size())
	_build_alpha_profile()
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
	_slosh_velocity += tilt_change * 2.8
	_lift = pose.x
	_tilt = pose.y
	queue_redraw()


func get_pose() -> Vector2:
	return Vector2(_lift, _tilt)


func get_global_spout_position() -> Vector2:
	var center_x: float = size.x * 0.5
	var local_spout: Vector2
	if render_mode == MODE_GENERATED and _bottle_texture != null:
		var art_rect := _get_generated_rect(center_x)
		local_spout = Vector2(center_x, art_rect.position.y + art_rect.size.y * 0.075)
	else:
		local_spout = Vector2(center_x, 42.0)

	var pivot := Vector2(center_x, size.y * 0.86)
	var transformed := pivot + Vector2(0.0, -_lift) + (local_spout - pivot).rotated(_tilt)
	return get_global_transform_with_canvas() * transformed


func _process(delta: float) -> void:
	_wave_time += delta * 2.7
	_slosh_velocity += (-_slosh * 17.0 - _slosh_velocity * 5.8) * delta
	_slosh += _slosh_velocity * delta
	if absf(_slosh) > 0.001 or absf(_slosh_velocity) > 0.001:
		queue_redraw()


func _build_alpha_profile() -> void:
	_alpha_profile = PackedVector2Array()
	if _source_image == null or _source_image.is_empty():
		return

	var width: int = _source_image.get_width()
	var height: int = _source_image.get_height()
	var previous := Vector2(0.5, 0.0)

	for y in range(height):
		var left: int = width
		var right: int = -1
		for x in range(width):
			if _source_image.get_pixel(x, y).a > 0.055:
				left = mini(left, x)
				right = maxi(right, x)

		if right >= left:
			var center_fraction: float = (float(left + right) * 0.5) / float(width)
			var half_width_fraction: float = (float(right - left + 1) * 0.5 / float(width)) * 0.78
			previous = Vector2(center_fraction, half_width_fraction)
		_alpha_profile.append(previous)


func _draw() -> void:
	var center_x: float = size.x * 0.5
	var shadow_y: float = size.y * 0.865
	draw_circle(Vector2(center_x, shadow_y), size.x * 0.34, Color(0.012, 0.022, 0.027, 0.30))

	var pivot := Vector2(center_x, size.y * 0.86)
	var draw_origin := pivot + Vector2(0.0, -_lift) - pivot.rotated(_tilt)
	draw_set_transform(draw_origin, _tilt, Vector2.ONE)

	if _selected or _targeted or _dragging:
		var pulse: float = 0.5 + 0.5 * sin(_wave_time * 1.7)
		var glow_color := Color(0.96, 0.76, 0.43, 0.10 + pulse * 0.08) if _selected or _dragging else Color(0.46, 0.91, 0.76, 0.10 + pulse * 0.08)
		draw_circle(Vector2(center_x, size.y * 0.47), size.x * 0.44, glow_color)
		draw_arc(Vector2(center_x, size.y * 0.47), size.x * 0.43, 0.0, TAU, 48, Color(glow_color.r, glow_color.g, glow_color.b, 0.50), 2.0, true)

	var vessel_rect: Rect2
	if render_mode == MODE_GENERATED and _bottle_texture != null:
		vessel_rect = _get_generated_rect(center_x)
		_draw_generated_shell_back(vessel_rect)
	else:
		vessel_rect = _get_procedural_rect(center_x)
		_draw_procedural_shell_back(vessel_rect)

	_draw_liquid(vessel_rect)

	if render_mode == MODE_GENERATED and _bottle_texture != null:
		_draw_generated_shell_front(vessel_rect)
	else:
		_draw_procedural_shell_front(vessel_rect)

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


func _get_generated_rect(center_x: float) -> Rect2:
	var image_size := Vector2(_source_image.get_size())
	var available := Vector2(size.x * 0.88, size.y * 0.78)
	var fit_scale: float = minf(available.x / image_size.x, available.y / image_size.y)
	var rendered_size := image_size * fit_scale
	return Rect2(
		Vector2(center_x - rendered_size.x * 0.5, 14.0 + (available.y - rendered_size.y) * 0.5),
		rendered_size
	)


func _get_procedural_rect(center_x: float) -> Rect2:
	var width_scale: float = 0.76 if procedural_variant == 1 else 0.88
	return Rect2(center_x - size.x * width_scale * 0.5, 74.0, size.x * width_scale, size.y * 0.70)


func _draw_generated_shell_back(rect: Rect2) -> void:
	draw_texture_rect(_bottle_texture, rect, false, Color(1.0, 1.0, 1.0, 0.28))


func _draw_generated_shell_front(rect: Rect2) -> void:
	draw_texture_rect(_bottle_texture, rect, false, Color(1.0, 1.0, 1.0, 0.40))


func _draw_procedural_shell_back(rect: Rect2) -> void:
	var silhouette := _get_procedural_silhouette(rect)
	draw_colored_polygon(silhouette, Color(0.68, 0.87, 0.92, 0.17))
	var closed := silhouette.duplicate()
	closed.append(silhouette[0])
	draw_polyline(closed, Color(0.82, 0.94, 0.96, 0.86), 2.2, true)
	var neck_width: float = rect.size.x * 0.22
	draw_rect(Rect2(rect.get_center().x - neck_width * 0.5, 43.0, neck_width, 47.0), Color(0.69, 0.87, 0.94, 0.20), true)
	draw_rect(Rect2(rect.get_center().x - neck_width * 0.58, 35.0, neck_width * 1.16, 12.0), Color(0.77, 0.65, 0.45, 0.98), true)
	draw_rect(Rect2(rect.get_center().x - neck_width * 0.58, 35.0, neck_width * 1.16, 3.0), Color(0.97, 0.85, 0.63, 0.90), true)


func _draw_procedural_shell_front(rect: Rect2) -> void:
	var left_highlight := PackedVector2Array()
	var right_highlight := PackedVector2Array()
	for i in range(10):
		var y_norm: float = 0.25 + float(i) * 0.062
		var profile := _get_profile_at(y_norm)
		var center_x: float = rect.position.x + rect.size.x * profile.x
		var half_width: float = rect.size.x * profile.y
		left_highlight.append(Vector2(center_x - half_width * 0.72, rect.position.y + rect.size.y * y_norm))
		right_highlight.append(Vector2(center_x + half_width * 0.72, rect.position.y + rect.size.y * y_norm))
	draw_polyline(left_highlight, Color(0.97, 1.0, 1.0, 0.50), 2.0, true)
	draw_polyline(right_highlight, Color(0.55, 0.75, 0.80, 0.24), 1.5, true)
	draw_arc(Vector2(rect.get_center().x, rect.position.y + 8.0), rect.size.x * 0.12, 0.0, TAU, 24, Color(0.95, 0.99, 1.0, 0.85), 2.0, true)


func _get_procedural_silhouette(rect: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(25):
		var y_norm: float = float(i) / 24.0
		var profile := _get_profile_at(y_norm)
		points.append(Vector2(rect.position.x + rect.size.x * profile.x + rect.size.x * profile.y, rect.position.y + rect.size.y * y_norm))
	for i in range(24, -1, -1):
		var y_norm: float = float(i) / 24.0
		var profile := _get_profile_at(y_norm)
		points.append(Vector2(rect.position.x + rect.size.x * profile.x - rect.size.x * profile.y, rect.position.y + rect.size.y * y_norm))
	return points


func _get_profile_at(y_norm: float) -> Vector2:
	if render_mode == MODE_GENERATED and not _alpha_profile.is_empty():
		var image_y: float = clampf(y_norm, 0.0, 1.0) * float(_alpha_profile.size() - 1)
		var lower: int = clampi(int(floor(image_y)), 0, _alpha_profile.size() - 1)
		var upper: int = mini(lower + 1, _alpha_profile.size() - 1)
		return _alpha_profile[lower].lerp(_alpha_profile[upper], image_y - float(lower))

	var profile: Array = _get_procedural_profile()
	for i in range(profile.size() - 1):
		var first: Vector2 = profile[i]
		var second: Vector2 = profile[i + 1]
		if y_norm <= second.x:
			var span: float = maxf(0.001, second.x - first.x)
			return Vector2(0.5, lerpf(first.y, second.y, clampf((y_norm - first.x) / span, 0.0, 1.0)))
	return Vector2(0.5, profile.back().y)


func _get_procedural_profile() -> Array:
	if procedural_variant == 1:
		return [
			Vector2(0.0, 0.15), Vector2(0.10, 0.15), Vector2(0.18, 0.22),
			Vector2(0.25, 0.31), Vector2(0.72, 0.31), Vector2(0.88, 0.27),
			Vector2(1.0, 0.20)
		]
	return [
		Vector2(0.0, 0.13), Vector2(0.12, 0.14), Vector2(0.22, 0.29),
		Vector2(0.34, 0.41), Vector2(0.57, 0.43), Vector2(0.78, 0.36),
		Vector2(0.92, 0.27), Vector2(1.0, 0.20)
	]


func _get_profile_at_image_y(rect: Rect2, local_y: float) -> Vector2:
	var y_norm: float = clampf((local_y - rect.position.y) / rect.size.y, 0.0, 1.0)
	return _get_profile_at(y_norm)


func _draw_liquid(rect: Rect2) -> void:
	if _visual_contents.is_empty() or _liquid_level <= 0.001:
		return

	const BOTTOM_RATIO := 0.87
	const TOP_RATIO := 0.29
	var layer_height: float = (BOTTOM_RATIO - TOP_RATIO) / float(CAPACITY)
	var visible_layers: int = mini(int(ceil(_liquid_level)), _visual_contents.size())

	for layer_index in range(visible_layers):
		var amount: float = clampf(_liquid_level - float(layer_index), 0.0, 1.0)
		if amount <= 0.001:
			continue
		var bottom_ratio: float = BOTTOM_RATIO - float(layer_index) * layer_height
		var top_ratio: float = bottom_ratio - layer_height * amount
		var essence: String = String(_visual_contents[layer_index])
		var liquid_color: Color = _palette.get(essence, Color(0.45, 0.78, 0.75, 1.0))
		_draw_liquid_band(rect, top_ratio, bottom_ratio, liquid_color, layer_index == visible_layers - 1)


func _draw_liquid_band(rect: Rect2, top_ratio: float, bottom_ratio: float, liquid_color: Color, is_top: bool) -> void:
	var top_y: float = rect.position.y + rect.size.y * top_ratio
	var bottom_y: float = rect.position.y + rect.size.y * bottom_ratio
	var top_profile := _get_profile_at_image_y(rect, top_y)
	var top_center_x: float = rect.position.x + rect.size.x * top_profile.x
	var top_half_width: float = rect.size.x * top_profile.y * 0.78
	if top_half_width < 2.0:
		return

	var surface_slope: float = tan(-_tilt) + _slosh * 0.045
	var surface_amplitude: float = 2.0 + absf(_slosh) * 8.0 if is_top else 0.8
	var points := PackedVector2Array()
	var top_steps: int = 12

	for i in range(top_steps + 1):
		var x_fraction: float = float(i) / float(top_steps)
		var x: float = top_center_x - top_half_width + (top_half_width * 2.0) * x_fraction
		var wave: float = sin(_wave_time * 2.2 + x_fraction * TAU) * surface_amplitude
		var y: float = top_y + surface_slope * (x - top_center_x) + wave
		points.append(Vector2(x, y))

	for i in range(1, 15):
		var y_fraction: float = float(i) / 14.0
		var y: float = lerpf(top_y, bottom_y, y_fraction)
		var profile := _get_profile_at_image_y(rect, y)
		var center_x: float = rect.position.x + rect.size.x * profile.x
		var half_width: float = rect.size.x * profile.y * 0.78
		points.append(Vector2(center_x + half_width, y))

	var bottom_profile := _get_profile_at_image_y(rect, bottom_y)
	var bottom_center_x: float = rect.position.x + rect.size.x * bottom_profile.x
	var bottom_half_width: float = rect.size.x * bottom_profile.y * 0.78
	points.append(Vector2(bottom_center_x - bottom_half_width, bottom_y))

	for i in range(13, 0, -1):
		var y_fraction: float = float(i) / 14.0
		var y: float = lerpf(top_y, bottom_y, y_fraction)
		var profile := _get_profile_at_image_y(rect, y)
		var center_x: float = rect.position.x + rect.size.x * profile.x
		var half_width: float = rect.size.x * profile.y * 0.78
		points.append(Vector2(center_x - half_width, y))

	var shaded := liquid_color.darkened(0.17)
	var body_color := liquid_color.lerp(Color(0.10, 0.18, 0.21, 1.0), 0.18)
	draw_colored_polygon(points, body_color)

	# Soft side depth and a narrow highlight make the fill read as liquid, not tiles.
	var left_side := PackedVector2Array([
		points[0],
		Vector2(points[0].x + 3.0, points[0].y + 5.0),
		Vector2(points[points.size() - 1].x + 6.0, bottom_y - 3.0),
		Vector2(points[points.size() - 1].x, bottom_y)
	])
	draw_colored_polygon(left_side, Color(shaded.r, shaded.g, shaded.b, 0.24))

	if is_top:
		var surface_points := PackedVector2Array()
		for i in range(top_steps + 1):
			surface_points.append(points[i])
		draw_polyline(surface_points, Color(1.0, 1.0, 1.0, 0.44), 2.0, true)
	else:
		draw_line(points[0], points[top_steps], Color(1.0, 1.0, 1.0, 0.10), 1.0, true)


func _get_glass_spout_local() -> Vector2:
	var center_x: float = size.x * 0.5
	if render_mode == MODE_GENERATED and _bottle_texture != null:
		var rect := _get_generated_rect(center_x)
		return Vector2(center_x, rect.position.y + rect.size.y * 0.075)
	return Vector2(center_x, 42.0)
