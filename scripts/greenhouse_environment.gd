extends Control

# Reusable chapter environment component. All geometry belongs to this scene;
# no sorting slots, vial count or HUD layout is baked into the environment.

func _draw() -> void:
	_draw_greenhouse_environment()


func _draw_greenhouse_environment() -> void:
	# A compact, hand-crafted greenhouse study: architecture and props establish
	# the place, while the centre of the work surface remains free for gameplay.
	draw_rect(Rect2(0.0, 0.0, 720.0, 1280.0), Color("#101d1c"))
	draw_rect(Rect2(0.0, 0.0, 720.0, 670.0), Color("#172b28"))
	draw_rect(Rect2(0.0, 670.0, 720.0, 610.0), Color("#17201d"))

	# Tall greenhouse glazing and the central arched window.
	draw_colored_polygon(PackedVector2Array([
		Vector2(78.0, 76.0), Vector2(642.0, 76.0),
		Vector2(624.0, 542.0), Vector2(96.0, 542.0)
	]), Color("#213b36"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(154.0, 512.0), Vector2(154.0, 278.0),
		Vector2(178.0, 186.0), Vector2(250.0, 115.0),
		Vector2(360.0, 91.0), Vector2(470.0, 115.0),
		Vector2(542.0, 186.0), Vector2(566.0, 278.0),
		Vector2(566.0, 512.0)
	]), Color("#31534a"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(171.0, 500.0), Vector2(171.0, 279.0),
		Vector2(193.0, 194.0), Vector2(258.0, 132.0),
		Vector2(360.0, 110.0), Vector2(462.0, 132.0),
		Vector2(527.0, 194.0), Vector2(549.0, 279.0),
		Vector2(549.0, 500.0)
	]), Color("#45685a"))
	# Soft light behind the glass panes.
	for ring in range(8, 0, -1):
		var alpha: float = 0.008 + float(8 - ring) * 0.002
		draw_circle(Vector2(360.0, 300.0), float(ring) * 49.0, Color(0.78, 0.83, 0.57, alpha))

	# Window mullions and timber frame.
	draw_polyline(PackedVector2Array([
		Vector2(154.0, 512.0), Vector2(154.0, 278.0),
		Vector2(178.0, 186.0), Vector2(250.0, 115.0),
		Vector2(360.0, 91.0), Vector2(470.0, 115.0),
		Vector2(542.0, 186.0), Vector2(566.0, 278.0),
		Vector2(566.0, 512.0)
	]), Color("#6f573b"), 15.0, true)
	draw_line(Vector2(360.0, 100.0), Vector2(360.0, 510.0), Color("#8b7049"), 8.0, true)
	draw_line(Vector2(165.0, 292.0), Vector2(555.0, 292.0), Color("#8b7049"), 7.0, true)
	draw_line(Vector2(252.0, 132.0), Vector2(252.0, 510.0), Color("#745b3e"), 5.0, true)
	draw_line(Vector2(468.0, 132.0), Vector2(468.0, 510.0), Color("#745b3e"), 5.0, true)
	draw_line(Vector2(86.0, 536.0), Vector2(634.0, 536.0), Color("#94704a"), 12.0, true)

	# Receding stone wall piers and sill.
	draw_colored_polygon(PackedVector2Array([
		Vector2(32.0, 118.0), Vector2(88.0, 118.0),
		Vector2(104.0, 620.0), Vector2(30.0, 620.0)
	]), Color("#35423a"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(632.0, 118.0), Vector2(688.0, 118.0),
		Vector2(690.0, 620.0), Vector2(616.0, 620.0)
	]), Color("#2d3b34"))
	_draw_plant_cluster(Vector2(80.0, 556.0), 0.95, Color("#5b8750"))
	_draw_plant_cluster(Vector2(644.0, 540.0), 0.92, Color("#6b9354"))

	# Left botanical shelves.
	_draw_shelf(Vector2(25.0, 350.0), Vector2(177.0, 20.0))
	_draw_shelf(Vector2(25.0, 478.0), Vector2(177.0, 18.0))
	_draw_pot(Vector2(66.0, 339.0), 0.76, Color("#a66e43"))
	_draw_pot(Vector2(137.0, 339.0), 0.68, Color("#896344"))
	_draw_plant_cluster(Vector2(66.0, 322.0), 0.48, Color("#76a65d"))
	_draw_plant_cluster(Vector2(137.0, 324.0), 0.44, Color("#83a960"))
	_draw_pot(Vector2(95.0, 466.0), 0.64, Color("#9a6841"))
	_draw_plant_cluster(Vector2(95.0, 451.0), 0.45, Color("#668d4c"))

	# Right archive shelves and vessels.
	_draw_shelf(Vector2(518.0, 350.0), Vector2(177.0, 20.0))
	_draw_shelf(Vector2(518.0, 478.0), Vector2(177.0, 18.0))
	_draw_book(Vector2(548.0, 310.0), 0.72, -0.07)
	_draw_book(Vector2(612.0, 315.0), 0.62, 0.08)
	_draw_crystal_cluster(Vector2(583.0, 449.0), 0.9)

	# Hanging vines around the window without closing the playable centre.
	_draw_vine(Vector2(105.0, 95.0), Vector2(130.0, 430.0), Color("#547d49"))
	_draw_vine(Vector2(609.0, 92.0), Vector2(584.0, 410.0), Color("#61844a"))

	# Central worktable: broad, open surface for an apparatus that can change
	# per experiment rather than a rack baked into this scene.
	draw_colored_polygon(PackedVector2Array([
		Vector2(42.0, 686.0), Vector2(678.0, 686.0),
		Vector2(715.0, 954.0), Vector2(5.0, 954.0)
	]), Color("#493322"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(55.0, 694.0), Vector2(665.0, 694.0),
		Vector2(694.0, 932.0), Vector2(26.0, 932.0)
	]), Color("#805638"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(26.0, 932.0), Vector2(694.0, 932.0),
		Vector2(678.0, 1075.0), Vector2(43.0, 1075.0)
	]), Color("#4b3021"))
	draw_line(Vector2(36.0, 945.0), Vector2(684.0, 945.0), Color("#c08a55"), 4.0, true)
	draw_line(Vector2(48.0, 1064.0), Vector2(671.0, 1064.0), Color("#2e2119"), 5.0, true)
	for line_index in range(5):
		var y: float = 724.0 + float(line_index) * 42.0
		draw_line(Vector2(80.0, y), Vector2(640.0, y - 3.0), Color(0.28, 0.16, 0.095, 0.22), 1.2, true)
	# A quiet brass inlay: this is a place marker, not a fixed vial layout.
	draw_arc(Vector2(360.0, 816.0), 112.0, 0.0, TAU, 96, Color(0.91, 0.68, 0.37, 0.42), 3.0, true)
	draw_arc(Vector2(360.0, 816.0), 91.0, 0.0, TAU, 96, Color(0.91, 0.68, 0.37, 0.22), 1.5, true)
	draw_line(Vector2(248.0, 816.0), Vector2(472.0, 816.0), Color(0.91, 0.68, 0.37, 0.24), 1.0, true)
	draw_line(Vector2(360.0, 704.0), Vector2(360.0, 928.0), Color(0.91, 0.68, 0.37, 0.24), 1.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(360.0, 788.0), Vector2(388.0, 816.0),
		Vector2(360.0, 844.0), Vector2(332.0, 816.0)
	]), Color(0.69, 0.78, 0.60, 0.28))
	_draw_book(Vector2(78.0, 745.0), 0.86, -0.08)
	_draw_pot(Vector2(600.0, 738.0), 0.78, Color("#a86c42"))
	_draw_plant_cluster(Vector2(600.0, 720.0), 0.36, Color("#699455"))

	# Floor stones and foreground foliage.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, 1082.0), Vector2(720.0, 1082.0),
		Vector2(720.0, 1280.0), Vector2(0.0, 1280.0)
	]), Color("#1d2924"))
	for stone_index in range(5):
		var stone_x: float = 74.0 + float(stone_index) * 143.0
		draw_line(Vector2(stone_x, 1120.0), Vector2(stone_x + 55.0, 1270.0), Color(0.54, 0.62, 0.49, 0.12), 2.0, true)
	_draw_pot(Vector2(47.0, 1135.0), 0.83, Color("#77553b"))
	_draw_plant_cluster(Vector2(47.0, 1115.0), 0.75, Color("#527d47"))
	_draw_pot(Vector2(673.0, 1140.0), 0.86, Color("#79543a"))
	_draw_plant_cluster(Vector2(673.0, 1120.0), 0.74, Color("#63884c"))

	# Warm lanterns and drifting motes.
	_draw_lantern(Vector2(210.0, 579.0))
	_draw_lantern(Vector2(510.0, 579.0))
	for mote_index in range(17):
		var px: float = 125.0 + float((mote_index * 79) % 475)
		var py: float = 180.0 + float((mote_index * 53) % 620)
		draw_circle(Vector2(px, py), 1.8 + float(mote_index % 3) * 0.6, Color(0.89, 0.76, 0.47, 0.25))


