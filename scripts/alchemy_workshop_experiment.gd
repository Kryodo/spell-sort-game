extends Node2D

@export var show_tabletop_guides: bool = false

const CauldronScene = preload("res://scenes/alchemy_cauldron.tscn")
const EffectsScript = preload("res://scripts/alchemy_workshop_effects.gd")

const BACK_SHELF_PATH := "res://assets/environments/Workshop_Back_Shelf.svg"
const REAR_CABINET_PATH := "res://assets/environments/Workshop_Rear_Cabinet.svg"
const LEFT_CABINET_PATH := "res://assets/environments/Workshop_Left_Cabinet.svg"
const RIGHT_SHELF_PATH := "res://assets/environments/Workshop_Right_Shelf.svg"
const BENCH_PATH := "res://assets/environments/Workshop_Bench.svg"
const BOOK_PATH := "res://assets/environments/Workshop_Tabletop_Book.svg"
const POTIONS_PATH := "res://assets/environments/Workshop_Tabletop_Potions.svg"
const MORTAR_PATH := "res://assets/environments/Workshop_Tabletop_Mortar.svg"
const PLANT_PATH := "res://assets/environments/Workshop_Floor_Plant.svg"

# Corners of the visible tabletop, measured from the Qwen reference and
# mapped into the 720 x 1280 preview viewport.
const TABLE_REAR_LEFT := Vector2(150.0, 455.0)
const TABLE_REAR_RIGHT := Vector2(570.0, 455.0)
const TABLE_FRONT_RIGHT := Vector2(720.0, 742.0)
const TABLE_FRONT_LEFT := Vector2(0.0, 742.0)


func _ready() -> void:
	_wall_gradient = _make_vertical_gradient(
		PackedColorArray([Color("#142522"), Color("#1d302a"), Color("#263a31")]),
		PackedFloat32Array([0.0, 0.58, 1.0]),
		1280
	)
	_floor_gradient = _make_vertical_gradient(
		PackedColorArray([Color("#29332d"), Color("#222824"), Color("#151a1b")]),
		PackedFloat32Array([0.0, 0.42, 1.0]),
		900
	)

	# Back-to-front order follows the Qwen room: wall shelf, rear cabinet,
	# side framing furniture, floor foliage, and then the foreground workbench.
	_add_room_sprite(BACK_SHELF_PATH, Vector2(140.0, 28.0), 1)
	_add_room_sprite(REAR_CABINET_PATH, Vector2(145.0, 270.0), 2)
	_add_room_sprite(LEFT_CABINET_PATH, Vector2(-48.0, 208.0), 3, Vector2(0.92, 0.92))
	_add_room_sprite(RIGHT_SHELF_PATH, Vector2(506.0, 58.0), 3, Vector2(0.94, 0.94))

	# Foreground foliage sits in front of the legs, not on the tabletop.
	var left_plant := _add_room_sprite(
		PLANT_PATH, Vector2(-58.0, 1055.0), 6, Vector2(0.88, 0.88)
	)
	left_plant.name = "LeftForegroundHerb"
	var right_plant := _add_room_sprite(
		PLANT_PATH, Vector2(620.0, 1050.0), 6, Vector2(0.80, 0.80)
	)
	right_plant.name = "RightForegroundHerb"
	right_plant.flip_h = true

	_add_room_sprite(BENCH_PATH, Vector2(0.0, 455.0), 5)

	# Each prop is anchored to a normalized point on the projected tabletop.
	# Godot calculates its screen position and depth scale from the same plane.
	_add_tabletop_prop(CauldronScene, 0.22, 0.44, 0.64, 7, "LivingCopperCauldron")
	_add_tabletop_prop(BOOK_PATH, 0.48, 0.76, 0.88, 7, "OpenGrimoire")
	_add_tabletop_prop(POTIONS_PATH, 0.81, 0.52, 0.80, 7, "TabletopPotionSet")
	_add_tabletop_prop(MORTAR_PATH, 0.59, 0.39, 0.78, 7, "BrassMortar")

	var effects := EffectsScript.new() as Node2D
	effects.name = "LivingWorkshopLight"
	effects.z_index = 20
	add_child(effects)

	queue_redraw()


func _make_vertical_gradient(
	colors: PackedColorArray,
	offsets: PackedFloat32Array,
	texture_height: int
) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = colors
	gradient.offsets = offsets

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


func _project_tabletop(u: float, v: float) -> Vector2:
	# Bilinear projection from normalized tabletop coordinates (0..1, 0..1)
	# to the four measured screen-space corners.
	var top_edge := TABLE_REAR_LEFT.lerp(TABLE_REAR_RIGHT, u)
	var front_edge := TABLE_FRONT_LEFT.lerp(TABLE_FRONT_RIGHT, u)
	return top_edge.lerp(front_edge, v)


