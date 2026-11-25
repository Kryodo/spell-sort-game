extends Node3D

const PUZZLE_SCENE := "res://scenes/alchemy_interaction_test.tscn"
const CHAPTER_SCENE := "res://scenes/chapter_forest_prototype.tscn"
const ROOM_WIDTH := 21.5
const ROOM_DEPTH := 6.75
const WALL_HEIGHT := 5.0

var _camera: Camera3D
var _modal: Panel
var _modal_title: Label
var _modal_body: Label
var _primary_button: Button
var _active_interaction := ""
var _interactables: Array[Area3D] = []
var _flames: Array[MeshInstance3D] = []
var _flame_lights: Array[OmniLight3D] = []
var _flame_base_positions: Array[Vector3] = []
var _elapsed := 0.0
var _camera_look_target := Vector3(0.45, 1.55, 0.0)
var _gesture_start := Vector2.ZERO
var _gesture_last := Vector2.ZERO
var _gesture_active := false
var _gesture_moved := false
var _transition_overlay: ColorRect


func _ready() -> void:
	_build_world()
	_build_room()
	_build_props()
	_build_hub_wings()
	_build_interactables()
	_build_hud()
	_build_transition_overlay()


func _build_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.082, 0.087, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.66, 0.59, 1.0)
	environment.ambient_light_energy = 0.72
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key_light.light_color = Color(1.0, 0.83, 0.63, 1.0)
	key_light.light_energy = 1.15
	key_light.shadow_enabled = true
	key_light.directional_shadow_max_distance = 18.0
	add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.1, 3.4, 1.5)
	fill_light.light_color = Color(0.52, 0.78, 0.78, 1.0)
	fill_light.light_energy = 0.65
	fill_light.omni_range = 8.0
	add_child(fill_light)

	_camera = Camera3D.new()
	_camera.name = "RoomCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# View into the open front-left corner, looking diagonally across both interior walls.
	# The wider orthographic frame compensates for the portrait viewport.
	_camera.size = 10.7
	_camera.position = Vector3(4.2, 8.1, 10.8)
	_camera.near = 0.05
	_camera.far = 60.0
	add_child(_camera)
	_camera.look_at(_camera_look_target, Vector3.UP)
	_camera.make_current()