func _draw_shelf(position_value: Vector2, size_value: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		position_value,
		position_value + Vector2(size_value.x, 0.0),
		position_value + Vector2(size_value.x + 8.0, size_value.y),
		position_value + Vector2(-6.0, size_value.y)
	]), Color("#5e402b"))
	draw_line(position_value + Vector2(0.0, 2.0), position_value + Vector2(size_value.x, 2.0), Color("#bd8951"), 3.0, true)
	draw_line(position_value + Vector2(12.0, size_value.y), position_value + Vector2(12.0, size_value.y + 23.0), Color("#3d2c20"), 5.0, true)
	draw_line(position_value + Vector2(size_value.x - 12.0, size_value.y), position_value + Vector2(size_value.x - 12.0, size_value.y + 23.0), Color("#3d2c20"), 5.0, true)


func _draw_pot(base: Vector2, scale_value: float, tint: Color) -> void:
	var w: float = 29.0 * scale_value
	var h: float = 33.0 * scale_value
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-w, -h), base + Vector2(w, -h),
		base + Vector2(w * 0.76, 0.0), base + Vector2(-w * 0.76, 0.0)
	]), tint)
	_draw_ellipse(base + Vector2(0.0, -h), w, 6.0 * scale_value, tint.lightened(0.2))
	draw_line(base + Vector2(-w * 0.65, -h * 0.35), base + Vector2(w * 0.65, -h * 0.35), tint.darkened(0.22), 2.0, true)
	draw_line(base + Vector2(-w * 0.72, -4.0), base + Vector2(w * 0.72, -4.0), tint.darkened(0.28), 2.0, true)


