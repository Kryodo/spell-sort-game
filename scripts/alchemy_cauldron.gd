extends Node2D

@export_range(0.0, 1.0, 0.01) var fill_level: float = 1.0
@export var animate_liquid: bool = true
@export var liquid_color: Color = Color(0.12, 0.72, 0.55, 1.0)

const LIQUID_CENTER := Vector2(120.0, 76.0)
const LIQUID_RADIUS := Vector2(78.0, 16.5)
const SURFACE_SEGMENTS := 72

# x and y are normalized positions inside the liquid oval; z is bubble radius.
const BUBBLES: Array[Vector3] = [
	Vector3(-0.64, -0.20, 2.4),
	Vector3(-0.43, 0.31, 2.0),
	Vector3(-0.22, -0.43, 2.8),
	Vector3(-0.04, 0.12, 2.2),
	Vector3(0.18, -0.27, 2.6),
	Vector3(0.38, 0.34, 2.1),
	Vector3(0.59, -0.08, 2.4),
	Vector3(-0.48, -0.02, 1.8),
	Vector3(0.05, 0.43, 1.9),
	Vector3(0.48, 0.12, 1.8)
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
	# Keep the full oval covered. The fill setting slightly contracts the
	# surface inward; at the default full setting it reaches the inner brass lip.
	var surface_scale: float = lerpf(0.86, 1.0, fill_level)
	var radius: Vector2 = LIQUID_RADIUS * surface_scale
	var center: Vector2 = LIQUID_CENTER + Vector2(0.0, (1.0 - surface_scale) * 1.8)

	var surface_color := liquid_color
	surface_color.a = 1.0
	draw_colored_polygon(_make_ellipse(center, radius), surface_color)

	# Deeper colour and a broad moving sheen make the surface feel rounded.
	var depth_color := liquid_color.darkened(0.24)
	depth_color.a = 0.18
	draw_colored_polygon(
		_make_ellipse(center + Vector2(0.0, radius.y * 0.20), radius * Vector2(0.78, 0.56)),
		depth_color
	)

	var sheen_center := center + Vector2(
		sin(_time * 1.15) * 5.5,
		-2.0 + sin(_time * 1.65) * 1.3
	)
	var sheen_color := liquid_color.lightened(0.30)
	sheen_color.a = 0.20
	draw_colored_polygon(
		_make_ellipse(sheen_center, radius * Vector2(0.46, 0.38)),
		sheen_color
	)

	_draw_surface_waves(center, radius)
	_draw_moving_glint(center, radius)


func _draw_surface_waves(center: Vector2, radius: Vector2) -> void:
	# Several crossing wave bands travel across the surface at different speeds.
	# Their positions are clipped mathematically to the oval's interior.
	for wave_index in range(3):
		var points := PackedVector2Array()
		var band_offset: float = float(wave_index - 1) * 4.6
		for point_index in range(39):
			var t: float = float(point_index) / 38.0
			var normalized_x: float = lerpf(-0.82, 0.82, t)
			var edge_height: float = radius.y * sqrt(maxf(0.0, 1.0 - normalized_x * normalized_x))
			var wave: float = sin(_time * 2.35 + normalized_x * 8.5 + float(wave_index) * 1.55) * 1.55
			wave += sin(_time * 3.1 - normalized_x * 11.0 + float(wave_index)) * 0.72
			var local_y: float = clampf(band_offset + wave, -edge_height + 0.8, edge_height - 0.8)
			points.append(center + Vector2(normalized_x * radius.x, local_y))

		var wave_color := liquid_color.lightened(0.56)
		wave_color.a = 0.32 if wave_index == 1 else 0.21
		draw_polyline(points, wave_color, 1.25, true)


func _draw_moving_glint(center: Vector2, radius: Vector2) -> void:
	var points := PackedVector2Array()
	var glint_offset: float = sin(_time * 1.25) * 0.34
	for index in range(19):
		var t: float = float(index) / 18.0
		var normalized_x: float = glint_offset + lerpf(-0.20, 0.20, t)
		var local_y: float = -5.0 + sin(t * TAU + _time * 2.0) * 1.9
		var edge_height: float = radius.y * sqrt(maxf(0.0, 1.0 - normalized_x * normalized_x))
		local_y = clampf(local_y, -edge_height + 1.0, edge_height - 1.0)
		points.append(center + Vector2(normalized_x * radius.x, local_y))

	var glint_color := Color(0.91, 1.0, 0.94, 0.48)
	draw_polyline(points, glint_color, 1.55, true)


func _draw_bubbles() -> void:
	var surface_scale: float = lerpf(0.86, 1.0, fill_level)
	var radius: Vector2 = LIQUID_RADIUS * surface_scale
	var center: Vector2 = LIQUID_CENTER + Vector2(0.0, (1.0 - surface_scale) * 1.8)

	for index in range(BUBBLES.size()):
		var bubble: Vector3 = BUBBLES[index]
		var phase: float = _time * (1.35 + float(index % 4) * 0.18) + bubble.y * 7.0
		var drift_x: float = sin(phase * 0.72) * 2.25
		var drift_y: float = cos(phase) * 3.1
		var position := center + Vector2(
			bubble.x * radius.x + drift_x,
			bubble.y * radius.y + drift_y
		)
		# Tiny changes in size keep the bubbles lively without fading or flashing.
		var bubble_radius: float = bubble.z * (1.0 + sin(phase * 1.35) * 0.10)
		var bubble_fill := Color(0.76, 1.0, 0.92, 0.19)
		var bubble_edge := Color(0.91, 1.0, 0.97, 0.46)
		draw_circle(position, bubble_radius, bubble_fill)
		draw_arc(position, bubble_radius, 0.0, TAU, 20, bubble_edge, 0.9, true)
		draw_circle(
			position + Vector2(-bubble_radius * 0.30, -bubble_radius * 0.34),
			maxf(0.5, bubble_radius * 0.22),
			Color(0.98, 1.0, 0.98, 0.62)
		)


func _make_ellipse(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(SURFACE_SEGMENTS):
		var angle: float = TAU * float(index) / float(SURFACE_SEGMENTS)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
