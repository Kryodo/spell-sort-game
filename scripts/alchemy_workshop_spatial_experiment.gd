extends Node2D

@export var show_surface_guides: bool = false

const CauldronScene = preload("res://scenes/alchemy_cauldron.tscn")
const CandleFlameScript = preload("res://scripts/alchemy_workshop_spatial_candle.gd")

const BACK_SHELF_PATH := "res://assets/environments/Workshop_Back_Shelf.svg"
const REAR_CABINET_PATH := "res://assets/environments/Workshop_Rear_Cabinet.svg"
const LEFT_CABINET_PATH := "res://assets/environments/Workshop_Left_Cabinet_Spatial.svg"
const RIGHT_SHELF_PATH := "res://assets/environments/Workshop_Right_Shelf.svg"
const BENCH_PATH := "res://assets/environments/Workshop_Bench_Spatial.svg"
const CANDLE_PATH := "res://assets/environments/Workshop_Candle_Spatial.svg"
const BOOK_PATH := "res://assets/environments/Workshop_Tabletop_Book.svg"
const POTIONS_PATH := "res://assets/environments/Workshop_Tabletop_Potions.svg"
const MORTAR_PATH := "res://assets/environments/Workshop_Tabletop_Mortar.svg"
const PLANT_PATH := "res://assets/environments/Workshop_Floor_Plant.svg"

# The bench has its own local plane. These points match the visible top of
# Workshop_Bench_Spatial.svg, not a room-wide isometric projection.
const BENCH_POSITION := Vector2(0.0, 455.0)
const TABLE_REAR_LEFT := Vector2(148.0, 0.0)
const TABLE_REAR_RIGHT := Vector2(572.0, 0.0)
const TABLE_FRONT_RIGHT := Vector2(697.0, 462.0)
const TABLE_FRONT_LEFT := Vector2(23.0, 462.0)

var _wall_gradient: GradientTexture2D
var _floor_gradient: GradientTexture2D
var _tabletop_anchors: Array[Vector2] = []


func _ready() -> void:
	_wall_gradient = _make_vertical_gradient(
		PackedColorArray([Color("#101d1c"), Color("#1a2d29"), Color("#263a31")]),
		PackedFloat32Array([0.0, 0.62, 1.0]),
		560
	)
	_floor_gradient = _make_vertical_gradient(
		PackedColorArray([Color("#29342f"), Color("#202925"), Color("#121a1b")]),
		PackedFloat32Array([0.0, 0.48, 1.0]),
		900
	)

	_build_rear_furniture()
	_build_workbench()
	_build_tabletop_props()
	_build_floor_plants()
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


func _build_rear_furniture() -> void:
	# The central wall shelf and rear cabinet stay front-facing. They do not
	# inherit the tabletop projection or the side furniture's orientation.
	_add_layer_asset(
		BACK_SHELF_PATH,
		Vector2(145.0, 40.0),
		Vector2(0.84, 0.84),
		2,
		"RearWallShelf"
	)
	_add_layer_asset(
		REAR_CABINET_PATH,
		Vector2(145.0, 258.0),
		Vector2(0.94, 0.94),
		3,
		"RearStorageCabinet"
	)

	# The left and right pieces each keep their own local plane. The right
	# shelf is mirrored so its shelf boards recede in the same direction as
	# the reference image rather than inheriting the previous reversed tilt.
	var left_cabinet := _add_layer_asset(
		LEFT_CABINET_PATH,
		Vector2(-22.0, 220.0),
		Vector2(0.77, 0.77),
		4,
		"LeftSideCabinet"
	)
	_add_shelf_candle(left_cabinet)

	_add_layer_asset(
		RIGHT_SHELF_PATH,
		Vector2(730.0, 135.0),
		Vector2(-0.70, 0.70),
		4,
		"RightSideShelf"
	)


func _add_layer_asset(
	resource_path: String,
	asset_position: Vector2,
	asset_scale: Vector2,
	layer: int,
	node_name: String
) -> Node2D:
	var anchor := Node2D.new()
	anchor.name = node_name
	anchor.position = asset_position
	anchor.scale = asset_scale
	anchor.z_index = layer
	add_child(anchor)

	var sprite := Sprite2D.new()
	sprite.name = "Artwork"
	sprite.texture = load(resource_path) as Texture2D
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	anchor.add_child(sprite)

	if sprite.texture == null:
		push_error("Could not load workshop artwork: " + resource_path)
	return anchor


func _add_shelf_candle(shelf_anchor: Node2D) -> void:
	# The candle is a separate object. Its base anchor is placed directly on
	# the cabinet's top plane; the flame is attached to the candle wick.
	var candle := Node2D.new()
	candle.name = "AnchoredShelfCandle"
	candle.position = Vector2(80.0, 123.0)
	candle.scale = Vector2(0.90, 0.90)
	candle.z_index = 3
	shelf_anchor.add_child(candle)

	var candle_sprite := Sprite2D.new()
	candle_sprite.name = "CandleArtwork"
	candle_sprite.texture = load(CANDLE_PATH) as Texture2D
	candle_sprite.centered = false
	candle_sprite.position = -Vector2(42.0, 132.0)
	candle_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	candle.add_child(candle_sprite)

	var flame := Node2D.new()
	flame.name = "WickFlame"
	flame.position = Vector2(0.0, -88.0)
	flame.z_index = 2
	flame.set_script(CandleFlameScript)
	candle.add_child(flame)


