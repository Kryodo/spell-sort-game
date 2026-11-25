extends Node3D

const HUB_SCENE := "res://scenes/lab_room_prototype.tscn"
const TABLE_TOP_Y := 0.90
const VIAL_BASE_Y := 0.84
const VIAL_SPACING := 1.12
const CAPACITY := 4
const ESSENCES: Array[String] = ["tide", "moon", "ember"]
const COLORS: Dictionary = {
	"tide": Color(0.27, 0.77, 0.72),
	"moon": Color(0.67, 0.55, 0.91),
	"ember": Color(0.96, 0.48, 0.25)
}
const INITIAL_CONTENTS: Array = [
	["moon", "tide", "ember", "moon"],
	["tide", "ember", "moon", "tide"],
	["ember", "moon", "tide", "ember"],
	[]
]

var _camera: Camera3D
var _vials: Array[Node3D] = []
var _contents: Array = []
var _home_positions: Array[Vector3] = []
var _history: Array[Dictionary] = []
var _drag_index := -1
var _drag_origin := Vector3.ZERO
var _drag_offset := Vector3.ZERO
var _last_pointer := Vector2.ZERO
var _is_animating := false
var _complete := false
var _moves := 0
var _stream: MeshInstance3D
var _stream_material: StandardMaterial3D
var _stream_phase := 0.0
var _status_label: Label
var _moves_label: Label
var _purity_label: Label
var _undo_button: Button
var _reset_button: Button
var _completion_panel: Panel
var _completion_label: Label


func _ready() -> void:
	_build_world()
	_build_workbench()
	_build_vials()
	_build_stream()
	_build_hud()
	_refresh_hud()
	_set_status("Drag a vial onto an empty vessel or one with a matching top essence.")


func _build_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.045, 0.066, 0.071)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.61, 0.68, 0.64)
	environment.ambient_light_energy = 0.82
	world_environment.environment = environment
	add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52.0, -25.0, 0.0)
	key.light_color = Color(1.0, 0.83, 0.63)
	key.light_energy = 1.25
	key.shadow_enabled = true
	add_child(key)

	var cool_fill := OmniLight3D.new()
	cool_fill.position = Vector3(-2.7, 4.2, 2.2)
	cool_fill.light_color = Color(0.42, 0.72, 0.78)
	cool_fill.light_energy = 0.62
	cool_fill.omni_range = 8.0
	add_child(cool_fill)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 9.2
	_camera.position = Vector3(0.0, 8.2, 8.8)
	_camera.near = 0.05
	_camera.far = 60.0
	add_child(_camera)
	_camera.look_at(Vector3(0.0, 1.1, 0.10), Vector3.UP)
	_camera.make_current()


func _build_workbench() -> void:
	var wood := _mat(Color(0.38, 0.25, 0.16))
	var edge := _mat(Color(0.22, 0.15, 0.11))
	var gold := _mat(Color(0.68, 0.49, 0.25), 0.42)
	var inlay := _mat(Color(0.24, 0.31, 0.28))
	_add_box("WorkbenchTop", Vector3(5.15, 0.24, 3.45), Vector3(0.0, 0.76, 0.0), wood)
	_add_box("WorkbenchFrontEdge", Vector3(5.18, 0.12, 0.09), Vector3(0.0, 0.61, 1.70), gold)
	_add_box("WorkbenchInset", Vector3(4.72, 0.025, 2.95), Vector3(0.0, 0.895, 0.0), inlay)
	for x in [-2.18, 2.18]:
		for z in [-1.28, 1.28]:
			_add_box("WorkbenchLeg", Vector3(0.22, 0.76, 0.22), Vector3(x, 0.28, z), edge)
	for x in [-2.40, 2.40]:
		_add_cylinder("CornerStud", 0.075, 0.075, 0.035, Vector3(x, 0.91, 1.42), gold)
	_add_box("TableBackRail", Vector3(4.80, 0.11, 0.10), Vector3(0.0, 0.98, -1.56), gold)

	# Small ambient props frame the experiment without hiding the vials.
	_add_cylinder("CandleBase", 0.16, 0.19, 0.09, Vector3(-2.02, 0.99, -1.02), gold)
	_add_cylinder("CandleWax", 0.10, 0.10, 0.30, Vector3(-2.02, 1.18, -1.02), _mat(Color(0.79, 0.68, 0.48)))
	var flame := _add_sphere("CandleFlame", 0.085, Vector3(-2.02, 1.40, -1.02), _mat(Color(1.0, 0.61, 0.29), 0.0, 1.3))
	flame.scale = Vector3(0.7, 1.3, 0.7)

	_add_box("StudyNote", Vector3(0.72, 0.035, 0.48), Vector3(2.08, 0.94, -1.18), _mat(Color(0.76, 0.67, 0.49)))
	_add_box("StudyNoteMark", Vector3(0.38, 0.018, 0.035), Vector3(2.08, 0.965, -1.14), gold)