func _add_tabletop_prop(
	resource_or_scene: Variant,
	u: float,
	v: float,
	base_scale: float,
	base_layer: int,
	node_name: String
) -> Node2D:
	var depth := clampf(v, 0.0, 1.0)
	var depth_scale := lerpf(0.76, 1.0, depth)
	var final_scale := base_scale * depth_scale
	var anchor := _project_tabletop(u, depth)

	if resource_or_scene is PackedScene:
		var prop_scene := (resource_or_scene as PackedScene).instantiate() as Node2D
		prop_scene.name = node_name
		prop_scene.scale = Vector2.ONE * final_scale
		# The cauldron artwork's ground-contact shadow is centred at (120, 208).
		prop_scene.position = anchor - Vector2(120.0, 208.0) * final_scale
		prop_scene.z_index = base_layer + int(depth * 3.0)
		add_child(prop_scene)
		return prop_scene

	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = load(resource_or_scene as String) as Texture2D
	sprite.centered = false
	sprite.scale = Vector2.ONE * final_scale
	var texture_size := sprite.texture.get_size()
	# The SVG's bottom-centre contact point lands exactly on the projected plane.
	sprite.position = anchor - Vector2(
		float(texture_size.x) * final_scale * 0.5,
		float(texture_size.y) * final_scale
	)
	sprite.z_index = base_layer + int(depth * 3.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	return sprite


func _draw() -> void:
	if _wall_gradient != null:
		draw_texture_rect(_wall_gradient, Rect2(0.0, 0.0, 720.0, 1280.0), false)
	if _floor_gradient != null:
		draw_texture_rect(_floor_gradient, Rect2(0.0, 475.0, 720.0, 805.0), false)

	_draw_room_architecture()
	_draw_floor_tiles()
	_draw_wall_light_and_shadow()
	if show_tabletop_guides:
		_draw_tabletop_guides()


func _draw_room_architecture() -> void:
	# The central rear wall is recessed between two angled side returns.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(74.0, 46.0), Vector2(646.0, 46.0),
			Vector2(674.0, 476.0), Vector2(46.0, 476.0)
		]),
		Color(0.20, 0.31, 0.27, 0.52)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(76.0, 46.0),
			Vector2(47.0, 476.0), Vector2(0.0, 530.0)
		]),
		Color(0.055, 0.10, 0.095, 0.58)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(644.0, 46.0), Vector2(720.0, 0.0),
			Vector2(720.0, 530.0), Vector2(673.0, 476.0)
		]),
		Color(0.045, 0.09, 0.088, 0.66)
	)

	# Heavy ceiling beam and side posts frame the room, but stay subdued.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(720.0, 0.0),
			Vector2(720.0, 48.0), Vector2(0.0, 64.0)
		]),
		Color(0.10, 0.16, 0.145, 0.96)
	)
	draw_polyline(
		PackedVector2Array([Vector2(0.0, 57.0), Vector2(360.0, 42.0), Vector2(720.0, 42.0)]),
		Color(0.66, 0.48, 0.30, 0.34), 3.0, true
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(27.0, 0.0),
			Vector2(36.0, 520.0), Vector2(0.0, 552.0)
		]),
		Color(0.075, 0.115, 0.105, 0.82)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(693.0, 0.0), Vector2(720.0, 0.0),
			Vector2(720.0, 552.0), Vector2(684.0, 520.0)
		]),
		Color(0.06, 0.105, 0.10, 0.88)
	)

	# Broad, quiet wall-stone joints create scale without visual noise.
	var joint := Color(0.07, 0.13, 0.12, 0.30)
	draw_polyline(PackedVector2Array([Vector2(52.0, 274.0), Vector2(668.0, 274.0)]), joint, 2.0, true)
	draw_polyline(PackedVector2Array([Vector2(80.0, 402.0), Vector2(640.0, 402.0)]), joint, 2.0, true)
	draw_polyline(PackedVector2Array([Vector2(238.0, 48.0), Vector2(231.0, 274.0)]), joint, 2.0, true)
	draw_polyline(PackedVector2Array([Vector2(482.0, 48.0), Vector2(491.0, 274.0)]), joint, 2.0, true)

	# Softly worn plaster patches are broad tonal shapes, not small noisy marks.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(65.0, 85.0), Vector2(148.0, 72.0),
			Vector2(164.0, 119.0), Vector2(121.0, 145.0),
			Vector2(71.0, 129.0)
		]),
		Color(0.69, 0.59, 0.42, 0.055)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(540.0, 414.0), Vector2(641.0, 397.0),
			Vector2(660.0, 448.0), Vector2(594.0, 466.0),
			Vector2(548.0, 451.0)
		]),
		Color(0.64, 0.53, 0.38, 0.045)
	)

	# A low wall rail visually separates wall and floor behind the furniture.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 466.0), Vector2(720.0, 466.0),
			Vector2(720.0, 500.0), Vector2(0.0, 500.0)
		]),
		Color(0.09, 0.14, 0.13, 0.88)
	)
	draw_polyline(
		PackedVector2Array([Vector2(0.0, 468.0), Vector2(720.0, 468.0)]),
		Color(0.62, 0.43, 0.28, 0.30), 2.0, true
	)


