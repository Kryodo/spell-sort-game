extends "res://scripts/fantasy_alchemy_bottle.gd"

# A laboratory test tube study. The glass uses the same live liquid and motion
# pipeline as the existing vessels, while the silhouette and holder are drawn
# entirely in Godot so this can be compared without generated vial artwork.

const TUBE_BODY_WIDTH_RATIO := 0.46
const TUBE_BODY_TOP_RATIO := 0.12
const TUBE_BODY_HEIGHT_RATIO := 0.77
const HOLDER_CENTRE_Y_RATIO := 0.925
const HOLDER_RADIUS_X_RATIO := 0.34
const HOLDER_RADIUS_Y_RATIO := 0.082


func _profile_points() -> Array[Vector2]:
	# Nearly parallel cylindrical walls with a long, softly rounded closed base.
	return [
		Vector2(0.00, 0.415),
		Vector2(0.035, 0.43),
		Vector2(0.78, 0.43),
		Vector2(0.87, 0.425),
		Vector2(0.925, 0.36),
		Vector2(0.972, 0.22),
		Vector2(0.994, 0.075),
		Vector2(1.00, 0.018)
	]


func _get_vessel_rect() -> Rect2:
	var tube_width := size.x * TUBE_BODY_WIDTH_RATIO
	var tube_height := size.y * TUBE_BODY_HEIGHT_RATIO
	return Rect2(
		Vector2((size.x - tube_width) * 0.5, size.y * TUBE_BODY_TOP_RATIO),
		Vector2(tube_width, tube_height)
	)


func set_front_mouth_lip_active(_active: bool) -> void:
	# The rolled glass rim is part of the tube renderer and remains visible
	# above the stream; the original artwork renderer's lip overlay is not used.
	pass


func _draw_glass_back(rect: Rect2) -> void:
	_draw_holder_back()
	super._draw_glass_back(rect)


func _draw_glass_overlay() -> void:
	var rect := _get_vessel_rect()
	_draw_tube_edges(rect)
	_draw_rounded_glass_base(rect)
	_draw_rolled_rim(rect)
	_draw_holder_front()


func _draw_holder_back() -> void:
	var centre := Vector2(size.x * 0.5, size.y * HOLDER_CENTRE_Y_RATIO)
	var radius_x := size.x * HOLDER_RADIUS_X_RATIO
	var radius_y := size.x * HOLDER_RADIUS_Y_RATIO

	# Contact shadow and broad lower flange.
	draw_colored_polygon(
		_ellipse_points(centre + Vector2(0.0, 4.0), radius_x * 1.04, radius_y * 1.10, 48),
		Color(0.0, 0.0, 0.0, 0.42)
	)
	var outer_ring := _ellipse_points(centre, radius_x, radius_y, 48)
	draw_colored_polygon(outer_ring, Color("#111918"))
	draw_polyline(_closed_points(outer_ring), Color(0.48, 0.57, 0.54, 0.54), 1.5, true)

	# Two machined steps around the opening give the low holder its circular,
	# stacked-metal profile instead of reading as a flat shadow or coaster.
	var middle_centre := centre + Vector2(0.0, -2.0)
	var middle_ring := _ellipse_points(middle_centre, radius_x * 0.84, radius_y * 0.78, 48)
	draw_colored_polygon(middle_ring, Color("#29332f"))
	draw_polyline(_closed_points(middle_ring), Color(0.57, 0.64, 0.58, 0.40), 1.2, true)

	var opening := _ellipse_points(
		centre + Vector2(0.0, -4.0),
		radius_x * 0.62,
		radius_y * 0.54,
		48
	)
	draw_colored_polygon(opening, Color("#080f0e"))
	draw_polyline(_closed_points(opening), Color(0.36, 0.44, 0.41, 0.40), 1.0, true)