func _build_room() -> void:
	var floor_material := _mat(Color(0.36, 0.25, 0.16))
	var plank_material := _mat(Color(0.43, 0.30, 0.19))
	var back_wall_material := _mat(Color(0.47, 0.48, 0.37))
	var side_wall_material := _mat(Color(0.34, 0.40, 0.34))
	var trim_material := _mat(Color(0.20, 0.15, 0.11))

	# One continuous shell replaces the old three-room strip. The side areas
	# remain part of the same laboratory and are reached by free camera panning.
	_add_box("Floor", Vector3(ROOM_WIDTH, 0.24, ROOM_DEPTH), Vector3(0.0, -0.12, 0.75), floor_material)
	for index in range(14):
		var z := -2.48 + float(index) * 0.48
		_add_box("FloorPlankSeam_%02d" % index, Vector3(ROOM_WIDTH - 0.06, 0.018, 0.018), Vector3(0.0, 0.012, z), plank_material)

	_add_box("BackWall", Vector3(ROOM_WIDTH, WALL_HEIGHT, 0.20), Vector3(0.0, WALL_HEIGHT * 0.5, -2.62), back_wall_material)
	_add_box("LeftWall", Vector3(0.20, WALL_HEIGHT, ROOM_DEPTH), Vector3(-ROOM_WIDTH * 0.5, WALL_HEIGHT * 0.5, 0.70), side_wall_material)
	_add_box("RightWall", Vector3(0.20, WALL_HEIGHT, ROOM_DEPTH), Vector3(ROOM_WIDTH * 0.5, WALL_HEIGHT * 0.5, 0.70), side_wall_material)

	_add_box("BackWallTopTrim", Vector3(ROOM_WIDTH, 0.22, 0.30), Vector3(0.0, WALL_HEIGHT - 0.05, -2.48), trim_material)
	_add_box("LeftWallTopTrim", Vector3(0.30, 0.22, ROOM_DEPTH), Vector3(-ROOM_WIDTH * 0.5 + 0.05, WALL_HEIGHT - 0.05, 0.70), trim_material)
	_add_box("RightWallTopTrim", Vector3(0.30, 0.22, ROOM_DEPTH), Vector3(ROOM_WIDTH * 0.5 - 0.05, WALL_HEIGHT - 0.05, 0.70), trim_material)
	_add_box("BackSkirting", Vector3(ROOM_WIDTH, 0.28, 0.24), Vector3(0.0, 0.18, -2.45), trim_material)
	_add_box("LeftSkirting", Vector3(0.24, 0.28, ROOM_DEPTH), Vector3(-ROOM_WIDTH * 0.5 + 0.16, 0.18, 0.70), trim_material)
	_add_box("RightSkirting", Vector3(0.24, 0.28, ROOM_DEPTH), Vector3(ROOM_WIDTH * 0.5 - 0.16, 0.18, 0.70), trim_material)

	var window_glass := _mat(Color(0.29, 0.57, 0.61), 0.0, 0.18)
	_add_box("WindowGlass", Vector3(1.55, 1.55, 0.055), Vector3(0.0, 3.05, -2.475), window_glass)
	_add_box("WindowFrameLeft", Vector3(0.13, 1.82, 0.16), Vector3(-0.84, 3.05, -2.40), trim_material)
	_add_box("WindowFrameRight", Vector3(0.13, 1.82, 0.16), Vector3(0.84, 3.05, -2.40), trim_material)
	_add_box("WindowFrameTop", Vector3(1.80, 0.13, 0.16), Vector3(0.0, 3.91, -2.40), trim_material)
	_add_box("WindowFrameBottom", Vector3(1.80, 0.13, 0.16), Vector3(0.0, 2.19, -2.40), trim_material)
	_add_box("WindowCrossbar", Vector3(1.58, 0.075, 0.12), Vector3(0.0, 3.05, -2.35), trim_material)
	_add_box("WindowSill", Vector3(2.02, 0.15, 0.42), Vector3(0.0, 2.14, -2.25), plank_material)

	_add_box("BackPostLeft", Vector3(0.20, WALL_HEIGHT, 0.22), Vector3(-ROOM_WIDTH * 0.5 + 0.12, 2.5, -2.43), trim_material)
	_add_box("BackPostRight", Vector3(0.20, WALL_HEIGHT, 0.22), Vector3(ROOM_WIDTH * 0.5 - 0.12, 2.5, -2.43), trim_material)

	var rug_material := _mat(Color(0.23, 0.28, 0.22))
	_add_box("WorkbenchRug", Vector3(3.85, 0.035, 2.65), Vector3(0.0, 0.025, 1.15), rug_material)
	_add_box("RugBorderFront", Vector3(3.72, 0.018, 0.055), Vector3(0.0, 0.05, 2.43), _mat(Color(0.61, 0.43, 0.24)))
	_add_box("RugBorderBack", Vector3(3.72, 0.018, 0.055), Vector3(0.0, 0.05, -0.13), _mat(Color(0.61, 0.43, 0.24)))


