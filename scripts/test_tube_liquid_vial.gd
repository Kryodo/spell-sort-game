extends "res://scripts/test_tube_vial.gd"

## Isolated liquid-profile experiment for the new laboratory bottle.
## The original test_tube_vial.gd and primary bottle renderers remain untouched.
##
## This renderer reuses the established fill-level state, bottle profile,
## slosh motion and bubble animation, but replaces rectangular liquid bands
## with profile-conforming polygons and a visible elliptical free surface.

const PROFILE_LIQUID_HORIZONTAL_SAMPLES := 40
const PROFILE_LIQUID_SIDE_SAMPLES := 28
const PROFILE_SURFACE_SAMPLES := 48
const PROFILE_SURFACE_DEPTH_RATIO := 0.026
const PROFILE_SURFACE_DEPTH_MIN := 4.0
const PROFILE_SURFACE_DEPTH_MAX := 8.0
const PROFILE_LIQUID_WALL_INSET := 4.5
const PROFILE_LIQUID_BOTTOM_OVERLAP := 1.2
const PROFILE_LIQUID_SURFACE_WAVE_SCALE := 0.42


func _draw_liquid(_rect: Rect2) -> void:
	if _visual_contents.is_empty() or _liquid_level <= 0.001:
		return

	var rect := _get_vessel_rect()
	var layer_height: float = (LIQUID_BOTTOM_RATIO - LIQUID_TOP_RATIO) / float(CAPACITY)
	var visible_layers: int = mini(int(ceil(_liquid_level)), _visual_contents.size())

	# Draw the solid liquid volumes from the foot upward. Each side is sampled
	# against the same profile that defines this bottle's inner glass contour.
	for layer_index in range(visible_layers):
		var amount: float = clampf(_liquid_level - float(layer_index), 0.0, 1.0)
		if amount <= 0.001:
			continue

		var bottom_ratio: float = LIQUID_BOTTOM_RATIO - float(layer_index) * layer_height
		var top_ratio: float = bottom_ratio - layer_height * amount
		var essence: String = String(_visual_contents[layer_index])
		var liquid_color: Color = _palette.get(essence, Color(0.45, 0.78, 0.75, 1.0))
		liquid_color.a *= smoothstep(0.0, 0.12, amount)

		var is_top_surface: bool = layer_index == visible_layers - 1
		var is_bottom_layer: bool = layer_index == 0
		_draw_profile_liquid_band(
			rect,
			top_ratio,
			bottom_ratio,
			liquid_color,
			is_top_surface,
			is_bottom_layer
		)

		if is_top_surface:
			_draw_profile_liquid_surface(rect, top_ratio, liquid_color)

	_draw_profile_liquid_bubbles(rect, layer_height, visible_layers)


