extends Control

const ROOM_TEXTURE_PATH := "res://assets/environments/SpellSort_Atelier_Warm.svg"
const CANDLE_FLAME_PATH := "res://assets/environments/SpellSort_Atelier_Candle_Flame.svg"
const CANDLE_GLOW_PATH := "res://assets/environments/SpellSort_Atelier_Candle_Glow.svg"
const FIRST_LESSONS_SCENE := "res://scenes/atelier_first_lessons.tscn"
const PROGRESS_PATH := "user://spell_sort_progress.cfg"

class AtelierMoteLayer extends Control:
	var _time := 0.0
	var _motes: Array[Dictionary] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_motes = [
			{"origin": Vector2(184.0, 682.0), "speed": 5.2, "phase": 0.4, "size": 1.3},
			{"origin": Vector2(256.0, 737.0), "speed": 4.0, "phase": 2.1, "size": 1.0},
			{"origin": Vector2(478.0, 700.0), "speed": 4.7, "phase": 1.2, "size": 1.4},
			{"origin": Vector2(532.0, 787.0), "speed": 3.6, "phase": 3.2, "size": 1.1},
			{"origin": Vector2(142.0, 846.0), "speed": 3.2, "phase": 4.1, "size": 1.0},
			{"origin": Vector2(612.0, 833.0), "speed": 4.4, "phase": 5.0, "size": 1.3},
			{"origin": Vector2(330.0, 705.0), "speed": 2.8, "phase": 2.7, "size": 0.9}
		]
		set_process(true)

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		for mote in _motes:
			var origin: Vector2 = mote["origin"]
			var speed: float = float(mote["speed"])
			var phase: float = float(mote["phase"])
			var radius: float = float(mote["size"])
			var cycle := _time * speed * 0.12 + phase
			var position_value := origin + Vector2(
				sin(cycle * 0.55) * 7.0,
				-fposmod(_time * speed * 2.0 + phase * 13.0, 146.0)
			)
			var pulse := 0.5 + 0.5 * sin(cycle * 1.4)
			var alpha := 0.035 + pulse * 0.026
			draw_circle(
				position_value,
				radius * 2.7,
				Color(0.88, 0.70, 0.43, alpha * 0.24)
			)
			draw_circle(
				position_value,
				radius,
				Color(0.94, 0.82, 0.59, alpha)
			)


var _first_lessons_complete := false
var _atlas_button: Button
var _workbench_button: Button
var _atlas_status: Label
var _subtitle_label: Label
var _candle_flame: TextureRect
var _candle_glow: TextureRect
var _ambience_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_progress()
	_build_room()
	set_process(true)


func _process(delta: float) -> void:
	_ambience_time += delta
	if not is_instance_valid(_candle_flame) or not is_instance_valid(_candle_glow):
		return

	_update_candle_layout()
	# The flame pivots around its bottom-centre wick anchor. Only its upper
	# silhouette flickers; its base never drifts away from the candle.
	_candle_flame.rotation = sin(_ambience_time * 4.7) * 0.026
	_candle_flame.scale = Vector2(
		1.0 + sin(_ambience_time * 7.3) * 0.018,
		1.0 + sin(_ambience_time * 5.9) * 0.035
	)
	_candle_glow.modulate.a = 0.76 + sin(_ambience_time * 1.9) * 0.045 + sin(_ambience_time * 3.2) * 0.018


func _load_progress() -> void:
	var progress := ConfigFile.new()
	if progress.load(PROGRESS_PATH) != OK:
		return

	_first_lessons_complete = bool(
		progress.get_value("progress", "first_lessons_complete", false)
	)


func _build_room() -> void:
	var room := TextureRect.new()
	room.name = "AtelierRoomArtwork"
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room.texture = load(ROOM_TEXTURE_PATH) as Texture2D
	room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room.stretch_mode = TextureRect.STRETCH_SCALE
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(room)

	# A very restrained overall veil keeps the UI and room in the same
	# low-light range without flattening the candle and window accents.
	var veil := ColorRect.new()
	veil.name = "RoomVeil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.012, 0.020, 0.017, 0.035)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	_build_atmosphere()
	_build_header()
	_build_atlas_hotspot()
	_build_workbench_action()
	_update_room_state()



