extends Control

signal tapped(vial_index: int)

const CAPACITY := 4

var vial_index: int = 0
var _contents: Array = []
var _palette: Dictionary = {}
var _selected: bool = false
var _pulse_time: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(122.0, 340.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func configure(index: int, contents: Array, palette: Dictionary, selected: bool) -> void:
	vial_index = index
	_contents = contents.duplicate()
	_palette = palette
	_selected = selected
	set_process(_selected)
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += delta * 2.2
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

	# Soft contact shadow and selection glow.
	draw_circle(Vector2(center_x, 286.0), 34.0, Color(0.015, 0.025, 0.035, 0.28))
	if _selected:
		var pulse: float = 0.5 + 0.5 * sin(_pulse_time)
		draw_circle(Vector2(center_x, 176.0), 63.0, Color(0.91, 0.70, 0.39, 0.045 + pulse * 0.045))
		draw_arc(
			Vector2(center_x, 176.0),
			62.0,
			0.0,
			TAU,
			48,
			Color(0.95, 0.76, 0.46, 0.48 + pulse * 0.36),
			2.5,
			true
		)

	# The temporary vial silhouette is drawn in Godot so the liquid can be
	# changed independently while the final bottle atlas is being prepared.
	var body := PackedVector2Array([
		Vector2(center_x - 19.0, 59.0),
		Vector2(center_x + 19.0, 59.0),
		Vector2(center_x + 19.0, 99.0),
		Vector2(center_x + 28.0, 112.0),
		Vector2(center_x + 34.0, 130.0),
		Vector2(center_x + 34.0, 255.0),
		Vector2(center_x + 30.0, 269.0),
		Vector2(center_x + 20.0, 279.0),
		Vector2(center_x - 20.0, 279.0),
		Vector2(center_x - 30.0, 269.0),
		Vector2(center_x - 34.0, 255.0),
		Vector2(center_x - 34.0, 130.0),
		Vector2(center_x - 28.0, 112.0),
		Vector2(center_x - 19.0, 99.0)
	])
	draw_colored_polygon(body, Color(0.70, 0.84, 0.91, 0.13))

	# Contents are stored bottom-to-top. Each pour transfers the complete
	# contiguous run of the uppermost essence that fits in the destination.
	var liquid_bottom: float = 263.0
	var layer_height: float = 34.0
	var layer_gap: float = 3.0
	for layer_index in range(_contents.size()):
		var essence_name: String = String(_contents[layer_index])
		var liquid_color: Color = _palette.get(essence_name, Color.WHITE)
		var y_position: float = liquid_bottom - (layer_index + 1) * layer_height - layer_index * layer_gap
		var liquid_rect := Rect2(center_x - 27.0, y_position, 54.0, layer_height)
		draw_rect(liquid_rect, liquid_color, true)
		draw_rect(
			Rect2(center_x - 27.0, y_position, 54.0, 5.0),
			Color(1.0, 1.0, 1.0, 0.16),
			true
		)
		draw_circle(
			Vector2(center_x + 14.0, y_position + 12.0),
			2.2,
			Color(1.0, 1.0, 1.0, 0.38)
		)

	# Fine glass outline and reflections sit above the liquid.
	var closed_body := body.duplicate()
	closed_body.append(body[0])
	draw_polyline(closed_body, Color(0.83, 0.93, 0.97, 0.84), 2.2, true)
	draw_arc(
		Vector2(center_x, 59.0),
		19.0,
		0.0,
		TAU,
		36,
		Color(0.91, 0.96, 0.98, 0.86),
		2.2,
		true
	)
	draw_line(
		Vector2(center_x - 25.0, 139.0),
		Vector2(center_x - 25.0, 245.0),
		Color(0.98, 1.0, 1.0, 0.38),
		2.0,
		true
	)
	draw_line(
		Vector2(center_x + 28.0, 148.0),
		Vector2(center_x + 28.0, 238.0),
		Color(0.48, 0.67, 0.76, 0.24),
		1.5,
		true
	)

	if _contents.is_empty():
		draw_string(
			ThemeDB.fallback_font,
			Vector2(center_x - 29.0, 197.0),
			"EMPTY",
			HORIZONTAL_ALIGNMENT_CENTER,
			58.0,
			11,
			Color(0.79, 0.86, 0.88, 0.74)
		)

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
