extends CanvasLayer

const TRANSITION_SHADER := preload("res://shaders/scene_transition.gdshader")
const OPEN_RADIUS := 1.04
const CLOSED_RADIUS := 0.0
const DEFAULT_DURATION := 0.92

var _overlay: ColorRect
var _material: ShaderMaterial
var _transition_active := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_material = ShaderMaterial.new()
	_material.shader = TRANSITION_SHADER

	_overlay = ColorRect.new()
	_overlay.name = "SceneTransitionOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color.WHITE
	_overlay.material = _material
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

	_set_aperture_radius(OPEN_RADIUS)


func transition_to(
	scene_path: String,
	source_focus: Vector2 = Vector2(0.5, 0.5),
	destination_focus: Vector2 = Vector2(0.5, 0.5),
	duration: float = DEFAULT_DURATION
) -> void:
	if _transition_active:
		return
	if not ResourceLoader.exists(scene_path):
		push_error("SpellSort transition target does not exist: %s" % scene_path)
		return

	_transition_active = true
	_overlay.visible = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_focus(source_focus)
	_set_aperture_radius(OPEN_RADIUS)

	var close_tween := create_tween()
	close_tween.tween_method(
		_set_aperture_radius,
		OPEN_RADIUS,
		CLOSED_RADIUS,
		maxf(0.12, duration * 0.46)
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await close_tween.finished

	# The screen is fully covered here. Move the aperture to the destination
	# before replacing the scene, so the reveal feels like one continuous handoff.
	_set_focus(destination_focus)
	var change_error: Error = get_tree().change_scene_to_file(scene_path)
	if change_error != OK:
		push_error(
			"SpellSort could not open scene %s (error %d)." % [scene_path, change_error]
		)
	else:
		await get_tree().process_frame

	var open_tween := create_tween()
	open_tween.tween_method(
		_set_aperture_radius,
		CLOSED_RADIUS,
		OPEN_RADIUS,
		maxf(0.12, duration * 0.54)
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await open_tween.finished

	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_active = false


func _set_focus(focus: Vector2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var normalized_focus := Vector2(
		clampf(focus.x, 0.0, 1.0),
		clampf(focus.y, 0.0, 1.0)
	)
	var focus_pixels := normalized_focus * viewport_size
	var corners: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(viewport_size.x, 0.0),
		viewport_size,
		Vector2(0.0, viewport_size.y)
	]
	var farthest_corner := 0.0
	for corner in corners:
		farthest_corner = maxf(farthest_corner, focus_pixels.distance_to(corner))

	_material.set_shader_parameter("aperture_center", normalized_focus)
	_material.set_shader_parameter("screen_aspect", viewport_size.x / viewport_size.y)
	_material.set_shader_parameter(
		"corner_radius",
		maxf(0.001, farthest_corner / viewport_size.y)
	)


func _set_aperture_radius(radius: float) -> void:
	_material.set_shader_parameter("aperture_radius", radius)
