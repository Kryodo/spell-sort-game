extends "res://scripts/fantasy_alchemy_bottle.gd"

# A more characterful laboratory bottle study. The live liquid, slosh, drag and
# pour behaviour remain shared with the existing vessel system; only the glass
# silhouette and its reflections are authored here.

const BOTTLE_BODY_WIDTH_RATIO := 0.55
const BOTTLE_BODY_TOP_RATIO := 0.085
const BOTTLE_BODY_HEIGHT_RATIO := 0.855


func _profile_points() -> Array[Vector2]:
	# A softly curved neck opens into a broad cylindrical body. The lower
	# shoulders roll inward to a gently flattened, rounded glass foot.
	return [
		Vector2(0.000, 0.290),
		Vector2(0.025, 0.310),
		Vector2(0.065, 0.310),
		Vector2(0.115, 0.305),
		Vector2(0.165, 0.325),
		Vector2(0.220, 0.375),
		Vector2(0.285, 0.430),
		Vector2(0.350, 0.450),
		Vector2(0.700, 0.450),
		Vector2(0.790, 0.445),
		Vector2(0.865, 0.415),
		Vector2(0.915, 0.365),
		Vector2(0.955, 0.295),
		Vector2(0.982, 0.225),
		Vector2(1.000, 0.190)
	]


func _get_vessel_rect() -> Rect2:
	var bottle_width := size.x * BOTTLE_BODY_WIDTH_RATIO
	var bottle_height := size.y * BOTTLE_BODY_HEIGHT_RATIO
	return Rect2(
		Vector2((size.x - bottle_width) * 0.5, size.y * BOTTLE_BODY_TOP_RATIO),
		Vector2(bottle_width, bottle_height)
	)


func set_front_mouth_lip_active(_active: bool) -> void:
	# The glass lip is drawn as part of the vessel. The inherited image-based
	# mouth overlay is intentionally unused for this procedural renderer.
	pass


func _draw_glass_back(rect: Rect2) -> void:
	# Keep the existing soft translucent body shading and place the inner
	# bottom reflection behind the liquid, so the liquid inherits the glass depth.
	super._draw_glass_back(rect)
	_draw_inner_bottom_back_highlight(rect)


func _draw_glass_overlay() -> void:
	var rect := _get_vessel_rect()
	_draw_bottle_edges(rect)
	_draw_rounded_glass_base(rect)
	_draw_flared_rolled_rim(rect)


func _draw_bottle_edges(rect: Rect2) -> void:
	var left_edge := PackedVector2Array()
	var right_edge := PackedVector2Array()
	var left_glint := PackedVector2Array()
	var right_glint := PackedVector2Array()
	const EDGE_SAMPLES := 56

	for index in range(EDGE_SAMPLES + 1):
		var y_norm := float(index) / float(EDGE_SAMPLES)
		var profile := _get_profile_at(y_norm)
		var y := rect.position.y + rect.size.y * y_norm
		var half_width := rect.size.x * profile.y
		var left_x := rect.get_center().x - half_width
		var right_x := rect.get_center().x + half_width
		left_edge.append(Vector2(left_x, y))
		right_edge.append(Vector2(right_x, y))
		left_glint.append(Vector2(left_x + rect.size.x * 0.145, y))
		right_glint.append(Vector2(right_x - rect.size.x * 0.155, y))

	# Distinct but soft wall edges preserve transparency and give the thicker
	# bottle shoulders a readable silhouette.
	draw_polyline(left_edge, Color(0.80, 0.93, 0.96, 0.78), 2.25, true)
	draw_polyline(right_edge, Color(0.47, 0.66, 0.72, 0.50), 1.9, true)
	draw_polyline(left_glint, Color(0.88, 0.97, 0.98, 0.22), maxf(2.4, rect.size.x * 0.058), true)
	draw_polyline(left_glint, Color(0.98, 1.0, 1.0, 0.72), 1.35, true)
	draw_polyline(right_glint, Color(0.69, 0.84, 0.87, 0.23), 1.8, true)

	# A short inner reflection on the right wall suggests glass thickness
	# without turning the clear centre into a filled shape.
	var inner_reflection := PackedVector2Array()
	for index in range(35):
		var t := float(index) / 34.0
		var y_norm := lerpf(0.19, 0.82, t)
		var profile := _get_profile_at(y_norm)
		var y := rect.position.y + rect.size.y * y_norm
		var x := rect.get_center().x + rect.size.x * profile.y * 0.56
		inner_reflection.append(Vector2(x, y))
	draw_polyline(inner_reflection, Color(0.88, 0.97, 0.98, 0.13), 1.6, true)