func _draw_ellipse(center: Vector2, radius_x: float, radius_y: float, tint: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		var angle: float = TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_colored_polygon(points, tint)


func _draw_leaf(center: Vector2, length: float, width: float, angle: float, tint: Color) -> void:
	var direction := Vector2(cos(angle), sin(angle))
	var side := Vector2(-direction.y, direction.x)
	var p0: Vector2 = center - direction * length * 0.5
	var p1: Vector2 = center - direction * length * 0.16 + side * width * 0.52
	var p2: Vector2 = center + direction * length * 0.27 + side * width * 0.30
	var p3: Vector2 = center + direction * length * 0.5
	var p4: Vector2 = center + direction * length * 0.20 - side * width * 0.36
	var p5: Vector2 = center - direction * length * 0.20 - side * width * 0.48
	draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3, p4, p5]), tint)


func _draw_plant_cluster(origin: Vector2, scale_value: float, tint: Color) -> void:
	for index in range(9):
		var angle: float = -PI * 0.90 + float(index) * PI * 0.225
		var length: float = (42.0 + float((index * 13) % 24)) * scale_value
		var end: Vector2 = origin + Vector2(cos(angle) * length * 0.66, sin(angle) * length)
		draw_line(origin, end, tint.darkened(0.24), 3.0 * scale_value, true)
		_draw_leaf(end - Vector2(cos(angle) * 12.0, sin(angle) * 12.0), 36.0 * scale_value, 17.0 * scale_value, angle + 0.38, tint.lightened(float(index % 3) * 0.06))
		_draw_leaf(end + Vector2(cos(angle) * 7.0, sin(angle) * 8.0), 27.0 * scale_value, 13.0 * scale_value, angle - 0.42, tint.darkened(0.08))