func _draw_floor_tiles() -> void:
	# A restrained perspective floor: broad slabs expand toward the viewer.
	var row_count := 7
	var column_count := 6
	var tile_colors: Array[Color] = [
		Color("#3a3e36"), Color("#343a34"), Color("#424138"),
		Color("#353831"), Color("#3e4038"), Color("#303732")
	]
	for row in range(row_count):
		var near_top := float(row) / float(row_count)
		var near_bottom := float(row + 1) / float(row_count)
		var top_y := 480.0 + pow(near_top, 1.55) * 800.0
		var bottom_y := 480.0 + pow(near_bottom, 1.55) * 800.0
		var top_half := lerpf(340.0, 520.0, near_top)
		var bottom_half := lerpf(390.0, 610.0, near_bottom)
		for column in range(column_count):
			var left_fraction := float(column) / float(column_count)
			var right_fraction := float(column + 1) / float(column_count)
			var top_left_x := 360.0 - top_half + 2.0 * top_half * left_fraction
			var top_right_x := 360.0 - top_half + 2.0 * top_half * right_fraction
			var bottom_left_x := 360.0 - bottom_half + 2.0 * bottom_half * left_fraction
			var bottom_right_x := 360.0 - bottom_half + 2.0 * bottom_half * right_fraction
			var points := PackedVector2Array([
				Vector2(top_left_x, top_y),
				Vector2(top_right_x, top_y),
				Vector2(bottom_right_x, bottom_y),
				Vector2(bottom_left_x, bottom_y)
			])
			var shade := tile_colors[(row * 3 + column * 2) % tile_colors.size()]
			draw_colored_polygon(points, shade)
			draw_polyline(
				PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]),
				Color(0.085, 0.095, 0.09, 0.52), 2.0, true
			)
			draw_polyline(
				PackedVector2Array([points[3], points[2]]),
				Color(0.82, 0.68, 0.49, 0.075), 1.5, true
			)


func _draw_wall_light_and_shadow() -> void:
	# The rear stays noticeably darker than the foreground tabletop.
	for layer in range(9, 0, -1):
		var radius := float(layer) * 31.0
		var alpha := 0.006 + float(9 - layer) * 0.0012
		draw_circle(Vector2(356.0, 258.0), radius, Color(0.54, 0.55, 0.33, alpha))

	# Subtle warm bounce and grounding shadow beneath the foreground table.
	for layer in range(8, 0, -1):
		var radius := float(layer) * 34.0
		var alpha := 0.005 + float(8 - layer) * 0.0012
		draw_circle(Vector2(360.0, 1040.0), radius, Color(0.72, 0.43, 0.23, alpha))


func _draw_tabletop_guides() -> void:
	var corners := PackedVector2Array([
		TABLE_REAR_LEFT, TABLE_REAR_RIGHT, TABLE_FRONT_RIGHT, TABLE_FRONT_LEFT, TABLE_REAR_LEFT
	])
	draw_polyline(corners, Color(0.2, 1.0, 0.75, 0.9), 2.0, true)
	draw_line(TABLE_REAR_LEFT, TABLE_FRONT_RIGHT, Color(0.2, 1.0, 0.75, 0.45), 1.0, true)
	draw_line(TABLE_REAR_RIGHT, TABLE_FRONT_LEFT, Color(0.2, 1.0, 0.75, 0.45), 1.0, true)

	for anchor in [
		_project_tabletop(0.22, 0.44),
		_project_tabletop(0.48, 0.76),
		_project_tabletop(0.81, 0.52),
		_project_tabletop(0.59, 0.39)
	]:
		draw_circle(anchor, 7.0, Color(0.1, 0.95, 0.72, 0.88))
		draw_circle(anchor, 3.0, Color(0.04, 0.18, 0.15, 1.0))
