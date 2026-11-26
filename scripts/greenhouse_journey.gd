extends Control

# First vertical slice of the chapter-led Spell Sort journey.
# The environment is an independent scene layer; all navigation and experiment
# content is built above it and does not assume a fixed vial count.

const EXPERIMENT_SCENE := "res://scenes/sorting_direction_prototype.tscn"

var _active_page: Control
var _hotspot_hint: Label
var _world_title: Label
var _nav_buttons: Array[Button] = []
var _codex_category := "INGREDIENTS"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_world()
	_build_top_hud()
	_build_hotspots()
	_build_bottom_navigation()


func _draw() -> void:
	_draw_greenhouse_environment()


func _draw_greenhouse_environment() -> void:
	# A compact, hand-crafted greenhouse study: architecture and props establish
	# the place, while the centre of the work surface remains free for gameplay.
	draw_rect(Rect2(0.0, 0.0, 720.0, 1280.0), Color("#101d1c"))
	draw_rect(Rect2(0.0, 0.0, 720.0, 670.0), Color("#172b28"))
	draw_rect(Rect2(0.0, 670.0, 720.0, 610.0), Color("#17201d"))

	# Tall greenhouse glazing and the central arched window.
	draw_colored_polygon(PackedVector2Array([
		Vector2(78.0, 76.0), Vector2(642.0, 76.0),
		Vector2(624.0, 542.0), Vector2(96.0, 542.0)
	]), Color("#213b36"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(154.0, 512.0), Vector2(154.0, 278.0),
		Vector2(178.0, 186.0), Vector2(250.0, 115.0),
		Vector2(360.0, 91.0), Vector2(470.0, 115.0),
		Vector2(542.0, 186.0), Vector2(566.0, 278.0),
		Vector2(566.0, 512.0)
	]), Color("#31534a"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(171.0, 500.0), Vector2(171.0, 279.0),
		Vector2(193.0, 194.0), Vector2(258.0, 132.0),
		Vector2(360.0, 110.0), Vector2(462.0, 132.0),
		Vector2(527.0, 194.0), Vector2(549.0, 279.0),
		Vector2(549.0, 500.0)
	]), Color("#45685a"))
	# Soft light behind the glass panes.
	for ring in range(8, 0, -1):
		var alpha: float = 0.008 + float(8 - ring) * 0.002
		draw_circle(Vector2(360.0, 300.0), float(ring) * 49.0, Color(0.78, 0.83, 0.57, alpha))

	# Window mullions and timber frame.
	draw_polyline(PackedVector2Array([
		Vector2(154.0, 512.0), Vector2(154.0, 278.0),
		Vector2(178.0, 186.0), Vector2(250.0, 115.0),
		Vector2(360.0, 91.0), Vector2(470.0, 115.0),
		Vector2(542.0, 186.0), Vector2(566.0, 278.0),
		Vector2(566.0, 512.0)
	]), Color("#6f573b"), 15.0, true)
	draw_line(Vector2(360.0, 100.0), Vector2(360.0, 510.0), Color("#8b7049"), 8.0, true)
	draw_line(Vector2(165.0, 292.0), Vector2(555.0, 292.0), Color("#8b7049"), 7.0, true)
	draw_line(Vector2(252.0, 132.0), Vector2(252.0, 510.0), Color("#745b3e"), 5.0, true)
	draw_line(Vector2(468.0, 132.0), Vector2(468.0, 510.0), Color("#745b3e"), 5.0, true)
	draw_line(Vector2(86.0, 536.0), Vector2(634.0, 536.0), Color("#94704a"), 12.0, true)

	# Receding stone wall piers and sill.
	draw_colored_polygon(PackedVector2Array([
		Vector2(32.0, 118.0), Vector2(88.0, 118.0),
		Vector2(104.0, 620.0), Vector2(30.0, 620.0)
	]), Color("#35423a"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(632.0, 118.0), Vector2(688.0, 118.0),
		Vector2(690.0, 620.0), Vector2(616.0, 620.0)
	]), Color("#2d3b34"))
	_draw_plant_cluster(Vector2(80.0, 556.0), 0.95, Color("#5b8750"))
	_draw_plant_cluster(Vector2(644.0, 540.0), 0.92, Color("#6b9354"))

	# Left botanical shelves.
	_draw_shelf(Vector2(25.0, 350.0), Vector2(177.0, 20.0))
	_draw_shelf(Vector2(25.0, 478.0), Vector2(177.0, 18.0))
	_draw_pot(Vector2(66.0, 339.0), 0.76, Color("#a66e43"))
	_draw_pot(Vector2(137.0, 339.0), 0.68, Color("#896344"))
	_draw_plant_cluster(Vector2(66.0, 322.0), 0.48, Color("#76a65d"))
	_draw_plant_cluster(Vector2(137.0, 324.0), 0.44, Color("#83a960"))
	_draw_pot(Vector2(95.0, 466.0), 0.64, Color("#9a6841"))
	_draw_plant_cluster(Vector2(95.0, 451.0), 0.45, Color("#668d4c"))

	# Right archive shelves and vessels.
	_draw_shelf(Vector2(518.0, 350.0), Vector2(177.0, 20.0))
	_draw_shelf(Vector2(518.0, 478.0), Vector2(177.0, 18.0))
	_draw_book(Vector2(548.0, 310.0), 0.72, -0.07)
	_draw_book(Vector2(612.0, 315.0), 0.62, 0.08)
	_draw_crystal_cluster(Vector2(583.0, 449.0), 0.9)

	# Hanging vines around the window without closing the playable centre.
	_draw_vine(Vector2(105.0, 95.0), Vector2(130.0, 430.0), Color("#547d49"))
	_draw_vine(Vector2(609.0, 92.0), Vector2(584.0, 410.0), Color("#61844a"))

	# Central worktable: broad, open surface for an apparatus that can change
	# per experiment rather than a rack baked into this scene.
	draw_colored_polygon(PackedVector2Array([
		Vector2(42.0, 686.0), Vector2(678.0, 686.0),
		Vector2(715.0, 954.0), Vector2(5.0, 954.0)
	]), Color("#493322"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(55.0, 694.0), Vector2(665.0, 694.0),
		Vector2(694.0, 932.0), Vector2(26.0, 932.0)
	]), Color("#805638"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(26.0, 932.0), Vector2(694.0, 932.0),
		Vector2(678.0, 1075.0), Vector2(43.0, 1075.0)
	]), Color("#4b3021"))
	draw_line(Vector2(36.0, 945.0), Vector2(684.0, 945.0), Color("#c08a55"), 4.0, true)
	draw_line(Vector2(48.0, 1064.0), Vector2(671.0, 1064.0), Color("#2e2119"), 5.0, true)
	for line_index in range(5):
		var y: float = 724.0 + float(line_index) * 42.0
		draw_line(Vector2(80.0, y), Vector2(640.0, y - 3.0), Color(0.28, 0.16, 0.095, 0.22), 1.2, true)
	# A quiet brass inlay: this is a place marker, not a fixed vial layout.
	draw_arc(Vector2(360.0, 816.0), 112.0, 0.0, TAU, 96, Color(0.91, 0.68, 0.37, 0.42), 3.0, true)
	draw_arc(Vector2(360.0, 816.0), 91.0, 0.0, TAU, 96, Color(0.91, 0.68, 0.37, 0.22), 1.5, true)
	draw_line(Vector2(248.0, 816.0), Vector2(472.0, 816.0), Color(0.91, 0.68, 0.37, 0.24), 1.0, true)
	draw_line(Vector2(360.0, 704.0), Vector2(360.0, 928.0), Color(0.91, 0.68, 0.37, 0.24), 1.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(360.0, 788.0), Vector2(388.0, 816.0),
		Vector2(360.0, 844.0), Vector2(332.0, 816.0)
	]), Color(0.69, 0.78, 0.60, 0.28))
	_draw_book(Vector2(78.0, 745.0), 0.86, -0.08)
	_draw_pot(Vector2(600.0, 738.0), 0.78, Color("#a86c42"))
	_draw_plant_cluster(Vector2(600.0, 720.0), 0.36, Color("#699455"))

	# Floor stones and foreground foliage.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, 1082.0), Vector2(720.0, 1082.0),
		Vector2(720.0, 1280.0), Vector2(0.0, 1280.0)
	]), Color("#1d2924"))
	for stone_index in range(5):
		var stone_x: float = 74.0 + float(stone_index) * 143.0
		draw_line(Vector2(stone_x, 1120.0), Vector2(stone_x + 55.0, 1270.0), Color(0.54, 0.62, 0.49, 0.12), 2.0, true)
	_draw_pot(Vector2(47.0, 1135.0), 0.83, Color("#77553b"))
	_draw_plant_cluster(Vector2(47.0, 1115.0), 0.75, Color("#527d47"))
	_draw_pot(Vector2(673.0, 1140.0), 0.86, Color("#79543a"))
	_draw_plant_cluster(Vector2(673.0, 1120.0), 0.74, Color("#63884c"))

	# Warm lanterns and drifting motes.
	_draw_lantern(Vector2(210.0, 579.0))
	_draw_lantern(Vector2(510.0, 579.0))
	for mote_index in range(17):
		var px: float = 125.0 + float((mote_index * 79) % 475)
		var py: float = 180.0 + float((mote_index * 53) % 620)
		draw_circle(Vector2(px, py), 1.8 + float(mote_index % 3) * 0.6, Color(0.89, 0.76, 0.47, 0.25))


