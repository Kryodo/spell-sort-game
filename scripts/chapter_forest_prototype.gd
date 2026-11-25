extends Node3D

const HUB_SCENE := "res://scenes/lab_room_prototype.tscn"

var _camera: Camera3D
var _modal: Panel
var _modal_title: Label
var _modal_text: Label
var _active_id := ""
var _interactables: Array[Area3D] = []
var _fireflies: Array[MeshInstance3D] = []
var _firefly_origins: Array[Vector3] = []
var _firefly_lights: Array[OmniLight3D] = []
var _clock := 0.0


func _ready() -> void:
	_build_world()
	_build_glade()
	_build_landmarks()
	_build_interactions()
	_build_hud()


func _build_world() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.060, 0.067)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.51, 0.65, 0.59)
	environment.ambient_light_energy = 0.66
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.16, 0.27, 0.25)
	environment.fog_density = 0.018
	world.environment = environment
	add_child(world)

	var moonlight := DirectionalLight3D.new()
	moonlight.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	moonlight.light_color = Color(0.60, 0.76, 0.82)
	moonlight.light_energy = 0.78
	moonlight.shadow_enabled = true
	add_child(moonlight)

	var altar_light := OmniLight3D.new()
	altar_light.position = Vector3(0.0, 3.0, -0.2)
	altar_light.light_color = Color(0.43, 0.84, 0.76)
	altar_light.light_energy = 1.35
	altar_light.omni_range = 5.0
	add_child(altar_light)

	var camera := Camera3D.new()
	_camera = camera
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 10.7
	_camera.position = Vector3(6.8, 8.1, 10.8)
	_camera.near = 0.05
	_camera.far = 80.0
	add_child(_camera)
	_camera.look_at(Vector3(0.0, 1.45, -0.25), Vector3.UP)
	_camera.make_current()


func _build_glade() -> void:
	var ground := _mat(Color(0.19, 0.31, 0.24))
	_add_box("ForestFloor", Vector3(18.0, 0.35, 18.0), Vector3(0.0, -0.18, 0.0), ground)

	var path_material := _mat(Color(0.43, 0.42, 0.34))
	for index in range(9):
		var z := 4.5 - float(index) * 0.78
		var x := -0.20 + 0.18 * sin(float(index) * 0.7)
		var stone := _add_box("PathStone_%d" % index, Vector3(1.25, 0.10, 0.62), Vector3(x, 0.035, z), path_material)
		stone.rotation_degrees.y = 8.0 * sin(float(index) * 0.5)

	# Soft banks frame the clearing and give the path a destination.
	for index in range(7):
		var z := -3.0 + float(index) * 1.05
		var left_rock := _add_sphere("LeftMossRock_%d" % index, 0.72, Vector3(-5.2 + 0.22 * sin(float(index)), 0.35, z), _mat(Color(0.28, 0.37, 0.28)))
		left_rock.scale = Vector3(1.35, 0.70, 0.90)
		var right_rock := _add_sphere("RightMossRock_%d" % index, 0.68, Vector3(5.0 + 0.18 * cos(float(index)), 0.32, z - 0.25), _mat(Color(0.31, 0.39, 0.29)))
		right_rock.scale = Vector3(1.30, 0.68, 0.92)

	_add_tree(Vector3(-4.2, 0.0, -2.9), 1.25)
	_add_tree(Vector3(-5.0, 0.0, 1.0), 1.05)
	_add_tree(Vector3(-3.9, 0.0, 4.5), 0.95)
	_add_tree(Vector3(4.3, 0.0, -3.1), 1.30)
	_add_tree(Vector3(5.0, 0.0, 1.5), 1.05)
	_add_tree(Vector3(3.8, 0.0, 4.6), 0.95)

	# Fern-like silhouettes around the stone path.
	for plant_index in range(10):
		var side := -1.0 if plant_index % 2 == 0 else 1.0
		var z := 3.7 - float(plant_index) * 0.72
		var x := side * (2.5 + 0.35 * sin(float(plant_index)))
		_add_fern(Vector3(x, 0.06, z), 0.70 + 0.12 * float(plant_index % 3))

	# A quiet pool sits behind the gate.
	var pool := _add_cylinder("SpringPool", 1.32, 1.32, 0.065, Vector3(0.0, 0.04, -3.75), _mat(Color(0.15, 0.45, 0.50, 0.88), 0.10, 0.18))
	pool.rotation_degrees.x = 0.0
	var pool_edge := _add_cylinder("SpringPoolEdge", 1.50, 1.50, 0.11, Vector3(0.0, 0.00, -3.75), _mat(Color(0.38, 0.42, 0.34)))
	pool_edge.material_override = _mat(Color(0.38, 0.42, 0.34))


