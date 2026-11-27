extends Control

const BottleScript = preload("res://scripts/alchemy_bottle.gd")
const CAPACITY := 4
const BOTTLE_SOURCE_SIZE := Vector2(116.0, 365.0)

# A-G are the standard essences used by the expandable track. D is also the
# Dusk result used by the alchemy transmutation levels.
const PALETTE := {
	"A": Color(0.13, 0.83, 0.79, 1.0), # Tide — luminous turquoise
	"B": Color(0.98, 0.39, 0.20, 1.0), # Ember — saturated coral orange
	"C": Color(0.65, 0.44, 0.98, 1.0), # Moon — vivid amethyst
	"D": Color(0.35, 0.79, 0.47, 1.0), # Moss / Dusk result — enchanted green
	"E": Color(0.98, 0.69, 0.22, 1.0), # Amber — rich golden yellow
	"F": Color(0.32, 0.60, 0.99, 1.0), # Azure — bright alchemical blue
	"G": Color(0.89, 0.39, 0.78, 1.0)  # Violet — glowing orchid
}

const TRACK_A_LEVELS := [
	{
		"name": "First Separation",
		"description": "Two essences. Learn to lift a vial and pour its complete top layer group into an empty vessel or onto a matching essence.",
		"contents": [["A", "B", "A", "B"], ["B", "A", "B", "A"], [], []],
		"expected": ["A", "B"],
		"special": "classic"
	},
	{
		"name": "Third Essence",
		"description": "Three essences and one empty vessel. Plan where each temporary group should go.",
		"contents": [["C", "A", "B", "A"], ["A", "B", "C", "B"], ["B", "C", "A", "C"], []],
		"expected": ["A", "B", "C"],
		"special": "classic"
	},
	{
		"name": "The Tangle",
		"description": "Three essences with deeper interleaving. No new rule: the puzzle itself must provide the challenge.",
		"contents": [["A", "B", "C", "B"], ["C", "A", "C", "B"], ["A", "B", "A", "C"], []],
		"expected": ["A", "B", "C"],
		"special": "classic"
	},
	{
		"name": "Pipette",
		"description": "A one-use pipette can split a matching top group. Arm it, then pour when a source has multiple matching top layers. The pipette must be used to complete this level.",
		"contents": [["A", "B", "A", "B"], ["B", "A", "B", "A"], [], []],
		"expected": ["A", "B"],
		"special": "pipette",
		"precision_required": true
	},
	{
		"name": "The Careful Draught",
		"description": "Three essences and one precision charge. The pipette moves exactly one layer from a matching top group. Use it once to finish the puzzle.",
		"contents": [["C", "A", "B", "A"], ["A", "B", "C", "B"], ["B", "C", "A", "C"], []],
		"expected": ["A", "B", "C"],
		"special": "pipette",
		"precision_required": true
	},
	{
		"name": "Rune-Sealed Flask",
		"description": "The fourth flask is sealed as a receiver. Join two matching top layers in another vial to break the seal and unlock the extra space.",
		"contents": [["A", "B", "A"], ["B", "C", "A"], ["C", "B", "C"], []],
		"expected": ["A", "B", "C"],
		"special": "seal",
		"locked_vial": 3
	},
	{
		"name": "Breaking the Seal",
		"description": "A different arrangement, the same rune rule. First create a matching pair on top of a vial; only then can the sealed receiver be used.",
		"contents": [["B", "C", "B"], ["C", "A", "B"], ["A", "C", "A"], []],
		"expected": ["A", "B", "C"],
		"special": "seal",
		"locked_vial": 3
	},
	{
		"name": "Recipe Order",
		"description": "Build the recipe in the fourth vial, bottom-to-top: Tide → Ember → Moon → Tide. After the recipe is complete, purify the remaining Ember and Moon layers.",
		"contents": [["B", "C", "A"], ["C", "B"], ["B", "A", "C"], []],
		"special": "recipe",
		"recipe_target": 3,
		"recipe": ["A", "B", "C", "A"],
		"remaining_expected": ["B", "C"]
	},
	{
		"name": "Transmutation",
		"description": "Select the first vial and use TRANSMUTE. The adjacent Tide + Ember pair becomes one Dusk essence. Then sort Tide, Ember and Dusk.",
		"contents": [["A", "B", "A", "B"], ["B", "A", "B", "A"], [], []],
		"expected": ["A", "B", "D"],
		"special": "transmute",
		"transmute_required": true
	},
	{
		"name": "The Master Formula",
		"description": "Combine the known tools. First transmute Tide + Ember into Dusk. Then use the one-use pipette to split a multi-layer top group, and finish sorting.",
		"contents": [["A", "B", "A", "B"], ["B", "A", "B", "A"], [], []],
		"expected": ["A", "B", "D"],
		"special": "master",
		"transmute_required": true,
		"precision_required": true
	}
]