func _build_props() -> void:
	var wood := _mat(Color(0.28, 0.19, 0.13))
	var wood_light := _mat(Color(0.49, 0.33, 0.20))
	var wood_edge := _mat(Color(0.61, 0.43, 0.27))
	var brass := _mat(Color(0.72, 0.52, 0.25), 0.45)
	var ceramic := _mat(Color(0.23, 0.32, 0.29))
	var page := _mat(Color(0.79, 0.68, 0.48))
	var green := _mat(Color(0.35, 0.62, 0.35), 0.0, 0.22)

	# Main workbench in the foreground.
	_add_box("WorkbenchTop", Vector3(2.75, 0.22, 1.42), Vector3(0.0, 1.12, 1.63), wood_light)
	_add_box("WorkbenchFrontApron", Vector3(2.56, 0.32, 0.16), Vector3(0.0, 0.86, 2.25), wood)
	_add_box("WorkbenchDrawer", Vector3(0.82, 0.21, 0.08), Vector3(0.0, 0.88, 2.34), wood_light)
	_add_box("WorkbenchDrawerPull", Vector3(0.18, 0.045, 0.05), Vector3(0.0, 0.88, 2.405), brass)
	for x in [-1.13, 1.13]:
		for z in [1.12, 2.10]:
			_add_box("WorkbenchLeg", Vector3(0.20, 0.98, 0.20), Vector3(x, 0.52, z), wood)
	_add_box("WorkbenchLowerBrace", Vector3(2.30, 0.13, 0.14), Vector3(0.0, 0.34, 1.62), wood)

	# Grimoire resting on the workbench.
	var book := _add_box("GrimoireCover", Vector3(0.80, 0.13, 0.92), Vector3(-0.48, 1.30, 1.62), _mat(Color(0.26, 0.25, 0.40)))
	book.rotation_degrees = Vector3(0.0, -12.0, -7.0)
	var book_pages := _add_box("GrimoirePages", Vector3(0.72, 0.07, 0.84), Vector3(-0.48, 1.39, 1.62), page)
	book_pages.rotation_degrees = Vector3(0.0, -12.0, -7.0)
	var book_emblem := _add_box("GrimoireEmblem", Vector3(0.20, 0.025, 0.24), Vector3(-0.48, 1.44, 1.62), brass)
	book_emblem.rotation_degrees = Vector3(0.0, -12.0, -7.0)

	# Ingredient cabinet on the left.
	_add_box("CabinetBody", Vector3(1.02, 2.36, 0.88), Vector3(-2.00, 1.25, 0.30), wood)
	_add_box("CabinetTop", Vector3(1.18, 0.16, 1.00), Vector3(-2.00, 2.52, 0.30), wood_edge)
	_add_box("CabinetShelf1", Vector3(0.96, 0.12, 0.84), Vector3(-2.00, 1.65, 0.30), wood_light)
	_add_box("CabinetShelf2", Vector3(0.96, 0.12, 0.84), Vector3(-2.00, 0.90, 0.30), wood_light)
	_add_box("CabinetSideLeft", Vector3(0.12, 2.30, 0.92), Vector3(-2.56, 1.26, 0.30), wood_edge)
	_add_box("CabinetSideRight", Vector3(0.12, 2.30, 0.92), Vector3(-1.44, 1.26, 0.30), wood_edge)
	for index in range(5):
		var tint: Color = [Color(0.34, 0.67, 0.55), Color(0.65, 0.48, 0.77), Color(0.87, 0.48, 0.26), Color(0.37, 0.60, 0.76), Color(0.77, 0.67, 0.34)][index]
		_make_potion(Vector3(-2.33 + float(index) * 0.16, 1.90, 0.27), tint, 0.70 + 0.04 * float(index % 2))
		_add_box("CabinetBook_%d" % index, Vector3(0.12, 0.46 + 0.05 * float(index % 2), 0.40), Vector3(-2.30 + float(index) * 0.15, 1.18, 0.30), _mat(tint.darkened(0.38)))

	# A compact cauldron and stand on the right.
	_add_box("CauldronStandTop", Vector3(1.30, 0.15, 1.12), Vector3(1.78, 0.78, 0.42), wood_light)
	for x in [1.32, 2.24]:
		_add_box("CauldronStandLeg", Vector3(0.14, 0.76, 0.14), Vector3(x, 0.39, 0.42), wood)
	_add_cylinder("CauldronBody", 0.56, 0.40, 0.76, Vector3(1.78, 1.27, 0.42), ceramic)
	_add_cylinder("CauldronRim", 0.61, 0.61, 0.13, Vector3(1.78, 1.67, 0.42), brass)
	_add_cylinder("CauldronLiquid", 0.51, 0.51, 0.055, Vector3(1.78, 1.62, 0.42), green)
	_add_sphere("CauldronBubbleA", 0.075, Vector3(1.56, 1.72, 0.32), _mat(Color(0.58, 0.85, 0.53), 0.0, 0.32))
	_add_sphere("CauldronBubbleB", 0.055, Vector3(1.91, 1.73, 0.50), _mat(Color(0.58, 0.85, 0.53), 0.0, 0.32))
	_add_box("CauldronHandleLeft", Vector3(0.10, 0.16, 0.15), Vector3(1.18, 1.54, 0.42), brass)
	_add_box("CauldronHandleRight", Vector3(0.10, 0.16, 0.15), Vector3(2.38, 1.54, 0.42), brass)

	# Wall shelves with readable, simple silhouettes.
	_add_box("BackShelf", Vector3(1.95, 0.14, 0.52), Vector3(-1.72, 2.16, -2.05), wood_light)
	_add_box("BackShelfSupportLeft", Vector3(0.10, 0.34, 0.12), Vector3(-2.48, 2.00, -2.25), brass)
	_add_box("BackShelfSupportRight", Vector3(0.10, 0.34, 0.12), Vector3(-0.96, 2.00, -2.25), brass)
	for index in range(5):
		var colors: Array[Color] = [
			Color(0.35, 0.70, 0.63), Color(0.69, 0.56, 0.85),
			Color(0.89, 0.50, 0.29), Color(0.42, 0.65, 0.82),
			Color(0.83, 0.70, 0.39)
		]
		_make_potion(Vector3(-2.42 + float(index) * 0.34, 2.35, -2.05), colors[index], 0.76)

	_add_box("MapShelf", Vector3(1.38, 0.14, 0.52), Vector3(1.83, 2.00, -2.05), wood_light)
	_add_box("MapShelfSupportLeft", Vector3(0.10, 0.30, 0.12), Vector3(1.30, 1.83, -2.25), brass)
	_add_box("MapShelfSupportRight", Vector3(0.10, 0.30, 0.12), Vector3(2.36, 1.83, -2.25), brass)
	_add_box("WorldMapFrame", Vector3(1.02, 1.26, 0.14), Vector3(1.83, 2.95, -2.42), brass)
	_add_box("WorldMapCanvas", Vector3(0.88, 1.12, 0.055), Vector3(1.83, 2.95, -2.32), _mat(Color(0.42, 0.52, 0.43)))
	for index in range(4):
		_add_box("MapRoute_%d" % index, Vector3(0.055, 0.55 - 0.07 * float(index), 0.025), Vector3(1.58 + float(index) * 0.16, 2.93 + 0.10 * sin(float(index)), -2.275), _mat(Color(0.83, 0.69, 0.39)))

	# Candles add a little warm life without relying on textures.
	_add_candle(Vector3(-2.18, 2.38, -2.00))
	_add_candle(Vector3(0.78, 1.35, 1.55))
	_add_candle(Vector3(2.16, 2.22, -2.02))

	# Simple plant silhouettes near the window.
	_add_cylinder("PlantPot", 0.24, 0.18, 0.30, Vector3(0.93, 0.17, -2.03), _mat(Color(0.57, 0.32, 0.22)))
	for index in range(5):
		var leaf := _add_sphere("PlantLeaf_%d" % index, 0.20, Vector3(0.93 + 0.15 * cos(float(index) * TAU / 5.0), 0.48 + 0.08 * float(index % 2), -2.02 + 0.15 * sin(float(index) * TAU / 5.0)), _mat(Color(0.28, 0.52, 0.32)))
		leaf.scale = Vector3(0.68, 1.0, 0.48)



