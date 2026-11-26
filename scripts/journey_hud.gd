extends Control

signal experiment_requested

var _active_page: Control
var _codex_category: String = "INGREDIENTS"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_top_hud()
	_build_hotspots()
	_build_bottom_navigation()


func _build_top_hud() -> void:
	var header := _make_panel(Rect2(18.0, 18.0, 684.0, 94.0), Color(0.018, 0.034, 0.032, 0.80), Color(0.76, 0.61, 0.39, 0.52), 18)
	add_child(header)
	var logo := _make_label("SPELL SORT", Vector2(16.0, 8.0), Vector2(265.0, 34.0), 25, Color("#f3dfbd"))
	header.add_child(logo)
	var chapter := _make_label("CHAPTER 01  /  THE OVERGROWN GREENHOUSE", Vector2(18.0, 43.0), Vector2(460.0, 22.0), 11, Color("#b8c9b7"))
	header.add_child(chapter)
	var journal := _make_button("FIELD JOURNAL", Rect2(507.0, 21.0, 155.0, 42.0), true)
	journal.pressed.connect(func() -> void: _open_page("discoveries"))
	header.add_child(journal)


func _build_hotspots() -> void:
	var garden := _make_button("BOTANICAL GARDEN", Rect2(24.0, 510.0, 190.0, 52.0), false)
	garden.pressed.connect(func() -> void:
		_codex_category = "INGREDIENTS"
		_open_page("codex")
	)
	add_child(garden)

	var archive := _make_button("RESEARCH ARCHIVE", Rect2(506.0, 510.0, 190.0, 52.0), false)
	archive.pressed.connect(func() -> void:
		_codex_category = "SPELLS"
		_open_page("codex")
	)
	add_child(archive)

	var study := _make_button("ENTER EXPERIMENT", Rect2(214.0, 855.0, 292.0, 58.0), true)
	study.add_theme_font_size_override("font_size", 16)
	study.pressed.connect(func() -> void: _open_page("experiments"))
	add_child(study)

	var workbench_hint := _make_label("THE BOTANICAL STUDY TABLE", Vector2(196.0, 920.0), Vector2(328.0, 22.0), 11, Color("#f0d6a8"))
	workbench_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(workbench_hint)


func _build_bottom_navigation() -> void:
	var dock := _make_panel(Rect2(18.0, 1124.0, 684.0, 138.0), Color(0.018, 0.032, 0.031, 0.92), Color(0.76, 0.61, 0.39, 0.64), 20)
	add_child(dock)
	var nav_items: Array[Dictionary] = [
		{"key": "experiments", "title": "EXPERIMENTS", "subtitle": "Chapters & puzzles"},
		{"key": "codex", "title": "CODEX", "subtitle": "Potions & knowledge"},
		{"key": "discoveries", "title": "DISCOVERIES", "subtitle": "Collections & records"},
		{"key": "laboratory", "title": "LABORATORY", "subtitle": "Restore & expand"}
	]
	for index in range(nav_items.size()):
		var item: Dictionary = nav_items[index]
		var button := _make_button(String(item["title"]), Rect2(12.0 + float(index) * 168.0, 14.0, 158.0, 48.0), false)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_open_page.bind(String(item["key"])))
		dock.add_child(button)
		var subtitle := _make_label(String(item["subtitle"]), Vector2(14.0 + float(index) * 168.0, 67.0), Vector2(154.0, 26.0), 10, Color("#aebdb0"))
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dock.add_child(subtitle)


func _open_page(page_key: String) -> void:
	if is_instance_valid(_active_page):
		_active_page.queue_free()
	_active_page = Control.new()
	_active_page.name = "JourneyPage_" + page_key
	_active_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_active_page.z_index = 100
	add_child(_active_page)

	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.008, 0.018, 0.017, 0.82)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_active_page.add_child(scrim)

	var panel := _make_panel(Rect2(28.0, 138.0, 664.0, 1004.0), Color("#182824"), Color("#b38a56"), 22)
	_active_page.add_child(panel)

	var heading_text: String = _page_heading(page_key)
	var heading := _make_label(heading_text, Vector2(54.0, 160.0), Vector2(500.0, 42.0), 26, Color("#f0dfc0"))
	_active_page.add_child(heading)
	var close := _make_button("RETURN", Rect2(570.0, 163.0, 96.0, 40.0), false)
	close.pressed.connect(_close_page)
	_active_page.add_child(close)

	var kicker := _make_label("THE OVERGROWN GREENHOUSE  /  CHAPTER 01", Vector2(56.0, 207.0), Vector2(600.0, 23.0), 11, Color("#a9c0a8"))
	_active_page.add_child(kicker)

	var content_root := VBoxContainer.new()
	content_root.position = Vector2(54.0, 254.0)
	content_root.size = Vector2(612.0, 820.0)
	content_root.add_theme_constant_override("separation", 12)
	_active_page.add_child(content_root)

	match page_key:
		"experiments":
			_build_experiments_page(content_root)
		"codex":
			_build_codex_page(content_root)
		"discoveries":
			_build_discoveries_page(content_root)
		"laboratory":
			_build_laboratory_page(content_root)
		_:
			_add_info_card(content_root, "Unknown page", "This journal page has not been authored yet.", "IN PROGRESS", 140)


