extends Node2D

var _time := 0.0

const LEFT_FLAME_BASE := Vector2(26.0, 213.0)
const REAR_CANDLE_FOOT := Vector2(520.0, 345.0)
const REAR_FLAME_BASE := Vector2(520.0, 281.0)
const CRYSTAL_GLOW_CENTER := Vector2(470.0, 142.0)
const CAULDRON_GLOW_CENTER := Vector2(205.0, 548.0)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	_draw_candle_glow(LEFT_FLAME_BASE + Vector2(0.0, -9.0), 1.0, 72.0)
	_draw_candle_glow(REAR_FLAME_BASE + Vector2(0.0, -9.0), 0.82, 62.0)
	_draw_crystal_glow(CRYSTAL_GLOW_CENTER)
	_draw_cauldron_glow(CAULDRON_GLOW_CENTER)

	_draw_rear_candle_stand()
	_draw_flame(LEFT_FLAME_BASE, 1.0, 0.0)
	_draw_flame(REAR_FLAME_BASE, 0.82, 1.4)
	_draw_motes()


func _draw_candle_glow(center: Vector2, strength: float, max_radius: float) -> void:
	var pulse := 1.0 + sin(_time * 2.4 + center.x * 0.01) * 0.045
	for layer in range(10, 0, -1):
		var radius := max_radius * float(layer) / 10.0 * pulse
		var alpha := (0.010 + (10.0 - float(layer)) * 0.0014) * strength
		draw_circle(center + Vector2(0.0, -4.0), radius, Color(1.0, 0.57, 0.24, alpha))


func _draw_crystal_glow(center: Vector2) -> void:
	var pulse := 1.0 + sin(_time * 1.6) * 0.07
	for layer in range(11, 0, -1):
		var radius := float(layer) * 8.0 * pulse
		var alpha := 0.007 + (11.0 - float(layer)) * 0.001
		draw_circle(center, radius, Color(0.34, 0.88, 0.76, alpha))


func _draw_cauldron_glow(center: Vector2) -> void:
	var pulse := 1.0 + sin(_time * 1.2) * 0.035
	for layer in range(9, 0, -1):
		var radius := float(layer) * 10.0 * pulse
		var alpha := 0.008 + (9.0 - float(layer)) * 0.001
		draw_circle(center, radius, Color(0.28, 0.91, 0.71, alpha))


func _draw_rear_candle_stand() -> void:
	# A restrained brass holder on the rear counter; the wick and flame stay live.
	var base := REAR_CANDLE_FOOT
	draw_colored_polygon(
		PackedVector2Array([
			base + Vector2(-20.0, 0.0),
			base + Vector2(-15.0, -8.0),
			base + Vector2(15.0, -8.0),
			base + Vector2(20.0, 0.0),
			base + Vector2(14.0, 7.0),
			base + Vector2(-14.0, 7.0)
		]),
		Color("#9a6838")
	)
	draw_colored_polygon(
		PackedVector2Array([
			base + Vector2(-8.0, -8.0),
			base + Vector2(-6.0, -38.0),
			base + Vector2(6.0, -38.0),
			base + Vector2(8.0, -8.0)
		]),
		Color("#bd8748")
	)
	draw_colored_polygon(
		PackedVector2Array([
			base + Vector2(-11.0, -36.0),
			base + Vector2(-9.0, -58.0),
			base + Vector2(9.0, -58.0),
			base + Vector2(11.0, -36.0)
		]),
		Color("#d9c394")
	)
	draw_line(base + Vector2(0.0, -58.0), base + Vector2(0.0, -64.0), Color("#2e2419"), 2.0, true)


func _draw_flame(base: Vector2, strength: float, phase: float) -> void:
	var sway := sin(_time * 5.2 + phase) * 2.7
	var height := 28.0 + sin(_time * 4.1 + phase) * 2.2
	var outer := PackedVector2Array([
		base + Vector2(-8.0, 0.0),
		base + Vector2(-10.0 + sway * 0.35, -height * 0.34),
		base + Vector2(-4.0 + sway, -height * 0.78),
		base + Vector2(1.0 + sway * 1.2, -height),
		base + Vector2(8.0 + sway * 0.65, -height * 0.68),
		base + Vector2(9.0, -height * 0.28),
		base + Vector2(6.0, 0.0)
	])
	draw_colored_polygon(outer, Color(1.0, 0.48, 0.15, 0.92 * strength))

	var inner := PackedVector2Array([
		base + Vector2(-4.5, 0.0),
		base + Vector2(-4.0 + sway * 0.5, -height * 0.35),
		base + Vector2(0.0 + sway, -height * 0.72),
		base + Vector2(4.5 + sway * 0.4, -height * 0.31),
		base + Vector2(4.0, 0.0)
	])
	draw_colored_polygon(inner, Color(1.0, 0.82, 0.43, 0.96 * strength))

	var core := PackedVector2Array([
		base + Vector2(-2.0, 0.0),
		base + Vector2(-1.0 + sway * 0.25, -height * 0.39),
		base + Vector2(2.5 + sway * 0.3, -height * 0.15),
		base + Vector2(2.5, 0.0)
	])
	draw_colored_polygon(core, Color(1.0, 0.96, 0.76, 0.86 * strength))


func _draw_motes() -> void:
	for index in range(13):
		var seed := float(index) * 1.73
		var drift := fposmod(_time * (6.0 + float(index % 4) * 1.7) + seed * 13.0, 260.0)
		var x := 300.0 + sin(seed + _time * 0.32) * (65.0 + float(index % 3) * 17.0)
		var y := 890.0 - drift
		var radius := 1.0 + float(index % 3) * 0.48
		var alpha := 0.18 + (sin(_time * 1.6 + seed) + 1.0) * 0.09
		draw_circle(Vector2(x, y), radius, Color(1.0, 0.78, 0.49, alpha))