func _build_hub_wings() -> void:
	var wood := _mat(Color(0.27, 0.18, 0.12))
	var wood_light := _mat(Color(0.48, 0.32, 0.20))
	var brass := _mat(Color(0.70, 0.52, 0.27), 0.35)

	# Storage wing to the left of the central laboratory.
	var storage_x := -7.8
	for shelf_index in range(3):
		var shelf_x := storage_x - 1.65 + float(shelf_index) * 1.55
		_add_box("StorageShelf_%d" % shelf_index, Vector3(1.25, 0.13, 0.52), Vector3(shelf_x, 2.55, -2.06), wood_light)
		_add_box("StorageShelfUpper_%d" % shelf_index, Vector3(1.25, 0.13, 0.52), Vector3(shelf_x, 3.66, -2.06), wood_light)
		for item_index in range(4):
			var colors: Array[Color] = [Color(0.37, 0.69, 0.56), Color(0.69, 0.53, 0.82), Color(0.89, 0.50, 0.28), Color(0.40, 0.62, 0.77)]
			var potion_x := shelf_x - 0.43 + float(item_index) * 0.28
			_make_potion(Vector3(potion_x, 2.72, -2.06), colors[(shelf_index + item_index) % 4], 0.82)
			_make_potion(Vector3(potion_x, 3.83, -2.06), colors[(shelf_index + item_index + 1) % 4], 0.72)
	_add_box("StorageIslandTop", Vector3(2.45, 0.20, 1.35), Vector3(storage_x, 1.06, 1.55), wood_light)
	for leg_x in [storage_x - 0.98, storage_x + 0.98]:
		for leg_z in [1.08, 2.02]:
			_add_box("StorageIslandLeg", Vector3(0.16, 0.92, 0.16), Vector3(leg_x, 0.48, leg_z), wood)
	for crate_index in range(3):
		var crate_x := storage_x - 0.72 + float(crate_index) * 0.72
		_add_box("IngredientCrate_%d" % crate_index, Vector3(0.54, 0.48, 0.52), Vector3(crate_x, 1.40, 1.50), _mat(Color(0.39, 0.29, 0.18)))
		_add_box("IngredientCrateBand_%d" % crate_index, Vector3(0.56, 0.07, 0.055), Vector3(crate_x, 1.43, 1.77), brass)

	# Research archive to the right of the central laboratory.
	var archive_x := 7.8
	for shelf_index in range(2):
		var shelf_x := archive_x - 1.65 + float(shelf_index) * 1.55
		_add_box("ArchiveBookcase_%d" % shelf_index, Vector3(1.24, 3.42, 0.48), Vector3(shelf_x, 1.91, -2.18), wood)
		for level in range(3):
			var shelf_y := 0.82 + float(level) * 1.05
			_add_box("ArchiveShelf_%d_%d" % [shelf_index, level], Vector3(1.10, 0.10, 0.55), Vector3(shelf_x, shelf_y, -1.87), wood_light)
			for book_index in range(4):
				var book_colors: Array[Color] = [Color(0.30, 0.39, 0.52), Color(0.52, 0.31, 0.34), Color(0.43, 0.48, 0.32), Color(0.65, 0.50, 0.29)]
				var book := _add_box("ArchiveBook_%d_%d_%d" % [shelf_index, level, book_index], Vector3(0.16, 0.46, 0.32), Vector3(shelf_x - 0.40 + float(book_index) * 0.26, shelf_y + 0.26, -1.92), _mat(book_colors[book_index]))
				book.rotation_degrees.z = -3.0 * float(book_index % 2)
	_add_box("ArchiveMapFrame", Vector3(1.72, 2.05, 0.16), Vector3(archive_x + 1.52, 2.83, -2.43), brass)
	_add_box("ArchiveMap", Vector3(1.52, 1.85, 0.06), Vector3(archive_x + 1.52, 2.83, -2.32), _mat(Color(0.29, 0.42, 0.39)))
	_add_box("ArchiveDeskTop", Vector3(2.35, 0.18, 1.30), Vector3(archive_x, 1.05, 1.52), wood_light)
	for leg_x in [archive_x - 0.92, archive_x + 0.92]:
		for leg_z in [1.02, 2.00]:
			_add_box("ArchiveDeskLeg", Vector3(0.16, 0.94, 0.16), Vector3(leg_x, 0.48, leg_z), wood)
	_add_box("ArchiveOpenBook", Vector3(1.10, 0.08, 0.72), Vector3(archive_x - 0.32, 1.19, 1.50), _mat(Color(0.78, 0.68, 0.49)))
	_add_cylinder("ArchiveCrystalBase", 0.35, 0.27, 0.22, Vector3(archive_x + 0.70, 1.20, 1.48), brass)
	var archive_crystal := _add_sphere("ArchiveCrystal", 0.34, Vector3(archive_x + 0.70, 1.58, 1.48), _mat(Color(0.38, 0.78, 0.76), 0.0, 1.1))
	archive_crystal.scale = Vector3(0.70, 1.35, 0.70)