func _page_heading(page_key: String) -> String:
	match page_key:
		"experiments":
			return "Experiments"
		"codex":
			return "Alchemist's Codex"
		"discoveries":
			return "Discoveries & Mastery"
		"laboratory":
			return "Restore the Laboratory"
	return "Field Journal"


func _build_experiments_page(parent: VBoxContainer) -> void:
	_add_info_card(parent, "Experiment 01 — First Contact", "Learn to lift, transfer and settle magical essences. Your first controlled separation.", "COMPLETED", 112)
	_add_info_card(parent, "Experiment 02 — The Three Essences", "Identify Tide, Moon and Ember, then separate their mixed layers.", "COMPLETED", 112)
	var current := _make_action_card(
		"Experiment 03 — A Pure Formula",
		"Separate four essences across five vessels. The wider workspace creates more possible transfers, so plan each temporary grouping carefully.",
		"AVAILABLE  ·  CONTINUE",
		"BEGIN EXPERIMENT"
	)
	current.pressed.connect(_launch_experiment)
	parent.add_child(current)
	_add_info_card(parent, "Experiment 04 — The First Recipe", "Discover how layer order and ingredient quantities change a potion formula.", "LOCKED", 112)
	_add_info_card(parent, "Experiment 05 — The Lost Alchemist", "A more challenging final experiment awaits beyond the first research notes.", "LOCKED", 112)


func _build_codex_page(parent: VBoxContainer) -> void:
	var category_row := HBoxContainer.new()
	category_row.add_theme_constant_override("separation", 8)
	parent.add_child(category_row)
	for category in ["INGREDIENTS", "POTIONS", "SPELLS", "ARTIFACTS"]:
		var category_button := _make_button(category, Rect2(Vector2.ZERO, Vector2(138.0, 42.0)), category == _codex_category)
		category_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category_button.pressed.connect(_set_codex_category.bind(category))
		category_row.add_child(category_button)

	match _codex_category:
		"INGREDIENTS":
			_add_info_card(parent, "Moonleaf", "A cool, silvery herb found in shaded greenhouse beds. Its essence steadies unstable mixtures.", "DISCOVERED", 128)
			_add_info_card(parent, "Tide Crystal", "A translucent mineral that holds a slow-moving blue-green essence.", "DISCOVERED", 128)
			_add_info_card(parent, "Ember Bloom", "A warm flower whose concentrated sap reacts strongly with Tide essence.", "UNKNOWN VARIATION", 128)
			_add_info_card(parent, "Uncatalogued specimen", "More ingredients can be recorded as new chapter environments are explored.", "UNDISCOVERED", 128)
		"POTIONS":
			_add_info_card(parent, "Lesser Healing Draught", "A simple restorative mixture. Its complete formula has not yet been recovered.", "RECIPE FRAGMENT", 128)
			_add_info_card(parent, "Moonlit Tonic", "A quieting potion associated with moonleaf and cool mineral essences.", "RUMOURED", 128)
			_add_info_card(parent, "Unknown mixture", "Discover new formulations by completing recipe experiments.", "UNDISCOVERED", 128)
		"SPELLS":
			_add_info_card(parent, "Essence Attunement", "A basic incantation used to recognize the character of an unfamiliar essence.", "DISCOVERED", 128)
			_add_info_card(parent, "Transmutation", "A lost technique capable of changing one paired substance into another.", "FRAGMENT FOUND", 128)
			_add_info_card(parent, "Unknown incantation", "Record new spell sequences as the research archive is restored.", "UNDISCOVERED", 128)
		"ARTIFACTS":
			_add_info_card(parent, "Brass Retort Seal", "An old laboratory mark. Its original purpose is still unclear.", "RECOVERED", 128)
			_add_info_card(parent, "Weathered Field Lens", "A small instrument once used to inspect rare botanical specimens.", "DAMAGED", 128)
			_add_info_card(parent, "Forgotten instrument", "Explore other research stations to uncover more artifacts.", "UNDISCOVERED", 128)