func _build_vials() -> void:
	var glass := _mat(Color(0.73, 0.91, 0.88, 0.23), 0.10)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.12
	var neck_glass := _mat(Color(0.81, 0.94, 0.91, 0.34), 0.08)
	neck_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	neck_glass.roughness = 0.10
	var highlight := _mat(Color(0.98, 1.0, 0.94, 0.34), 0.0, 0.08)
	highlight.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for index in range(4):
		var vial := Node3D.new()
		vial.name = "Vial_%d" % index
		var x := (float(index) - 1.5) * VIAL_SPACING
		vial.position = Vector3(x, VIAL_BASE_Y, 0.10)
		add_child(vial)
		_vials.append(vial)
		_home_positions.append(vial.position)
		_contents.append(INITIAL_CONTENTS[index].duplicate())

		_add_cylinder_child(vial, "GlassBody", 0.40, 0.33, 1.10, Vector3(0.0, 0.64, 0.0), glass, 28)
		var shoulder := _add_sphere_child(vial, "Shoulder", 0.34, Vector3(0.0, 1.18, 0.0), glass)
		shoulder.scale = Vector3(1.0, 0.55, 1.0)
		_add_cylinder_child(vial, "Neck", 0.205, 0.205, 0.38, Vector3(0.0, 1.39, 0.0), neck_glass, 24)
		var mouth_ring := MeshInstance3D.new()
		mouth_ring.name = "OpenMouthRim"
		var torus := TorusMesh.new()
		torus.inner_radius = 0.19
		torus.outer_radius = 0.245
		torus.rings = 24
		torus.ring_segments = 8
		mouth_ring.mesh = torus
		mouth_ring.position = Vector3(0.0, 1.60, 0.0)
		mouth_ring.material_override = neck_glass
		vial.add_child(mouth_ring)
		_add_cylinder_child(vial, "FootRing", 0.42, 0.42, 0.09, Vector3(0.0, 0.12, 0.0), neck_glass, 28)
		_add_box_child(vial, "FrontGlassGlint", Vector3(0.045, 0.70, 0.035), Vector3(-0.22, 0.72, 0.365), highlight)
		_add_box_child(vial, "SideGlassGlint", Vector3(0.035, 0.46, 0.035), Vector3(0.27, 0.56, 0.29), highlight)

		var liquid_container := Node3D.new()
		liquid_container.name = "LiquidLayers"
		vial.add_child(liquid_container)

		var hit_area := Area3D.new()
		hit_area.name = "HitArea"
		hit_area.position = Vector3(0.0, 0.79, 0.0)
		hit_area.collision_layer = 4
		hit_area.collision_mask = 0
		hit_area.monitoring = false
		hit_area.monitorable = true
		hit_area.set_meta("vial_index", index)
		var hit_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.92, 1.75, 0.90)
		hit_shape.shape = box
		hit_area.add_child(hit_shape)
		vial.add_child(hit_area)

		_refresh_vial_visual(index)
		_add_label_marker(index)