func _build_interactables() -> void:
	_register_interactable(
		"alchemy_table", "Alchemy Table",
		"Your first experiment is ready. Separate the tangled tide, moon and ember essences by guiding each vial's open mouth into position.",
		Vector3(0.0, 1.17, 1.72), Vector3(2.72, 0.30, 1.52)
	)
	_register_interactable(
		"grimoire", "The Grimoire",
		"Recipes, discoveries and notes will collect here as the laboratory is restored.",
		Vector3(-0.48, 1.48, 1.62), Vector3(0.94, 0.36, 0.98)
	)
	_register_interactable(
		"ingredient_cabinet", "Ingredient Cabinet",
		"The cabinet is waiting to be stocked with herbs, minerals and curious ingredients.",
		Vector3(-2.00, 1.55, 0.30), Vector3(1.24, 2.48, 1.02)
	)
	_register_interactable(
		"cauldron", "The Cauldron",
		"The fire is low, but the cauldron still holds a little dormant magic. New recipes will bring it back to life.",
		Vector3(1.78, 1.42, 0.42), Vector3(1.38, 1.42, 1.18)
	)
	_register_interactable(
		"ingredient_store", "Ingredient Stores",
		"Collected herbs, minerals and curious ingredients are kept here. The shelves and work surfaces will gradually fill as new ingredients are discovered.",
		Vector3(-7.8, 1.42, 1.50), Vector3(2.55, 1.10, 1.50)
	)
	_register_interactable(
		"chapter_gate", "Verdant Hollow",
		"A first place beyond the laboratory has been discovered. Explore a quiet glade of ancient stones, luminous plants and forgotten magic.",
		Vector3(9.32, 2.80, -2.25), Vector3(1.80, 2.30, 0.70)
	)
	_register_interactable(
		"world_map", "World Map",
		"Unknown places lie beyond the laboratory. Discoveries will gradually reveal new environments and experiments.",
		Vector3(1.83, 2.95, -2.27), Vector3(1.16, 1.42, 0.42)
	)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var header := _make_panel(Rect2(22.0, 22.0, 430.0, 78.0), Color(0.045, 0.067, 0.068, 0.80), Color(0.78, 0.61, 0.36, 0.56), 17)
	root.add_child(header)
	var title := _make_label("THE LOST ALCHEMY LAB", 20, Color(0.98, 0.87, 0.68))
	title.position = Vector2(17.0, 10.0)
	title.size = Vector2(395.0, 31.0)
	header.add_child(title)
	var subtitle := _make_label("A quiet place for curious discoveries", 11, Color(0.76, 0.84, 0.78))
	subtitle.position = Vector2(19.0, 43.0)
	subtitle.size = Vector2(390.0, 22.0)
	header.add_child(subtitle)

	var footer := _make_panel(Rect2(65.0, 1188.0, 590.0, 62.0), Color(0.045, 0.067, 0.068, 0.78), Color(0.78, 0.61, 0.36, 0.40), 16)
	root.add_child(footer)
	var instruction := _make_label("SWIPE TO LOOK AROUND  ·  TAP OBJECTS TO INTERACT", 13, Color(0.98, 0.91, 0.77))
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.position = Vector2(12.0, 8.0)
	instruction.size = Vector2(566.0, 22.0)
	footer.add_child(instruction)
	var footer_note := _make_label("ONE CONTINUOUS LABORATORY  ·  EXPLORE FREELY", 9, Color(0.71, 0.80, 0.76))
	footer_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_note.position = Vector2(12.0, 32.0)
	footer_note.size = Vector2(566.0, 18.0)
	footer.add_child(footer_note)


	_modal = _make_panel(Rect2(76.0, 492.0, 568.0, 292.0), Color(0.055, 0.078, 0.075, 0.97), Color(0.86, 0.69, 0.43, 0.92), 22)
	_modal.visible = false
	root.add_child(_modal)

	var kicker := _make_label("LABORATORY  /  INTERACTION", 10, Color(0.84, 0.68, 0.44))
	kicker.position = Vector2(27.0, 22.0)
	kicker.size = Vector2(500.0, 19.0)
	_modal.add_child(kicker)

	_modal_title = _make_label("Alchemy Table", 25, Color(0.98, 0.93, 0.82))
	_modal_title.position = Vector2(26.0, 55.0)
	_modal_title.size = Vector2(505.0, 42.0)
	_modal.add_child(_modal_title)

	_modal_body = _make_label("", 14, Color(0.78, 0.85, 0.80))
	_modal_body.position = Vector2(28.0, 111.0)
	_modal_body.size = Vector2(510.0, 86.0)
	_modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal.add_child(_modal_body)

	_primary_button = _make_button("BEGIN EXPERIMENT", true)
	_primary_button.position = Vector2(284.0, 220.0)
	_primary_button.size = Vector2(244.0, 48.0)
	_primary_button.pressed.connect(_on_primary_pressed)
	_modal.add_child(_primary_button)

	var close_button := _make_button("CLOSE", false)
	close_button.position = Vector2(28.0, 220.0)
	close_button.size = Vector2(150.0, 48.0)
	close_button.pressed.connect(_close_modal)
	_modal.add_child(close_button)


