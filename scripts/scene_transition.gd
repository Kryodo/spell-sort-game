extends CanvasLayer

const DEFAULT_DURATION := 0.42
const HANDOFF_SCALE := Vector2(1.018, 1.018)
const HANDOFF_MODULATE := Color(0.955, 0.955, 0.955, 1.0)
const VEIL_COLOR := Color(0.008, 0.014, 0.011, 1.0)
const VEIL_PEAK_ALPHA := 0.075

var _overlay: ColorRect
var _transition_active := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_overlay = ColorRect.new()
	_overlay.name = "SceneTransitionOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(VEIL_COLOR.r, VEIL_COLOR.g, VEIL_COLOR.b, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)


func transition_to(scene_path: String, duration: float = DEFAULT_DURATION) -> void:
	if _transition_active:
		return
	if not ResourceLoader.exists(scene_path):
		push_error("SpellSort transition target does not exist: %s" % scene_path)
		return

	_transition_active = true
	var outgoing_scene := get_tree().current_scene as Control
	if is_instance_valid(outgoing_scene):
		_prepare_scene_root(outgoing_scene)

	_overlay.visible = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_veil_alpha(0.0)

	var safe_duration := maxf(0.20, duration)
	var close_duration := safe_duration * 0.43
	var open_duration := safe_duration * 0.57

	# A barely perceptible push-in on the outgoing scene. The warm veil only
	# darkens enough to soften the actual scene replacement beneath it.
	var close_tween := create_tween().set_parallel(true)
	if is_instance_valid(outgoing_scene):
		close_tween.tween_property(
			outgoing_scene,
			"scale",
			HANDOFF_SCALE,
			close_duration
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		close_tween.tween_property(
			outgoing_scene,
			"modulate",
			HANDOFF_MODULATE,
			close_duration
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	close_tween.tween_method(
		_set_veil_alpha,
		0.0,
		VEIL_PEAK_ALPHA,
		close_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await close_tween.finished

	# Fully cover the one-frame gap while Godot removes the outgoing scene
	# and installs the incoming one. Without this, the viewport clear color can
	# show through the translucent veil as a brief white flash.
	_set_veil_alpha(1.0)
	var change_error: Error = get_tree().change_scene_to_file(scene_path)
	if change_error != OK:
		push_error(
			"SpellSort could not open scene %s (error %d)." % [scene_path, change_error]
		)
		await _restore_outgoing_scene(outgoing_scene, open_duration)
		return

	await get_tree().process_frame
	# The incoming scene is now installed; restore the subtle veil level before
	# the visible settle animation continues.
	_set_veil_alpha(VEIL_PEAK_ALPHA)
	var incoming_scene := get_tree().current_scene as Control
	if is_instance_valid(incoming_scene):
		_prepare_scene_root(incoming_scene)
		incoming_scene.scale = HANDOFF_SCALE
		incoming_scene.modulate = HANDOFF_MODULATE

	# The incoming scene settles back to its natural size as the veil lifts.
	var open_tween := create_tween().set_parallel(true)
	if is_instance_valid(incoming_scene):
		open_tween.tween_property(
			incoming_scene,
			"scale",
			Vector2.ONE,
			open_duration
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		open_tween.tween_property(
			incoming_scene,
			"modulate",
			Color.WHITE,
			open_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	open_tween.tween_method(
		_set_veil_alpha,
		VEIL_PEAK_ALPHA,
		0.0,
		open_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await open_tween.finished

	_finish_transition()


func _prepare_scene_root(scene_root: Control) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		scene_root.pivot_offset = scene_root.size * 0.5
	scene_root.scale = Vector2.ONE


func _set_veil_alpha(alpha: float) -> void:
	if not is_instance_valid(_overlay):
		return
	_overlay.color = Color(VEIL_COLOR.r, VEIL_COLOR.g, VEIL_COLOR.b, clampf(alpha, 0.0, 1.0))


func _restore_outgoing_scene(scene_root: Control, duration: float) -> void:
	var recovery_tween := create_tween().set_parallel(true)
	if is_instance_valid(scene_root):
		recovery_tween.tween_property(scene_root, "scale", Vector2.ONE, duration)
		recovery_tween.tween_property(scene_root, "modulate", Color.WHITE, duration)
	recovery_tween.tween_method(_set_veil_alpha, 1.0, 0.0, duration)
	await recovery_tween.finished
	_finish_transition()


func _finish_transition() -> void:
	_set_veil_alpha(0.0)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_active = false