func _build_atmosphere() -> void:
	_candle_glow = TextureRect.new()
	_candle_glow.name = "CandleGlow"
	_candle_glow.texture = load(CANDLE_GLOW_PATH) as Texture2D
	_candle_glow.position = Vector2(442.0, 626.0)
	_candle_glow.size = Vector2(256.0, 256.0)
	_candle_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_candle_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_candle_glow.modulate.a = 0.76
	_candle_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_candle_glow.z_index = 0
	add_child(_candle_glow)

	_candle_flame = TextureRect.new()
	_candle_flame.name = "CandleFlame"
	_candle_flame.texture = load(CANDLE_FLAME_PATH) as Texture2D
	_candle_flame.size = Vector2(28.0, 44.0)
	_candle_flame.pivot_offset = Vector2(14.39, 40.07)
	_candle_flame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_candle_flame.stretch_mode = TextureRect.STRETCH_SCALE
	_candle_flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_candle_flame.z_index = 0
	add_child(_candle_flame)
	_update_candle_layout()

	var motes := AtelierMoteLayer.new()
	motes.name = "AmbientMotes"
	motes.z_index = 0
	add_child(motes)


func _update_candle_layout() -> void:
	# The room artwork is a 720x1280 composition stretched to the Control.
	# Derive the overlay geometry from the same live rect so it stays aligned
	# at every window size/aspect ratio.
	var room_size := get_rect().size
	if room_size.x <= 0.0 or room_size.y <= 0.0:
		return

	var scale_x := room_size.x / 720.0
	var scale_y := room_size.y / 1280.0
	var flame_size := Vector2(28.0 * scale_x, 44.0 * scale_y)
	var wick_anchor := Vector2(516.0 * scale_x, 723.0 * scale_y)
	var flame_base := Vector2(14.39 * scale_x, 40.07 * scale_y)

	_candle_flame.size = flame_size
	_candle_flame.pivot_offset = flame_base
	_candle_flame.position = wick_anchor - flame_base

	var glow_size := Vector2(256.0 * scale_x, 256.0 * scale_y)
	_candle_glow.size = glow_size
	_candle_glow.position = Vector2(516.0 * scale_x, 724.0 * scale_y) - glow_size * 0.5


func _build_header() -> void:
	var title := _make_label(
		"THE ATELIER",
		Rect2(36.0, 38.0, 500.0, 42.0),
		27,
		Color("#e4d7b9")
	)
	add_child(title)

	_subtitle_label = _make_label(
		"",
		Rect2(39.0, 82.0, 630.0, 27.0),
		11,
		Color("#a6aa91")
	)
	add_child(_subtitle_label)


func _build_atlas_hotspot() -> void:
	_atlas_button = Button.new()
	_atlas_button.name = "AtlasHotspot"
	_atlas_button.position = Vector2(190.0, 292.0)
	_atlas_button.size = Vector2(340.0, 360.0)
	_atlas_button.focus_mode = Control.FOCUS_NONE
	_atlas_button.tooltip_text = "The Atlas is dormant. Complete your first lessons."
	_atlas_button.disabled = not _first_lessons_complete
	_atlas_button.add_theme_stylebox_override("normal", _empty_style())
	_atlas_button.add_theme_stylebox_override("hover", _flat_style(
		Color(0.72, 0.60, 0.37, 0.045),
		Color(0.72, 0.60, 0.37, 0.10),
		10,
		1
	))
	_atlas_button.add_theme_stylebox_override("pressed", _flat_style(
		Color(0.72, 0.60, 0.37, 0.075),
		Color(0.72, 0.60, 0.37, 0.16),
		10,
		1
	))
	_atlas_button.add_theme_stylebox_override("disabled", _empty_style())
	_atlas_button.pressed.connect(_open_atlas)
	add_child(_atlas_button)

	var atlas_title := _make_label(
		"THE ATLAS",
		Rect2(230.0, 655.0, 260.0, 24.0),
		13,
		Color("#d4c29a") if _first_lessons_complete else Color("#817f6d")
	)
	atlas_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(atlas_title)

	_atlas_status = _make_label(
		"",
		Rect2(230.0, 680.0, 260.0, 18.0),
		9,
		Color("#c0a36d") if _first_lessons_complete else Color("#777b6d")
	)
	_atlas_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_atlas_status)


func _build_workbench_action() -> void:
	var prompt := _make_label(
		"THE WORKBENCH",
		Rect2(170.0, 1070.0, 380.0, 22.0),
		10,
		Color("#c9b28a")
	)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(prompt)

	_workbench_button = _make_button(
		"APPROACH THE WORKBENCH",
		Rect2(132.0, 1102.0, 456.0, 72.0),
		15,
		true
	)
	_workbench_button.pressed.connect(_open_workbench)
	add_child(_workbench_button)