func _draw_shelf(position_value: Vector2, size_value: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		position_value,
		position_value + Vector2(size_value.x, 0.0),
		position_value + Vector2(size_value.x + 8.0, size_value.y),
		position_value + Vector2(-6.0, size_value.y)
	]), Color("#5e402b"))
	draw_line(position_value + Vector2(0.0, 2.0), position_value + Vector2(size_value.x, 2.0), Color("#bd8951"), 3.0, true)
	draw_line(position_value + Vector2(12.0, size_value.y), position_value + Vector2(12.0, size_value.y + 23.0), Color("#3d2c20"), 5.0, true)
	draw_line(position_value + Vector2(size_value.x - 12.0, size_value.y), position_value + Vector2(size_value.x - 12.0, size_value.y + 23.0), Color("#3d2c20"), 5.0, true)


func _draw_pot(base: Vector2, scale_value: float, tint: Color) -> void:
	var w: float = 29.0 * scale_value
	var h: float = 33.0 * scale_value
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-w, -h), base + Vector2(w, -h),
		base + Vector2(w * 0.76, 0.0), base + Vector2(-w * 0.76, 0.0)
	]), tint)
	_draw_ellipse(base + Vector2(0.0, -h), w, 6.0 * scale_value, tint.lightened(0.2))
	draw_line(base + Vector2(-w * 0.65, -h * 0.35), base + Vector2(w * 0.65, -h * 0.35), tint.darkened(0.22), 2.0, true)
	draw_line(base + Vector2(-w * 0.72, -4.0), base + Vector2(w * 0.72, -4.0), tint.darkened(0.28), 2.0, true)


