extends Node2D

const CauldronScene = preload("res://scenes/alchemy_cauldron.tscn")
const EffectsScript = preload("res://scripts/alchemy_workshop_effects.gd")

const SHELVES_PATH := "res://assets/environments/Workshop_Shelves.svg"
const BENCH_PATH := "res://assets/environments/Workshop_Bench.svg"
const TABLETOP_PROPS_PATH := "res://assets/environments/Workshop_Tabletop_Props.svg"
const FLOOR_PLANT_PATH := "res://assets/environments/Workshop_Floor_Plant.svg"

var _wall_gradient: GradientTexture2D
var _floor_gradient: GradientTexture2D


func _ready() -> void:
	_wall_gradient = _make_vertical_gradient(
		Color("#40574e"),
		Color("#22372f"),
		1024
	)
	_floor_gradient = _make_vertical_gradient(
		Color("#66503b"),
		Color("#252528"),
		512
	)

	_add_room_sprite(SHELVES_PATH, Vector2(0.0, 92.0), 2)
	_add_room_sprite(BENCH_PATH, Vector2(0.0, 595.0), 5)
	_add_room_sprite(TABLETOP_PROPS_PATH, Vector2(220.0, 625.0), 7)

	var cauldron := CauldronScene.instantiate() as Node2D
	cauldron.name = "LivingCopperCauldron"
	cauldron.position = Vector2(58.0, 624.0)
	cauldron.scale = Vector2(0.60, 0.60)
	cauldron.z_index = 8
	add_child(cauldron)

	var left_plant := _add_room_sprite(
		FLOOR_PLANT_PATH,
		Vector2(8.0, 965.0),
		9,
		Vector2(0.82, 0.82)
	)
	left_plant.name = "LeftFloorHerb"

	var right_plant := _add_room_sprite(
		FLOOR_PLANT_PATH,
		Vector2(570.0, 978.0),
		9,
		Vector2(0.72, 0.72)
	)
	right_plant.name = "RightFloorHerb"
	right_plant.flip_h = true

	var effects := EffectsScript.new() as Node2D
	effects.name = "LivingWorkshopLight"
	effects.z_index = 20
	add_child(effects)

	queue_redraw()


func _make_vertical_gradient(top_color: Color, bottom_color: Color, texture_height: int) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([top_color, bottom_color])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 2
	texture.height = texture_height
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	return texture


func _add_room_sprite(
	resource_path: String,
	sprite_position: Vector2,
	layer: int,
	sprite_scale: Vector2 = Vector2.ONE
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(resource_path) as Texture2D
	sprite.centered = false
	sprite.position = sprite_position
	sprite.scale = sprite_scale
	sprite.z_index = layer
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	return sprite


func _draw() -> void:
	# Broad wall and floor planes are native Godot drawing, not a painted
	# background image. Their gradients establish the room's lighting zones.
	if _wall_gradient != null:
		draw_texture_rect(_wall_gradient, Rect2(0.0, 0.0, 720.0, 1015.0), false)
	if _floor_gradient != null:
		draw_texture_rect(_floor_gradient, Rect2(0.0, 965.0, 720.0, 315.0), false)

	_draw_wall_masonry()
	_draw_architecture()
	_draw_floor_tiles()
	_draw_workshop_light_pools()


func _draw_wall_masonry() -> void:
	# Large quiet plaster/stone panels; low contrast keeps the shelves readable.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(50.0, 220.0), Vector2(334.0, 206.0),
			Vector2(336.0, 560.0), Vector2(54.0, 576.0)
		]),
		Color(0.31, 0.43, 0.37, 0.20)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(382.0, 210.0), Vector2(665.0, 224.0),
			Vector2(666.0, 570.0), Vector2(384.0, 560.0)
		]),
		Color(0.12, 0.25, 0.23, 0.22)
	)

	var mortar := Color(0.12, 0.23, 0.21, 0.34)
	draw_polyline(
		PackedVector2Array([Vector2(0.0, 286.0), Vector2(720.0, 286.0)]),
		mortar, 2.0, true
	)
	draw_polyline(
		PackedVector2Array([Vector2(0.0, 470.0), Vector2(720.0, 470.0)]),
		mortar, 2.0, true
	)
	draw_polyline(
		PackedVector2Array([Vector2(235.0, 210.0), Vector2(228.0, 286.0), Vector2(235.0, 470.0)]),
		Color(0.12, 0.22, 0.20, 0.20), 2.0, true
	)
	draw_polyline(
		PackedVector2Array([Vector2(488.0, 210.0), Vector2(496.0, 286.0), Vector2(488.0, 470.0)]),
		Color(0.12, 0.22, 0.20, 0.20), 2.0, true
	)

	# A few broad, irregular plaster patches add age without visual noise.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(8.0, 170.0), Vector2(92.0, 160.0),
			Vector2(108.0, 195.0), Vector2(76.0, 221.0),
			Vector2(14.0, 211.0)
		]),
		Color(0.66, 0.62, 0.46, 0.055)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(610.0, 488.0), Vector2(704.0, 470.0),
			Vector2(716.0, 515.0), Vector2(671.0, 548.0),
			Vector2(619.0, 535.0)
		]),
		Color(0.74, 0.57, 0.39, 0.055)
	)


