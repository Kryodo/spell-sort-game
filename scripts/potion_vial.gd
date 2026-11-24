extends Control

signal tapped(vial_index: int)

const CAPACITY := 4

var vial_index: int = 0
var _visual_contents: Array = []
var _palette: Dictionary = {}
var _selected: bool = false
var _receiving: bool = false
var _pulse_time: float = 0.0
var _liquid_level: float = 0.0
var _bottle_texture: Texture2D
var _animation_lift: float = 0.0
var _animation_tilt: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(122.0, 340.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func configure(
	index: int,
	contents: Array,
	palette: Dictionary,
	selected: bool,
	bottle_texture: Texture2D = null
) -> void:
	vial_index = index
	_visual_contents = contents.duplicate()
	_liquid_level = float(contents.size())
	_palette = palette
	_selected = selected
	_receiving = false
	_bottle_texture = bottle_texture
	set_process(_selected or _receiving)
	queue_redraw()


func set_visual_contents(contents: Array, liquid_level: float) -> void:
	_visual_contents = contents.duplicate()
	_liquid_level = clampf(liquid_level, 0.0, float(CAPACITY))
	queue_redraw()


func set_visual_state(selected: bool, receiving: bool) -> void:
	_selected = selected
	_receiving = receiving
	set_process(_selected or _receiving)
	queue_redraw()


func set_animation_pose(pose: Vector2) -> void:
	_animation_lift = pose.x
	_animation_tilt = pose.y
	queue_redraw()


func get_global_spout_position() -> Vector2:
	var center_x: float = size.x * 0.5
	var local_spout := Vector2(center_x, 58.0)
	if _bottle_texture != null:
		var art_rect := _get_art_rect(center_x)
		local_spout = Vector2(center_x, art_rect.position.y + art_rect.size.y * 0.12)
	var pivot := Vector2(center_x, 276.0)
	var transformed := pivot + Vector2(0.0, -_animation_lift) + (local_spout - pivot).rotated(_animation_tilt)
	return get_global_transform() * transformed


func _process(delta: float) -> void:
	_pulse_time += delta * 3.0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			tapped.emit(vial_index)
			accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			tapped.emit(vial_index)
			accept_event()


func _draw() -> void:
	var center_x: float = size.x * 0.5

	# Keep the contact shadow on the work surface while the bottle lifts.
	draw_circle(Vector2(center_x, 286.0), 35.0, Color(0.015, 0.025, 0.035, 0.30))

	var pivot := Vector2(center_x, 276.0)
	var draw_origin := pivot + Vector2(0.0, -_animation_lift) - pivot.rotated(_animation_tilt)
	draw_set_transform(draw_origin, _animation_tilt, Vector2.ONE)

	if _selected or _receiving:
		var pulse: float = 0.5 + 0.5 * sin(_pulse_time)
		var glow_alpha: float = 0.055 + pulse * 0.055 if _selected else 0.035 + pulse * 0.045
		draw_circle(Vector2(center_x, 177.0), 66.0, Color(0.91, 0.70, 0.39, glow_alpha))
		draw_arc(Vector2(center_x, 177.0), 63.0, 0.0, TAU, 48, Color(0.95, 0.76, 0.46, 0.36 + pulse * 0.40), 2.5, true)

	if _bottle_texture != null:
		_draw_bottle_and_liquid(center_x)
	else:
		_draw_procedural_fallback(center_x)

	if _visual_contents.is_empty():
		draw_string(
			ThemeDB.fallback_font,
			Vector2(center_x - 29.0, 202.0),
			"EMPTY",
			HORIZONTAL_ALIGNMENT_CENTER,
			58.0,
			11,
			Color(0.90, 0.94, 0.94, 0.88)
		)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var vial_labels: Array[String] = ["I", "II", "III", "IV"]
	draw_string(
		ThemeDB.fallback_font,
		Vector2(center_x - 24.0, 325.0),
		vial_labels[vial_index],
		HORIZONTAL_ALIGNMENT_CENTER,
		48.0,
		15,
		Color(0.91, 0.84, 0.69, 0.92)
	)


func _get_art_rect(center_x: float) -> Rect2:
	var texture_size := Vector2(_bottle_texture.get_size())
	var available := Vector2(112.0, 286.0)
	var fit_scale: float = minf(available.x / texture_size.x, available.y / texture_size.y)
	var rendered_size := texture_size * fit_scale
	return Rect2(
		Vector2(center_x - rendered_size.x * 0.5, 18.0 + (available.y - rendered_size.y) * 0.5),
		rendered_size
	)


func _draw_bottle_and_liquid(center_x: float) -> void:
	var art_rect := _get_art_rect(center_x)
	# The source sheet has opaque pixels inside the glass. Soft art passes and
	# a live liquid layer keep the bottle recognisable while tinting its contents.
	draw_texture_rect(_bottle_texture, art_rect, false, Color(1.0, 1.0, 1.0, 0.50))
	_draw_liquid_layers(art_rect, center_x)
	draw_texture_rect(_bottle_texture, art_rect, false, Color(1.0, 1.0, 1.0, 0.38))


func _draw_liquid_layers(art_rect: Rect2, center_x: float) -> void:
	var liquid_left: float = center_x - art_rect.size.x * 0.245
	var liquid_right: float = center_x + art_rect.size.x * 0.245
	var liquid_bottom: float = art_rect.position.y + art_rect.size.y * 0.84
	var layer_height: float = art_rect.size.y * 0.080
	var layer_gap: float = art_rect.size.y * 0.008
	var visible_layers: int = mini(int(ceil(_liquid_level)), _visual_contents.size())

	for layer_index in range(visible_layers):
		var filled_fraction: float = clampf(_liquid_level - float(layer_index), 0.0, 1.0)
		if filled_fraction <= 0.0:
			continue
		var essence_name: String = String(_visual_contents[layer_index])
		var liquid_color: Color = _palette.get(essence_name, Color.WHITE)
		var bottom_y: float = liquid_bottom - float(layer_index) * (layer_height + layer_gap)
		var top_y: float = bottom_y - layer_height * filled_fraction
		var edge_inset: float = art_rect.size.x * 0.025
		var liquid_shape := PackedVector2Array([
			Vector2(liquid_left + edge_inset, top_y),
			Vector2(liquid_right - edge_inset, top_y),
			Vector2(liquid_right, bottom_y),
			Vector2(liquid_left, bottom_y)
		])
		draw_colored_polygon(liquid_shape, Color(liquid_color.r, liquid_color.g, liquid_color.b, 0.91))
		draw_line(
			Vector2(liquid_left + edge_inset + 2.0, top_y + 1.5),
			Vector2(liquid_right - edge_inset - 2.0, top_y + 1.5),
			Color(1.0, 1.0, 1.0, 0.34),
			1.8,
			true
		)


func _draw_procedural_fallback(center_x: float) -> void:
	var body := PackedVector2Array([
		Vector2(center_x - 19.0, 59.0), Vector2(center_x + 19.0, 59.0),
		Vector2(center_x + 19.0, 99.0), Vector2(center_x + 28.0, 112.0),
		Vector2(center_x + 34.0, 130.0), Vector2(center_x + 34.0, 255.0),
		Vector2(center_x + 30.0, 269.0), Vector2(center_x + 20.0, 279.0),
		Vector2(center_x - 20.0, 279.0), Vector2(center_x - 30.0, 269.0),
		Vector2(center_x - 34.0, 255.0), Vector2(center_x - 34.0, 130.0),
		Vector2(center_x - 28.0, 112.0), Vector2(center_x - 19.0, 99.0)
	])
	draw_colored_polygon(body, Color(0.70, 0.84, 0.91, 0.13))
	var liquid_bottom: float = 263.0
	var layer_height: float = 34.0
	var visible_layers: int = mini(int(ceil(_liquid_level)), _visual_contents.size())
	for layer_index in range(visible_layers):
		var fraction: float = clampf(_liquid_level - float(layer_index), 0.0, 1.0)
		var essence_name: String = String(_visual_contents[layer_index])
		var liquid_color: Color = _palette.get(essence_name, Color.WHITE)
		var y_position: float = liquid_bottom - float(layer_index + 1) * layer_height
		draw_rect(Rect2(center_x - 27.0, y_position, 54.0, layer_height * fraction), liquid_color, true)
	var closed_body := body.duplicate()
	closed_body.append(body[0])
	draw_polyline(closed_body, Color(0.83, 0.93, 0.97, 0.84), 2.2, true)
	draw_arc(Vector2(center_x, 59.0), 19.0, 0.0, TAU, 36, Color(0.91, 0.96, 0.98, 0.86), 2.2, true)
	draw_line(Vector2(center_x - 25.0, 139.0), Vector2(center_x - 25.0, 245.0), Color(0.98, 1.0, 1.0, 0.38), 2.0, true)