func _add_label_marker(index: int) -> void:
	var marker := Label3D.new()
	marker.name = "VialMarker"
	marker.text = ["I", "II", "III", "IV"][index]
	marker.font_size = 36
	marker.pixel_size = 0.004
	marker.position = Vector3(0.0, -0.05, 0.48)
	marker.modulate = Color(0.88, 0.78, 0.58)
	_vials[index].add_child(marker)


func _refresh_vial_visual(index: int) -> void:
	var container := _vials[index].get_node("LiquidLayers") as Node3D
	for child in container.get_children():
		child.queue_free()

	var layers: Array = _contents[index]
	for layer_index in range(layers.size()):
		var essence := String(layers[layer_index])
		var liquid_material := _mat(COLORS[essence], 0.0, 0.07)
		var layer := MeshInstance3D.new()
		layer.name = "Layer_%d" % layer_index
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.305
		mesh.bottom_radius = 0.305
		mesh.height = 0.215
		mesh.radial_segments = 28
		layer.mesh = mesh
		layer.position = Vector3(0.0, 0.18 + float(layer_index) * 0.225, 0.0)
		layer.material_override = liquid_material
		container.add_child(layer)

		# A small meniscus disc makes the uppermost essence read clearly through the glass.
		if layer_index == layers.size() - 1:
			var meniscus := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = 0.30
			disc.bottom_radius = 0.30
			disc.height = 0.025
			disc.radial_segments = 28
			meniscus.mesh = disc
			meniscus.position = Vector3(0.0, 0.30 + float(layer_index) * 0.225, 0.0)
			meniscus.material_override = _mat(Color(COLORS[essence].lightened(0.16).r, COLORS[essence].lightened(0.16).g, COLORS[essence].lightened(0.16).b), 0.0, 0.16)
			container.add_child(meniscus)


