extends Node2D

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	_draw_warm_glow()
	_draw_flame()


func _draw_warm_glow() -> void:
	var pulse := 1.0 + sin(_time * 2.15) * 0.035
	for layer in range(10, 0, -1):
		var radius := float(layer) * 7.2 * pulse
		var alpha := 0.006 + float(10 - layer) * 0.0011
		draw_circle(Vector2(0.0, -9.0), radius, Color(1.0, 0.55, 0.23, alpha))


func _draw_flame() -> void:
	var sway := sin(_time * 5.1) * 1.7
	var height := 25.0 + sin(_time * 4.0) * 1.4
	var outer := PackedVector2Array([
		Vector2(-6.5, 0.0),
		Vector2(-7.0 + sway * 0.35, -height * 0.34),
		Vector2(-3.2 + sway, -height * 0.76),
		Vector2(0.8 + sway * 1.1, -height),
		Vector2(6.0 + sway * 0.6, -height * 0.66),
		Vector2(7.0, -height * 0.25),
		Vector2(4.5, 0.0)
	])
	draw_colored_polygon(outer, Color(1.0, 0.47, 0.14, 0.94))

	var inner := PackedVector2Array([
		Vector2(-3.8, 0.0),
		Vector2(-3.0 + sway * 0.5, -height * 0.35),
		Vector2(0.0 + sway, -height * 0.72),
		Vector2(3.5 + sway * 0.4, -height * 0.30),
		Vector2(3.0, 0.0)
	])
	draw_colored_polygon(inner, Color(1.0, 0.82, 0.43, 0.98))

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-1.8, 0.0),
			Vector2(-0.7 + sway * 0.2, -height * 0.39),
			Vector2(2.0 + sway * 0.25, -height * 0.16),
			Vector2(2.0, 0.0)
		]),
		Color(1.0, 0.97, 0.78, 0.88)
	)
