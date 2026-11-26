extends "res://scripts/fantasy_alchemy_bottle.gd"

# Current composition candidate: Qwen's second transparent-front vessel.
# The style remains provisional until checked inside the workshop environment.
const VIAL_ART: Texture2D = preload("res://assets/bottles/SpellSort_Vial_2.png")


func get_mouth_local() -> Vector2:
	# The open rim is near 6.5% of the square source image height.
	return Vector2(size.x * 0.5, size.y * 0.065)


func get_mouth_hit_radius() -> Vector2:
	# Match the relatively broad mouth while keeping alignment precise vertically.
	return Vector2(size.y * 0.105, size.y * 0.04)


func _get_vessel_rect() -> Rect2:
	# Vial 2 has a tall, narrow neck and a large central transparent window.
	# The inherited four-layer interval maps from roughly 26.5% to 76% of
	# the source image, leaving the shoulders and pedestal clear.
	var width: float = size.x
	var height: float = size.y * 0.79
	return Rect2(
		Vector2((size.x - width) * 0.5, size.y * 0.02),
		Vector2(width, height)
	)


func _profile_points() -> Array[Vector2]:
	# Inner chamber half-widths, traced against Vial 2's actual transparent
	# window. The widest point sits lower in the vessel than in Vial 1.
	return [
		Vector2(0.00, 0.008),
		Vector2(0.16, 0.012),
		Vector2(0.25, 0.020),
		Vector2(0.30, 0.034),
		Vector2(0.34, 0.060),
		Vector2(0.39, 0.105),
		Vector2(0.44, 0.155),
		Vector2(0.50, 0.195),
		Vector2(0.56, 0.235),
		Vector2(0.60, 0.255),
		Vector2(0.66, 0.245),
		Vector2(0.72, 0.225),
		Vector2(0.78, 0.205),
		Vector2(0.84, 0.170),
		Vector2(0.89, 0.115),
		Vector2(0.93, 0.055),
		Vector2(0.96, 0.018),
		Vector2(1.00, 0.008)
	]


func _draw_liquid_band(
	rect: Rect2,
	top_ratio: float,
	bottom_ratio: float,
	liquid_color: Color,
	is_surface: bool,
	is_bottom: bool
) -> void:
	# Vial 2 has a very large, visibly transparent front window. Fill closer to
	# its inner walls than the old generic vessel renderer and use one continuous
	# curved polygon instead of 18 horizontal rectangles (which left gaps and
	# made the liquid look too small inside this silhouette).
	var top_y: float = rect.position.y + rect.size.y * top_ratio
	var bottom_y: float = rect.position.y + rect.size.y * bottom_ratio
	if not is_bottom:
		bottom_y += 0.85

	var surface_depth: float = 0.0
	if is_surface:
		surface_depth = minf(8.0, maxf(0.0, bottom_y - top_y) * 0.30)
	var body_top: float = top_y + surface_depth - 0.45
	if is_surface:
		_draw_wavy_surface_fill(
			rect,
			top_y,
			body_top + 1.0,
			body_top + 4.0,
			liquid_color
		)

	const SIDE_SAMPLES := 40
	var left_edge := PackedVector2Array()
	var right_edge := PackedVector2Array()
	for sample_index in range(SIDE_SAMPLES + 1):
		var t: float = float(sample_index) / float(SIDE_SAMPLES)
		var y: float = lerpf(body_top, bottom_y, t)
		var normalized_y: float = clampf(
			(y - rect.position.y) / maxf(1.0, rect.size.y),
			0.0,
			1.0
		)
		var half_width: float = maxf(
			0.0,
			rect.size.x * _get_profile_at(normalized_y).y - 1.15
		)
		left_edge.append(Vector2(rect.get_center().x - half_width, y))
		right_edge.append(Vector2(rect.get_center().x + half_width, y))

	var liquid_polygon := left_edge.duplicate()
	for point_index in range(right_edge.size() - 1, -1, -1):
		liquid_polygon.append(right_edge[point_index])

	if liquid_polygon.size() >= 3:
		var fill_color: Color = liquid_color.lerp(liquid_color.lightened(0.16), 0.10)
		draw_colored_polygon(liquid_polygon, fill_color)

	# Subtle dark contact shading gives the liquid a little depth at the glass
	# walls without leaving a conspicuous unfilled gap.
	var edge_shade: Color = liquid_color.darkened(0.25)
	edge_shade.a = 0.17
	draw_polyline(left_edge, edge_shade, 0.9, true)
	draw_polyline(right_edge, edge_shade, 0.9, true)