func _build_landmarks() -> void:
	var stone := _mat(Color(0.40, 0.45, 0.40))
	var worn_stone := _mat(Color(0.52, 0.54, 0.44))
	var gold := _mat(Color(0.72, 0.58, 0.31), 0.30)
	var glow := _mat(Color(0.42, 0.88, 0.77), 0.0, 1.4)

	# Old stone arch at the end of the path.
	_add_box("GateLeftFoot", Vector3(1.05, 0.40, 0.88), Vector3(-1.55, 0.20, -2.35), worn_stone)
	_add_box("GateRightFoot", Vector3(1.05, 0.40, 0.88), Vector3(1.55, 0.20, -2.35), worn_stone)
	_add_box("GateLeftPillar", Vector3(0.66, 3.20, 0.68), Vector3(-1.55, 1.92, -2.35), stone)
	_add_box("GateRightPillar", Vector3(0.66, 3.20, 0.68), Vector3(1.55, 1.92, -2.35), stone)
	_add_box("GateLintel", Vector3(3.88, 0.72, 0.90), Vector3(0.0, 3.75, -2.35), worn_stone)
	_add_box("GateTopInset", Vector3(1.55, 0.14, 0.12), Vector3(0.0, 3.75, -1.87), gold)
	for rune_index in range(3):
		var rune := _add_box("GateRune_%d" % rune_index, Vector3(0.18, 0.52, 0.07), Vector3(-0.42 + float(rune_index) * 0.42, 3.74, -1.83), glow)
		rune.rotation_degrees.z = 22.0 - float(rune_index) * 22.0

	# Central discovery altar with a recognizable broad bowl and pedestal.
	_add_cylinder("AltarFoot", 0.80, 0.92, 0.24, Vector3(0.0, 0.22, 0.10), worn_stone)
	_add_cylinder("AltarPedestal", 0.54, 0.68, 0.82, Vector3(0.0, 0.72, 0.10), stone)
	_add_cylinder("AltarBowl", 0.83, 0.62, 0.28, Vector3(0.0, 1.24, 0.10), worn_stone)
	_add_cylinder("AltarWater", 0.58, 0.58, 0.035, Vector3(0.0, 1.40, 0.10), glow)
	_add_sphere("AltarSeed", 0.34, Vector3(0.0, 1.82, 0.10), _mat(Color(0.61, 0.94, 0.78), 0.0, 1.8))
	_add_cylinder("AltarGoldBand", 0.56, 0.56, 0.08, Vector3(0.0, 0.63, 0.10), gold)

	# Broken standing stones on the edge of the glade.
	for index in range(4):
		var angle := TAU * float(index) / 4.0
		var x := cos(angle) * 3.8
		var z := sin(angle) * 2.7 - 0.3
		var standing := _add_box("StandingStone_%d" % index, Vector3(0.42, 1.75 + 0.25 * float(index % 2), 0.52), Vector3(x, 0.87, z), stone)
		standing.rotation_degrees.z = -7.0 + 4.0 * float(index)
		_add_box("StandingStoneCap_%d" % index, Vector3(0.58, 0.22, 0.62), Vector3(x, 1.82 + 0.25 * float(index % 2), z), worn_stone)

	_add_crystal_cluster(Vector3(-2.65, 0.08, -1.05), Color(0.36, 0.79, 0.78))
	_add_crystal_cluster(Vector3(2.85, 0.08, -0.45), Color(0.66, 0.56, 0.91))
	_add_firefly(Vector3(-1.75, 1.55, 1.85))
	_add_firefly(Vector3(1.85, 2.10, 0.35))
	_add_firefly(Vector3(-2.75, 1.35, -2.25))
	_add_firefly(Vector3(2.70, 1.65, -2.65))
	_add_firefly(Vector3(0.85, 2.35, -3.10))


