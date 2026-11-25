extends Node2D

signal activated

@export_range(0.0, 1.0, 0.01) var fill_level: float = 0.62
@export var animate_liquid: bool = true
@export var liquid_color: Color = Color(0.12, 0.72, 0.55, 1.0)

const LIQUID_CENTER := Vector2(120.0, 76.0)
const LIQUID_RADIUS := Vector2(78.0, 17.0)
const SURFACE_SEGMENTS := 56

# x = normalized horizontal position, y = phase offset, z = bubble radius.
const BUBBLES: Array[Vector3] = [
	Vector3(-0.62, 0.12, 2.2),
	Vector3(-0.34, 0.54, 1.8),
	Vector3(-0.08, 0.28, 2.7),
	Vector3(0.18, 0.78, 1.7),
	Vector3(0.43, 0.37, 2.3),
	Vector3(0.66, 0.91, 1.6),
	Vector3(0.02, 0.06, 1.4),
	Vector3(-0.48, 0.84, 1.5)
]

var _time := 0.0


func _ready() -> void:
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not animate_liquid:
		return
	_time += delta
	queue_redraw()


func set_fill_level(value: float) -> void:
	fill_level = clampf(value, 0.0, 1.0)
	queue_redraw()


func set_liquid_color(value: Color) -> void:
	liquid_color = value
	queue_redraw()


func _draw() -> void:
	if fill_level <= 0.005:
		return
	_draw_liquid_surface()
	if animate_liquid:
		_draw_bubbles()


func _draw_liquid_surface() -> void:
	var cx: float = LIQUID_CENTER.x
	var cy: float = LIQUID_CENTER.y
	var rx: float = LIQUID_RADIUS.x
	var ry: float = LIQUID_RADIUS.y

	var surface_y: float = cy + ry - (ry * 2.0 * fill_level)
	var normalized_surface: float = clampf((surface_y - cy) / ry, -1.0, 1.0)
	var half_span: float = sqrt(maxf(0.0, 1.0 - normalized_surface * normalized_surface))
	if surface_y <= cy:
		half_span = 1.0
	if half_span <= 0.01:
		return

	var top_edge := PackedVector2Array()
	var polygon := PackedVector2Array()
	var colors := PackedColorArray()

	for index in range(SURFACE_SEGMENTS + 1):
		var t: float = float(index) / float(SURFACE_SEGMENTS)
		var normalized_x: float = lerpf(-half_span, half_span, t)
		var envelope: float = sin(t * PI)
		var wave: float = 0.9 * sin(_time * 2.0 + normalized_x * 4.2)
		wave += 0.48 * sin(_time * 2.8 - normalized_x * 7.0)
		var x: float = cx + normalized_x * rx
		var y: float = surface_y + wave * envelope
		y = minf(y, _get_lower_ellipse_y(normalized_x) - 1.0)
		var point := Vector2(x, y)
		top_edge.append(point)
		polygon.append(point)
		colors.append(liquid_color.lightened(0.13))

	# Follow the lower curve of the bowl opening back to the left edge.
	for index in range(SURFACE_SEGMENTS, -1, -1):
		var t: float = float(index) / float(SURFACE_SEGMENTS)
		var normalized_x: float = lerpf(-half_span, half_span, t)
		polygon.append(Vector2(
			cx + normalized_x * rx,
			_get_lower_ellipse_y(normalized_x)
		))
		colors.append(liquid_color.darkened(0.30))

	draw_polygon(polygon, colors)

	# A darker meniscus gives the liquid a little thickness against the metal.
	var meniscus := PackedVector2Array()
	for point in top_edge:
		meniscus.append(point + Vector2(0.0, 1.25))
	var meniscus_color := liquid_color.darkened(0.24)
	meniscus_color.a = 0.48
	draw_polyline(meniscus, meniscus_color, 2.0, true)

	var surface_glint := liquid_color.lightened(0.48)
	surface_glint.a = 0.72
	draw_polyline(top_edge, surface_glint, 1.35, true)

	# Broken, soft reflections on the liquid, not a hard white outline.
	var reflection := PackedVector2Array()
	for index in range(12):
		var t: float = float(index) / 11.0
		var normalized_x: float = lerpf(-0.35, -0.04, t)
		var x: float = cx + normalized_x * rx
		var y: float = surface_y - 1.2 + sin(t * PI) * 0.7
		reflection.append(Vector2(x, y))
	var reflection_color := Color(0.80, 1.0, 0.89, 0.38)
	draw_polyline(reflection, reflection_color, 2.1, true)


func _draw_bubbles() -> void:
	var cy: float = LIQUID_CENTER.y
	var ry: float = LIQUID_RADIUS.y
	var surface_y: float = cy + ry - (ry * 2.0 * fill_level)
	var normalized_surface: float = clampf((surface_y - cy) / ry, -1.0, 1.0)
	var half_span: float = sqrt(maxf(0.0, 1.0 - normalized_surface * normalized_surface))
	if surface_y <= cy:
		half_span = 1.0

	for index in range(BUBBLES.size()):
		var bubble: Vector3 = BUBBLES[index]
		var x_limit: float = maxf(0.08, half_span * 0.78)
		var normalized_x: float = clampf(bubble.x, -x_limit, x_limit)
		var phase: float = fposmod(_time * (0.19 + float(index % 3) * 0.035) + bubble.y, 1.0)
		var lower_y: float = _get_lower_ellipse_y(normalized_x) - 2.0
		var upper_y: float = surface_y + 3.0
		var x: float = LIQUID_CENTER.x + normalized_x * LIQUID_RADIUS.x
		x += sin(_time * 1.3 + float(index) * 1.7) * 1.4
		var y: float = lerpf(lower_y, upper_y, phase)
		var fade: float = sin(phase * PI)
		var radius: float = bubble.z * (0.72 + phase * 0.24)
		var bubble_fill := Color(0.70, 1.0, 0.91, 0.12 + fade * 0.20)
		var bubble_edge := Color(0.83, 1.0, 0.95, 0.18 + fade * 0.44)
		draw_circle(Vector2(x, y), radius, bubble_fill)
		draw_arc(Vector2(x, y), radius, 0.0, TAU, 20, bubble_edge, 0.85, true)
		draw_circle(Vector2(x - radius * 0.30, y - radius * 0.32), maxf(0.5, radius * 0.22), Color(0.95, 1.0, 0.97, 0.58))


func _get_lower_ellipse_y(normalized_x: float) -> float:
	var inside: float = maxf(0.0, 1.0 - normalized_x * normalized_x)
	return LIQUID_CENTER.y + LIQUID_RADIUS.y * sqrt(inside)


func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	pass
