extends Node2D

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	_draw_candle_glow(Vector2(118.0, 178.0), 1.0)
	_draw_candle_glow(Vector2(598.0, 178.0), 0.88)
	_draw_crystal_glow(Vector2(590.0, 405.0))
	_draw_cauldron_glow(Vector2(130.0, 670.0))
	_draw_flame(Vector2(118.0, 178.0), 1.0, 0.0)
	_draw_flame(Vector2(598.0, 178.0), 0.88, 1.7)
	_draw_motes()


func _draw_candle_glow(center: Vector2, strength: float) -> void:
	var pulse := 1.0 + sin(_time * 2.4 + center.x * 0.01) * 0.045
	for layer in range(10, 0, -1):
		var radius := float(layer) * 12.0 * pulse
		var alpha := (0.012 + (10.0 - float(layer)) * 0.0015) * strength
		draw_circle(center + Vector2(0.0, -5.0), radius, Color(1.0, 0.57, 0.24, alpha))


func _draw_crystal_glow(center: Vector2) -> void:
	var pulse := 1.0 + sin(_time * 1.6) * 0.07
	for layer in range(12, 0, -1):
		var radius := float(layer) * 9.0 * pulse
		var alpha := 0.008 + (12.0 - float(layer)) * 0.001
		draw_circle(center, radius, Color(0.34, 0.92, 0.78, alpha))


func _draw_cauldron_glow(center: Vector2) -> void:
	var pulse := 1.0 + sin(_time * 1.2) * 0.035
	for layer in range(9, 0, -1):
		var radius := float(layer) * 11.0 * pulse
		var alpha := 0.008 + (9.0 - float(layer)) * 0.001
		draw_circle(center, radius, Color(0.28, 0.91, 0.71, alpha))


func _draw_flame(base: Vector2, strength: float, phase: float) -> void:
	var sway := sin(_time * 5.2 + phase) * 3.0
	var height := 32.0 + sin(_time * 4.1 + phase) * 2.5
	var outer := PackedVector2Array([
		base + Vector2(-9.0, 0.0),
		base + Vector2(-11.0 + sway * 0.35, -height * 0.34),
		base + Vector2(-5.0 + sway, -height * 0.78),
		base + Vector2(1.0 + sway * 1.2, -height),
		base + Vector2(8.0 + sway * 0.65, -height * 0.68),
		base + Vector2(10.0, -height * 0.28),
		base + Vector2(7.0, 0.0)
	])
	draw_colored_polygon(outer, Color(1.0, 0.49, 0.16, 0.93 * strength))

	var inner := PackedVector2Array([
		base + Vector2(-5.0, -1.0),
		base + Vector2(-5.0 + sway * 0.5, -height * 0.34),
		base + Vector2(0.0 + sway, -height * 0.72),
		base + Vector2(5.0 + sway * 0.4, -height * 0.31),
		base + Vector2(4.0, -1.0)
	])
	draw_colored_polygon(inner, Color(1.0, 0.82, 0.42, 0.96 * strength))

	var core := PackedVector2Array([
		base + Vector2(-2.5, -1.0),
		base + Vector2(-1.0 + sway * 0.25, -height * 0.39),
		base + Vector2(2.5 + sway * 0.3, -height * 0.15),
		base + Vector2(2.5, -1.0)
	])
	draw_colored_polygon(core, Color(1.0, 0.96, 0.76, 0.86 * strength))


func _draw_motes() -> void:
	for index in range(14):
		var seed := float(index) * 1.73
		var drift := fposmod(_time * (8.0 + float(index % 4) * 2.0) + seed * 13.0, 210.0)
		var x := 205.0 + sin(seed + _time * 0.35) * (34.0 + float(index % 3) * 13.0)
		var y := 820.0 - drift
		var radius := 1.0 + float(index % 3) * 0.55
		var alpha := 0.25 + (sin(_time * 1.7 + seed) + 1.0) * 0.10
		draw_circle(Vector2(x, y), radius, Color(1.0, 0.79, 0.49, alpha))