func _draw_inner_bottom_back_highlight(rect: Rect2) -> void:
	# A shallow arch just above the foot reads as the far inner wall of the
	# glass. It is drawn under the liquid, so it remains subdued when filled.
	var centre := Vector2(
		rect.get_center().x,
		rect.end.y - rect.size.y * 0.075
	)
	var radius_x := rect.size.x * 0.235
	var radius_y := size.x * 0.040
	var back_arc := _ellipse_arc(
		centre,
		radius_x,
		radius_y,
		PI + 0.16,
		TAU - 0.16,
		28
	)
	draw_polyline(back_arc, Color(0.91, 0.98, 0.99, 0.22), 1.35, true)


func _draw_rounded_glass_base(rect: Rect2) -> void:
	var bottom_centre := Vector2(rect.get_center().x, rect.end.y - 1.0)
	var bottom_radius_x := rect.size.x * 0.19
	var bottom_radius_y := size.x * 0.021
	var base_glass := _ellipse_points(bottom_centre, bottom_radius_x, bottom_radius_y, 36)
	draw_colored_polygon(base_glass, Color(0.65, 0.82, 0.87, 0.17))
	draw_polyline(
		_ellipse_arc(
			bottom_centre,
			bottom_radius_x * 0.88,
			bottom_radius_y * 0.72,
			0.10,
			PI - 0.10,
			28
		),
		Color(0.94, 0.99, 1.0, 0.48),
		1.35,
		true
	)
	# A cooler lower edge separates the rounded foot from the ground shadow.
	draw_polyline(
		_ellipse_arc(
			bottom_centre + Vector2(0.0, 1.0),
			bottom_radius_x * 0.72,
			bottom_radius_y * 0.48,
			PI + 0.18,
			TAU - 0.18,
			24
		),
		Color(0.50, 0.70, 0.76, 0.30),
		1.0,
		true
	)


func _draw_flared_rolled_rim(rect: Rect2) -> void:
	var centre := Vector2(rect.get_center().x, rect.position.y + size.x * 0.006)
	var outer_radius_x := rect.size.x * 0.365
	var outer_radius_y := size.x * 0.048
	var inner_radius_x := outer_radius_x * 0.755
	var inner_radius_y := outer_radius_y * 0.56

	# The flared roll is broad enough to catch light, but stays clearly smaller
	# than the body so the mouth feels like a bottle neck, not a test-tube rim.
	var outer_lip := _ellipse_points(centre, outer_radius_x, outer_radius_y, 40)
	draw_colored_polygon(outer_lip, Color(0.70, 0.85, 0.89, 0.48))
	draw_polyline(_closed_points(outer_lip), Color(0.89, 0.97, 0.99, 0.90), 1.9, true)

	var inner_opening := _ellipse_points(
		centre + Vector2(0.0, size.x * 0.003),
		inner_radius_x,
		inner_radius_y,
		40
	)
	draw_colored_polygon(inner_opening, Color(0.015, 0.029, 0.032, 0.96))
	draw_polyline(_closed_points(inner_opening), Color(0.50, 0.69, 0.75, 0.76), 1.1, true)

	# Bright forward rolled edge and a dimmer rear edge establish the lip's
	# thickness and the depth of the opening.
	draw_polyline(
		_ellipse_arc(centre, outer_radius_x, outer_radius_y, 0.0, PI, 28),
		Color(0.98, 1.0, 1.0, 0.90),
		2.0,
		true
	)
	draw_polyline(
		_ellipse_arc(
			centre + Vector2(0.0, -size.x * 0.004),
			outer_radius_x * 0.91,
			outer_radius_y * 0.76,
			PI,
			TAU,
			28
		),
		Color(0.55, 0.73, 0.78, 0.48),
		1.0,
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