func _build_interactions() -> void:
	_register_interaction("altar", "The Verdant Altar", "A luminous seed rests above the old stone bowl. It responds to the alchemical essences you have begun to separate.", Vector3(0.0, 1.45, 0.10), Vector3(1.75, 2.20, 1.50))
	_register_interaction("gate", "The Ancient Gate", "Runes awaken in the stone. Beyond this arch lies a deeper part of Verdant Hollow, still hidden from view.", Vector3(0.0, 3.00, -2.32), Vector3(3.95, 2.80, 0.92))
	_register_interaction("spring", "The Moonlit Spring", "The water reflects a light that does not seem to come from the sky. Perhaps a discovered recipe will reveal its purpose.", Vector3(0.0, 0.28, -3.75), Vector3(2.90, 0.65, 2.90))


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var header := _panel(Rect2(20.0, 22.0, 680.0, 100.0), Color(0.035, 0.058, 0.064, 0.86), Color(0.71, 0.76, 0.62, 0.62), 18)
	root.add_child(header)
	var eyebrow := _label("CHAPTER 01  /  FIRST DISCOVERY", 10, Color(0.72, 0.84, 0.74))
	eyebrow.position = Vector2(20.0, 12.0)
	eyebrow.size = Vector2(420.0, 20.0)
	header.add_child(eyebrow)
	var title := _label("Verdant Hollow", 25, Color(0.94, 0.91, 0.77))
	title.position = Vector2(18.0, 40.0)
	title.size = Vector2(430.0, 40.0)
	header.add_child(title)
	var back := _button("BACK TO LAB", false)
	back.position = Vector2(496.0, 26.0)
	back.size = Vector2(164.0, 48.0)
	back.pressed.connect(func(): get_tree().change_scene_to_file(HUB_SCENE))
	header.add_child(back)

	var footer := _panel(Rect2(52.0, 1178.0, 616.0, 72.0), Color(0.035, 0.058, 0.064, 0.82), Color(0.71, 0.76, 0.62, 0.48), 18)
	root.add_child(footer)
	var instruction := _label("EXPLORE THE GLADE  ·  TAP THE ALTAR, GATE OR SPRING", 11, Color(0.82, 0.88, 0.80))
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.position = Vector2(12.0, 12.0)
	instruction.size = Vector2(592.0, 40.0)
	footer.add_child(instruction)

	_modal = _panel(Rect2(72.0, 484.0, 576.0, 304.0), Color(0.035, 0.058, 0.064, 0.97), Color(0.74, 0.80, 0.64, 0.88), 22)
	_modal.visible = false
	root.add_child(_modal)
	var kicker := _label("VERDANT HOLLOW  /  FIELD NOTES", 10, Color(0.72, 0.84, 0.74))
	kicker.position = Vector2(26.0, 22.0)
	kicker.size = Vector2(510.0, 20.0)
	_modal.add_child(kicker)
	_modal_title = _label("A Quiet Discovery", 25, Color(0.95, 0.93, 0.81))
	_modal_title.position = Vector2(25.0, 57.0)
	_modal_title.size = Vector2(520.0, 42.0)
	_modal.add_child(_modal_title)
	_modal_text = _label("", 14, Color(0.78, 0.86, 0.79))
	_modal_text.position = Vector2(27.0, 116.0)
	_modal_text.size = Vector2(520.0, 105.0)
	_modal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal.add_child(_modal_text)
	var close := _button("CLOSE", true)
	close.position = Vector2(350.0, 236.0)
	close.size = Vector2(174.0, 44.0)
	close.pressed.connect(func(): _modal.visible = false)
	_modal.add_child(close)


func _register_interaction(id: String, title: String, description: String, center: Vector3, extent: Vector3) -> void:
	var area := Area3D.new()
	area.name = "Explore_" + id
	area.position = center
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.set_meta("interaction_id", id)
	area.set_meta("title", title)
	area.set_meta("description", description)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = extent
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	_interactables.append(area)


func _add_tree(origin: Vector3, scale_value: float) -> void:
	var trunk := _add_cylinder("TreeTrunk", 0.24 * scale_value, 0.36 * scale_value, 2.10 * scale_value, origin + Vector3(0.0, 1.05 * scale_value, 0.0), _mat(Color(0.31, 0.20, 0.13)))
	trunk.rotation_degrees.z = -3.0
	var crown_material := _mat(Color(0.25, 0.47, 0.31))
	var crown := _add_sphere("TreeCrown", 1.18 * scale_value, origin + Vector3(0.0, 2.75 * scale_value, 0.0), crown_material)
	crown.scale = Vector3(1.10, 1.25, 0.94)
	for index in range(4):
		var angle := TAU * float(index) / 4.0
		var leaf := _add_sphere("TreeCanopy_%d" % index, 0.74 * scale_value, origin + Vector3(cos(angle) * 0.72 * scale_value, (2.45 + 0.28 * float(index % 2)) * scale_value, sin(angle) * 0.62 * scale_value), _mat(Color(0.31 + 0.025 * float(index % 2), 0.52, 0.32)))
		leaf.scale = Vector3(1.0, 1.08, 0.92)


