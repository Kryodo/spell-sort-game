extends Node2D

@export_range(0.0, 1.0, 0.01) var fill_level: float = 1.0
@export var animate_liquid: bool = true
@export var liquid_color: Color = Color(0.12, 0.72, 0.55, 1.0)

const LIQUID_CENTER := Vector2(120.0, 76.0)
const LIQUID_RADIUS := Vector2(78.0, 16.5)
const SURFACE_SEGMENTS := 72

# x and y are normalized positions inside the liquid oval; z is bubble radius.
const BUBBLES: Array[Vector3] = [
	Vector3(-0.58, -0.18, 1.7),
	Vector3(-0.34, 0.34, 1.5),
	Vector3(-0.12, -0.43, 2.0),
	Vector3(0.12, 0.16, 1.6),
	Vector3(0.37, -0.22, 1.8),
	Vector3(0.58, 0.28, 1.4),
	Vector3(0.02, 0.48, 1.3)
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
	# The cauldron is viewed from above: the liquid must cover the complete
	# visible oval, rather than looking like a horizontal slice through it.
	# Lower fill levels contract the surface slightly while keeping it inside
	# the brass opening.
	var surface_scale: float = lerpf(0.86, 1.0, fill_level)
	var radius := LIQUID_RADIUS * surface_scale
	var center := LIQUID_CENTER + Vector2(0.0, (1.0 - surface_scale) * 1.8)

	var surface_points := _make_ellipse(center, radius)
	var surface_color := liquid_color
	surface_color.a = 1.0
	draw_colored_polygon(surface_points, surface_color)

	# Soft depth near the front half gives the liquid some volume without
	# exposing the dark bowl underneath or creating a moving cut-out edge.
	var depth_color := liquid_color.darkened(0.24)
	depth_color.a = 0.16
	draw_colored_polygon(
		_make_ellipse(center + Vector2(0.0, radius.y * 0.20), radius * Vector2(0.78, 0.56)),
		depth_color
	)

	_draw_surface_ripples(center, radius)


func _draw_surface_ripples(center: Vector2, radius: Vector2) -> void:
	var ripple_specs: Array[Vector3] = [
		Vector3(-0.30, -0.22, 13.0),
		Vector3(0.23, -0.04, 17.0),
		Vector3(-0.02, 0.34, 10.0)
	]

	for index in range(ripple_specs.size()):
		var ripple: Vector3 = ripple_specs[index]
		var points := PackedVector2Array()
		var ripple_center_x: float = ripple.x * radius.x
		var ripple_center_y: float = ripple.y * radius.y
		var half_width: float = ripple.z * 0.5
		for point_index in range(15):
			var t: float = float(point_index) / 14.0
			var local_x: float = ripple_center_x + lerpf(-half_width, half_width, t)
			var normalized_x: float = clampf(local_x / radius.x, -0.96, 0.96)
			var vertical_limit: float = radius.y * sqrt(maxf(0.0, 1.0 - normalized_x * normalized_x))
			var wave: float = sin(t * PI) * 0.9
			wave += sin(_time * 0.72 + float(index) * 1.8 + t * PI * 2.0) * 0.28
			var local_y: float = clampf(
				ripple_center_y + wave,
				-vertical_limit + 0.8,
				vertical_limit - 0.8
			)
			points.append(center + Vector2(local_x, local_y))

		var ripple_color := liquid_color.lightened(0.52)
		ripple_color.a = 0.22 if index == 0 else 0.14
		draw_polyline(points, ripple_color, 1.15, true)


func _draw_bubbles() -> void:
	var surface_scale: float = lerpf(0.86, 1.0, fill_level)
	var radius := LIQUID_RADIUS * surface_scale
	var center := LIQUID_CENTER + Vector2(0.0, (1.0 - surface_scale) * 1.8)

	for index in range(BUBBLES.size()):
		var bubble: Vector3 = BUBBLES[index]
		# Gentle bobbing is continuous and deliberately never fades to zero,
		# so the liquid does not flash or appear to switch on and off.
		var drift_x: float = sin(_time * 0.58 + float(index) * 1.7) * 0.75
		var drift_y: float = sin(_time * 0.76 + float(index) * 2.1) * 0.85
		var position := center + Vector2(
			bubble.x * radius.x + drift_x,
			bubble.y * radius.y + drift_y
		)
		var bubble_radius: float = bubble.z * (1.0 + sin(_time * 0.9 + float(index)) * 0.045)

		var bubble_fill := Color(0.78, 1.0, 0.94, 0.13)
		var bubble_edge := Color(0.88, 1.0, 0.97, 0.34)
		draw_circle(position, bubble_radius, bubble_fill)
		draw_arc(position, bubble_radius, 0.0, TAU, 20, bubble_edge, 0.8, true)
		draw_circle(
			position + Vector2(-bubble_radius * 0.28, -bubble_radius * 0.32),
			maxf(0.45, bubble_radius * 0.20),
			Color(0.96, 1.0, 0.98, 0.42)
		)


func _make_ellipse(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(SURFACE_SEGMENTS):
		var angle: float = TAU * float(index) / float(SURFACE_SEGMENTS)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