func _register_interactable(id: String, title: String, description: String, center: Vector3, extent: Vector3) -> void:
	var area := Area3D.new()
	area.name = "Interact_" + id
	area.position = center
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("interaction_id", id)
	area.set_meta("title", title)
	area.set_meta("description", description)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = extent
	collision.shape = shape
	area.add_child(collision)

	var marker := MeshInstance3D.new()
	marker.name = "Marker"
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.075
	marker_mesh.height = 0.15
	marker.mesh = marker_mesh
	marker.position = Vector3(0.0, extent.y * 0.5 + 0.20, 0.0)
	marker.material_override = _mat(Color(0.98, 0.78, 0.43), 0.0, 0.65)
	area.add_child(marker)

	add_child(area)
	_interactables.append(area)


func _make_potion(world_position: Vector3, tint: Color, scale_value: float) -> void:
	var glass := _mat(Color(tint.r, tint.g, tint.b, 0.92), 0.0, 0.08)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_add_cylinder("PotionBody", 0.095 * scale_value, 0.095 * scale_value, 0.30 * scale_value, world_position, glass)
	_add_cylinder("PotionNeck", 0.046 * scale_value, 0.046 * scale_value, 0.12 * scale_value, world_position + Vector3(0.0, 0.21 * scale_value, 0.0), glass)
	_add_cylinder("PotionCork", 0.052 * scale_value, 0.052 * scale_value, 0.07 * scale_value, world_position + Vector3(0.0, 0.30 * scale_value, 0.0), _mat(Color(0.57, 0.38, 0.22)))


