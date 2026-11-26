extends "res://scripts/sorting_direction_prototype.gd"


class SlotMarkerSurface extends Control:
    var slot_markers: Array = []

    func configure(markers: Array) -> void:
        slot_markers = markers.duplicate(true)
        queue_redraw()

    func _draw() -> void:
        for marker in slot_markers:
            var centre: Vector2 = marker["centre"]
            var radius: Vector2 = marker["radius"]
            var scale_value: float = float(marker["scale"])

            var shadow := _ellipse_points(
                centre + Vector2(0.0, 5.0),
                radius.x * 1.12,
                radius.y * 1.28,
                48
            )
            draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.38))

            var inset := _ellipse_points(centre, radius.x, radius.y, 48)
            draw_colored_polygon(inset, Color(0.012, 0.025, 0.026, 0.72))
            draw_polyline(
                _closed_points(inset),
                Color(0.38, 0.60, 0.54, 0.25),
                maxf(1.0, 1.35 * scale_value),
                true
            )

            var inner := _ellipse_points(
                centre + Vector2(0.0, -1.0),
                radius.x * 0.82,
                radius.y * 0.72,
                48
            )
            draw_polyline(
                _closed_points(inner),
                Color(0.72, 0.80, 0.69, 0.10),
                1.0,
                true
            )

    func _ellipse_points(centre: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
        var points := PackedVector2Array()
        for index in range(segments):
            var angle: float = TAU * float(index) / float(segments)
            points.append(centre + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
        return points

    func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
        var closed := points.duplicate()
        if not closed.is_empty():
            closed.append(closed[0])
        return closed


class SoftIconButton extends Button:
    var icon_kind: String = "undo"
    var caption: String = ""

    func configure(kind: String, caption_text: String = "") -> void:
        icon_kind = kind
        caption = caption_text
        queue_redraw()

    func _ready() -> void:
        focus_mode = Control.FOCUS_NONE
        custom_minimum_size = Vector2(84.0, 78.0)
        add_theme_color_override("font_color", Color("#dce7df"))
        add_theme_color_override("font_disabled_color", Color(0.75, 0.82, 0.77, 0.28))
        var normal := StyleBoxFlat.new()
        normal.bg_color = Color(0.10, 0.17, 0.17, 0.48)
        normal.border_color = Color(0.55, 0.73, 0.65, 0.08)
        normal.set_border_width_all(1)
        normal.set_corner_radius_all(24)
        normal.set_content_margin_all(0.0)
        var hover := normal.duplicate() as StyleBoxFlat
        hover.bg_color = Color(0.19, 0.31, 0.28, 0.82)
        hover.border_color = Color(0.66, 0.84, 0.74, 0.20)
        var pressed := normal.duplicate() as StyleBoxFlat
        pressed.bg_color = Color(0.28, 0.32, 0.25, 0.92)
        add_theme_stylebox_override("normal", normal)
        add_theme_stylebox_override("hover", hover)
        add_theme_stylebox_override("pressed", pressed)
        add_theme_stylebox_override("disabled", normal)

    func _draw() -> void:
        var centre := Vector2(size.x * 0.5, 25.0)
        var ink := Color("#dce8df")
        if disabled:
            ink.a = 0.30

        match icon_kind:
            "back":
                draw_line(centre + Vector2(7.0, -8.0), centre + Vector2(-2.0, 0.0), ink, 2.0, true)
                draw_line(centre + Vector2(-2.0, 0.0), centre + Vector2(7.0, 8.0), ink, 2.0, true)
                draw_line(centre + Vector2(-2.0, 0.0), centre + Vector2(12.0, 0.0), ink, 2.0, true)
            "menu":
                for offset in [-9.0, 0.0, 9.0]:
                    draw_circle(centre + Vector2(offset, 0.0), 1.9, ink)
            "pipette":
                var stem := PackedVector2Array([
                    centre + Vector2(-8.0, -8.0),
                    centre + Vector2(7.0, 7.0)
                ])
                draw_line(stem[0], stem[1], ink, 3.0, true)
                draw_line(centre + Vector2(-11.0, -5.0), centre + Vector2(-5.0, -11.0), ink, 3.0, true)
                draw_line(centre + Vector2(4.0, 4.0), centre + Vector2(10.0, -2.0), ink, 3.0, true)
                draw_line(centre + Vector2(7.0, 7.0), centre + Vector2(11.0, 15.0), ink, 1.8, true)
                draw_circle(centre + Vector2(12.0, 17.0), 1.8, ink)
            "transmute":
                draw_line(centre + Vector2(0.0, -12.0), centre + Vector2(0.0, 12.0), ink, 1.8, true)
                draw_line(centre + Vector2(-12.0, 0.0), centre + Vector2(12.0, 0.0), ink, 1.8, true)
                draw_line(centre + Vector2(-7.0, -7.0), centre + Vector2(7.0, 7.0), ink, 1.4, true)
                draw_line(centre + Vector2(-7.0, 7.0), centre + Vector2(7.0, -7.0), ink, 1.4, true)
                draw_circle(centre, 3.0, ink)
            "continue":
                draw_line(centre + Vector2(-10.0, 0.0), centre + Vector2(10.0, 0.0), ink, 2.2, true)
                draw_line(centre + Vector2(3.0, -8.0), centre + Vector2(11.0, 0.0), ink, 2.2, true)
                draw_line(centre + Vector2(11.0, 0.0), centre + Vector2(3.0, 8.0), ink, 2.2, true)
            "info":
                draw_arc(centre, 11.0, 0.0, TAU, 36, ink, 1.8, true)
                draw_circle(centre + Vector2(0.0, -5.0), 1.2, ink)
                draw_line(centre + Vector2(0.0, 0.0), centre + Vector2(0.0, 7.0), ink, 1.8, true)
            "undo":
                draw_arc(centre + Vector2(1.0, 1.0), 9.0, deg_to_rad(42.0), deg_to_rad(318.0), 28, ink, 2.0, true)
                draw_line(centre + Vector2(-8.0, -8.0), centre + Vector2(-13.0, -1.0), ink, 2.0, true)
                draw_line(centre + Vector2(-8.0, -8.0), centre + Vector2(-1.0, -10.0), ink, 2.0, true)
            _:
                draw_circle(centre, 8.0, ink)

        if not caption.is_empty():
            var caption_color := ink
            caption_color.a *= 0.92
            draw_string(
                ThemeDB.fallback_font,
                Vector2(3.0, size.y - 7.0),
                caption,
                HORIZONTAL_ALIGNMENT_CENTER,
                size.x - 6.0,
                11,
                caption_color
            )


const VIAL_LEVELS := {
    4: 0,
    6: 4,
    8: 8
}

const LAYOUT_LABELS := {
    "line": "Line",
    "arc": "Arc",
    "rows": "Two rows"
}

const LAYOUT_NOTES := {
    "line": "Vessels share one horizontal line wherever the screen can comfortably fit them.",
    "arc": "Vessels follow a shallow curve, keeping the central positions slightly lower.",
    "rows": "Vessels use two aligned rows with a clear gap between the upper and lower groups."
}

var _selected_layout: String = "line"
var _selected_vial_count: int = 4
var _slot_surface: SlotMarkerSurface
var _layout_buttons: Dictionary = {}
var _count_buttons: Dictionary = {}

var _back_button: SoftIconButton
var _menu_button: SoftIconButton
var _objective_button: Button
var _experiment_title: Label
var _chapter_label: Label
var _status_tween: Tween

var _sheet_layer: Control
var _sheet_dimmer: ColorRect
var _sheet_panel: Panel
var _sheet_title: Label
var _sheet_content: VBoxContainer
var _sheet_kind: String = ""


func _draw() -> void:
    draw_rect(Rect2(0.0, 0.0, 720.0, 1280.0), Color("#080e11"))
    draw_rect(Rect2(0.0, 0.0, 720.0, 300.0), Color("#0c1518"))

    for radius_step in range(12, 0, -1):
        var radius: float = float(radius_step) * 62.0
        var alpha: float = 0.004 + float(12 - radius_step) * 0.0015
        draw_circle(Vector2(360.0, 638.0), radius, Color(0.19, 0.39, 0.34, alpha))

    draw_rect(Rect2(0.0, 0.0, 720.0, 1280.0), Color(0.0, 0.0, 0.0, 0.10), false, 1.0)


func _build_interface() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP

    _back_button = _make_icon_button("back", "", Callable(self, "_return_to_world"))
    _back_button.position = Vector2(22.0, 25.0)
    _back_button.size = Vector2(52.0, 52.0)
    _back_button.z_index = 20
    _back_button.tooltip_text = "Return to the greenhouse"
    add_child(_back_button)

    _menu_button = _make_icon_button("menu", "", Callable(self, "_open_menu"))
    _menu_button.position = Vector2(646.0, 25.0)
    _menu_button.size = Vector2(52.0, 52.0)
    _menu_button.z_index = 20
    _menu_button.tooltip_text = "Experiment menu"
    add_child(_menu_button)

    _chapter_label = _make_label(
        "THE OVERGROWN GREENHOUSE",
        Vector2(88.0, 33.0),
        Vector2(544.0, 22.0),
        11,
        Color("#9db3a8")
    )
    _chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _chapter_label.add_theme_color_override("font_color", Color("#9db3a8"))
    _chapter_label.z_index = 20
    add_child(_chapter_label)

    _experiment_title = _make_label(
        "",
        Vector2(42.0, 82.0),
        Vector2(636.0, 46.0),
        30,
        Color("#e8e7d8")
    )
    _experiment_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _experiment_title.z_index = 20
    add_child(_experiment_title)

    level_label = _make_label(
        "",
        Vector2(70.0, 130.0),
        Vector2(580.0, 20.0),
        10,
        Color("#b4bda9")
    )
    level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    level_label.z_index = 20
    add_child(level_label)

    _objective_button = Button.new()
    _objective_button.position = Vector2(44.0, 172.0)
    _objective_button.size = Vector2(632.0, 46.0)
    _objective_button.focus_mode = Control.FOCUS_NONE
    _objective_button.text = ""
    _objective_button.add_theme_font_size_override("font_size", 15)
    _objective_button.add_theme_color_override("font_color", Color("#d5dfd5"))
    _objective_button.add_theme_color_override("font_hover_color", Color("#f0ead9"))
    _objective_button.add_theme_stylebox_override("normal", _flat_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 18, 0))
    _objective_button.add_theme_stylebox_override("hover", _flat_style(Color(0.10, 0.19, 0.18, 0.38), Color(0.0, 0.0, 0.0, 0.0), 18, 0))
    _objective_button.add_theme_stylebox_override("pressed", _flat_style(Color(0.15, 0.22, 0.19, 0.50), Color(0.0, 0.0, 0.0, 0.0), 18, 0))
    _objective_button.pressed.connect(Callable(self, "_open_objective_details"))
    _objective_button.z_index = 20
    add_child(_objective_button)

    status_label = _make_label(
        "",
        Vector2(62.0, 226.0),
        Vector2(596.0, 34.0),
        13,
        Color("#c6d8cc")
    )
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
    status_label.z_index = 20
    add_child(status_label)

    _slot_surface = SlotMarkerSurface.new()
    _slot_surface.name = "MinimalSlotMarkers"
    _slot_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _slot_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _slot_surface.z_index = 1
    add_child(_slot_surface)

    undo_button = _make_icon_button("undo", "Undo", Callable(self, "_undo_move"))
    undo_button.z_index = 24
    add_child(undo_button)

    pipette_button = _make_icon_button("pipette", "Pipette", Callable(self, "_toggle_pipette"))
    pipette_button.z_index = 24
    add_child(pipette_button)

    transmute_button = _make_icon_button("transmute", "Transmute", Callable(self, "_transmute_selected"))
    transmute_button.z_index = 24
    add_child(transmute_button)

    next_level_action_button = _make_icon_button("continue", "Continue", Callable(self, "_continue_from_completion"))
    next_level_action_button.z_index = 24
    add_child(next_level_action_button)

    # The inherited sorting controller still owns puzzle state and action rules.
    # These non-rendered controls satisfy its shared HUD refresh contract.
    restart_button = Button.new()
    track_a_button = Button.new()
    track_b_button = Button.new()
    previous_button = Button.new()
    next_button = Button.new()
    description_label = Label.new()
    move_label = Label.new()
    objective_label = Label.new()

    _layout_action_buttons()


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


func _flat_style(background_color: Color, border_color: Color, radius: int, border_width: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background_color
    style.border_color = border_color
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(radius)
    style.set_content_margin_all(0.0)
    return style


func _make_icon_button(kind: String, caption_text: String, callback: Callable) -> SoftIconButton:
    var button := SoftIconButton.new()
    button.configure(kind, caption_text)
    button.pressed.connect(callback)
    return button


func _build_vial_layout() -> void:
    var count: int = bottle_contents.size()
    var markers: Array = []

    match _selected_layout:
        "arc":
            if count <= 6:
                var scale_value: float = 1.0 if count == 4 else 0.84
                _place_vial_row(0, count, scale_value, 856.0, markers, 0.0, 48.0)
            else:
                _place_vial_row(0, 4, 0.80, 600.0, markers, 0.0, 22.0)
                _place_vial_row(4, 4, 0.80, 910.0, markers, 0.0, 22.0)
        "rows":
            _place_two_rows(count, markers, false)
        _:
            if count <= 6:
                var scale_value: float = 1.0 if count == 4 else 0.84
                _place_vial_row(0, count, scale_value, 856.0, markers)
            else:
                _place_vial_row(0, 4, 0.80, 600.0, markers)
                _place_vial_row(4, 4, 0.80, 910.0, markers)

    _slot_surface.configure(markers)


func _place_two_rows(count: int, markers: Array, staggered: bool) -> void:
    var columns: int = int(ceil(float(count) * 0.5))
    var upper_count: int = columns
    var lower_count: int = count - upper_count
    var scale_value: float
    match count:
        4:
            scale_value = 0.80
        6:
            scale_value = 0.78
        _:
            scale_value = 0.72

    _place_vial_row(0, upper_count, scale_value, 610.0, markers, 20.0 if staggered else 0.0)
    if lower_count > 0:
        _place_vial_row(upper_count, lower_count, scale_value, 910.0, markers, -20.0 if staggered else 0.0)


func _place_vial_row(
    start_index: int,
    row_count: int,
    scale_value: float,
    base_y: float,
    markers: Array,
    horizontal_shift: float = 0.0,
    arc_strength: float = 0.0
) -> void:
    var size_value: Vector2 = BOTTLE_SOURCE_SIZE * scale_value
    var gap: float = (720.0 - float(row_count) * size_value.x) / float(row_count + 1)

    for column in range(row_count):
        var x_position: float = gap + float(column) * (size_value.x + gap) + horizontal_shift
        var normalized_x: float = (x_position + size_value.x * 0.5 - 360.0) / 330.0
        var foot_y: float = base_y - pow(absf(normalized_x), 1.45) * arc_strength
        var position_value := Vector2(
            x_position,
            foot_y - _vial_base_offset(size_value)
        )
        var vial_index: int = start_index + column
        _add_minimal_vial(vial_index, position_value, size_value, markers)


func _add_minimal_vial(index: int, position_value: Vector2, size_value: Vector2, markers: Array) -> void:
    var vial: Control = BottleScript.new()
    vial.name = "SortingVial%02d" % (index + 1)
    vial.position = position_value
    vial.size = size_value
    vial.z_index = 2
    vial.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vial.call(
        "setup",
        index,
        "%02d" % (index + 1),
        index % 4,
        PALETTE,
        bottle_contents[index]
    )
    add_child(vial)
    bottle_nodes.append(vial)
    slot_positions.append(position_value)

    var foot := Vector2(
        position_value.x + size_value.x * 0.5,
        position_value.y + _vial_base_offset(size_value)
    )
    markers.append({
        "centre": foot,
        "radius": Vector2(size_value.x * 0.47, size_value.x * 0.125),
        "scale": size_value.x / BOTTLE_SOURCE_SIZE.x
    })

    if index == int(level_data.get("locked_vial", -1)):
        locked_label = _make_label(
            "SEALED",
            position_value + Vector2(4.0, size_value.y * 0.54),
            Vector2(size_value.x - 8.0, 24.0),
            11,
            Color("#f5d69a")
        )
        locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        locked_label.z_index = 8
        locked_label.add_to_group("direction_level_overlay")
        add_child(locked_label)


func _vial_base_offset(size_value: Vector2) -> float:
    return 72.0 + size_value.y * 0.735 * 0.975


func _refresh_hud() -> void:
    super._refresh_hud()
    if not is_instance_valid(level_label) or not is_instance_valid(_experiment_title):
        return

    _selected_vial_count = bottle_contents.size()
    var level_number := current_level + 1
    _experiment_title.text = String(level_data.get("name", "Alchemy experiment"))
    if round_complete:
        level_label.text = "THE OVERGROWN GREENHOUSE  ·  EXPERIMENT COMPLETE"
        _objective_button.text = "The essences are balanced  ·  View experiment notes  ⌄"
    else:
        level_label.text = "CHAPTER I  ·  EXPERIMENT %02d / 10" % level_number
        _objective_button.text = _short_objective() + "   ⌄"

    description_label.visible = false
    move_label.visible = false
    objective_label.visible = false
    restart_button.visible = false

    undo_button.visible = not round_complete
    undo_button.disabled = move_history.is_empty() or is_animating
    undo_button.caption = "Undo"
    undo_button.queue_redraw()

    var special := String(level_data.get("special", "classic"))
    pipette_button.visible = not round_complete and (special == "pipette" or special == "master")
    pipette_button.disabled = precision_used or is_animating
    pipette_button.configure("pipette", "Used" if precision_used else ("Armed" if precision_armed else "Pipette"))

    transmute_button.visible = not round_complete and (special == "transmute" or special == "master")
    transmute_button.disabled = transmute_used or is_animating
    transmute_button.configure("transmute", "Done" if transmute_used else "Transmute")

    next_level_action_button.visible = round_complete
    next_level_action_button.disabled = is_animating
    next_level_action_button.configure("continue", "Return" if current_level >= 9 else "Continue")

    _layout_action_buttons()


func _short_objective() -> String:
    var special := String(level_data.get("special", "classic"))
    match special:
        "seal":
            return "Break the seal, then purify each essence"
        "recipe":
            return "Complete the formula in the receiving vial"
        "transmute":
            return "Combine Tide + Ember, then sort the essences"
        "master":
            return "Transmute, use the pipette, then sort"
        "pipette":
            return "Use the precision pipette, then sort"
        _:
            return "Separate each essence into its own vessel"


func _layout_action_buttons() -> void:
    if not is_instance_valid(undo_button):
        return

    if round_complete:
        next_level_action_button.position = Vector2(236.0, 1128.0)
        next_level_action_button.size = Vector2(248.0, 78.0)
        return

    var actions: Array = []
    if undo_button.visible:
        actions.append(undo_button)
    if pipette_button.visible:
        actions.append(pipette_button)
    if transmute_button.visible:
        actions.append(transmute_button)

    var button_width := 88.0
    var button_height := 78.0
    var separation := 22.0
    var total_width := float(actions.size()) * button_width + float(maxi(0, actions.size() - 1)) * separation
    var start_x := (720.0 - total_width) * 0.5

    for index in range(actions.size()):
        var action: SoftIconButton = actions[index]
        action.position = Vector2(start_x + float(index) * (button_width + separation), 1128.0)
        action.size = Vector2(button_width, button_height)


func _set_status(value: String) -> void:
    if not is_instance_valid(status_label):
        return
    status_label.text = value
    if _status_tween != null and _status_tween.is_running():
        _status_tween.kill()
    status_label.modulate.a = 0.0
    _status_tween = create_tween()
    _status_tween.tween_property(status_label, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _status_tween.tween_interval(2.6)
    _status_tween.tween_property(status_label, "modulate:a", 0.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func _update_drag(pointer: Vector2) -> void:
    super._update_drag(pointer)
    if selected_vial < 0 or not is_dragging:
        return

    for index in range(bottle_nodes.size()):
        if index == selected_vial:
            continue
        var is_valid_target := _can_pour(selected_vial, index)
        bottle_nodes[index].call("set_feedback", false, is_valid_target, false)


func _finish_drag(pointer: Vector2) -> void:
    var source_index := selected_vial
    super._finish_drag(pointer)
    if source_index < 0:
        return
    for index in range(bottle_nodes.size()):
        if index != source_index:
            bottle_nodes[index].call("set_feedback", false, false, false)


func _continue_from_completion() -> void:
    if is_animating or not round_complete:
        return
    if current_level >= 9:
        _return_to_world()
    else:
        _next_level()


func _open_menu() -> void:
    _show_sheet("menu")


func _open_objective_details() -> void:
    _show_sheet("details")


func _show_sheet(kind: String) -> void:
    if not is_instance_valid(_sheet_layer):
        _create_sheet_layer()
    _populate_sheet(kind)
    _sheet_panel.position.y = 1280.0
    _sheet_panel.modulate.a = 0.92
    _sheet_dimmer.color.a = 0.0
    var tween := create_tween().set_parallel(true)
    tween.tween_property(_sheet_dimmer, "color:a", 0.58, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(_sheet_panel, "position:y", 760.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(_sheet_panel, "modulate:a", 1.0, 0.20)


func _create_sheet_layer() -> void:
    _sheet_layer = Control.new()
    _sheet_layer.name = "AdaptiveSheetLayer"
    _sheet_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _sheet_layer.mouse_filter = Control.MOUSE_FILTER_STOP
    _sheet_layer.z_index = 100
    add_child(_sheet_layer)

    _sheet_dimmer = ColorRect.new()
    _sheet_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _sheet_dimmer.color = Color(0.0, 0.0, 0.0, 0.0)
    _sheet_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    _sheet_dimmer.gui_input.connect(_on_sheet_dimmer_input)
    _sheet_layer.add_child(_sheet_dimmer)

    _sheet_panel = Panel.new()
    _sheet_panel.position = Vector2(20.0, 1280.0)
    _sheet_panel.size = Vector2(680.0, 500.0)
    _sheet_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _sheet_panel.add_theme_stylebox_override(
        "panel",
        _flat_style(Color("#142326"), Color(0.60, 0.78, 0.68, 0.18), 28, 1)
    )
    _sheet_layer.add_child(_sheet_panel)

    var handle := Panel.new()
    handle.position = Vector2(304.0, 12.0)
    handle.size = Vector2(72.0, 4.0)
    handle.add_theme_stylebox_override(
        "panel",
        _flat_style(Color(0.74, 0.85, 0.77, 0.34), Color(0.0, 0.0, 0.0, 0.0), 4, 0)
    )
    handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _sheet_panel.add_child(handle)

    _sheet_title = _make_label("", Vector2(30.0, 28.0), Vector2(540.0, 38.0), 22, Color("#e7e8da"))
    _sheet_panel.add_child(_sheet_title)

    var close_button := Button.new()
    close_button.position = Vector2(612.0, 22.0)
    close_button.size = Vector2(42.0, 42.0)
    close_button.text = "×"
    close_button.focus_mode = Control.FOCUS_NONE
    close_button.add_theme_font_size_override("font_size", 26)
    close_button.add_theme_color_override("font_color", Color("#bdcbc1"))
    close_button.add_theme_stylebox_override("normal", _flat_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 20, 0))
    close_button.add_theme_stylebox_override("hover", _flat_style(Color(0.35, 0.48, 0.42, 0.30), Color(0.0, 0.0, 0.0, 0.0), 20, 0))
    close_button.pressed.connect(_close_sheet)
    _sheet_panel.add_child(close_button)

    _sheet_content = VBoxContainer.new()
    _sheet_content.position = Vector2(30.0, 82.0)
    _sheet_content.size = Vector2(620.0, 390.0)
    _sheet_content.add_theme_constant_override("separation", 12)
    _sheet_content.mouse_filter = Control.MOUSE_FILTER_PASS
    _sheet_panel.add_child(_sheet_content)


func _populate_sheet(kind: String) -> void:
    _sheet_kind = kind
    for child in _sheet_content.get_children():
        _sheet_content.remove_child(child)
        child.queue_free()

    match kind:
        "menu":
            _sheet_title.text = "Experiment menu"
            _add_sheet_copy("A little more room for the details. The sorting space stays clear while you play.")
            _add_sheet_button("Experiment notes", Callable(self, "_show_sheet").bind("details"))
            _add_sheet_button("Arrangement & vial count", Callable(self, "_show_sheet").bind("layout"))
            _add_sheet_button("Restart experiment", Callable(self, "_show_sheet").bind("restart"))
            _add_sheet_button("Return to greenhouse", Callable(self, "_return_to_world"))
        "details":
            _sheet_title.text = "Experiment notes"
            _add_sheet_heading("THE OBJECTIVE")
            _add_sheet_copy(_short_objective() + ".")
            _add_sheet_heading("FIELD NOTES")
            _add_sheet_copy(String(level_data.get("description", "No additional notes for this experiment.")))
            var stats := "MOVES  %02d     ·     VIALS  %02d     ·     EXPERIMENT  %02d / 10" % [move_count, bottle_contents.size(), current_level + 1]
            _add_sheet_copy(stats, 12, Color("#a8b8ae"))
            if level_data.has("special"):
                _add_sheet_button("Back to experiment menu", Callable(self, "_show_sheet").bind("menu"))
        "layout":
            _sheet_title.text = "Arrangement"
            _add_sheet_copy("These comparison controls are tucked away here so they never compete with the actual sorting.")
            _add_sheet_heading("VIAL ARRANGEMENT")
            var layout_row := HBoxContainer.new()
            layout_row.add_theme_constant_override("separation", 8)
            _sheet_content.add_child(layout_row)
            for layout_id in ["line", "arc", "rows"]:
                var layout_button := _make_choice_button(
                    String(LAYOUT_LABELS[layout_id]),
                    Callable(self, "_choose_layout").bind(layout_id),
                    _selected_layout == layout_id
                )
                layout_row.add_child(layout_button)
                _layout_buttons[layout_id] = layout_button

            _add_sheet_heading("VIAL COUNT")
            var count_row := HBoxContainer.new()
            count_row.add_theme_constant_override("separation", 8)
            _sheet_content.add_child(count_row)
            for vial_count in [4, 6, 8]:
                var count_button := _make_choice_button(
                    "%d vials" % vial_count,
                    Callable(self, "_choose_vial_count").bind(vial_count),
                    _selected_vial_count == vial_count
                )
                count_row.add_child(count_button)
                _count_buttons[vial_count] = count_button
            _add_sheet_copy("Changing either setting reloads the current sample puzzle.", 12, Color("#9eaea4"))
            _add_sheet_button("Back to experiment menu", Callable(self, "_show_sheet").bind("menu"))
        "restart":
            _sheet_title.text = "Start this experiment again?"
            _add_sheet_copy("Your current sorting progress will be cleared. The experiment will return to its original arrangement.")
            _add_sheet_button("Restart experiment", Callable(self, "_confirm_restart"), true)
            _add_sheet_button("Keep sorting", Callable(self, "_show_sheet").bind("menu"))


func _add_sheet_heading(value: String) -> void:
    var heading := Label.new()
    heading.text = value
    heading.add_theme_font_size_override("font_size", 10)
    heading.add_theme_color_override("font_color", Color("#9fb6a8"))
    heading.custom_minimum_size = Vector2(0.0, 18.0)
    _sheet_content.add_child(heading)


func _add_sheet_copy(value: String, font_size: int = 15, font_color: Color = Color("#d3ddd3")) -> void:
    var copy := Label.new()
    copy.text = value
    copy.add_theme_font_size_override("font_size", font_size)
    copy.add_theme_color_override("font_color", font_color)
    copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    copy.custom_minimum_size = Vector2(0.0, 34.0 if font_size >= 14 else 22.0)
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _sheet_content.add_child(copy)


func _add_sheet_button(value: String, callback: Callable, primary: bool = false) -> void:
    var button := Button.new()
    button.text = value
    button.custom_minimum_size = Vector2(0.0, 54.0)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", 15)
    button.add_theme_color_override("font_color", Color("#e0e8de"))
    var base_color := Color(0.25, 0.39, 0.33, 0.78) if primary else Color(0.11, 0.20, 0.20, 0.74)
    button.add_theme_stylebox_override("normal", _flat_style(base_color, Color(0.62, 0.79, 0.68, 0.13), 17, 1))
    button.add_theme_stylebox_override("hover", _flat_style(base_color.lightened(0.16), Color(0.72, 0.88, 0.76, 0.25), 17, 1))
    button.add_theme_stylebox_override("pressed", _flat_style(base_color.lightened(0.24), Color(0.72, 0.88, 0.76, 0.30), 17, 1))
    button.pressed.connect(callback)
    _sheet_content.add_child(button)


func _make_choice_button(value: String, callback: Callable, selected: bool) -> Button:
    var button := Button.new()
    button.text = value
    button.custom_minimum_size = Vector2(0.0, 48.0)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.size_flags_stretch_ratio = 1.0
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", 13)
    button.add_theme_color_override("font_color", Color("#e1e8df"))
    var fill := Color(0.27, 0.42, 0.35, 0.82) if selected else Color(0.09, 0.17, 0.17, 0.74)
    button.add_theme_stylebox_override("normal", _flat_style(fill, Color(0.62, 0.79, 0.68, 0.16), 14, 1))
    button.add_theme_stylebox_override("hover", _flat_style(fill.lightened(0.14), Color(0.72, 0.88, 0.76, 0.26), 14, 1))
    button.add_theme_stylebox_override("pressed", _flat_style(fill.lightened(0.22), Color(0.72, 0.88, 0.76, 0.30), 14, 1))
    button.pressed.connect(callback)
    return button


func _choose_layout(layout_id: String) -> void:
    _select_layout(layout_id)
    _populate_sheet("layout")


func _choose_vial_count(vial_count: int) -> void:
    _select_vial_count(vial_count)
    _populate_sheet("layout")


func _confirm_restart() -> void:
    _close_sheet()
    _restart_level()


func _on_sheet_dimmer_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _close_sheet()
    elif event is InputEventScreenTouch and event.pressed:
        _close_sheet()


func _close_sheet() -> void:
    if not is_instance_valid(_sheet_layer):
        return
    var layer := _sheet_layer
    var panel := _sheet_panel
    var dimmer := _sheet_dimmer
    _sheet_layer = null
    _sheet_panel = null
    _sheet_dimmer = null
    _sheet_content = null
    _sheet_title = null
    _sheet_kind = ""

    var tween := create_tween().set_parallel(true)
    tween.tween_property(panel, "position:y", 1280.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    tween.tween_property(dimmer, "color:a", 0.0, 0.20)
    tween.tween_property(panel, "modulate:a", 0.82, 0.18)
    tween.chain().tween_callback(Callable(layer, "queue_free"))


func _select_layout(layout_id: String) -> void:
    if layout_id == _selected_layout or is_animating:
        return
    _selected_layout = layout_id
    _load_level()
    _set_status(String(LAYOUT_NOTES[layout_id]) + " The sorting rules stay the same.")


func _select_vial_count(vial_count: int) -> void:
    if is_animating or not VIAL_LEVELS.has(vial_count):
        return
    _selected_vial_count = vial_count
    current_track = "B"
    current_level = int(VIAL_LEVELS[vial_count])
    _load_level()
    _set_status("Showing %d playable vials." % vial_count)