const TRACK_B_LEVELS := [
	{
		"name": "First Separation",
		"description": "Two essences across four vials. Two empty vessels give you room to learn the standard pour rules.",
		"contents": [["A", "B", "A", "B"], ["B", "A", "B", "A"], [], []],
		"expected": ["A", "B"]
	},
	{
		"name": "Third Essence",
		"description": "Three essences and four vials. One empty vessel must do the work of a temporary buffer.",
		"contents": [["C", "A", "B", "A"], ["A", "B", "C", "B"], ["B", "C", "A", "C"], []],
		"expected": ["A", "B", "C"]
	},
	{
		"name": "The Tangle",
		"description": "Three essences, one buffer, and a more interleaved starting state.",
		"contents": [["A", "B", "C", "B"], ["C", "A", "C", "B"], ["A", "B", "A", "C"], []],
		"expected": ["A", "B", "C"]
	},
	{
		"name": "A Wider Bench",
		"description": "Four essences and five vials. The first expansion adds a fifth position; there is no completely empty vial at the start.",
		"contents": [["A", "C", "D", "D"], ["B", "A", "C", "A"], ["C", "D"], ["D", "B", "B", "C"], ["B", "A"]],
		"expected": ["A", "B", "C", "D"]
	},
	{
		"name": "Extra Reagent",
		"description": "Four essences across six vials. One empty buffer remains, but the extra containers create more possible destinations.",
		"contents": [["A", "C", "D"], ["B", "D", "B", "A"], ["C", "B", "D"], ["D", "A", "C"], ["B", "A", "C"], []],
		"expected": ["A", "B", "C", "D"]
	},
	{
		"name": "Five Essences",
		"description": "Five essences across six vials. More colors, with no completely empty vial at the start.",
		"contents": [["A", "C"], ["B", "D", "B", "D"], ["C", "B", "C"], ["D", "E", "D", "C"], ["E", "A", "A", "B"], ["A", "E", "E"]],
		"expected": ["A", "B", "C", "D", "E"]
	},
	{
		"name": "The Second Row",
		"description": "Five essences across seven positions. A second row is now required, with one empty buffer.",
		"contents": [["A", "E", "D", "A"], ["B", "C", "E", "C"], ["C", "A", "C"], ["D", "B", "A"], ["E", "D"], ["D", "B", "B", "E"], []],
		"expected": ["A", "B", "C", "D", "E"]
	},
	{
		"name": "Six Essences",
		"description": "Six essences across seven positions. The second row stays, while the number of possible color groups increases.",
		"contents": [["A", "C", "A"], ["B", "F", "D", "D"], ["C", "B", "C", "C"], ["D", "E", "E", "B"], ["E", "A", "F"], ["F", "D", "A"], ["E", "B", "F"]],
		"expected": ["A", "B", "C", "D", "E", "F"]
	},
	{
		"name": "The Full Rack",
		"description": "Six essences across eight positions. One empty buffer remains in a full two-row layout.",
		"contents": [["A", "E", "B"], ["B", "A", "B", "A"], ["C", "B", "C"], ["D", "F", "F", "E"], ["E", "D", "E"], ["F", "C", "A"], ["F", "D", "D", "C"], []],
		"expected": ["A", "B", "C", "D", "E", "F"]
	},
	{
		"name": "Grand Sorting",
		"description": "Seven essences across eight positions. The largest conventional sorting layout in this test.",
		"contents": [["A", "D", "G"], ["B", "F", "B", "B"], ["C", "E", "D", "D"], ["D", "B", "G"], ["E", "G", "E", "F"], ["F", "C", "C"], ["G", "A", "F"], ["C", "A", "A", "E"]],
		"expected": ["A", "B", "C", "D", "E", "F", "G"]
	}
]

@export var launch_track: String = "A"
@export_range(0, 9, 1) var launch_level: int = 0