func _draw_tube_edges(rect: Rect2) -> void:
	var left_edge := PackedVector2Array()
	var right_edge := PackedVector2Array()
	var left_glint := PackedVector2Array()
	var right_glint := PackedVector2Array()
	const EDGE_SAMPLES := 48

	for index in range(EDGE_SAMPLES + 1):
		var y_norm := float(index) / float(EDGE_SAMPLES)
		var profile := _get_profile_at(y_norm)
		var y := rect.position.y + rect.size.y * y_norm
		var half_width := rect.size.x * profile.y
		var left_x := rect.get_center().x - half_width
		var right_x := rect.get_center().x + half_width
		left_edge.append(Vector2(left_x, y))
		right_edge.append(Vector2(right_x, y))
		left_glint.append(Vector2(left_x + rect.size.x * 0.13, y))
		right_glint.append(Vector2(right_x - rect.size.x * 0.16, y))

	draw_polyline(left_edge, Color(0.78, 0.91, 0.94, 0.78), 2.2, true)
	draw_polyline(right_edge, Color(0.47, 0.66, 0.72, 0.48), 1.8, true)
	draw_polyline(left_glint, Color(0.88, 0.97, 0.98, 0.25), maxf(2.2, rect.size.x * 0.075), true)
	draw_polyline(left_glint, Color(0.98, 1.0, 1.0, 0.70), 1.35, true)
	draw_polyline(right_glint, Color(0.69, 0.84, 0.87, 0.25), 1.8, true)

	# A restrained curved reflection down the opposite wall makes the glass
	# read as a cylinder without filling the transparent centre.
	var inner_reflection := PackedVector2Array()
	for index in range(33):
		var t := float(index) / 32.0
		var y_norm := lerpf(0.12, 0.76, t)
		var profile := _get_profile_at(y_norm)
		var y := rect.position.y + rect.size.y * y_norm
		var x := rect.get_center().x + rect.size.x * profile.y * 0.48
		inner_reflection.append(Vector2(x, y))
	draw_polyline(inner_reflection, Color(0.87, 0.96, 0.97, 0.12), 2.0, true)


func _draw_rounded_glass_base(rect: Rect2) -> void:
	var bottom_centre := Vector2(rect.get_center().x, rect.end.y - rect.size.y * 0.012)
	var bottom_radius_x := rect.size.x * 0.22
	var bottom_radius_y := size.x * 0.020
	var base_glass := _ellipse_points(bottom_centre, bottom_radius_x, bottom_radius_y, 32)
	draw_colored_polygon(base_glass, Color(0.65, 0.82, 0.87, 0.16))
	draw_polyline(
		_ellipse_arc(bottom_centre, bottom_radius_x * 0.82, bottom_radius_y * 0.72, 0.0, PI, 24),
		Color(0.94, 0.99, 1.0, 0.54),
		1.35,
		true
	)


func _draw_rolled_rim(rect: Rect2) -> void:
	var centre := Vector2(rect.get_center().x, rect.position.y + size.x * 0.006)
	var outer_radius_x := rect.size.x * 0.54
	var outer_radius_y := size.x * 0.055
	var inner_radius_x := outer_radius_x * 0.75
	var inner_radius_y := outer_radius_y * 0.54

	# The broad outer oval and dark inner opening form a thick rolled glass lip.
	var outer_lip := _ellipse_points(centre, outer_radius_x, outer_radius_y, 40)
	draw_colored_polygon(outer_lip, Color(0.69, 0.84, 0.88, 0.50))
	draw_polyline(_closed_points(outer_lip), Color(0.87, 0.96, 0.98, 0.88), 2.0, true)

	var inner_opening := _ellipse_points(
		centre + Vector2(0.0, size.x * 0.003),
		inner_radius_x,
		inner_radius_y,
		40
	)
	draw_colored_polygon(inner_opening, Color(0.015, 0.029, 0.032, 0.96))
	draw_polyline(_closed_points(inner_opening), Color(0.49, 0.68, 0.74, 0.76), 1.15, true)

	draw_polyline(
		_ellipse_arc(centre, outer_radius_x, outer_radius_y, 0.0, PI, 28),
		Color(0.98, 1.0, 1.0, 0.92),
		2.1,
		true
	)
	draw_polyline(
		_ellipse_arc(centre, outer_radius_x * 0.91, outer_radius_y * 0.78, PI, TAU, 28),
		Color(0.58, 0.76, 0.80, 0.50),
		1.0,
		true
	)


func _draw_holder_front() -> void:
	var centre := Vector2(size.x * 0.5, size.y * HOLDER_CENTRE_Y_RATIO)
	var radius_x := size.x * HOLDER_RADIUS_X_RATIO
	var radius_y := size.x * HOLDER_RADIUS_Y_RATIO

	# Only the front arcs are redrawn here, so the tube appears seated inside
	# the holder rather than painted on top of it.
	draw_polyline(
		_ellipse_arc(centre, radius_x, radius_y, 0.0, PI, 32),
		Color("#0a1110"),
		5.0,
		true
	)
	draw_polyline(
		_ellipse_arc(centre + Vector2(0.0, -2.0), radius_x * 0.84, radius_y * 0.78, 0.0, PI, 32),
		Color(0.64, 0.72, 0.66, 0.66),
		1.55,
		true
	)
	draw_polyline(
		_ellipse_arc(centre + Vector2(0.0, -4.0), radius_x * 0.62, radius_y * 0.54, 0.0, PI, 28),
		Color(0.08, 0.13, 0.12, 0.92),
		2.2,
		true
	)


func _ellipse_arc(
	centre: Vector2,
	radius_x: float,
	radius_y: float,
	start_angle: float,
	end_angle: float,
	segments: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments + 1):
		var t := float(index) / float(segments)
		var angle := lerpf(start_angle, end_angle, t)
		points.append(centre + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points