func _draw_profile_liquid_band(
	rect: Rect2,
	top_ratio: float,
	bottom_ratio: float,
	liquid_color: Color,
	is_top_surface: bool,
	is_bottom_layer: bool
) -> void:
	var top_y: float = rect.position.y + rect.size.y * top_ratio
	var bottom_y: float = rect.position.y + rect.size.y * bottom_ratio
	if not is_bottom_layer:
		bottom_y += PROFILE_LIQUID_BOTTOM_OVERLAP

	if bottom_y - top_y <= 0.35:
		return

	var centre_x: float = rect.get_center().x
	var top_edge := PackedVector2Array()
	var right_edge := PackedVector2Array()
	var bottom_edge := PackedVector2Array()
	var left_edge := PackedVector2Array()
	var polygon := PackedVector2Array()
	var colours := PackedColorArray()

	# The top edge follows the bottle profile and moves gently with the liquid.
	for sample_index in range(PROFILE_LIQUID_HORIZONTAL_SAMPLES + 1):
		var t: float = float(sample_index) / float(PROFILE_LIQUID_HORIZONTAL_SAMPLES)
		var normalized_x: float = t * 2.0 - 1.0
		var wave: float = _get_surface_wave_offset(normalized_x) * (
			PROFILE_LIQUID_SURFACE_WAVE_SCALE if is_top_surface else 0.0
		)
		var sample_y: float = top_y + wave
		var half_width: float = _profile_liquid_half_width(rect, sample_y)
		var point := Vector2(centre_x + normalized_x * half_width, sample_y)
		top_edge.append(point)

		var centre_weight: float = pow(maxf(0.0, sin(PI * t)), 0.82)
		var top_colour: Color = liquid_color.darkened(0.13).lerp(
			liquid_color.lightened(0.13),
			centre_weight * 0.68
		)
		colours.append(top_colour)

	# Right wall: sample the changing bottle width all the way to the foot.
	for sample_index in range(1, PROFILE_LIQUID_SIDE_SAMPLES + 1):
		var t: float = float(sample_index) / float(PROFILE_LIQUID_SIDE_SAMPLES)
		var y: float = lerpf(top_y, bottom_y, t)
		var half_width: float = _profile_liquid_half_width(rect, y)
		right_edge.append(Vector2(centre_x + half_width, y))
		colours.append(liquid_color.darkened(lerpf(0.12, 0.23, t)))

	# The bottom edge also follows the actual rounded profile instead of a
	# rectangular floor, which is especially important at the bottle foot.
	for sample_index in range(PROFILE_LIQUID_HORIZONTAL_SAMPLES - 1, -1, -1):
		var t: float = float(sample_index) / float(PROFILE_LIQUID_HORIZONTAL_SAMPLES)
		var normalized_x: float = t * 2.0 - 1.0
		var half_width: float = _profile_liquid_half_width(rect, bottom_y)
		bottom_edge.append(Vector2(centre_x + normalized_x * half_width, bottom_y))
		colours.append(liquid_color.darkened(0.22))

	# Left wall returns to the top edge.
	for sample_index in range(PROFILE_LIQUID_SIDE_SAMPLES - 1, 0, -1):
		var t: float = float(sample_index) / float(PROFILE_LIQUID_SIDE_SAMPLES)
		var y: float = lerpf(top_y, bottom_y, t)
		var half_width: float = _profile_liquid_half_width(rect, y)
		left_edge.append(Vector2(centre_x - half_width, y))
		colours.append(liquid_color.darkened(lerpf(0.12, 0.23, t)))

	polygon.append_array(top_edge)
	polygon.append_array(right_edge)
	polygon.append_array(bottom_edge)
	polygon.append_array(left_edge)

	if polygon.size() >= 3 and polygon.size() == colours.size():
		draw_polygon(polygon, colours)


func _draw_profile_liquid_surface(
	rect: Rect2,
	surface_ratio: float,
	liquid_color: Color
) -> void:
	# A shallow elliptical plane makes the top of the liquid read as a surface
	# viewed through glass, rather than a coloured rectangle with a line.
	var surface_y: float = rect.position.y + rect.size.y * surface_ratio
	var surface_depth: float = clampf(
		rect.size.y * PROFILE_SURFACE_DEPTH_RATIO,
		PROFILE_SURFACE_DEPTH_MIN,
		PROFILE_SURFACE_DEPTH_MAX
	)
	var width_ratio: float = _get_min_profile_width(
		surface_ratio - surface_depth / rect.size.y,
		surface_ratio + surface_depth / rect.size.y
	)
	var radius_x: float = rect.size.x * width_ratio - PROFILE_LIQUID_WALL_INSET - 3.0
	if radius_x <= 4.0:
		return

	var centre := Vector2(rect.get_center().x, surface_y)
	var ellipse := PackedVector2Array()
	var surface_colours := PackedColorArray()
	for point_index in range(PROFILE_SURFACE_SAMPLES):
		var angle: float = TAU * float(point_index) / float(PROFILE_SURFACE_SAMPLES)
		var normalized_x: float = cos(angle)
		var wave: float = _get_surface_wave_offset(normalized_x) * 0.24
		ellipse.append(Vector2(
			centre.x + normalized_x * radius_x,
			centre.y + sin(angle) * surface_depth + wave
		))

		# The rear half is slightly deeper; the front half catches a soft light.
		var front_weight: float = 0.5 + 0.5 * sin(angle)
		var surface_colour: Color = liquid_color.darkened(0.16).lerp(
			liquid_color.lightened(0.20),
			front_weight
		)
		surface_colour = surface_colour.lerp(
			liquid_color.lightened(0.30),
			pow(maxf(0.0, 1.0 - absf(normalized_x)), 1.5) * 0.12
		)
		surface_colours.append(surface_colour)

	draw_polygon(ellipse, surface_colours)

	# A restrained rear edge and a softer front glint create the meniscus.
	var rear_edge := PackedVector2Array()
	var front_edge := PackedVector2Array()
	for point_index in range(PROFILE_SURFACE_SAMPLES / 2 + 1):
		var t: float = float(point_index) / float(PROFILE_SURFACE_SAMPLES / 2)
		var rear_angle: float = PI + PI * t
		var front_angle: float = PI * t
		rear_edge.append(Vector2(
			centre.x + cos(rear_angle) * radius_x,
			centre.y + sin(rear_angle) * surface_depth
		))
		front_edge.append(Vector2(
			centre.x + cos(front_angle) * radius_x,
			centre.y + sin(front_angle) * surface_depth
		))

	draw_polyline(
		rear_edge,
		Color(
			liquid_color.darkened(0.24).r,
			liquid_color.darkened(0.24).g,
			liquid_color.darkened(0.24).b,
			0.48 * liquid_color.a
		),
		1.15,
		true
	)
	draw_polyline(
		front_edge,
		Color(0.96, 1.0, 0.94, 0.24 * liquid_color.a),
		1.2,
		true
	)