func _draw_wavy_surface_fill(
	rect: Rect2,
	surface_y: float,
	fill_bottom: float,
	first_strip_bottom: float,
	liquid_color: Color
) -> void:
	# A thin, smooth top cap follows the true inner contour at the current fill
	# height, expanding naturally as the chamber gets wider.
	var height: float = maxf(1.0, rect.size.y)
	var maximum_wave: float = 0.35 + _surface_activity * 2.25 + absf(_slosh) * 1.35
	var top_ratio_start: float = (
		surface_y - maximum_wave - 2.0 - rect.position.y
	) / height
	var bottom_ratio: float = (first_strip_bottom - rect.position.y) / height
	var top_half_width: float = rect.size.x * _get_min_profile_width(
		top_ratio_start,
		bottom_ratio
	) - 1.15
	var bottom_half_width: float = rect.size.x * _get_profile_at(
		clampf((fill_bottom - rect.position.y) / height, 0.0, 1.0)
	).y - 1.15
	if top_half_width <= 1.0 or bottom_half_width <= 1.0:
		return

	const SURFACE_SAMPLES := 64
	var top_edge := PackedVector2Array()
	var bottom_edge := PackedVector2Array()
	for sample_index in range(SURFACE_SAMPLES + 1):
		var normalized_x: float = float(sample_index) / float(SURFACE_SAMPLES) * 2.0 - 1.0
		var top_x: float = rect.get_center().x + normalized_x * top_half_width
		var wave_y: float = surface_y + _get_surface_wave_offset(normalized_x)
		wave_y = clampf(
			wave_y,
			surface_y - maximum_wave - 2.0,
			fill_bottom - 0.5
		)
		top_edge.append(Vector2(top_x, wave_y))

		var bottom_x: float = rect.get_center().x + normalized_x * bottom_half_width
		bottom_edge.append(Vector2(bottom_x, fill_bottom))

	var surface_polygon := top_edge.duplicate()
	for point_index in range(bottom_edge.size() - 1, -1, -1):
		surface_polygon.append(bottom_edge[point_index])
	var surface_color: Color = liquid_color.lerp(liquid_color.lightened(0.20), 0.16)
	draw_colored_polygon(surface_polygon, surface_color)

	var highlight_color: Color = surface_color.lightened(0.36)
	highlight_color.a = 0.13 + _surface_activity * 0.07 + absf(_slosh) * 0.035
	draw_polyline(top_edge, highlight_color, 1.15, true)


func _draw_glass_back(_rect: Rect2) -> void:
	# The Qwen asset supplies the rear glass and outer painted reflections.
	# Keep the transparent body clear for the live liquid drawn underneath.
	pass


func _draw_glass_overlay() -> void:
	# Preserve the square source aspect ratio while fitting the artwork to the
	# vial's height. Its transparent margins leave the actual silhouette aligned
	# with the interaction control and the wider gameplay slot.
	var source_size: Vector2 = VIAL_ART.get_size()
	var draw_scale: float = size.y / source_size.y
	var draw_size: Vector2 = source_size * draw_scale
	var draw_position := Vector2(
		(size.x - draw_size.x) * 0.5,
		(size.y - draw_size.y) * 0.5
	)
	draw_texture_rect(
		VIAL_ART,
		Rect2(draw_position, draw_size),
		false,
		Color.WHITE
	)