func _add_candle(world_position: Vector3) -> void:
	_add_cylinder("Candle", 0.09, 0.09, 0.30, world_position, _mat(Color(0.79, 0.69, 0.49)))
	var flame := _add_sphere("CandleFlame", 0.075, world_position + Vector3(0.0, 0.20, 0.0), _mat(Color(1.0, 0.64, 0.29), 0.0, 1.4))
	flame.scale = Vector3(0.72, 1.25, 0.72)
	_flames.append(flame)
	_flame_base_positions.append(flame.position)
	var light := OmniLight3D.new()
	light.position = world_position + Vector3(0.0, 0.28, 0.0)
	light.light_color = Color(1.0, 0.59, 0.30)
	light.light_energy = 0.72
	light.omni_range = 2.2
	add_child(light)
	_flame_lights.append(light)


func _add_box(node_name: String, dimensions: Vector3, world_position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = world_position
	instance.material_override = material
	add_child(instance)
	return instance


func _add_cylinder(node_name: String, top_radius: float, bottom_radius: float, height: float, world_position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 16
	instance.mesh = mesh
	instance.position = world_position
	instance.material_override = material
	add_child(instance)
	return instance


func _add_sphere(node_name: String, radius: float, world_position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	instance.mesh = mesh
	instance.position = world_position
	instance.material_override = material
	add_child(instance)
	return instance


func _mat(color: Color, metallic: float = 0.0, emission_strength: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	material.metallic = metallic
	if emission_strength > 0.0:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = emission_strength
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _make_label(text_value: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_panel(rect: Rect2, background: Color, border: Color, radius: int) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 3.0)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_button(text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal_color := Color(0.39, 0.28, 0.17, 0.98) if primary else Color(0.10, 0.15, 0.14, 0.96)
	var hover_color := Color(0.52, 0.38, 0.22, 1.0) if primary else Color(0.17, 0.23, 0.21, 1.0)
	var border_color := Color(0.91, 0.73, 0.46, 0.92) if primary else Color(0.63, 0.73, 0.67, 0.66)
	button.add_theme_stylebox_override("normal", _button_style(normal_color, border_color))
	button.add_theme_stylebox_override("hover", _button_style(hover_color, border_color))
	button.add_theme_stylebox_override("pressed", _button_style(normal_color.darkened(0.15), border_color))
	return button


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style


func _unhandled_input(event: InputEvent) -> void:
	if _modal != null and _modal.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_hub_gesture(event.position)
		else:
			_finish_hub_gesture(event.position)
	elif event is InputEventScreenDrag:
		_update_hub_gesture(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_hub_gesture(event.position)
		else:
			_finish_hub_gesture(event.position)
	elif event is InputEventMouseMotion:
		if _gesture_active and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_update_hub_gesture(event.position)
		elif not _gesture_active:
			_update_hover(event.position)


func _begin_hub_gesture(screen_position: Vector2) -> void:
	_gesture_active = true
	_gesture_moved = false
	_gesture_start = screen_position
	_gesture_last = screen_position


func _update_hub_gesture(screen_position: Vector2) -> void:
	if not _gesture_active:
		return
	var delta := screen_position - _gesture_last
	if delta.length() > 1.0:
		_pan_camera(delta)
		_gesture_last = screen_position
	if screen_position.distance_to(_gesture_start) > 12.0:
		_gesture_moved = true


func _finish_hub_gesture(screen_position: Vector2) -> void:
	if not _gesture_active:
		return
	_update_hub_gesture(screen_position)
	_gesture_active = false
	if not _gesture_moved and screen_position.distance_to(_gesture_start) < 24.0:
		_try_interact(screen_position)


func _pan_camera(screen_delta: Vector2) -> void:
	if _camera == null:
		return
	var viewport_height := maxf(1.0, get_viewport().get_visible_rect().size.y)
	var world_per_pixel := _camera.size / viewport_height
	var screen_right := _camera.global_basis.x
	screen_right.y = 0.0
	screen_right = screen_right.normalized()
	var screen_up := _camera.global_basis.y
	screen_up.y = 0.0
	screen_up = screen_up.normalized()
	var requested_shift := (-screen_right * screen_delta.x + screen_up * screen_delta.y) * world_per_pixel
	requested_shift.y = 0.0

	var next_target := _camera_look_target + requested_shift
	next_target.x = clampf(next_target.x, -6.4, 6.4)
	next_target.z = clampf(next_target.z, -0.8, 0.8)
	var actual_shift := next_target - _camera_look_target
	actual_shift.y = 0.0
	if actual_shift.length_squared() < 0.000001:
		return
	_camera_look_target = next_target
	_camera.position += actual_shift
	_camera.look_at(_camera_look_target, Vector3.UP)


func _try_interact(screen_position: Vector2) -> void:
	var area := _pick_interactable(screen_position)
	if area == null:
		return
	_active_interaction = String(area.get_meta("interaction_id"))
	_modal_title.text = String(area.get_meta("title"))
	_modal_body.text = String(area.get_meta("description"))
	_primary_button.text = "BEGIN EXPERIMENT" if _active_interaction == "alchemy_table" else ("EXPLORE CHAPTER" if _active_interaction == "world_map" or _active_interaction == "chapter_gate" else "CLOSE")
	_modal.visible = true


func _pick_interactable(screen_position: Vector2) -> Area3D:
	var ray_origin := _camera.project_ray_origin(screen_position)
	var ray_direction := _camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 60.0, 2)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	var collider: Object = result.get("collider")
	if collider is Area3D:
		return collider as Area3D
	return null


func _update_hover(screen_position: Vector2) -> void:
	var hovered := _pick_interactable(screen_position)
	for area in _interactables:
		var marker := area.get_node_or_null("Marker") as MeshInstance3D
		if marker != null:
			var is_hovered := area == hovered
			marker.scale = Vector3.ONE * (1.45 if is_hovered else 1.0)


func _on_primary_pressed() -> void:
	if _active_interaction == "alchemy_table":
		_transition_to_scene(PUZZLE_SCENE, true)
	elif _active_interaction == "world_map" or _active_interaction == "chapter_gate":
		_transition_to_scene(CHAPTER_SCENE)
	else:
		_close_modal()


func _build_transition_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_transition_overlay = ColorRect.new()
	_transition_overlay.color = Color.BLACK
	_transition_overlay.modulate.a = 1.0
	_transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_transition_overlay)
	var fade_in := create_tween()
	fade_in.tween_property(_transition_overlay, "modulate:a", 0.0, 0.34)


func _transition_to_scene(scene_path: String, zoom_to_bench: bool = false) -> void:
	if _transition_overlay == null:
		get_tree().change_scene_to_file(scene_path)
		return
	var fade_out := create_tween().set_parallel(true)
	fade_out.tween_property(_transition_overlay, "modulate:a", 1.0, 0.30)
	if zoom_to_bench and _camera != null:
		fade_out.tween_property(_camera, "size", 9.2, 0.30)
	await fade_out.finished
	get_tree().change_scene_to_file(scene_path)


func _close_modal() -> void:
	if _modal != null:
		_modal.visible = false
	_active_interaction = ""


func _process(delta: float) -> void:
	_elapsed += delta
	for index in range(_flames.size()):
		var flame := _flames[index]
		flame.position = _flame_base_positions[index] + Vector3(0.0, 0.025 * sin(_elapsed * 8.0 + float(index) * 1.7), 0.0)
		_flame_lights[index].light_energy = 0.62 + 0.16 * sin(_elapsed * 6.0 + float(index) * 1.3)
