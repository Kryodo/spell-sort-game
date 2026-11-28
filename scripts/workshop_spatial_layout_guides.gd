extends Control

# Coordinates are mapped from the 720 x 1280 screenshot of the generated
# workshop background. These are development guides, not final gameplay UI.

const SLOT_CENTERS: Array[Vector2] = [
	Vector2(207.0, 826.0),
	Vector2(309.0, 826.0),
	Vector2(411.0, 826.0),
	Vector2(513.0, 826.0)
]
const SLOT_SIZE := Vector2(64.0, 200.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	# PackedVector2Array values are constructed here at runtime. GDScript
	# does not accept PackedVector2Array constructors as constant expressions.
	var tabletop := PackedVector2Array([
		Vector2(125.0, 480.0),
		Vector2(597.0, 480.0),
		Vector2(708.0, 902.0),
		Vector2(9.0, 902.0)
	])
	var tabletop_closed := PackedVector2Array([
		tabletop[0], tabletop[1], tabletop[2], tabletop[3], tabletop[0]
	])
	draw_polyline(tabletop_closed, Color(1.0, 0.72, 0.28, 0.95), 3.0, true)

	# The provisional sorting footprint deliberately begins below the book,
	# mortar and potion props, then widens toward the front of the table.
	var sorting_area := PackedVector2Array([
		Vector2(158.0, 610.0),
		Vector2(562.0, 610.0),
		Vector2(640.0, 860.0),
		Vector2(80.0, 860.0)
	])
	draw_colored_polygon(sorting_area, Color(0.20, 0.88, 0.69, 0.075))
	var sorting_closed := PackedVector2Array([
		sorting_area[0], sorting_area[1],
		sorting_area[2], sorting_area[3],
		sorting_area[0]
	])
	draw_polyline(sorting_closed, Color(0.26, 0.96, 0.77, 0.92), 2.0, true)

	var font: Font = ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(246.0, 598.0),
		"PROVISIONAL SORTING AREA",
		HORIZONTAL_ALIGNMENT_CENTER,
		228.0,
		16,
		Color(0.76, 1.0, 0.91, 0.98)
	)

	# Ghost silhouettes show the intended scale and spacing of four vials.
	# They are only placement guides; the real vial visuals are not added yet.
	for index in range(SLOT_CENTERS.size()):
		var center: Vector2 = SLOT_CENTERS[index]
		var rect := Rect2(
			Vector2(center.x - SLOT_SIZE.x * 0.5, center.y - SLOT_SIZE.y),
			SLOT_SIZE
		)
		draw_rect(rect, Color(0.25, 0.95, 0.78, 0.10), true)
		draw_rect(rect, Color(0.48, 1.0, 0.84, 0.88), false, 2.0, true)
		draw_line(
			Vector2(center.x - 10.0, center.y),
			Vector2(center.x + 10.0, center.y),
			Color(1.0, 0.92, 0.58, 0.95),
			2.0,
			true
		)
		draw_string(
			font,
			Vector2(center.x - 8.0, center.y - SLOT_SIZE.y * 0.5 + 5.0),
			str(index + 1),
			HORIZONTAL_ALIGNMENT_CENTER,
			16.0,
			13,
			Color(0.88, 1.0, 0.95, 0.98)
		)

	draw_string(
		font,
		Vector2(18.0, 938.0),
		"TABLE EDGE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		Color(1.0, 0.82, 0.52, 0.96)
	)