func _build_stream() -> void:
	_stream = MeshInstance3D.new()
	_stream.name = "EssenceStream"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.038
	mesh.bottom_radius = 0.038
	mesh.height = 1.0
	mesh.radial_segments = 10
	_stream.mesh = mesh
	_stream_material = _mat(COLORS["tide"], 0.0, 0.45)
	_stream.material_override = _stream_material
	_stream.visible = false
	add_child(_stream)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var header := _panel(Rect2(20.0, 22.0, 680.0, 108.0), Color(0.045, 0.066, 0.071, 0.86), Color(0.78, 0.61, 0.38, 0.72), 18)
	root.add_child(header)
	var eyebrow := _label("EXPERIMENT 01  /  PURIFICATION", 10, Color(0.84, 0.68, 0.45))
	eyebrow.position = Vector2(20.0, 12.0)
	eyebrow.size = Vector2(430.0, 20.0)
	header.add_child(eyebrow)
	var title := _label("Separation of Essences", 23, Color(0.98, 0.93, 0.82))
	title.position = Vector2(18.0, 37.0)
	title.size = Vector2(440.0, 39.0)
	header.add_child(title)
	var back := _button("BACK TO LAB", false)
	back.position = Vector2(496.0, 30.0)
	back.size = Vector2(164.0, 48.0)
	back.pressed.connect(func(): get_tree().change_scene_to_file(HUB_SCENE))
	header.add_child(back)

	var footer := _panel(Rect2(20.0, 1060.0, 680.0, 198.0), Color(0.045, 0.066, 0.071, 0.91), Color(0.78, 0.61, 0.38, 0.72), 18)
	root.add_child(footer)
	var instruction := _label("DRAG A VIAL ONTO AN EMPTY OR MATCHING VESSEL", 12, Color(0.96, 0.89, 0.75))
	instruction.position = Vector2(18.0, 12.0)
	instruction.size = Vector2(644.0, 24.0)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(instruction)

	_moves_label = _label("MOVES 00", 12, Color(0.88, 0.82, 0.68))
	_moves_label.position = Vector2(20.0, 53.0)
	_moves_label.size = Vector2(190.0, 25.0)
	footer.add_child(_moves_label)
	_purity_label = _label("PURE ESSENCES 0 / 3", 12, Color(0.84, 0.91, 0.84))
	_purity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_purity_label.position = Vector2(430.0, 53.0)
	_purity_label.size = Vector2(220.0, 25.0)
	footer.add_child(_purity_label)

	_status_label = _label("", 12, Color(0.76, 0.85, 0.81))
	_status_label.position = Vector2(20.0, 86.0)
	_status_label.size = Vector2(640.0, 30.0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(_status_label)

	_undo_button = _button("UNDO", false)
	_undo_button.position = Vector2(350.0, 132.0)
	_undo_button.size = Vector2(140.0, 48.0)
	_undo_button.pressed.connect(_on_undo)
	footer.add_child(_undo_button)

	_reset_button = _button("RESET", true)
	_reset_button.position = Vector2(510.0, 132.0)
	_reset_button.size = Vector2(140.0, 48.0)
	_reset_button.pressed.connect(_on_reset)
	footer.add_child(_reset_button)

	_completion_panel = _panel(Rect2(78.0, 492.0, 564.0, 250.0), Color(0.045, 0.066, 0.071, 0.98), Color(0.91, 0.75, 0.47, 0.96), 22)
	_completion_panel.visible = false
	root.add_child(_completion_panel)
	var complete_kicker := _label("EXPERIMENT COMPLETE", 11, Color(0.91, 0.75, 0.48))
	complete_kicker.position = Vector2(22.0, 23.0)
	complete_kicker.size = Vector2(520.0, 24.0)
	complete_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_completion_panel.add_child(complete_kicker)
	_completion_label = _label("The essences are pure.", 25, Color(0.98, 0.94, 0.83))
	_completion_label.position = Vector2(18.0, 65.0)
	_completion_label.size = Vector2(528.0, 45.0)
	_completion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_completion_panel.add_child(_completion_label)
	var repeat := _button("REPEAT EXPERIMENT", true)
	repeat.position = Vector2(166.0, 164.0)
	repeat.size = Vector2(230.0, 48.0)
	repeat.pressed.connect(_on_reset)
	_completion_panel.add_child(repeat)


func _unhandled_input(event: InputEvent) -> void:
	if _is_animating or _complete:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_finish_drag(event.position)
	elif event is InputEventScreenDrag:
		_update_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_finish_drag(event.position)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_update_drag(event.position)


func _begin_drag(screen_position: Vector2) -> void:
	if _drag_index >= 0:
		return
	var index := _pick_vial(screen_position)
	if index < 0:
		return
	if _contents[index].is_empty():
		_set_status("That vessel is empty. Choose one containing an essence.")
		return
	var table_point := _screen_to_table(screen_position)
	_drag_index = index
	_drag_origin = _vials[index].position
	_drag_offset = _drag_origin - Vector3(table_point.x, VIAL_BASE_Y, table_point.z)
	_last_pointer = screen_position
	_vials[index].scale = Vector3.ONE * 1.06
	_set_status("Vial lifted. Guide it to a valid receiving vessel.")


func _update_drag(screen_position: Vector2) -> void:
	if _drag_index < 0:
		return
	var table_point := _screen_to_table(screen_position)
	var root := _vials[_drag_index]
	root.position.x = clampf(table_point.x + _drag_offset.x, -2.08, 2.08)
	root.position.z = clampf(table_point.z + _drag_offset.z, -1.15, 1.15)
	root.rotation.z = clampf(-float(screen_position.x - _last_pointer.x) * 0.0035, -0.12, 0.12)
	_last_pointer = screen_position


func _finish_drag(screen_position: Vector2) -> void:
	if _drag_index < 0:
		return
	_update_drag(screen_position)
	var source_index := _drag_index
	var target_index := _find_target(source_index)
	if target_index >= 0 and _can_pour(source_index, target_index):
		_perform_pour(source_index, target_index)
	else:
		_return_vial(source_index, "No valid vessel aligned. Try an empty vial or matching top essence.")


func _pick_vial(screen_position: Vector2) -> int:
	var ray_origin := _camera.project_ray_origin(screen_position)
	var ray_direction := _camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 40.0, 4)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return -1
	var collider: Object = result.get("collider")
	if collider is Area3D:
		return int((collider as Area3D).get_meta("vial_index"))
	return -1