var current_track := "A"
var current_level := 0
var level_data: Dictionary = {}
var bottle_nodes: Array[Control] = []
var slot_positions: Array[Vector2] = []
var bottle_contents: Array = []
var move_history: Array[Dictionary] = []

var selected_vial := -1
var tool_selected_vial := -1
var drag_origin := Vector2.ZERO
var grab_offset := Vector2.ZERO
var is_dragging := false
var is_animating := false
var round_complete := false

var precision_armed := false
var precision_used := false
var seal_unlocked := false
var transmute_used := false
var recipe_progress := 0
var move_count := 0

var track_a_button: Button
var track_b_button: Button
var previous_button: Button
var next_button: Button
var next_level_action_button: Button
var restart_button: Button
var undo_button: Button
var pipette_button: Button
var transmute_button: Button
var level_label: Label
var description_label: Label
var status_label: Label
var move_label: Label
var objective_label: Label
var locked_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	current_track = "B" if launch_track == "B" else "A"
	current_level = clampi(launch_level, 0, 9)
	_build_interface()
	_load_level()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(720.0, 1280.0)), Color("#111a1b"))
	draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(720.0, 248.0)), Color("#172322"))
	draw_line(Vector2(22.0, 238.0), Vector2(698.0, 238.0), Color(0.78, 0.61, 0.38, 0.30), 1.0, true)


func _build_interface() -> void:
	var title := _make_label("SPELL SORT  /  EXPERIMENT", Vector2(26.0, 18.0), Vector2(475.0, 38.0), 26, Color("#f3dfbd"))
	add_child(title)
	var subtitle := _make_label("THE OVERGROWN GREENHOUSE  ·  CHAPTER 01", Vector2(28.0, 54.0), Vector2(470.0, 20.0), 12, Color("#9eb0a8"))
	add_child(subtitle)
	var return_button := _make_button("RETURN TO WORLD", Vector2(522.0, 20.0), Vector2(176.0, 36.0), Callable(self, "_return_to_world"))
	return_button.add_theme_font_size_override("font_size", 11)
	add_child(return_button)

	track_a_button = _make_button("TRACK A  ·  FOUR VIALS", Vector2(26.0, 84.0), Vector2(178.0, 42.0), Callable(self, "_select_track_a"))
	add_child(track_a_button)
	track_b_button = _make_button("TRACK B  ·  EXPANDABLE", Vector2(214.0, 84.0), Vector2(190.0, 42.0), Callable(self, "_select_track_b"))
	add_child(track_b_button)

	previous_button = _make_button("‹", Vector2(430.0, 84.0), Vector2(46.0, 42.0), Callable(self, "_previous_level"))
	add_child(previous_button)
	level_label = _make_label("", Vector2(484.0, 82.0), Vector2(164.0, 46.0), 15, Color("#f0d6a8"))
	add_child(level_label)
	next_button = _make_button("›", Vector2(660.0, 84.0), Vector2(38.0, 42.0), Callable(self, "_next_level"))
	add_child(next_button)

	description_label = _make_label("", Vector2(28.0, 139.0), Vector2(664.0, 82.0), 16, Color("#d1d9ce"), true)
	add_child(description_label)

	var board := _make_panel(Rect2(18.0, 260.0, 684.0, 662.0), Color("#1b2927"), Color("#8e714c"), 18)
	board.z_index = 0
	add_child(board)

	var board_title := _make_label("SORTING SURFACE  /  LAYOUT TEST", Vector2(32.0, 273.0), Vector2(560.0, 20.0), 12, Color("#9cae9f"))
	add_child(board_title)

	var status_panel := _make_panel(Rect2(20.0, 944.0, 680.0, 158.0), Color("#172421"), Color("#856844"), 16)
	status_panel.z_index = 0
	add_child(status_panel)

	status_label = _make_label("", Vector2(38.0, 956.0), Vector2(644.0, 44.0), 15, Color("#f0e6d1"), true)
	add_child(status_label)
	move_label = _make_label("", Vector2(38.0, 1000.0), Vector2(200.0, 27.0), 14, Color("#d8c39f"))
	add_child(move_label)
	objective_label = _make_label("", Vector2(38.0, 1027.0), Vector2(644.0, 58.0), 14, Color("#c3d0c4"), true)
	add_child(objective_label)

	restart_button = _make_button("RESTART", Vector2(22.0, 1124.0), Vector2(112.0, 48.0), Callable(self, "_restart_level"))
	add_child(restart_button)
	undo_button = _make_button("UNDO", Vector2(144.0, 1124.0), Vector2(94.0, 48.0), Callable(self, "_undo_move"))
	add_child(undo_button)
	pipette_button = _make_button("PIPETTE  1", Vector2(248.0, 1124.0), Vector2(126.0, 48.0), Callable(self, "_toggle_pipette"))
	add_child(pipette_button)
	transmute_button = _make_button("TRANSMUTE", Vector2(384.0, 1124.0), Vector2(132.0, 48.0), Callable(self, "_transmute_selected"))
	add_child(transmute_button)
	next_level_action_button = _make_button("NEXT LEVEL", Vector2(526.0, 1124.0), Vector2(172.0, 48.0), Callable(self, "_next_level"))
	add_child(next_level_action_button)

	_add_label_to_bottom("Drag a vial onto another vial to pour. Select a vial first to use an alchemy tool.", Vector2(26.0, 1186.0), Vector2(668.0, 30.0), 12, Color("#8fa39a"))