func _add_fern(origin: Vector3, scale_value: float) -> void:
	_add_cylinder("FernBase", 0.18 * scale_value, 0.22 * scale_value, 0.20 * scale_value, origin, _mat(Color(0.35, 0.31, 0.22)))
	for index in range(5):
		var angle := TAU * float(index) / 5.0
		var leaf := _add_sphere("FernLeaf_%d" % index, 0.27 * scale_value, origin + Vector3(cos(angle) * 0.24 * scale_value, 0.36 * scale_value, sin(angle) * 0.24 * scale_value), _mat(Color(0.34, 0.59, 0.35)))
		leaf.scale = Vector3(0.56, 1.25, 0.42)
		leaf.rotation_degrees.z = -18.0 + float(index) * 7.0



func _add_firefly(origin: Vector3) -> void:
	var orb := _add_sphere("Firefly", 0.075, origin, _mat(Color(0.74, 0.98, 0.69), 0.0, 1.8))
	orb.scale = Vector3(0.82, 0.82, 0.82)
	_fireflies.append(orb)
	_firefly_origins.append(origin)
	var light := OmniLight3D.new()
	light.position = origin
	light.light_color = Color(0.60, 0.94, 0.65)
	light.light_energy = 0.48
	light.omni_range = 1.8
	add_child(light)
	_firefly_lights.append(light)


func _add_crystal_cluster(origin: Vector3, tint: Color) -> void:
	var base := _mat(Color(0.30, 0.38, 0.35))
	var crystal_material := _mat(tint, 0.08, 0.72)
	_add_sphere("CrystalClusterBase", 0.55, origin + Vector3(0.0, 0.28, 0.0), base)
	for index in range(3):
		var spike := _add_cylinder("CrystalSpike_%d" % index, 0.0, 0.26 - 0.035 * float(index), 1.0 + 0.24 * float(index), origin + Vector3(-0.32 + float(index) * 0.32, 0.70 + 0.12 * float(index), 0.0), crystal_material)
		spike.rotation_degrees.z = -12.0 + float(index) * 12.0


func _mat(color: Color, metallic: float = 0.0, emission_strength: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.74 if metallic == 0.0 else 0.30
	if emission_strength > 0.0:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = emission_strength
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


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
	mesh.radial_segments = 24
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
	mesh.radial_segments = 16
	mesh.rings = 10
	instance.mesh = mesh
	instance.position = world_position
	instance.material_override = material
	add_child(instance)
	return instance


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _panel(rect: Rect2, background: Color, border: Color, radius: int) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 3.0)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _button(text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82))
	var normal := Color(0.39, 0.28, 0.17, 0.98) if primary else Color(0.10, 0.15, 0.14, 0.96)
	var hover := Color(0.52, 0.38, 0.22, 1.0) if primary else Color(0.17, 0.23, 0.21, 1.0)
	var border := Color(0.91, 0.73, 0.46, 0.92) if primary else Color(0.63, 0.73, 0.67, 0.66)
	button.add_theme_stylebox_override("normal", _button_style(normal, border))
	button.add_theme_stylebox_override("hover", _button_style(hover, border))
	button.add_theme_stylebox_override("pressed", _button_style(normal.darkened(0.15), border))
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
	if event is InputEventScreenTouch and event.pressed:
		_try_interaction(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_interaction(event.position)


func _try_interaction(screen_position: Vector2) -> void:
	var ray_origin := _camera.project_ray_origin(screen_position)
	var ray_direction := _camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 70.0, 2)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider: Object = result.get("collider")
	if not collider is Area3D:
		return
	var area := collider as Area3D
	_active_id = String(area.get_meta("interaction_id"))
	_modal_title.text = String(area.get_meta("title"))
	_modal_text.text = String(area.get_meta("description"))
	_modal.visible = true


func _process(delta: float) -> void:
	_clock += delta
	for index in range(_fireflies.size()):
		var firefly := _fireflies[index]
		var origin := _firefly_origins[index]
		firefly.position = origin + Vector3(0.0, 0.12 * sin(_clock * 1.7 + float(index)), 0.10 * cos(_clock * 1.1 + float(index) * 0.7))
		_firefly_lights[index].light_energy = 0.40 + 0.18 * sin(_clock * 2.2 + float(index))