func _screen_to_table(screen_position: Vector2) -> Vector3:
	var ray_origin := _camera.project_ray_origin(screen_position)
	var ray_direction := _camera.project_ray_normal(screen_position)
	if absf(ray_direction.y) < 0.0001:
		return Vector3(0.0, TABLE_TOP_Y, 0.0)
	var distance := (TABLE_TOP_Y - ray_origin.y) / ray_direction.y
	if distance < 0.0:
		return Vector3(0.0, TABLE_TOP_Y, 0.0)
	var table_point := ray_origin + ray_direction * distance
	return Vector3(table_point.x, TABLE_TOP_Y, table_point.z)


func _find_target(source_index: int) -> int:
	var source_position := _vials[source_index].position
	for index in range(_vials.size()):
		if index == source_index:
			continue
		var target_position := _vials[index].position
		var horizontal_distance := Vector2(source_position.x - target_position.x, source_position.z - target_position.z).length()
		if horizontal_distance < 0.88:
			return index
	return -1


func _can_pour(source_index: int, target_index: int) -> bool:
	var source: Array = _contents[source_index]
	var target: Array = _contents[target_index]
	if source.is_empty() or target.size() >= CAPACITY:
		return false
	if target.is_empty():
		return true
	return String(target.back()) == String(source.back())


func _get_pour_amount(source_index: int, target_index: int) -> int:
	var source: Array = _contents[source_index]
	var target: Array = _contents[target_index]
	if source.is_empty() or target.size() >= CAPACITY:
		return 0
	var essence := String(source.back())
	var run_length := 0
	for index in range(source.size() - 1, -1, -1):
		if String(source[index]) == essence:
			run_length += 1
		else:
			break
	return mini(run_length, CAPACITY - target.size())


func _copy_contents(layout: Array) -> Array:
	var copy: Array = []
	for vial_contents in layout:
		copy.append(vial_contents.duplicate(true))
	return copy


func _save_history() -> void:
	_history.append({"contents": _copy_contents(_contents), "moves": _moves})


func _return_vial(index: int, message: String) -> void:
	_is_animating = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_vials[index], "position", _drag_origin, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_vials[index], "rotation:z", 0.0, 0.20)
	tween.tween_property(_vials[index], "scale", Vector3.ONE, 0.20)
	await tween.finished
	_drag_index = -1
	_is_animating = false
	_set_status(message)
	_refresh_hud()