func _make_label(
	label_text: String,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int,
	font_color: Color,
	wrap: bool = false
) -> Label:
	var label := Label.new()
	label.text = label_text
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _add_label_to_bottom(
	label_text: String,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int,
	font_color: Color
) -> void:
	add_child(_make_label(label_text, position_value, size_value, font_size, font_color))


func _make_panel(rect: Rect2, background_color: Color, border_color: Color, radius: int) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_button(button_text: String, position_value: Vector2, size_value: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = button_text
	button.position = position_value
	button.size = size_value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("#f2e4ca"))
	button.add_theme_color_override("font_hover_color", Color("#fff3df"))
	button.add_theme_color_override("font_pressed_color", Color("#f9d18e"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#293a34")
	normal.border_color = Color("#8c704b")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(9)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#3a4d43")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#4a3b29")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.pressed.connect(callback)
	return button


func _current_levels() -> Array:
	return TRACK_A_LEVELS if current_track == "A" else TRACK_B_LEVELS


func _load_level() -> void:
	_clear_level_nodes()
	level_data = _current_levels()[current_level]
	bottle_contents = _copy_layout(level_data["contents"])
	move_history.clear()
	selected_vial = -1
	tool_selected_vial = -1
	is_dragging = false
	is_animating = false
	round_complete = false
	precision_armed = false
	precision_used = false
	seal_unlocked = false
	transmute_used = false
	recipe_progress = 0
	move_count = 0
	locked_label = null

	_build_vial_layout()
	_refresh_hud()
	_set_status("Drag a vial onto another vial. A target must be empty or show the same top essence.")


func _clear_level_nodes() -> void:
	for vial in bottle_nodes:
		if is_instance_valid(vial):
			remove_child(vial)
			vial.queue_free()
	bottle_nodes.clear()
	slot_positions.clear()
	for child in get_children():
		if child.is_in_group("direction_level_overlay"):
			remove_child(child)
			child.queue_free()


func _copy_layout(layout: Array) -> Array:
	var copied: Array = []
	for tube in layout:
		copied.append(tube.duplicate())
	return copied


func _build_vial_layout() -> void:
	var count := bottle_contents.size()
	var scale_value := 1.0
	var first_row_count := count
	var second_row_count := 0
	var horizontal_gap := 18.0
	var first_row_y := 385.0
	var second_row_y := 0.0

	if count > 4:
		scale_value = 0.70 if count <= 6 else 0.64
		horizontal_gap = 43.0 if count <= 6 else 39.0
		first_row_count = 3 if count <= 6 else 4
		second_row_count = count - first_row_count
		first_row_y = 342.0
		second_row_y = 342.0 + BOTTLE_SOURCE_SIZE.y * scale_value + (28.0 if count <= 6 else 25.0)

	var size_value := BOTTLE_SOURCE_SIZE * scale_value
	var first_start_x := (720.0 - (float(first_row_count) * size_value.x + float(first_row_count - 1) * horizontal_gap)) * 0.5
	var index := 0
	for column in range(first_row_count):
		var position_value := Vector2(first_start_x + float(column) * (size_value.x + horizontal_gap), first_row_y)
		_add_vial_slot(index, position_value, size_value)
		index += 1

	if second_row_count > 0:
		var second_start_x := (720.0 - (float(second_row_count) * size_value.x + float(second_row_count - 1) * horizontal_gap)) * 0.5
		for column in range(second_row_count):
			var position_value := Vector2(second_start_x + float(column) * (size_value.x + horizontal_gap), second_row_y)
			_add_vial_slot(index, position_value, size_value)
			index += 1


func _add_vial_slot(index: int, position_value: Vector2, size_value: Vector2) -> void:
	var slot := _make_panel(
		Rect2(position_value - Vector2(7.0, 5.0), size_value + Vector2(14.0, 10.0)),
		Color(0.055, 0.085, 0.08, 0.58),
		Color(0.66, 0.53, 0.34, 0.24),
		12
	)
	slot.add_to_group("direction_level_overlay")
	slot.z_index = 1
	add_child(slot)

	var vial = BottleScript.new()
	vial.name = "DirectionTestVial%d" % (index + 1)
	vial.position = position_value
	vial.size = size_value
	vial.z_index = 2
	vial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vial.call("setup", index, "VIAL %02d" % (index + 1), index % 4, PALETTE, bottle_contents[index])
	add_child(vial)
	bottle_nodes.append(vial)
	slot_positions.append(position_value)

	if index == int(level_data.get("locked_vial", -1)):
		locked_label = _make_label("SEALED", position_value + Vector2(7.0, size_value.y * 0.52), Vector2(size_value.x - 14.0, 25.0), 13, Color("#f5d69a"))
		locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked_label.z_index = 8
		locked_label.add_to_group("direction_level_overlay")
		add_child(locked_label)


func _gui_input(event: InputEvent) -> void:
	if is_animating or round_complete:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_drag(event.position)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_begin_drag(event.position)
		accept_event()


func _input(event: InputEvent) -> void:
	if selected_vial < 0 or not is_dragging or is_animating:
		return
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_update_drag(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_update_drag(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_drag(event.position)
		get_viewport().set_input_as_handled()


func _get_vial_at(pointer: Vector2) -> int:
	for index in range(bottle_nodes.size() - 1, -1, -1):
		var vial: Control = bottle_nodes[index]
		if Rect2(slot_positions[index], vial.size).has_point(pointer):
			return index
	return -1


func _begin_drag(pointer: Vector2) -> void:
	if selected_vial >= 0:
		return
	var index := _get_vial_at(pointer)
	if index < 0:
		return
	if bottle_contents[index].is_empty():
		_set_status("That vial is empty. Choose one containing an essence.")
		return
	if current_track == "A" and level_data.get("special", "") == "recipe" and index == int(level_data["recipe_target"]):
		_set_status("The recipe flask is the receiver. Choose an ingredient vial instead.")
		return

	if tool_selected_vial >= 0 and tool_selected_vial < bottle_nodes.size():
		bottle_nodes[tool_selected_vial].call("set_feedback", false, false, false)

	selected_vial = index
	tool_selected_vial = index
	is_dragging = true
	drag_origin = slot_positions[index]
	grab_offset = pointer - drag_origin
	var vial: Control = bottle_nodes[index]
	vial.z_index = 50
	vial.call("set_feedback", true, false, true)

	# The bottle draws its glass around an internal pivot. Compensate for that
	# transform immediately so the exact point grabbed stays under the pointer.
	var pickup_pose := Vector2(0.0, 0.0)
	vial.call("set_pose", pickup_pose)
	var pickup_anchor: Vector2 = vial.call("get_point_local_for_pose", grab_offset, pickup_pose)
	vial.position = pointer - pickup_anchor
	_set_status("Vial lifted. Release it over a valid receiving vial.")


func _update_drag(pointer: Vector2) -> void:
	if selected_vial < 0 or not is_dragging:
		return
	var vial: Control = bottle_nodes[selected_vial]
	var delta_x := pointer.x - (drag_origin.x + vial.size.x * 0.5)
	var tilt := deg_to_rad(38.0) * signf(delta_x)
	if is_zero_approx(delta_x):
		tilt = 0.0

	var drag_pose := Vector2(18.0, tilt)
	vial.call("set_pose", drag_pose)
	var drag_anchor: Vector2 = vial.call("get_point_local_for_pose", grab_offset, drag_pose)
	vial.position = pointer - drag_anchor


func _finish_drag(pointer: Vector2) -> void:
	if selected_vial < 0 or not is_dragging:
		return
	var source_index := selected_vial
	var target_index := _get_vial_at(pointer)
	is_dragging = false
	if target_index == source_index:
		tool_selected_vial = source_index
		_return_vial(source_index, "Vial selected for tool use. Press TRANSMUTE when ready.")
		return
	if target_index < 0:
		tool_selected_vial = -1
		_return_vial(source_index, "No receiving vial selected. Try again.")
		return
	_perform_pour(source_index, target_index)


func _get_transfer_details(source_index: int, target_index: int) -> Dictionary:
	if source_index == target_index:
		return {}
	var source: Array = bottle_contents[source_index]
	var target: Array = bottle_contents[target_index]
	if source.is_empty() or target.size() >= CAPACITY:
		return {}

	if current_track == "A" and level_data.get("special", "") == "seal":
		if target_index == int(level_data.get("locked_vial", -1)) and not seal_unlocked:
			return {}

	var essence := String(source.back())
	var special := String(level_data.get("special", ""))

	if special == "recipe" and target_index == int(level_data["recipe_target"]):
		var recipe: Array = level_data["recipe"]
		if recipe_progress >= recipe.size() or essence != String(recipe[recipe_progress]):
			return {}
		return {"amount": 1, "pipette": false, "recipe": true}

	if not target.is_empty() and String(target.back()) != essence:
		return {}

	var run_length := 0
	for layer_index in range(source.size() - 1, -1, -1):
		if String(source[layer_index]) == essence:
			run_length += 1
		else:
			break
	var available_space := CAPACITY - target.size()
	var amount := mini(run_length, available_space)
	var use_pipette := false
	if (special == "pipette" or special == "master") and precision_armed and not precision_used and run_length > 1 and available_space > 1:
		amount = 1
		use_pipette = true
	return {"amount": amount, "pipette": use_pipette, "recipe": false}


func _can_pour(source_index: int, target_index: int) -> bool:
	return not _get_transfer_details(source_index, target_index).is_empty()


func _perform_pour(source_index: int, target_index: int) -> void:
	var details := _get_transfer_details(source_index, target_index)
	if details.is_empty():
		tool_selected_vial = -1
		_return_vial(source_index, "Invalid pour. Use an empty vial or one with a matching top essence.")
		return

	is_animating = true
	_save_history()
	var source_vial: Control = bottle_nodes[source_index]
	var target_vial: Control = bottle_nodes[target_index]
	var amount := int(details["amount"])
	var essence := String(bottle_contents[source_index].back())
	var target_center := slot_positions[target_index] + target_vial.size * 0.5
	var stage_position := target_center - Vector2(source_vial.size.x * 0.5, source_vial.size.y * 0.78)

	var current_source_pose: Vector2 = source_vial.call("get_pose")
	var approach := create_tween().set_parallel(true)
	approach.tween_property(source_vial, "position", stage_position, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	approach.tween_method(Callable(source_vial, "set_pose"), current_source_pose, Vector2(20.0, deg_to_rad(62.0)), 0.16)
	await approach.finished

	var next_source: Array = bottle_contents[source_index].duplicate()
	var next_target: Array = bottle_contents[target_index].duplicate()
	for _step in range(amount):
		next_source.pop_back()
		next_target.append(essence)
	bottle_contents[source_index] = next_source
	bottle_contents[target_index] = next_target
	source_vial.call("set_contents", next_source)
	target_vial.call("set_contents", next_target)
	source_vial.call("trigger_slosh", 0.18)
	target_vial.call("trigger_slosh", 0.22)

	if bool(details["pipette"]):
		precision_used = true
		precision_armed = false
	if bool(details["recipe"]):
		recipe_progress += 1
	move_count += 1

	if current_track == "A" and level_data.get("special", "") == "seal" and not seal_unlocked:
		_check_seal_unlock()

	var settle := create_tween().set_parallel(true)
	settle.tween_property(source_vial, "position", slot_positions[source_index], 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	settle.tween_method(Callable(source_vial, "set_pose"), Vector2(20.0, deg_to_rad(62.0)), Vector2.ZERO, 0.20)
	await settle.finished
	source_vial.z_index = 2
	source_vial.call("set_feedback", false, false, false)
	source_vial.call("reset_motion")
	target_vial.call("set_feedback", false, false, false)
	selected_vial = -1
	tool_selected_vial = -1
	is_animating = false
	round_complete = _is_puzzle_solved()
	if round_complete:
		_set_status("LEVEL COMPLETE  ·  The objective is fulfilled. Move on or replay this level.")
	else:
		_set_status("Pour complete. Watch the top layers and plan the next transfer.")
	_refresh_hud()


func _check_seal_unlock() -> void:
	for tube in bottle_contents:
		if tube.size() >= 2 and String(tube[-1]) == String(tube[-2]):
			seal_unlocked = true
			if is_instance_valid(locked_label):
				locked_label.visible = false
			_set_status("The matching pair resonates. The rune seal breaks and the fourth vial is unlocked.")
			return


func _return_vial(index: int, message: String) -> void:
	is_animating = true
	var vial: Control = bottle_nodes[index]
	var current_pose: Vector2 = vial.call("get_pose")
	var tween := create_tween().set_parallel(true)
	tween.tween_property(vial, "position", slot_positions[index], 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(Callable(vial, "set_pose"), current_pose, Vector2.ZERO, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	vial.z_index = 2
	vial.call("set_feedback", false, false, false)
	vial.call("reset_motion")
	if tool_selected_vial == index:
		vial.call("set_feedback", true, false, false)
	selected_vial = -1
	is_animating = false
	_set_status(message)
	_refresh_hud()


func _save_history() -> void:
	move_history.append({
		"contents": _copy_layout(bottle_contents),
		"moves": move_count,
		"precision_armed": precision_armed,
		"precision_used": precision_used,
		"seal_unlocked": seal_unlocked,
		"transmute_used": transmute_used,
		"recipe_progress": recipe_progress
	})


func _undo_move() -> void:
	if is_animating or move_history.is_empty():
		return
	var snapshot: Dictionary = move_history.pop_back()
	bottle_contents = _copy_layout(snapshot["contents"])
	move_count = int(snapshot["moves"])
	precision_armed = bool(snapshot["precision_armed"])
	precision_used = bool(snapshot["precision_used"])
	seal_unlocked = bool(snapshot["seal_unlocked"])
	transmute_used = bool(snapshot["transmute_used"])
	recipe_progress = int(snapshot["recipe_progress"])
	for index in range(bottle_nodes.size()):
		var vial: Control = bottle_nodes[index]
		vial.position = slot_positions[index]
		vial.z_index = 2
		vial.call("reset_motion")
		vial.call("set_contents", bottle_contents[index])
	if is_instance_valid(locked_label):
		locked_label.visible = not seal_unlocked
	selected_vial = -1
	tool_selected_vial = -1
	round_complete = _is_puzzle_solved()
	_set_status("Last action undone.")
	_refresh_hud()


func _restart_level() -> void:
	if is_animating:
		return
	_load_level()


func _toggle_pipette() -> void:
	if is_animating or precision_used:
		return
	precision_armed = not precision_armed
	_set_status("Pipette armed. It will move exactly one layer from a matching top group." if precision_armed else "Pipette disarmed. Normal pours move the complete top group.")
	_refresh_hud()


func _transmute_selected() -> void:
	if is_animating or transmute_used:
		return
	if tool_selected_vial < 0:
		_set_status("Drag the retort vial onto itself to select it, then press TRANSMUTE.")
		return
	var tube: Array = bottle_contents[tool_selected_vial]
	for index in range(tube.size() - 1):
		if String(tube[index]) == "A" and String(tube[index + 1]) == "B":
			_save_history()
			tube[index] = "D"
			tube.remove_at(index + 1)
			bottle_contents[tool_selected_vial] = tube
			bottle_nodes[tool_selected_vial].call("set_contents", tube)
			bottle_nodes[tool_selected_vial].call("trigger_slosh", 0.24)
			transmute_used = true
			move_count += 1
			selected_vial = -1
			tool_selected_vial = -1
			round_complete = _is_puzzle_solved()
			_set_status("Tide and Ember combine into Dusk. Now separate all three essences.")
			_refresh_hud()
			return
	_set_status("The selected vial does not contain Tide directly beneath Ember. Select the retort vial.")


func _is_puzzle_solved() -> bool:
	var special := String(level_data.get("special", "classic"))
	if special == "recipe":
		if recipe_progress < level_data["recipe"].size():
			return false
		if not _pure_sort_except(int(level_data["recipe_target"]), level_data["remaining_expected"]):
			return false
		return true

	if not _pure_sort(level_data["expected"]):
		return false
	if bool(level_data.get("precision_required", false)) and not precision_used:
		return false
	if bool(level_data.get("transmute_required", false)) and not transmute_used:
		return false
	if special == "seal" and not seal_unlocked:
		return false
	return true


func _pure_sort(expected_essences: Array) -> bool:
	var found: Array = []
	for tube in bottle_contents:
		if tube.is_empty():
			continue
		var essence := String(tube[0])
		for layer in tube:
			if String(layer) != essence:
				return false
		if found.has(essence):
			return false
		found.append(essence)
	if found.size() != expected_essences.size():
		return false
	for essence in expected_essences:
		if not found.has(String(essence)):
			return false
	return true


func _pure_sort_except(excluded_vial: int, expected_essences: Array) -> bool:
	var found: Array = []
	for index in range(bottle_contents.size()):
		if index == excluded_vial:
			continue
		var tube: Array = bottle_contents[index]
		if tube.is_empty():
			continue
		var essence := String(tube[0])
		for layer in tube:
			if String(layer) != essence:
				return false
		if found.has(essence):
			return false
		found.append(essence)
	if found.size() != expected_essences.size():
		return false
	for essence in expected_essences:
		if not found.has(String(essence)):
			return false
	return true


func _copy_contents_for_counts() -> Dictionary:
	var counts := {}
	for tube in bottle_contents:
		for layer in tube:
			var essence := String(layer)
			counts[essence] = int(counts.get(essence, 0)) + 1
	return counts


func _refresh_hud() -> void:
	if not is_instance_valid(level_label):
		return
	var track_name := "FOUR-VIAL" if current_track == "A" else "EXPANDABLE"
	level_label.text = "%s  %02d / 10" % [track_name, current_level + 1]
	description_label.text = level_data.get("description", "")
	move_label.text = "MOVES  %02d" % move_count

	var special := String(level_data.get("special", "classic"))
	var objective := "Goal: consolidate every essence into one pure vial."
	if special == "seal":
		objective = "Goal: make a matching top pair to unlock the SEALED receiver, then purify all three essences."
	elif special == "recipe":
		var recipe_text := "TIDE  →  EMBER  →  MOON  →  TIDE"
		objective = "Recipe progress %d / 4: %s. Then consolidate the remaining essences." % [recipe_progress, recipe_text]
	elif special == "transmute":
		objective = "Select the retort vial and transmute the adjacent Tide + Ember pair into Dusk. Then sort."
	elif special == "master":
		objective = "Transmute Tide + Ember into Dusk, then use the pipette once before sorting."
	elif special == "pipette":
		objective = "Arm the one-use pipette and split a multi-layer top group. This action is required."
	objective_label.text = objective

	pipette_button.visible = special == "pipette" or special == "master"
	pipette_button.disabled = precision_used or is_animating
	pipette_button.text = "PIPETTE ARMED" if precision_armed else ("PIPETTE USED" if precision_used else "PIPETTE  1")
	transmute_button.visible = special == "transmute" or special == "master"
	transmute_button.disabled = transmute_used or is_animating
	transmute_button.text = "TRANSMUTED" if transmute_used else "TRANSMUTE"
	undo_button.disabled = move_history.is_empty() or is_animating
	restart_button.disabled = is_animating
	previous_button.disabled = current_level <= 0 or is_animating
	next_button.disabled = current_level >= 9 or is_animating
	next_level_action_button.disabled = current_level >= 9 or is_animating
	track_a_button.disabled = current_track == "A" or is_animating
	track_b_button.disabled = current_track == "B" or is_animating


func _set_status(value: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = value


func _select_track_a() -> void:
	if is_animating:
		return
	current_track = "A"
	current_level = 0
	_load_level()


func _select_track_b() -> void:
	if is_animating:
		return
	current_track = "B"
	current_level = 0
	_load_level()


func _previous_level() -> void:
	if is_animating or current_level <= 0:
		return
	current_level -= 1
	_load_level()


func _next_level() -> void:
	if is_animating or current_level >= 9:
		return
	current_level += 1
	_load_level()


func _return_to_world() -> void:
	if is_animating:
		return
	get_tree().change_scene_to_file("res://scenes/greenhouse_journey.tscn")