func _draw_vine(start: Vector2, finish: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for index in range(17):
		var t: float = float(index) / 16.0
		var x: float = lerpf(start.x, finish.x, t) + sin(t * TAU * 1.4) * 14.0
		var y: float = lerpf(start.y, finish.y, t)
		points.append(Vector2(x, y))
	draw_polyline(points, tint.darkened(0.2), 4.0, true)
	for index in range(1, 16, 2):
		var point: Vector2 = points[index]
		var side_angle: float = -0.7 if index % 4 == 1 else 2.5
		_draw_leaf(point + Vector2(10.0, 0.0), 31.0, 13.0, side_angle, tint)


func _draw_book(position_value: Vector2, scale_value: float, angle: float) -> void:
	var centre := position_value
	var x_axis := Vector2(cos(angle), sin(angle))
	var y_axis := Vector2(-sin(angle), cos(angle))
	var half_w: float = 47.0 * scale_value
	var half_h: float = 31.0 * scale_value
	var corners := PackedVector2Array([
		centre - x_axis * half_w - y_axis * half_h,
		centre + x_axis * half_w - y_axis * half_h,
		centre + x_axis * half_w + y_axis * half_h,
		centre - x_axis * half_w + y_axis * half_h
	])
	draw_colored_polygon(corners, Color("#34241d"))
	draw_colored_polygon(PackedVector2Array([
		corners[0] + Vector2(4.0, -2.0), corners[1] + Vector2(-4.0, -2.0),
		corners[2] + Vector2(-4.0, -5.0), centre + Vector2(0.0, -4.0)
	]), Color("#c3a676"))
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(0.0, -4.0), corners[2] + Vector2(-4.0, -5.0),
		corners[3] + Vector2(4.0, -5.0)
	]), Color("#e0c796"))
	draw_line(centre + Vector2(0.0, -27.0 * scale_value), centre + Vector2(0.0, 25.0 * scale_value), Color("#6e4a2e"), 2.0, true)


func _draw_crystal_cluster(center: Vector2, scale_value: float) -> void:
	for index in range(5):
		var offset_x: float = (float(index) - 2.0) * 13.0 * scale_value
		var height: float = (26.0 + float((index * 17) % 23)) * scale_value
		var base := Vector2(center.x + offset_x, center.y)
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-8.0 * scale_value, 0.0),
			base + Vector2(-5.0 * scale_value, -height * 0.64),
			base + Vector2(0.0, -height),
			base + Vector2(7.0 * scale_value, -height * 0.54),
			base + Vector2(8.0 * scale_value, 0.0)
		]), Color("#6d9c91") if index % 2 == 0 else Color("#7c8db5"))
		draw_line(base + Vector2(0.0, -height * 0.78), base + Vector2(3.0, -4.0), Color(0.84, 0.96, 0.83, 0.52), 1.5, true)


func _draw_lantern(center: Vector2) -> void:
	draw_line(center + Vector2(0.0, -45.0), center + Vector2(0.0, -15.0), Color("#8b7049"), 3.0, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-15.0, -15.0), center + Vector2(15.0, -15.0),
		center + Vector2(19.0, 20.0), center + Vector2(-19.0, 20.0)
	]), Color("#60432b"))
	draw_rect(Rect2(center + Vector2(-10.0, -9.0), Vector2(20.0, 23.0)), Color(1.0, 0.68, 0.32, 0.28))
	draw_line(center + Vector2(-12.0, -15.0), center + Vector2(12.0, -15.0), Color("#c69b5b"), 3.0, true)
	draw_arc(center + Vector2(0.0, 3.0), 33.0, 0.0, TAU, 32, Color(1.0, 0.67, 0.28, 0.08), 13.0, true)