func _draw_ellipse(center: Vector2, radius_x: float, radius_y: float, tint: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		var angle: float = TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_colored_polygon(points, tint)


func _draw_leaf(center: Vector2, length: float, width: float, angle: float, tint: Color) -> void:
	var direction := Vector2(cos(angle), sin(angle))
	var side := Vector2(-direction.y, direction.x)
	var p0: Vector2 = center - direction * length * 0.5
	var p1: Vector2 = center - direction * length * 0.16 + side * width * 0.52
	var p2: Vector2 = center + direction * length * 0.27 + side * width * 0.30
	var p3: Vector2 = center + direction * length * 0.5
	var p4: Vector2 = center + direction * length * 0.20 - side * width * 0.36
	var p5: Vector2 = center - direction * length * 0.20 - side * width * 0.48
	draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3, p4, p5]), tint)


func _draw_plant_cluster(origin: Vector2, scale_value: float, tint: Color) -> void:
	for index in range(9):
		var angle: float = -PI * 0.90 + float(index) * PI * 0.225
		var length: float = (42.0 + float((index * 13) % 24)) * scale_value
		var end: Vector2 = origin + Vector2(cos(angle) * length * 0.66, sin(angle) * length)
		draw_line(origin, end, tint.darkened(0.24), 3.0 * scale_value, true)
		_draw_leaf(end - Vector2(cos(angle) * 12.0, sin(angle) * 12.0), 36.0 * scale_value, 17.0 * scale_value, angle + 0.38, tint.lightened(float(index % 3) * 0.06))
		_draw_leaf(end + Vector2(cos(angle) * 7.0, sin(angle) * 8.0), 27.0 * scale_value, 13.0 * scale_value, angle - 0.42, tint.darkened(0.08))