func _draw_profile_liquid_bubbles(
	rect: Rect2,
	layer_height: float,
	visible_layers: int
) -> void:
	if visible_layers <= 0:
		return

	var fill_amount: float = clampf(_liquid_level, 0.0, float(CAPACITY))
	var top_ratio: float = LIQUID_BOTTOM_RATIO - layer_height * fill_amount
	var bottom_y: float = rect.position.y + rect.size.y * LIQUID_BOTTOM_RATIO
	var surface_y: float = rect.position.y + rect.size.y * top_ratio

	# Preserve the proven gentle bubble language from the existing fantasy
	# renderer, but constrain every bubble to the new vessel's curved chamber.
	for bubble_index in range(9):
		var phase: float = fposmod(
			_wave_time * (0.13 + float(bubble_index) * 0.011)
			+ float(bubble_index) * 0.137,
			1.0
		)
		var bubble_y: float = lerpf(bottom_y - 7.0, surface_y + 5.0, phase)
		var normalized_y: float = clampf(
			(bubble_y - rect.position.y) / rect.size.y,
			0.0,
			1.0
		)
		var local_half_width: float = _profile_liquid_half_width(rect, bubble_y) - 7.5
		if local_half_width <= 3.0:
			continue

		var sway: float = sin(_wave_time * 0.72 + float(bubble_index) * 1.71)
		var x_position: float = rect.get_center().x + sway * local_half_width * 0.58
		var bubble_position := Vector2(x_position, bubble_y)
		var bubble_size: float = 1.2 + fposmod(float(bubble_index) * 0.73, 2.0)
		var bubble_alpha: float = (
			0.13 + 0.09 * (0.5 + 0.5 * sin(_wave_time * 1.6 + float(bubble_index)))
		)

		var bubble_layer_index: int = clampi(
			int(floor((LIQUID_BOTTOM_RATIO - normalized_y) / layer_height)),
			0,
			_visual_contents.size() - 1
		)
		var bubble_essence: String = String(_visual_contents[bubble_layer_index])
		var bubble_color: Color = _palette.get(bubble_essence, Color(0.45, 0.78, 0.75, 1.0))

		draw_circle(
			bubble_position,
			bubble_size * 2.1,
			Color(bubble_color.r, bubble_color.g, bubble_color.b, bubble_alpha * 0.16)
		)
		draw_circle(
			bubble_position,
			bubble_size,
			Color(0.91, 1.0, 0.98, bubble_alpha * 0.54)
		)
		draw_arc(
			bubble_position + Vector2(-0.2, -0.2),
			bubble_size,
			deg_to_rad(205.0),
			deg_to_rad(325.0),
			12,
			Color(1.0, 1.0, 1.0, bubble_alpha * 0.82),
			0.85,
			true
		)
		draw_circle(
			bubble_position + Vector2(-bubble_size * 0.30, -bubble_size * 0.34),
			maxf(0.5, bubble_size * 0.22),
			Color(1.0, 1.0, 1.0, bubble_alpha * 0.78)
		)


func _profile_liquid_half_width(rect: Rect2, y: float) -> float:
	var normalized_y: float = clampf(
		(y - rect.position.y) / maxf(1.0, rect.size.y),
		0.0,
		1.0
	)
	var profile := _get_profile_at(normalized_y)
	return maxf(0.0, rect.size.x * profile.y - PROFILE_LIQUID_WALL_INSET)