func _build_workbench() -> void:
	var bench := _add_layer_asset(
		BENCH_PATH,
		BENCH_POSITION,
		Vector2.ONE,
		10,
		"ForegroundWorkbench"
	)
	bench.z_index = 10


func _project_tabletop(u: float, v: float) -> Vector2:
	# Bilinear mapping only applies to the tabletop. It is intentionally
	# independent from the wall, floor, rear shelf and side cabinets.
	var top_edge := TABLE_REAR_LEFT.lerp(TABLE_REAR_RIGHT, u)
	var front_edge := TABLE_FRONT_LEFT.lerp(TABLE_FRONT_RIGHT, u)
	return BENCH_POSITION + top_edge.lerp(front_edge, v)


func _build_tabletop_props() -> void:
	_add_tabletop_prop(
		CauldronScene,
		0.20, 0.42,
		0.60,
		Vector2(120.0, 208.0),
		0.0,
		"LivingCopperCauldron"
	)
	_add_tabletop_prop(
		MORTAR_PATH,
		0.64, 0.35,
		0.76,
		Vector2(60.0, 101.0),
		-5.0,
		"BrassMortar"
	)
	_add_tabletop_prop(
		POTIONS_PATH,
		0.84, 0.55,
		0.70,
		Vector2(75.0, 161.0),
		3.0,
		"TabletopPotionSet"
	)
	_add_tabletop_prop(
		BOOK_PATH,
		0.38, 0.76,
		0.76,
		Vector2(95.0, 124.0),
		-7.0,
		"OpenGrimoire"
	)


func _add_tabletop_prop(
	resource_or_scene: Variant,
	u: float,
	v: float,
	base_scale: float,
	contact_point: Vector2,
	rotation_degrees: float,
	node_name: String
) -> void:
	var depth := clampf(v, 0.0, 1.0)
	var depth_scale := lerpf(0.88, 1.0, depth)
	var final_scale := base_scale * depth_scale
	var anchor_position := _project_tabletop(u, depth)

	var prop_anchor := Node2D.new()
	prop_anchor.name = node_name + "Anchor"
	prop_anchor.position = anchor_position
	prop_anchor.rotation = deg_to_rad(rotation_degrees)
	prop_anchor.scale = Vector2.ONE * final_scale
	prop_anchor.z_index = 11 + int(depth * 3.0)
	add_child(prop_anchor)

	if resource_or_scene is PackedScene:
		var prop_scene := (resource_or_scene as PackedScene).instantiate() as Node2D
		prop_scene.name = node_name
		prop_scene.position = -contact_point
		prop_anchor.add_child(prop_scene)
	else:
		var sprite := Sprite2D.new()
		sprite.name = node_name
		sprite.texture = load(str(resource_or_scene)) as Texture2D
		sprite.centered = false
		sprite.position = -contact_point
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		prop_anchor.add_child(sprite)
		if sprite.texture == null:
			push_error("Could not load tabletop artwork: " + str(resource_or_scene))

	_tabletop_anchors.append(anchor_position)


func _build_floor_plants() -> void:
	_add_floor_plant(Vector2(52.0, 1218.0), 0.70, 12, "LeftFloorHerb")
	_add_floor_plant(Vector2(672.0, 1214.0), 0.68, 12, "RightFloorHerb")


func _add_floor_plant(
	ground_contact: Vector2,
	plant_scale: float,
	layer: int,
	node_name: String
) -> void:
	var plant_anchor := Node2D.new()
	plant_anchor.name = node_name + "Anchor"
	plant_anchor.position = ground_contact
	plant_anchor.scale = Vector2.ONE * plant_scale
	plant_anchor.z_index = layer
	add_child(plant_anchor)

	var plant := Sprite2D.new()
	plant.name = node_name
	plant.texture = load(PLANT_PATH) as Texture2D
	plant.centered = false
	# The bottom-centre of the pot, not the edge of the transparent canvas,
	# is the point that touches the floor.
	plant.position = -Vector2(84.0, 252.0)
	plant.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	plant_anchor.add_child(plant)


func _draw() -> void:
	if _wall_gradient != null:
		draw_texture_rect(_wall_gradient, Rect2(0.0, 0.0, 720.0, 520.0), false)
	if _floor_gradient != null:
		draw_texture_rect(_floor_gradient, Rect2(0.0, 470.0, 720.0, 810.0), false)

	_draw_independent_room_planes()
	_draw_floor_joints()
	_draw_recessed_crystal_light()

	if show_surface_guides:
		_draw_tabletop_guides()