func _perform_pour(source_index: int, target_index: int) -> void:
	_is_animating = true
	_refresh_hud()
	_save_history()
	var amount := _get_pour_amount(source_index, target_index)
	if amount <= 0:
		_is_animating = false
		_return_vial(source_index, "That vessel cannot accept the selected essence.")
		return

	var source := _vials[source_index]
	var target := _vials[target_index]
	var essence := String(_contents[source_index].back())
	var direction := signf(target.position.x - source.position.x)
	if is_zero_approx(direction):
		direction = 1.0
	var pour_position := target.position + Vector3(-direction * 1.24, 0.55, 0.12)
	var pour_angle := -direction * 0.98
	_drag_index = -1

	var approach := create_tween().set_parallel(true)
	approach.tween_property(source, "position", pour_position, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	approach.tween_property(source, "rotation:z", pour_angle, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	approach.tween_property(source, "scale", Vector3.ONE, 0.20)
	await approach.finished

	var start := source.to_global(Vector3(0.0, 1.50, 0.0))
	var target_surface := target.to_global(Vector3(0.0, 0.18 + float(_contents[target_index].size()) * 0.225, 0.0))
	_show_stream(start, target_surface, COLORS[essence])
	_set_status("Pouring %s essence..." % essence.capitalize())

	var pour_tween := create_tween()
	pour_tween.tween_interval(0.72)
	await pour_tween.finished
	_stream.visible = false

	for transfer_index in range(amount):
		_contents[source_index].pop_back()
		_contents[target_index].append(essence)
	_refresh_vial_visual(source_index)
	_refresh_vial_visual(target_index)

	var return_tween := create_tween().set_parallel(true)
	return_tween.tween_property(source, "position", _home_positions[source_index], 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_property(source, "rotation:z", 0.0, 0.25)
	await return_tween.finished
	source.scale = Vector3.ONE
	_moves += 1
	_complete = _is_solved()
	_is_animating = false
	_set_status("All essences purified. Experiment complete." if _complete else "Transfer complete. The liquid settles into its new layers.")
	_refresh_hud()


func _show_stream(start: Vector3, finish: Vector3, tint: Color) -> void:
	var direction := (finish - start).normalized()
	var distance := start.distance_to(finish)
	var mesh := _stream.mesh as CylinderMesh
	mesh.height = maxf(0.1, distance)
	_stream.position = (start + finish) * 0.5
	_stream.basis = Basis(Quaternion(Vector3.UP, direction))
	_stream_material.albedo_color = tint.lightened(0.10)
	_stream_material.emission = tint
	_stream_material.emission_energy_multiplier = 0.50
	_stream.visible = true


func _get_pure_essences() -> Array[String]:
	var pure: Array[String] = []
	for vial_contents in _contents:
		if vial_contents.size() != CAPACITY:
			continue
		var essence := String(vial_contents[0])
		var is_uniform := true
		for layer in vial_contents:
			if String(layer) != essence:
				is_uniform = false
				break
		if is_uniform and not pure.has(essence):
			pure.append(essence)
	return pure


func _is_solved() -> bool:
	return _get_pure_essences().size() == ESSENCES.size()


func _refresh_hud() -> void:
	if is_instance_valid(_moves_label):
		_moves_label.text = "MOVES %02d" % _moves
	if is_instance_valid(_purity_label):
		_purity_label.text = "PURE ESSENCES %d / %d" % [_get_pure_essences().size(), ESSENCES.size()]
	if is_instance_valid(_undo_button):
		_undo_button.disabled = _history.is_empty() or _is_animating
	if is_instance_valid(_reset_button):
		_reset_button.disabled = _is_animating
	if is_instance_valid(_completion_panel):
		_completion_panel.visible = _complete


func _on_undo() -> void:
	if _is_animating or _history.is_empty():
		return
	var snapshot: Dictionary = _history.pop_back()
	_contents = _copy_contents(snapshot["contents"])
	_moves = int(snapshot["moves"])
	_complete = _is_solved()
	for index in range(_vials.size()):
		_vials[index].position = _home_positions[index]
		_vials[index].rotation = Vector3.ZERO
		_vials[index].scale = Vector3.ONE
		_refresh_vial_visual(index)
	_set_status("Last transfer reversed.")
	_refresh_hud()


func _on_reset() -> void:
	if _is_animating:
		return
	_contents = _copy_contents(INITIAL_CONTENTS)
	_history.clear()
	_moves = 0
	_complete = false
	_drag_index = -1
	_stream.visible = false
	for index in range(_vials.size()):
		_vials[index].position = _home_positions[index]
		_vials[index].rotation = Vector3.ZERO
		_vials[index].scale = Vector3.ONE
		_refresh_vial_visual(index)
	_set_status("Experiment reset. Begin separating Tide, Moon and Ember.")
	_refresh_hud()


func _set_status(message: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = message


func _process(delta: float) -> void:
	if _stream.visible:
		_stream_phase += delta
		_stream.scale.x = 1.0 + 0.08 * sin(_stream_phase * 14.0)
		_stream.scale.z = _stream.scale.x


func _mat(color: Color, metallic: float = 0.0, emission_strength: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.22 if metallic > 0.0 else 0.68
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


func _add_box_child(parent: Node3D, node_name: String, dimensions: Vector3, local_position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	parent.add_child(instance)
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


func _add_cylinder_child(parent: Node3D, node_name: String, top_radius: float, bottom_radius: float, height: float, local_position: Vector3, material: Material, segments: int = 20) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	parent.add_child(instance)
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


func _add_sphere_child(parent: Node3D, node_name: String, radius: float, local_position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 12
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	parent.add_child(instance)
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
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
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