func _draw_architecture() -> void:
	# Dark timber uprights and a ceiling crossbeam frame the little room.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(39.0, 0.0),
			Vector2(48.0, 575.0), Vector2(0.0, 594.0)
		]),
		Color(0.15, 0.20, 0.18, 0.95)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(681.0, 0.0), Vector2(720.0, 0.0),
			Vector2(720.0, 594.0), Vector2(672.0, 575.0)
		]),
		Color(0.13, 0.18, 0.17, 0.96)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 76.0), Vector2(720.0, 57.0),
			Vector2(720.0, 112.0), Vector2(0.0, 133.0)
		]),
		Color(0.20, 0.25, 0.21, 0.96)
	)
	draw_polyline(
		PackedVector2Array([Vector2(0.0, 111.0), Vector2(360.0, 94.0), Vector2(720.0, 111.0)]),
		Color(0.80, 0.57, 0.34, 0.34), 3.0, true
	)

	# A simple old-world alchemy medallion, partly visible above the shelving.
	draw_circle(Vector2(360.0, 158.0), 61.0, Color(0.10, 0.22, 0.21, 0.28))
	draw_arc(Vector2(360.0, 158.0), 55.0, 0.0, TAU, 80, Color(0.78, 0.60, 0.36, 0.54), 2.0, true)
	draw_arc(Vector2(360.0, 158.0), 43.0, 0.0, TAU, 80, Color(0.78, 0.60, 0.36, 0.24), 1.0, true)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(360.0, 113.0), Vector2(386.0, 158.0),
			Vector2(360.0, 203.0), Vector2(334.0, 158.0)
		]),
		Color(0.65, 0.51, 0.33, 0.12)
	)
	draw_polyline(
		PackedVector2Array([Vector2(360.0, 126.0), Vector2(360.0, 190.0)]),
		Color(0.90, 0.72, 0.46, 0.42), 1.5, true
	)

	# Heavy lower wall rail and shallow floor skirting.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 552.0), Vector2(720.0, 552.0),
			Vector2(720.0, 605.0), Vector2(0.0, 605.0)
		]),
		Color(0.18, 0.22, 0.19, 0.94)
	)
	draw_polyline(
		PackedVector2Array([Vector2(0.0, 560.0), Vector2(720.0, 560.0)]),
		Color(0.82, 0.59, 0.36, 0.48), 3.0, true
	)
	draw_polyline(
		PackedVector2Array([Vector2(0.0, 599.0), Vector2(720.0, 599.0)]),
		Color(0.08, 0.12, 0.11, 0.85), 4.0, true
	)


func _draw_floor_tiles() -> void:
	# Broad staggered stone slabs with perspective expansion toward the viewer.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 966.0), Vector2(720.0, 966.0),
			Vector2(720.0, 1280.0), Vector2(0.0, 1280.0)
		]),
		Color(0.31, 0.27, 0.23, 0.42)
	)

	var tile_colors: Array[Color] = [
		Color("#665542"), Color("#5b4b3d"), Color("#70604a"),
		Color("#594a3d"), Color("#786449"), Color("#625241")
	]
	for row in range(5):
		var depth := float(row) / 4.0
		var tile_width := lerpf(98.0, 143.0, depth)
		var tile_height := lerpf(51.0, 75.0, depth)
		var start_y := 972.0 + float(row) * 68.0
		var skew := lerpf(8.0, 19.0, depth)
		var offset_x := -tile_width * 0.5 if row % 2 == 1 else 0.0

		for column in range(-1, 8):
			var x := offset_x + float(column) * tile_width
			var points := PackedVector2Array([
				Vector2(x, start_y),
				Vector2(x + tile_width, start_y + 2.0),
				Vector2(x + tile_width + skew, start_y + tile_height),
				Vector2(x + skew, start_y + tile_height - 2.0)
			])
			var shade := tile_colors[(row * 3 + column + 12) % tile_colors.size()]
			draw_colored_polygon(points, shade)
			draw_polyline(
				PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]),
				Color(0.16, 0.14, 0.13, 0.62), 2.0, true
			)
			draw_polyline(
				PackedVector2Array([
					points[3] + Vector2(5.0, -3.0),
					points[2] + Vector2(-7.0, -3.0)
				]),
				Color(0.88, 0.72, 0.52, 0.13), 1.0, true
			)


func _draw_workshop_light_pools() -> void:
	# Large translucent warm pools unify native surfaces with the illustrated props.
	for layer in range(8):
		var radius := 240.0 - float(layer) * 23.0
		var alpha := 0.012 + float(layer) * 0.002
		draw_circle(
			Vector2(360.0, 610.0),
			radius,
			Color(0.95, 0.63, 0.34, alpha)
		)
	draw_circle(Vector2(360.0, 720.0), 220.0, Color(0.78, 0.47, 0.25, 0.025))