func _draw_independent_room_planes() -> void:
	# Three architectural planes: a recessed rear wall and two dark side
	# returns. These are room shapes only; the furniture has separate local
	# transforms and does not inherit a single forced camera projection.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(67.0, 0.0),
			Vector2(653.0, 0.0),
			Vector2(680.0, 470.0),
			Vector2(40.0, 470.0)
		]),
		Color(0.11, 0.18, 0.16, 0.58)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(69.0, 38.0),
			Vector2(42.0, 470.0),
			Vector2(0.0, 515.0)
		]),
		Color(0.045, 0.085, 0.082, 0.72)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(651.0, 38.0),
			Vector2(720.0, 0.0),
			Vector2(720.0, 515.0),
			Vector2(678.0, 470.0)
		]),
		Color(0.04, 0.08, 0.078, 0.76)
	)

	# A quiet ceiling beam and a low wall rail frame the back wall without
	# introducing decorative polygons that compete with the furniture.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(720.0, 0.0),
			Vector2(720.0, 36.0),
			Vector2(0.0, 48.0)
		]),
		Color(0.075, 0.12, 0.11, 0.9)
	)
	draw_polyline(
		PackedVector2Array([Vector2(0.0, 461.0), Vector2(720.0, 461.0)]),
		Color(0.54, 0.37, 0.24, 0.23),
		2.0,
		true
	)
	draw_polyline(
		PackedVector2Array([Vector2(0.0, 474.0), Vector2(720.0, 474.0)]),
		Color(0.025, 0.045, 0.04, 0.38),
		4.0,
		true
	)

	# Broad wall joints are deliberately subtle and front-facing.
	var joint_color := Color(0.035, 0.075, 0.07, 0.25)
	draw_polyline(PackedVector2Array([Vector2(84.0, 255.0), Vector2(636.0, 255.0)]), joint_color, 2.0, true)
	draw_polyline(PackedVector2Array([Vector2(231.0, 40.0), Vector2(231.0, 460.0)]), joint_color, 1.5, true)
	draw_polyline(PackedVector2Array([Vector2(488.0, 40.0), Vector2(488.0, 460.0)]), joint_color, 1.5, true)


func _draw_floor_joints() -> void:
	# Floor seams converge gently toward the room and become wider toward the
	# viewer. They are intentionally low contrast; the table remains the focus.
	var seam := Color(0.045, 0.06, 0.055, 0.28)
	draw_line(Vector2(360.0, 480.0), Vector2(-75.0, 1280.0), seam, 2.0, true)
	draw_line(Vector2(360.0, 480.0), Vector2(795.0, 1280.0), seam, 2.0, true)
	draw_line(Vector2(360.0, 480.0), Vector2(192.0, 1280.0), Color(0.045, 0.06, 0.055, 0.18), 1.5, true)
	draw_line(Vector2(360.0, 480.0), Vector2(528.0, 1280.0), Color(0.045, 0.06, 0.055, 0.18), 1.5, true)

	draw_polyline(
		PackedVector2Array([Vector2(0.0, 650.0), Vector2(360.0, 677.0), Vector2(720.0, 650.0)]),
		seam,
		1.5,
		true
	)
	draw_polyline(
		PackedVector2Array([Vector2(0.0, 895.0), Vector2(360.0, 924.0), Vector2(720.0, 895.0)]),
		seam,
		1.5,
		true
	)
	draw_polyline(
		PackedVector2Array([Vector2(0.0, 1130.0), Vector2(360.0, 1164.0), Vector2(720.0, 1130.0)]),
		seam,
		1.5,
		true
	)


func _draw_recessed_crystal_light() -> void:
	var center := Vector2(444.0, 160.0)
	for layer in range(10, 0, -1):
		var radius := float(layer) * 13.0
		var alpha := 0.0035 + float(10 - layer) * 0.0008
		draw_circle(center, radius, Color(0.36, 0.83, 0.73, alpha))


func _draw_tabletop_guides() -> void:
	var corners := PackedVector2Array([
		BENCH_POSITION + TABLE_REAR_LEFT,
		BENCH_POSITION + TABLE_REAR_RIGHT,
		BENCH_POSITION + TABLE_FRONT_RIGHT,
		BENCH_POSITION + TABLE_FRONT_LEFT,
		BENCH_POSITION + TABLE_REAR_LEFT
	])
	draw_polyline(corners, Color(0.16, 0.98, 0.72, 0.92), 2.0, true)
	draw_line(corners[0], corners[2], Color(0.16, 0.98, 0.72, 0.42), 1.0, true)
	draw_line(corners[1], corners[3], Color(0.16, 0.98, 0.72, 0.42), 1.0, true)

	for anchor in _tabletop_anchors:
		draw_circle(anchor, 7.0, Color(0.12, 0.98, 0.75, 0.9))
		draw_circle(anchor, 3.0, Color(0.025, 0.15, 0.12, 1.0))