func _update_room_state() -> void:
	if _first_lessons_complete:
		_subtitle_label.text = (
			"THE FIRST LESSONS ARE COMPLETE. AN OLD PATH HAS APPEARED ON THE ATLAS."
		)
		_atlas_status.text = "PATH REVEALED"
		_atlas_button.tooltip_text = "Open the Atlas"
		_workbench_button.text = "REVISIT THE FIRST LESSONS"
	else:
		_subtitle_label.text = "A QUIET PLACE. A WAITING WORKBENCH. A SEALED ATLAS."
		_atlas_status.text = "DORMANT"
		_atlas_button.tooltip_text = "Complete your first lessons to awaken the Atlas."
		_workbench_button.text = "APPROACH THE WORKBENCH"


func _open_workbench() -> void:
	_change_scene(FIRST_LESSONS_SCENE)


func _open_atlas() -> void:
	if not _first_lessons_complete:
		return

	var overlay := Control.new()
	overlay.name = "AtlasOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 80
	add_child(overlay)

	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.006, 0.012, 0.011, 0.88)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(scrim)

	var panel := Panel.new()
	panel.position = Vector2(44.0, 365.0)
	panel.size = Vector2(632.0, 545.0)
	panel.add_theme_stylebox_override("panel", _flat_style(
		Color("#17211c"),
		Color("#8c7650"),
		20,
		1
	))
	overlay.add_child(panel)

	var kicker := _make_label(
		"THE FIRST PATH",
		Rect2(42.0, 38.0, 548.0, 24.0),
		10,
		Color("#b59a69")
	)
	panel.add_child(kicker)

	var heading := _make_label(
		"THE BOTANICAL GARDEN",
		Rect2(42.0, 76.0, 548.0, 42.0),
		25,
		Color("#e6d9bb")
	)
	panel.add_child(heading)

	var location := _make_label(
		"THE OVERGROWN ENTRANCE",
		Rect2(44.0, 157.0, 540.0, 26.0),
		12,
		Color("#b9c0a6")
	)
	panel.add_child(location)

	var description := _make_label(
		"An old conservatory lies beyond the Atelier. The Atlas has recovered its first marked path, though the rooms beyond remain quiet and unexplored.",
		Rect2(44.0, 204.0, 532.0, 106.0),
		15,
		Color("#c6cbbb")
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	panel.add_child(description)

	var divider := ColorRect.new()
	divider.position = Vector2(44.0, 334.0)
	divider.size = Vector2(532.0, 1.0)
	divider.color = Color("#b39a6a", 0.30)
	panel.add_child(divider)

	var note := _make_label(
		"FIRST DESTINATION",
		Rect2(44.0, 362.0, 532.0, 22.0),
		10,
		Color("#b59a69")
	)
	panel.add_child(note)

	var note_body := _make_label(
		"The Overgrown Entrance is now marked on your Atlas. The conservatory and its forgotten rooms remain unexplored.",
		Rect2(44.0, 391.0, 532.0, 48.0),
		13,
		Color("#aeb8a9")
	)
	note_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(note_body)

	var close_button := _make_button(
		"RETURN TO THE ATELIER",
		Rect2(112.0, 464.0, 408.0, 58.0),
		13,
		true
	)
	close_button.pressed.connect(Callable(overlay, "queue_free"))
	panel.add_child(close_button)


func _change_scene(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("SpellSort could not open scene %s (error %d)." % [scene_path, error])


func _make_label(
	value: String,
	rect: Rect2,
	font_size: int,
	font_color: Color
) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(
	value: String,
	rect: Rect2,
	font_size: int,
	primary: bool
) -> Button:
	var button := Button.new()
	button.text = value
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("#e0d7bd"))
	button.add_theme_color_override("font_hover_color", Color("#f0e5c9"))

	var normal_fill := Color(0.075, 0.105, 0.088, 0.90)
	var normal_border := Color(0.67, 0.54, 0.34, 0.50)
	if not primary:
		normal_fill = Color(0.075, 0.105, 0.088, 0.68)
		normal_border = Color(0.67, 0.54, 0.34, 0.28)

	button.add_theme_stylebox_override("normal", _flat_style(
		normal_fill,
		normal_border,
		16,
		1
	))
	button.add_theme_stylebox_override("hover", _flat_style(
		normal_fill.lightened(0.15),
		normal_border.lightened(0.16),
		16,
		1
	))
	button.add_theme_stylebox_override("pressed", _flat_style(
		normal_fill.lightened(0.23),
		normal_border.lightened(0.24),
		16,
		1
	))
	button.add_theme_stylebox_override("disabled", _flat_style(
		Color(0.05, 0.07, 0.06, 0.70),
		Color(0.36, 0.38, 0.31, 0.12),
		16,
		1
	))
	return button


func _flat_style(
	background: Color,
	border: Color,
	radius: int,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(10.0)
	return style


func _empty_style() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()