func _build_discoveries_page(parent: VBoxContainer) -> void:
	_add_info_card(parent, "Greenhouse collection", "Ingredients recorded: 2 / 12. Potion formulas: 0 / 5. Artifacts: 1 / 8.", "COLLECTION  ·  17%", 136)
	_add_info_card(parent, "Mastery challenges", "Replay completed experiments with fewer pours, fewer available vials or an additional restriction. No timer is required.", "UNLOCKS WITH MASTERY", 148)
	_add_info_card(parent, "Daily experiment", "A focused daily puzzle with its own record and a small discovery reward. The daily seed changes independently of the chapter.", "NEXT EXPERIMENT READY", 148)
	_add_info_card(parent, "Hidden variations", "Some recipes have alternate ingredient orders or unexpected reactions. The Codex records variations after they are discovered.", "2 CLUES RECORDED", 148)


func _build_laboratory_page(parent: VBoxContainer) -> void:
	_add_info_card(parent, "The forgotten laboratory", "A neglected research space is slowly becoming usable again. Restoration is based on discoveries, not factory timers or production chains.", "RESTORATION  ·  2 / 8", 144)
	_add_info_card(parent, "Modular experiment apparatus", "The central apparatus can be expanded with additional receivers, structural tiers and specialised tools as later experiments require them.", "FRAME RECOVERED", 144)
	_add_info_card(parent, "Botanical workbench", "Recover the planting trays and specimen drawers to support ingredient research.", "NEEDS 3 DISCOVERIES", 144)
	_add_info_card(parent, "Archive and spell desk", "Restore the archive to reveal lost formulas, annotations and advanced incantations.", "LOCKED", 144)


func _make_action_card(title_text: String, description_text: String, badge_text: String, action_text: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, 174.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_stylebox_override("normal", _panel_style(Color("#243b31"), Color("#c89a5a"), 16))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#2d493a"), Color("#f0c477"), 16))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#1e332c"), Color("#f0c477"), 16))
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 5)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(stack)
	var badge := _make_label(badge_text, Vector2.ZERO, Vector2(520.0, 20.0), 11, Color("#e3bd79"))
	stack.add_child(badge)
	var title := _make_label(title_text, Vector2.ZERO, Vector2(550.0, 32.0), 19, Color("#f4e2c2"))
	stack.add_child(title)
	var description := _make_label(description_text, Vector2.ZERO, Vector2(550.0, 45.0), 13, Color("#c3d1c2"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(description)
	var action := _make_label(action_text, Vector2.ZERO, Vector2(550.0, 22.0), 12, Color("#f0d3a0"))
	stack.add_child(action)
	return button


func _add_info_card(parent: VBoxContainer, title_text: String, description_text: String, badge_text: String, height: float) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, height)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(Color("#20342d"), Color("#6f8b70"), 14))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	card.add_child(stack)
	var badge := _make_label(badge_text, Vector2.ZERO, Vector2(560.0, 18.0), 10, Color("#d4b375"))
	stack.add_child(badge)
	var title := _make_label(title_text, Vector2.ZERO, Vector2(560.0, 29.0), 17, Color("#f1e2c5"))
	stack.add_child(title)
	var description := _make_label(description_text, Vector2.ZERO, Vector2(560.0, 50.0), 12, Color("#bdcbbf"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(description)
	parent.add_child(card)


func _set_codex_category(category: String) -> void:
	_codex_category = category
	_open_page("codex")


func _close_page() -> void:
	if is_instance_valid(_active_page):
		_active_page.queue_free()
	_active_page = null


func _launch_experiment() -> void:
	experiment_requested.emit()


func _make_label(text_value: String, position_value: Vector2, size_value: Vector2, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = position_value
	label.size = size_value
	label.custom_minimum_size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_panel(rect: Rect2, background: Color, border: Color, radius: int) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style(background, border, radius))
	return panel


func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16.0
	style.content_margin_top = 12.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 12.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0.0, 3.0)
	return style


func _make_button(button_text: String, rect: Rect2, primary: bool) -> Button:
	var button := Button.new()
	button.text = button_text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("#f3e3c7"))
	button.add_theme_color_override("font_hover_color", Color("#fff4df"))
	var normal_color := Color("#60462a") if primary else Color("#20362f")
	var border_color := Color("#d9ad68") if primary else Color("#829b82")
	button.add_theme_stylebox_override("normal", _panel_style(normal_color, border_color, 12))
	button.add_theme_stylebox_override("hover", _panel_style(normal_color.lightened(0.15), border_color.lightened(0.25), 12))
	button.add_theme_stylebox_override("pressed", _panel_style(normal_color.darkened(0.12), border_color, 12))
	return button