func _draw_vine(start: Vector2, finish: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for index in range(17):
		var t: float = float(index) / 16.0
		var x: float = lerpf(start.x, finish.x, t) + sin(t * TAU * 1.4) * 14.0
		var y: float = lerpf(start.y, finish.y, t)
		points.append(Vector2(x, y))
	draw_polyline(points, tint.darkened(0.2), 4.0, true)
	for index in range(1, 16, 2):
		var point: Vector2 = points[index]
		var side_angle: float = -0.7 if index % 4 == 1 else 2.5
		_draw_leaf(point + Vector2(10.0, 0.0), 31.0, 13.0, side_angle, tint)


func _draw_book(position_value: Vector2, scale_value: float, angle: float) -> void:
	var centre := position_value
	var x_axis := Vector2(cos(angle), sin(angle))
	var y_axis := Vector2(-sin(angle), cos(angle))
	var half_w: float = 47.0 * scale_value
	var half_h: float = 31.0 * scale_value
	var corners := PackedVector2Array([
		centre - x_axis * half_w - y_axis * half_h,
		centre + x_axis * half_w - y_axis * half_h,
		centre + x_axis * half_w + y_axis * half_h,
		centre - x_axis * half_w + y_axis * half_h
	])
	draw_colored_polygon(corners, Color("#34241d"))
	draw_colored_polygon(PackedVector2Array([
		corners[0] + Vector2(4.0, -2.0), corners[1] + Vector2(-4.0, -2.0),
		corners[2] + Vector2(-4.0, -5.0), centre + Vector2(0.0, -4.0)
	]), Color("#c3a676"))
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(0.0, -4.0), corners[2] + Vector2(-4.0, -5.0),
		corners[3] + Vector2(4.0, -5.0)
	]), Color("#e0c796"))
	draw_line(centre + Vector2(0.0, -27.0 * scale_value), centre + Vector2(0.0, 25.0 * scale_value), Color("#6e4a2e"), 2.0, true)


func _draw_crystal_cluster(center: Vector2, scale_value: float) -> void:
	for index in range(5):
		var offset_x: float = (float(index) - 2.0) * 13.0 * scale_value
		var height: float = (26.0 + float((index * 17) % 23)) * scale_value
		var base := Vector2(center.x + offset_x, center.y)
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-8.0 * scale_value, 0.0),
			base + Vector2(-5.0 * scale_value, -height * 0.64),
			base + Vector2(0.0, -height),
			base + Vector2(7.0 * scale_value, -height * 0.54),
			base + Vector2(8.0 * scale_value, 0.0)
		]), Color("#6d9c91") if index % 2 == 0 else Color("#7c8db5"))
		draw_line(base + Vector2(0.0, -height * 0.78), base + Vector2(3.0, -4.0), Color(0.84, 0.96, 0.83, 0.52), 1.5, true)


func _draw_lantern(center: Vector2) -> void:
	draw_line(center + Vector2(0.0, -45.0), center + Vector2(0.0, -15.0), Color("#8b7049"), 3.0, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-15.0, -15.0), center + Vector2(15.0, -15.0),
		center + Vector2(19.0, 20.0), center + Vector2(-19.0, 20.0)
	]), Color("#60432b"))
	draw_rect(Rect2(center + Vector2(-10.0, -9.0), Vector2(20.0, 23.0)), Color(1.0, 0.68, 0.32, 0.28))
	draw_line(center + Vector2(-12.0, -15.0), center + Vector2(12.0, -15.0), Color("#c69b5b"), 3.0, true)
	draw_arc(center + Vector2(0.0, 3.0), 33.0, 0.0, TAU, 32, Color(1.0, 0.67, 0.28, 0.08), 13.0, true)


func _build_world() -> void:
	# World art is drawn by this root Control. The interactive layer remains
	# separate so all hotspots can move independently of the environment.
	set_process_input(true)


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
		_nav_buttons.append(button)


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
		"Work with limited vial capacity. Use the experiment apparatus to separate three essences with only one empty receiver.",
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
	get_tree().change_scene_to_file(EXPERIMENT_SCENE)


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
