extends "res://scripts/sorting_direction_prototype.gd"

const AssetFantasyBottleScript = preload("res://scripts/asset_fantasy_alchemy_bottle.gd")
const DEBUG_BARE_POUR_STREAM := false
const TEST_VIAL_SOURCE_SIZE := Vector2(160.0, 365.0)


class SlotMarkerSurface extends Control:
	const COMPLETION_STAGGER := 0.115
	const COMPLETION_BLOOM_DURATION := 0.90

	var slot_markers: Array = []
	var _marker_geometry: Array[Dictionary] = []
	var _completion_active: bool = false
	var _completion_time: float = 0.0

	func _ready() -> void:
		set_process(false)

	func configure(markers: Array) -> void:
		slot_markers = markers.duplicate(true)
		_rebuild_marker_geometry()
		queue_redraw()

	func _rebuild_marker_geometry() -> void:
		_marker_geometry.clear()
		for marker in slot_markers:
			var centre: Vector2 = marker["centre"]
			var radius: Vector2 = marker["radius"]
			var shadow := _ellipse_points(
				centre + Vector2(0.0, 5.0),
				radius.x * 1.12,
				radius.y * 1.28,
				48
			)
			var inset := _ellipse_points(centre, radius.x, radius.y, 48)
			var inner := _ellipse_points(
				centre + Vector2(0.0, -1.0),
				radius.x * 0.82,
				radius.y * 0.72,
				48
			)

			var completion_halos: Array[PackedVector2Array] = []
			for layer in range(1, 6):
				var fraction: float = float(layer) / 5.0
				var radius_scale: float = lerpf(1.12, 1.92, fraction)
				completion_halos.append(_ellipse_points(
					centre + Vector2(0.0, 1.0),
					radius.x * radius_scale,
					radius.y * (radius_scale + 0.28),
					48
				))

			_marker_geometry.append({
				"shadow": shadow,
				"inset": inset,
				"inset_closed": _closed_points(inset),
				"inner": inner,
				"inner_closed": _closed_points(inner),
				"inner_light": _ellipse_points(
					centre,
					radius.x * 0.88,
					radius.y * 0.76,
					48
				),
				"completion_halos": completion_halos
			})

	func set_completion_state(completed: bool, bottles: Array, palette: Dictionary) -> void:
		if completed:
			_update_completion_targets(bottles, palette)

		if completed == _completion_active:
			if completed:
				queue_redraw()
			return

		_completion_active = completed
		_completion_time = 0.0
		set_process(_completion_active)
		queue_redraw()

	func _update_completion_targets(bottles: Array, palette: Dictionary) -> void:
		# Read the live vial contents after the final pour, not the level's starting layout.
		for marker_index in range(slot_markers.size()):
			var marker: Dictionary = slot_markers[marker_index]
			var has_contents := false
			var glow_color: Color = Color(0.54, 0.84, 0.72, 1.0)

			if marker_index < bottles.size():
				var vial_value: Variant = bottles[marker_index]
				if is_instance_valid(vial_value):
					var contents: Array = vial_value.call("get_contents")
					has_contents = not contents.is_empty()
					if has_contents:
						glow_color = palette.get(String(contents.back()), glow_color)

			marker["has_contents"] = has_contents
			marker["glow_color"] = glow_color
			slot_markers[marker_index] = marker

	func _process(delta: float) -> void:
		if not _completion_active:
			return
		_completion_time += delta
		queue_redraw()

	func _draw() -> void:
		for marker_index in range(slot_markers.size()):
			if marker_index >= _marker_geometry.size():
				continue
			var marker: Dictionary = slot_markers[marker_index]
			var geometry: Dictionary = _marker_geometry[marker_index]
			var scale_value: float = float(marker["scale"])
			var has_contents: bool = bool(marker.get("has_contents", false))
			var glow_color: Color = marker.get("glow_color", Color(0.54, 0.84, 0.72, 1.0))
			var glow_strength: float = _get_completion_strength(marker_index) if has_contents else 0.0

			draw_colored_polygon(geometry["shadow"], Color(0.0, 0.0, 0.0, 0.38))

			if glow_strength > 0.001:
				_draw_completion_glow(geometry["completion_halos"], glow_color, glow_strength)

			draw_colored_polygon(geometry["inset"], Color(0.012, 0.025, 0.026, 0.72))

			if glow_strength > 0.001:
				draw_colored_polygon(
					geometry["inner_light"],
					Color(glow_color.r, glow_color.g, glow_color.b, 0.060 * glow_strength)
				)

			var rim_color := Color(0.38, 0.60, 0.54, 0.25)
			if glow_strength > 0.001:
				rim_color = Color(
					lerpf(rim_color.r, glow_color.r, 0.38 * glow_strength),
					lerpf(rim_color.g, glow_color.g, 0.38 * glow_strength),
					lerpf(rim_color.b, glow_color.b, 0.38 * glow_strength),
					lerpf(rim_color.a, 0.40, glow_strength)
				)
			draw_polyline(
				geometry["inset_closed"],
				rim_color,
				maxf(1.0, 1.35 * scale_value),
				true
			)

			draw_polyline(
				geometry["inner_closed"],
				Color(0.72, 0.80, 0.69, 0.10),
				1.0,
				true
			)

	func _get_completion_strength(marker_index: int) -> float:
		if not _completion_active:
			return 0.0
		var local_time: float = _completion_time - float(marker_index) * COMPLETION_STAGGER
		if local_time <= 0.0:
			return 0.0
		var progress: float = clampf(local_time / COMPLETION_BLOOM_DURATION, 0.0, 1.0)
		var bloom: float = 1.0 - pow(1.0 - progress, 3.0)
		var breathing: float = 0.96 + 0.04 * sin(local_time * 1.15)
		return bloom * breathing

	func _draw_completion_glow(
		halos: Array,
		glow_color: Color,
		strength: float
	) -> void:
		# The five halo paths are precomputed; only their alpha animates.
		for halo_index in range(halos.size() - 1, -1, -1):
			var fraction: float = float(halo_index + 1) / 5.0
			var alpha: float = lerpf(0.032, 0.012, fraction) * strength
			draw_colored_polygon(
				halos[halo_index],
				Color(glow_color.r, glow_color.g, glow_color.b, alpha)
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



class AmbientAtmosphere extends Control:
	var _time: float = 0.0
	var _motes: Array[Dictionary] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)
		for index in range(15):
			_motes.append({
				"position": Vector2(
					randf_range(55.0, 665.0),
					randf_range(300.0, 1080.0)
				),
				"speed": randf_range(3.5, 10.0),
				"size": randf_range(0.7, 1.6),
				"phase": randf_range(0.0, TAU)
			})

	func _process(delta: float) -> void:
		_time += delta
		for index in range(_motes.size()):
			var mote: Dictionary = _motes[index]
			var position_value: Vector2 = mote["position"]
			position_value.y -= float(mote["speed"]) * delta
			position_value.x += sin(_time * 0.34 + float(mote["phase"])) * delta * 2.0
			if position_value.y < 280.0:
				position_value.y = randf_range(940.0, 1090.0)
				position_value.x = randf_range(55.0, 665.0)
			mote["position"] = position_value
			_motes[index] = mote
		queue_redraw()

	func _draw() -> void:
		for mote in _motes:
			var position_value: Vector2 = mote["position"]
			var pulse := 0.5 + 0.5 * sin(_time * 1.25 + float(mote["phase"]))
			var radius: float = float(mote["size"])
			var alpha: float = 0.035 + pulse * 0.045
			draw_circle(position_value, radius * 2.8, Color(0.44, 0.78, 0.68, alpha * 0.16))
			draw_circle(position_value, radius, Color(0.75, 0.91, 0.78, alpha))

		_draw_candle(Vector2(144.0, 1228.0), 0.0)
		_draw_candle(Vector2(576.0, 1228.0), 1.8)

	func _draw_candle(base: Vector2, phase_offset: float) -> void:
		var flicker: float = sin(_time * 8.4 + phase_offset) * 1.7 + sin(_time * 13.1 + phase_offset) * 0.8
		var flame_center := Vector2(base.x + flicker * 0.34, base.y - 72.0)
		draw_circle(flame_center, 27.0, Color(1.0, 0.58, 0.25, 0.018))
		draw_circle(flame_center, 15.0, Color(1.0, 0.69, 0.35, 0.035))

		draw_rect(
			Rect2(base.x - 8.0, base.y - 54.0, 16.0, 52.0),
			Color("#cbbd91")
		)
		draw_rect(
			Rect2(base.x - 5.5, base.y - 51.0, 3.0, 44.0),
			Color(1.0, 0.96, 0.80, 0.24)
		)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(base.x - 8.0, base.y - 54.0),
				Vector2(base.x - 5.0, base.y - 59.0),
				Vector2(base.x + 1.0, base.y - 55.0),
				Vector2(base.x + 8.0, base.y - 58.0),
				Vector2(base.x + 8.0, base.y - 51.0),
				Vector2(base.x - 8.0, base.y - 51.0)
			]),
			Color("#e0d1a7")
		)
		draw_line(
			Vector2(base.x, base.y - 55.0),
			Vector2(base.x + 0.5, base.y - 65.0),
			Color("#40352a"),
			1.3,
			true
		)

		draw_colored_polygon(
			PackedVector2Array([
				flame_center + Vector2(0.0, -14.0 - flicker * 0.25),
				flame_center + Vector2(7.0, -2.0),
				flame_center + Vector2(5.0, 8.0),
				flame_center + Vector2(-4.0, 9.0),
				flame_center + Vector2(-8.0, 0.0)
			]),
			Color(1.0, 0.54, 0.19, 0.86)
		)
		draw_colored_polygon(
			PackedVector2Array([
				flame_center + Vector2(0.0, -7.0),
				flame_center + Vector2(3.0, 1.0),
				flame_center + Vector2(1.5, 6.0),
				flame_center + Vector2(-2.0, 5.0),
				flame_center + Vector2(-3.0, 0.0)
			]),
			Color(1.0, 0.87, 0.56, 0.94)
		)

		draw_colored_polygon(
			PackedVector2Array([
				Vector2(base.x - 15.0, base.y - 2.0),
				Vector2(base.x - 12.0, base.y - 8.0),
				Vector2(base.x + 12.0, base.y - 8.0),
				Vector2(base.x + 15.0, base.y - 2.0),
				Vector2(base.x + 11.0, base.y + 2.0),
				Vector2(base.x - 11.0, base.y + 2.0)
			]),
			Color(0.38, 0.29, 0.18, 0.82)
		)
		draw_line(
			Vector2(base.x - 10.0, base.y - 5.0),
			Vector2(base.x + 10.0, base.y - 5.0),
			Color(0.85, 0.69, 0.43, 0.60),
			1.1,
			true
		)


class MouthEssenceMotes extends Control:
	const MAX_MOTES_PER_VIAL := 3

	var _bottles: Array = []
	var _palette: Dictionary = {}
	var _emit_timers: Array[float] = []
	var _particles: Array[Dictionary] = []
	var _time: float = 0.0

	func configure(bottles: Array, palette: Dictionary) -> void:
		_bottles = bottles.duplicate()
		_palette = palette.duplicate()
		_emit_timers.clear()
		_particles.clear()
		for _index in range(_bottles.size()):
			_emit_timers.append(randf_range(0.18, 1.1))
		queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(delta: float) -> void:
		_time += delta
		_update_particles(delta)

		for vial_index in range(_bottles.size()):
			var vial_value: Variant = _bottles[vial_index]
			if not is_instance_valid(vial_value):
				continue
			var vial := vial_value as Control
			# Vials raised for dragging or pouring do not emit ambient motes.
			if vial.z_index != 2:
				continue

			var contents: Array = vial.call("get_contents")
			if contents.is_empty():
				continue

			_emit_timers[vial_index] = float(_emit_timers[vial_index]) - delta
			if float(_emit_timers[vial_index]) <= 0.0:
				if _count_vial_particles(vial_index) < MAX_MOTES_PER_VIAL:
					_spawn_mote(vial_index, vial, String(contents.back()))
				_emit_timers[vial_index] = randf_range(0.95, 1.65)

		if not _particles.is_empty():
			queue_redraw()

	func _update_particles(delta: float) -> void:
		for particle_index in range(_particles.size() - 1, -1, -1):
			var particle: Dictionary = _particles[particle_index]
			var life: float = maxf(0.0, float(particle["life"]) - delta)
			var position_value: Vector2 = particle["position"]
			var velocity: Vector2 = particle["velocity"]
			position_value += velocity * delta
			position_value.x += sin(
				_time * float(particle["sway_speed"]) + float(particle["phase"])
			) * 3.2 * delta
			particle["position"] = position_value
			particle["life"] = life

			if life <= 0.0:
				_particles.remove_at(particle_index)
			else:
				_particles[particle_index] = particle

	func _count_vial_particles(vial_index: int) -> int:
		var count := 0
		for particle in _particles:
			if int(particle["vial_index"]) == vial_index:
				count += 1
		return count

	func _spawn_mote(vial_index: int, vial: Control, essence: String) -> void:
		var pose: Vector2 = vial.call("get_pose")
		var mouth: Vector2 = vial.call("get_mouth_position_in_parent", pose)
		var lifetime := randf_range(0.95, 1.4)
		var essence_color: Color = _palette.get(
			essence,
			Color(0.45, 0.78, 0.75, 1.0)
		)
		var mote_color: Color = essence_color.lerp(Color(0.88, 1.0, 0.96, 1.0), 0.32)

		_particles.append({
			"vial_index": vial_index,
			"position": mouth + Vector2(randf_range(-5.0, 5.0), -3.0),
			"velocity": Vector2(randf_range(-6.0, 6.0), -randf_range(13.0, 22.0)),
			"life": lifetime,
			"lifetime": lifetime,
			"radius": randf_range(0.8, 1.45),
			"phase": randf_range(0.0, TAU),
			"sway_speed": randf_range(1.0, 2.0),
			"color": mote_color
		})

		queue_redraw()

	func _draw() -> void:
		for particle in _particles:
			var life: float = float(particle["life"])
			var lifetime: float = maxf(0.001, float(particle["lifetime"]))
			var age_ratio: float = 1.0 - life / lifetime
			var fade: float = sin(PI * clampf(age_ratio, 0.0, 1.0))
			if fade <= 0.005:
				continue

			var position_value: Vector2 = particle["position"]
			var radius: float = float(particle["radius"])
			var mote_color: Color = particle["color"]
			var halo_color := Color(
				mote_color.r,
				mote_color.g,
				mote_color.b,
				0.12 * fade
			)
			var core_color := Color(
				mote_color.r,
				mote_color.g,
				mote_color.b,
				0.42 * fade
			)
			draw_circle(position_value, radius * 3.0, halo_color)
			draw_circle(position_value, radius, core_color)
			draw_circle(
				position_value + Vector2(-radius * 0.25, -radius * 0.30),
				maxf(0.45, radius * 0.28),
				Color(1.0, 1.0, 0.94, 0.52 * fade)
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
var _undo_action_active: bool = false
var _pipette_action_active: bool = false
var _transmute_action_active: bool = false
var _continue_action_active: bool = false
var _drag_pointer := Vector2.ZERO
var _last_drag_pointer := Vector2.ZERO
var _drag_start_pointer := Vector2.ZERO
var _drag_pointer_velocity := Vector2.ZERO
var _drag_follow_velocity := Vector2.ZERO
var _drag_target_position := Vector2.ZERO
var _drag_hover_index: int = -1
var _drag_swing_time: float = 0.0

var _pour_source: int = -1
var _pour_target: int = -1
var _pour_source_preview: Array = []
var _pour_target_preview: Array = []
var _pour_source_start: float = 0.0
var _pour_target_start: float = 0.0
var _pour_amount: int = 0
var _pour_progress: float = 0.0
var _pour_color: Color = Color.WHITE
var _pour_stream_active: bool = false

var _stream_glow: Polygon2D
var _stream_shape: Polygon2D
var _stream_highlight: Line2D
var _stream_glint: Line2D
var _stream_drops: Array[Polygon2D] = []
var _splash_ring: Line2D
var _mouth_mote_layer: MouthEssenceMotes


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

	undo_button.visible = false
	pipette_button.visible = false
	transmute_button.visible = false
	next_level_action_button.visible = false
	undo_button.modulate.a = 0.0
	pipette_button.modulate.a = 0.0
	transmute_button.modulate.a = 0.0
	next_level_action_button.modulate.a = 0.0

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

	var atmosphere := AmbientAtmosphere.new()
	atmosphere.name = "CandlelightAndMotes"
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere.z_index = 16
	add_child(atmosphere)

	_build_stream_layers()

	_mouth_mote_layer = MouthEssenceMotes.new()
	_mouth_mote_layer.name = "MouthEssenceMotes"
	_mouth_mote_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mouth_mote_layer.z_index = 13
	add_child(_mouth_mote_layer)
	set_process(true)


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
				var scale_value: float = 1.0 if count == 4 else (0.75 if count == 5 else 0.66)
				_place_vial_row(0, count, scale_value, 856.0, markers, 0.0, 48.0)
			else:
				_place_vial_row(0, 4, 0.80, 600.0, markers, 0.0, 22.0)
				_place_vial_row(4, 4, 0.80, 910.0, markers, 0.0, 22.0)
		"rows":
			_place_two_rows(count, markers, false)
		_:
			if count <= 6:
				var scale_value: float = 1.0 if count == 4 else (0.75 if count == 5 else 0.66)
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
	var size_value: Vector2 = TEST_VIAL_SOURCE_SIZE * scale_value
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
	var vial: Control = AssetFantasyBottleScript.new()
	vial.name = "SortingVial%02d" % (index + 1)
	vial.position = position_value
	vial.size = size_value
	vial.z_index = 2
	vial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vial_contents: Array = bottle_contents[index]
	vial.call(
		"setup",
		index,
		"%02d" % (index + 1),
		index % 4,
		PALETTE,
		vial_contents
	)
	add_child(vial)
	bottle_nodes.append(vial)
	slot_positions.append(position_value)

	var foot := Vector2(
		position_value.x + size_value.x * 0.5,
		position_value.y + _vial_base_offset(size_value)
	)
	var slot_glow_color: Color = Color(0.54, 0.84, 0.72, 1.0)
	if not vial_contents.is_empty():
		slot_glow_color = PALETTE.get(String(vial_contents.back()), slot_glow_color)
	markers.append({
		"centre": foot,
		"radius": Vector2(size_value.x * 0.47, size_value.x * 0.125),
		"scale": size_value.x / TEST_VIAL_SOURCE_SIZE.x,
		"has_contents": not vial_contents.is_empty(),
		"glow_color": slot_glow_color
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
	return size_value.y * 0.953


func _refresh_hud() -> void:
	super._refresh_hud()
	if not is_instance_valid(level_label) or not is_instance_valid(_experiment_title):
		return

	if is_instance_valid(_slot_surface):
		_slot_surface.set_completion_state(round_complete, bottle_nodes, PALETTE)

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

	var special := String(level_data.get("special", "classic"))
	var show_undo := not round_complete
	var show_pipette := not round_complete and (special == "pipette" or special == "master")
	var show_transmute := not round_complete and (special == "transmute" or special == "master")
	var show_continue := round_complete

	_transition_action_visibility(undo_button, show_undo, _undo_action_active)
	_transition_action_visibility(pipette_button, show_pipette, _pipette_action_active)
	_transition_action_visibility(transmute_button, show_transmute, _transmute_action_active)
	_transition_action_visibility(next_level_action_button, show_continue, _continue_action_active)

	_undo_action_active = show_undo
	_pipette_action_active = show_pipette
	_transmute_action_active = show_transmute
	_continue_action_active = show_continue

	undo_button.disabled = move_history.is_empty() or is_animating
	undo_button.configure("undo", "Undo")
	pipette_button.disabled = precision_used or is_animating
	pipette_button.configure("pipette", "Used" if precision_used else ("Armed" if precision_armed else "Pipette"))
	transmute_button.disabled = transmute_used or is_animating
	transmute_button.configure("transmute", "Done" if transmute_used else "Transmute")
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

	if _continue_action_active:
		_animate_action_position(next_level_action_button, Vector2(236.0, 1128.0), Vector2(248.0, 78.0))
		return

	var actions: Array = []
	if _undo_action_active:
		actions.append(undo_button)
	if _pipette_action_active:
		actions.append(pipette_button)
	if _transmute_action_active:
		actions.append(transmute_button)

	var button_width := 88.0
	var button_height := 78.0
	var separation := 22.0
	var total_width := float(actions.size()) * button_width + float(maxi(0, actions.size() - 1)) * separation
	var start_x := (720.0 - total_width) * 0.5

	for index in range(actions.size()):
		var action: SoftIconButton = actions[index]
		var target := Vector2(start_x + float(index) * (button_width + separation), 1128.0)
		_animate_action_position(action, target, Vector2(button_width, button_height))


func _transition_action_visibility(button: SoftIconButton, should_show: bool, was_showing: bool) -> void:
	if should_show:
		button.visible = true
		if not was_showing:
			button.modulate.a = 0.0
			button.position.y = 1146.0
			var reveal := create_tween().set_parallel(true)
			reveal.tween_property(button, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			reveal.tween_property(button, "position:y", 1128.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			button.modulate.a = 1.0
	elif was_showing:
		button.visible = true
		var conceal := create_tween().set_parallel(true)
		conceal.tween_property(button, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		conceal.tween_property(button, "position:y", 1144.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		conceal.chain().tween_callback(Callable(button, "hide"))
	else:
		button.visible = false
		button.modulate.a = 0.0


func _animate_action_position(button: SoftIconButton, target: Vector2, target_size: Vector2) -> void:
	button.size = target_size
	if button.visible and button.modulate.a <= 0.95:
		# Keep the reveal tween's vertical travel while placing the control in
		# the correct horizontal group immediately.
		button.position.x = target.x
		return
	if button.visible and button.position.distance_to(target) > 1.0:
		var tween := create_tween()
		tween.tween_property(button, "position", target, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		button.position = target


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


func _gui_input(event: InputEvent) -> void:
	if is_animating or round_complete:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_finish_drag(event.position)
		accept_event()
	elif event is InputEventScreenDrag:
		_update_drag(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_finish_drag(event.position)
		accept_event()
	elif event is InputEventMouseMotion and selected_vial >= 0 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_update_drag(event.position)
		accept_event()


# The inherited global input handler is intentionally bypassed. The proven
# main interaction scene handles the complete pointer lifecycle in _gui_input.
func _input(_event: InputEvent) -> void:
	pass


func _begin_drag(pointer: Vector2) -> void:
	if selected_vial >= 0 or is_animating or round_complete:
		return

	for index in range(bottle_nodes.size()):
		var vial: Control = bottle_nodes[index]
		if not Rect2(vial.position, vial.size).has_point(pointer):
			continue

		if bottle_contents[index].is_empty():
			_set_status("That vial is empty. Choose one containing an essence.")
			return
		if current_track == "A" and level_data.get("special", "") == "recipe" and index == int(level_data["recipe_target"]):
			_set_status("The formula flask is the receiver. Choose an ingredient vial.")
			return

		if tool_selected_vial >= 0 and tool_selected_vial < bottle_nodes.size():
			bottle_nodes[tool_selected_vial].call("set_feedback", false, false, false)

		tool_selected_vial = -1
		selected_vial = index
		is_dragging = true
		drag_origin = slot_positions[index]
		grab_offset = pointer - vial.position
		_drag_pointer = pointer
		_last_drag_pointer = pointer
		_drag_start_pointer = pointer
		_drag_pointer_velocity = Vector2.ZERO
		_drag_follow_velocity = Vector2.ZERO
		_drag_target_position = vial.position
		_drag_hover_index = -1
		_drag_swing_time = 0.0

		vial.z_index = 50
		vial.call("set_feedback", true, false, true)
		vial.call("set_drag_motion", false)
		# Begin upright; horizontal movement will build the tilt gradually.
		vial.call("set_pose", Vector2(18.0, 0.0))
		vial.call("set_draw_scale", 1.035)

		_set_status("Vial lifted. Guide its open mouth to a receiving vessel.")
		return


func _update_drag(pointer: Vector2) -> void:
	if selected_vial < 0 or not is_dragging or is_animating:
		return

	_drag_pointer_velocity = (pointer - _last_drag_pointer) * 60.0
	var pointer_delta: Vector2 = pointer - _last_drag_pointer
	_last_drag_pointer = pointer
	_drag_pointer = pointer

	var source: Control = bottle_nodes[selected_vial]
	source.call("set_drag_motion", pointer_delta.length() > 0.65)

	# Tilt follows horizontal pointer travel continuously, avoiding a sudden
	# left/right flip when the pointer crosses the vial's original centre.
	var tilt_angle: float = _get_drag_tilt_angle(pointer.x)
	source.call("set_pose", Vector2(18.0, tilt_angle))

	var pose: Vector2 = source.call("get_pose")
	_drag_target_position = pointer - source.call("get_drag_anchor_local", grab_offset, pose)
	_refresh_drag_target()


func _process(delta: float) -> void:
	if selected_vial >= 0 and is_dragging and not is_animating:
		var source: Control = bottle_nodes[selected_vial]
		_drag_swing_time += delta
		var tilt_angle: float = _get_drag_tilt_angle(_drag_pointer.x)
		var inertial_tilt: float = clampf(_drag_pointer_velocity.x / 2400.0, -0.035, 0.035)
		inertial_tilt += sin(_drag_swing_time * 3.6) * 0.006
		var gentle_bob: float = sin(_drag_swing_time * 2.1) * 0.6
		source.call("set_pose", Vector2(18.0 + gentle_bob, tilt_angle + inertial_tilt))
		source.call("set_drag_motion", _drag_pointer_velocity.length() > 20.0)

		var pose: Vector2 = source.call("get_pose")
		_drag_target_position = _drag_pointer - source.call("get_drag_anchor_local", grab_offset, pose)

		# Spring-follow the finger rather than pinning the vessel rigidly to it.
		var acceleration: Vector2 = (_drag_target_position - source.position) * 132.0 - _drag_follow_velocity * 22.5
		_drag_follow_velocity += acceleration * delta
		source.position += _drag_follow_velocity * delta
		_refresh_drag_target()

		_drag_pointer_velocity = _drag_pointer_velocity.move_toward(Vector2.ZERO, delta * 210.0)

	if _pour_stream_active:
		_update_stream()


func _refresh_drag_target() -> void:
	if selected_vial < 0:
		return
	var source: Control = bottle_nodes[selected_vial]
	var source_mouth: Vector2 = _drag_target_position + source.call("get_mouth_local_for_pose", source.call("get_pose"))
	var target_index := _find_target_for_mouth(selected_vial, source_mouth)

	if target_index == _drag_hover_index:
		return
	if _drag_hover_index >= 0 and _drag_hover_index < bottle_nodes.size():
		bottle_nodes[_drag_hover_index].call("set_feedback", false, false, false)

	_drag_hover_index = target_index
	if target_index >= 0:
		bottle_nodes[target_index].call("set_feedback", false, true, false)
		_set_status("Openings aligned. Release to transfer the top essence.")
	else:
		_set_status("Guide the source opening onto an empty or matching vial.")


func _get_drag_tilt_angle(pointer_x: float) -> float:
	# Base the lean on movement since pickup, not pointer position relative to
	# the vial centre. A small dead-simple linear response keeps vertical drags
	# upright and makes left/right changes pass smoothly through zero.
	var horizontal_travel: float = pointer_x - _drag_start_pointer.x
	var normalized_travel: float = clampf(horizontal_travel / 110.0, -1.0, 1.0)
	return deg_to_rad(38.0) * normalized_travel


func _find_target_for_mouth(source_index: int, source_mouth: Vector2) -> int:
	var source: Control = bottle_nodes[source_index]
	var source_radius: Vector2 = source.call("get_mouth_hit_radius")

	var best_target: int = -1
	var best_distance: float = INF
	for index in range(bottle_nodes.size()):
		if index == source_index or not _can_pour(source_index, index):
			continue

		var target: Control = bottle_nodes[index]
		var target_mouth: Vector2 = target.call("get_mouth_position_in_parent")
		var target_radius: Vector2 = target.call("get_mouth_hit_radius")
		# Treat the mouths as two real openings: their hit regions should meet
		# when the rims approach, without requiring the bodies to overlap.
		var tolerance := Vector2(
			maxf(24.0, (source_radius.x + target_radius.x) * 0.84),
			maxf(22.0, (source_radius.y + target_radius.y) * 0.84)
		)
		var delta: Vector2 = source_mouth - target_mouth
		var normalized_distance: float = pow(delta.x / tolerance.x, 2.0) + pow(delta.y / tolerance.y, 2.0)
		if normalized_distance <= 1.0 and normalized_distance < best_distance:
			best_distance = normalized_distance
			best_target = index

	return best_target


func _finish_drag(pointer: Vector2) -> void:
	if selected_vial < 0 or not is_dragging:
		return

	_update_drag(pointer)
	var source_index: int = selected_vial
	var source: Control = bottle_nodes[source_index]
	var pose: Vector2 = source.call("get_pose")
	source.position = pointer - source.call("get_drag_anchor_local", grab_offset, pose)
	_drag_follow_velocity = Vector2.ZERO

	var source_mouth: Vector2 = source.position + source.call("get_mouth_local_for_pose", pose)
	var target_index := _find_target_for_mouth(source_index, source_mouth)
	if target_index >= 0 and _can_pour(source_index, target_index):
		_perform_pour(source_index, target_index)
		return

	if Rect2(drag_origin, source.size).has_point(pointer):
		tool_selected_vial = source_index
		_return_dragged_vial(
			source_index,
			"Vial selected. Use the available alchemy tool.",
			true
		)
	else:
		tool_selected_vial = -1
		_return_dragged_vial(
			source_index,
			"No receiving opening aligned. Try guiding the vial mouth to a target.",
			false
		)


func _return_dragged_vial(source_index: int, message: String, keep_tool_selection: bool) -> void:
	is_animating = true
	is_dragging = false
	selected_vial = -1

	var source: Control = bottle_nodes[source_index]
	if _drag_hover_index >= 0 and _drag_hover_index < bottle_nodes.size():
		bottle_nodes[_drag_hover_index].call("set_feedback", false, false, false)
	_drag_hover_index = -1
	source.call("set_drag_motion", false)

	var return_tween := create_tween().set_parallel(true)
	return_tween.tween_property(source, "position", slot_positions[source_index], 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return_tween.tween_method(Callable(source, "set_pose"), source.call("get_pose"), Vector2.ZERO, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return_tween.tween_method(Callable(source, "set_draw_scale"), source.call("get_draw_scale"), 1.0, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await return_tween.finished

	source.z_index = 2
	source.call("reset_motion")
	source.call("set_feedback", keep_tool_selection, false, false)
	_drag_swing_time = 0.0
	is_animating = false
	_refresh_hud()
	_set_status(message)


func _perform_pour(source_index: int, target_index: int) -> void:
	var details: Dictionary = _get_transfer_details(source_index, target_index)
	if details.is_empty():
		tool_selected_vial = -1
		_return_dragged_vial(source_index, "That vial cannot receive this essence.", false)
		return

	is_animating = true
	_save_history()
	is_dragging = false
	selected_vial = -1
	_drag_hover_index = -1

	_pour_source = source_index
	_pour_target = target_index
	_pour_amount = int(details["amount"])
	_pour_progress = 0.0
	_pour_source_preview = bottle_contents[source_index].duplicate()
	_pour_target_preview = bottle_contents[target_index].duplicate()

	if _pour_amount <= 0:
		_pour_source = -1
		_pour_target = -1
		_return_dragged_vial(source_index, "No transferable essence was found.", false)
		return

	var essence: String = String(_pour_source_preview.back())
	_pour_color = PALETTE.get(essence, Color.WHITE)
	for _layer_index in range(_pour_amount):
		_pour_target_preview.append(essence)

	_pour_source_start = float(_pour_source_preview.size())
	_pour_target_start = float(bottle_contents[target_index].size())

	var source: Control = bottle_nodes[source_index]
	var target: Control = bottle_nodes[target_index]
	var direction: float = signf(target.position.x + target.size.x * 0.5 - drag_origin.x - source.size.x * 0.5)
	if is_zero_approx(direction):
		direction = 1.0

	var pour_pose := Vector2(24.0, deg_to_rad(95.0) * direction)
	const POUR_DRAW_SCALE := 0.82
	var target_mouth: Vector2 = target.call("get_mouth_position_in_parent")
	# Keep the two rims visibly separated: the source mouth sits slightly
	# above and to the outside of the receiver instead of directly overlapping it.
	var desired_source_mouth: Vector2 = target_mouth + Vector2(-direction * 14.0, -14.0)
	var staging_position: Vector2 = desired_source_mouth - source.call("get_mouth_local_for_pose", pour_pose, POUR_DRAW_SCALE)
	var target_original_z: int = target.z_index
	# Diagnostic: restore only the receiver z-order change; keep overlays and FX off.
	target.z_index = 7
	target.call("set_front_mouth_lip_active", true)

	source.call("set_drag_motion", false)
	source.call("set_feedback", false, false, false)
	target.call("set_preview", _pour_target_preview, _pour_target_start)
	source.call("set_preview", _pour_source_preview, _pour_source_start)
	target.call("set_feedback", false, true, false)

	_set_status("Aligning the glass spouts...")
	var approach := create_tween().set_parallel(true)
	approach.tween_property(source, "position", staging_position, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	approach.tween_method(Callable(source, "set_pose"), source.call("get_pose"), pour_pose, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	approach.tween_method(Callable(source, "set_draw_scale"), source.call("get_draw_scale"), POUR_DRAW_SCALE, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await approach.finished

	source.call("trigger_slosh", 0.24)
	target.call("trigger_slosh", 0.12)
	if source.has_method("set_pour_outflow_active"):
		source.call("set_pour_outflow_active", true, _pour_color)
	_set_status("Pouring %s essence..." % essence.capitalize())

	# Hide the receiver's far-base refraction while moving liquid is visible.
	target.call("set_pour_refraction_visible", false)
	_pour_stream_active = true
	_stream_shape.color = Color(_pour_color.r, _pour_color.g, _pour_color.b, 1.0)
	_stream_shape.visible = true
	_stream_glow.visible = true
	_stream_highlight.visible = true
	_stream_glint.visible = true
	_update_stream()
	for drop in _stream_drops:
		drop.visible = true
	_splash_ring.visible = true

	var pour_tween := create_tween()
	pour_tween.tween_method(Callable(self, "_set_pour_progress"), 0.0, 1.0, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await pour_tween.finished

	_pour_stream_active = false
	if source.has_method("set_pour_outflow_active"):
		source.call("set_pour_outflow_active", false)
	# Restore the optical reflection after the incoming stream has stopped.
	target.call("set_pour_refraction_visible", true)
	target.call("set_front_mouth_lip_active", false)
	target.z_index = target_original_z
	_stream_shape.visible = false
	_stream_glow.visible = false
	_stream_highlight.visible = false
	_stream_glint.visible = false
	for drop in _stream_drops:
		drop.visible = false
	_splash_ring.visible = false

	var return_tween := create_tween().set_parallel(true)
	return_tween.tween_property(source, "position", slot_positions[source_index], 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_method(Callable(source, "set_pose"), pour_pose, Vector2.ZERO, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_method(Callable(source, "set_draw_scale"), POUR_DRAW_SCALE, 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await return_tween.finished

	var next_source: Array = bottle_contents[source_index].duplicate()
	var next_target: Array = bottle_contents[target_index].duplicate()
	for _layer_index in range(_pour_amount):
		next_source.pop_back()
		next_target.append(essence)
	bottle_contents[source_index] = next_source
	bottle_contents[target_index] = next_target

	source.call("set_contents", next_source)
	target.call("set_contents", next_target)
	source.call("reset_motion")
	target.call("trigger_slosh", 0.22)
	source.z_index = 2
	target.call("set_feedback", false, false, false)

	if bool(details["pipette"]):
		precision_used = true
		precision_armed = false
	if bool(details["recipe"]):
		recipe_progress += 1

	move_count += 1
	if current_track == "A" and level_data.get("special", "") == "seal" and not seal_unlocked:
		_check_seal_unlock()

	round_complete = _is_puzzle_solved()
	tool_selected_vial = -1
	_pour_source = -1
	_pour_target = -1
	_pour_progress = 0.0
	is_animating = false

	if round_complete:
		_set_status("The essences settle into balance. Experiment complete.")
	else:
		_set_status("Transfer complete. Watch the surface settle.")
	_refresh_hud()


func _set_pour_progress(progress: float) -> void:
	_pour_progress = progress
	var source_level: float = lerpf(_pour_source_start, _pour_source_start - float(_pour_amount), progress)
	var target_level: float = lerpf(_pour_target_start, _pour_target_start + float(_pour_amount), progress)
	bottle_nodes[_pour_source].call("set_preview", _pour_source_preview, source_level)
	bottle_nodes[_pour_target].call("set_preview", _pour_target_preview, target_level)
	_update_stream()


func _build_stream_layers() -> void:
	# Diagnostic mode deliberately creates only one rendering layer.
	# The former glow, highlights, droplets and ripple are omitted completely.
	_stream_shape = Polygon2D.new()
	_stream_shape.name = "BarePourStream"
	_stream_shape.color = Color.WHITE
	_stream_shape.z_index = 9
	_stream_shape.visible = false
	add_child(_stream_shape)

	# Keep the glow available as the only optional FX layer in bare-stream tests.
	_stream_glow = Polygon2D.new()
	_stream_glow.color = Color.WHITE
	_stream_glow.z_index = 8
	_stream_glow.visible = false
	add_child(_stream_glow)

	# Keep the thin highlight available as the next isolated FX layer.
	_stream_highlight = Line2D.new()
	_stream_highlight.width = 1.2
	_stream_highlight.antialiased = true
	_stream_highlight.default_color = Color(1.0, 1.0, 1.0, 0.62)
	_stream_highlight.z_index = 10
	_stream_highlight.visible = false
	add_child(_stream_highlight)

	# Keep the moving glint available for isolated testing.
	_stream_glint = Line2D.new()
	_stream_glint.width = 1.0
	_stream_glint.antialiased = true
	_stream_glint.default_color = Color(1.0, 1.0, 1.0, 0.88)
	_stream_glint.z_index = 11
	_stream_glint.visible = false
	add_child(_stream_glint)

	# Create droplets before the diagnostic early return so they can be tested alone.
	for index in range(3):
		var drop := Polygon2D.new()
		drop.polygon = PackedVector2Array([
			Vector2(0.0, -4.5),
			Vector2(2.5, -0.5),
			Vector2(2.0, 3.0),
			Vector2(0.0, 4.2),
			Vector2(-2.0, 3.0),
			Vector2(-2.5, -0.5)
		])
		drop.color = Color(1.0, 1.0, 1.0, 0.82)
		drop.z_index = 11
		drop.visible = false
		add_child(drop)
		_stream_drops.append(drop)

	# Keep the splash ring available for the final isolated FX test.
	_splash_ring = Line2D.new()
	_splash_ring.width = 1.8
	_splash_ring.antialiased = true
	_splash_ring.default_color = Color(1.0, 1.0, 1.0, 0.40)
	_splash_ring.z_index = 12
	_splash_ring.visible = false
	add_child(_splash_ring)

	if DEBUG_BARE_POUR_STREAM:
		return


func _get_pour_stream_start(source: Control) -> Vector2:
	if source.has_method("get_pour_outlet_position_in_parent"):
		return source.call("get_pour_outlet_position_in_parent")
	return source.call("get_mouth_position_in_parent", source.call("get_pose")) + Vector2(0.0, -4.0)


func _update_stream() -> void:
	if not _pour_stream_active or _pour_source < 0 or _pour_target < 0:
		return
	if DEBUG_BARE_POUR_STREAM:
		_update_bare_stream()
		return

	var source: Control = bottle_nodes[_pour_source]
	var target: Control = bottle_nodes[_pour_target]
	# The stream begins just above the source lip. Its z-order is behind
	# both vials, so the oblique mouth rims naturally occlude its ends.
	var start: Vector2 = _get_pour_stream_start(source)
	var finish: Vector2 = target.call("get_liquid_surface_position_in_parent")
	var span: Vector2 = finish - start
	if span.length() < 1.0:
		return

	var horizontal_bend: float = clampf(span.x * 0.18, -42.0, 42.0)
	var vertical_fall: float = maxf(28.0, span.y * 0.36)
	var control_one := start + Vector2(horizontal_bend, vertical_fall * 0.28)
	var control_two := finish - Vector2(horizontal_bend, -vertical_fall * 0.28)

	var centres := PackedVector2Array()
	var left_glow := PackedVector2Array()
	var right_glow := PackedVector2Array()
	var left_edge := PackedVector2Array()
	var right_edge := PackedVector2Array()

	var estimated_curve_length: float = (
		start.distance_to(control_one)
		+ control_one.distance_to(control_two)
		+ control_two.distance_to(finish)
	)
	var point_count: int = clampi(ceili(estimated_curve_length / 7.0) + 1, 27, 112)

	for index in range(point_count):
		var t: float = float(index) / float(point_count - 1)
		var point: Vector2 = _get_stream_centre_point(start, control_one, control_two, finish, t)
		var tangent: Vector2 = _get_stream_tangent(control_one, start, control_two, finish, t)
		var normal := Vector2(-tangent.y, tangent.x)
		centres.append(point)
		var pulse_width: float = sin(PI * t)
		var irregularity: float = 0.94 + 0.06 * sin(t * 19.0)
		var half_width: float = (0.85 + pulse_width * 3.0) * 1.28 * irregularity
		left_edge.append(point + normal * half_width)
		right_edge.append(point - normal * half_width)
		left_glow.append(point + normal * half_width * 3.1)
		right_glow.append(point - normal * half_width * 3.1)

	var stream_polygon := PackedVector2Array()
	for point in left_edge:
		stream_polygon.append(point)
	for index in range(right_edge.size() - 1, -1, -1):
		stream_polygon.append(right_edge[index])

	var glow_polygon := PackedVector2Array()
	for point in left_glow:
		glow_polygon.append(point)
	for index in range(right_glow.size() - 1, -1, -1):
		glow_polygon.append(right_glow[index])

	_stream_glow.polygon = glow_polygon
	_stream_glow.color = Color(_pour_color.r, _pour_color.g, _pour_color.b, 0.16 + 0.12 * sin(PI * _pour_progress))
	_stream_shape.polygon = stream_polygon
	_stream_shape.color = Color(_pour_color.r, _pour_color.g, _pour_color.b, 0.94)
	_stream_highlight.points = centres
	_stream_highlight.default_color = Color(1.0, 1.0, 1.0, 0.25 + 0.12 * sin(PI * _pour_progress))
	var glint_progress: float = clampf(_pour_progress, 0.0, 1.0)
	var glint_start: float = lerpf(0.08, 0.76, glint_progress)
	var glint_end: float = minf(0.98, glint_start + 0.16)
	var glint_points := PackedVector2Array()
	const GLINT_SAMPLES := 9
	for index in range(GLINT_SAMPLES):
		var glint_t: float = lerpf(glint_start, glint_end, float(index) / float(GLINT_SAMPLES - 1))
		glint_points.append(_get_stream_centre_point(start, control_one, control_two, finish, glint_t))
	_stream_glint.points = glint_points
	_stream_glint.default_color = Color(1.0, 1.0, 1.0, 0.52 * sin(PI * glint_progress))

	for index in range(_stream_drops.size()):
		var travel: float = clampf(_pour_progress * 1.5 - float(index) * 0.25, 0.0, 1.0)
		var drop_position: Vector2 = start.bezier_interpolate(control_one, control_two, finish, travel)
		var drop: Polygon2D = _stream_drops[index]
		drop.position = drop_position
		drop.rotation = atan2(span.y, span.x) + PI * 0.5
		drop.scale = Vector2(0.75 + 0.25 * sin(PI * travel), 0.90 + 0.4 * sin(PI * travel))
		drop.color = Color(1.0, 1.0, 1.0, 0.46 * sin(PI * travel))

	var ring_radius: float = 4.5 + 13.0 * _pour_progress
	var ring_alpha: float = 0.16 * sin(PI * _pour_progress)
	var ring_points := PackedVector2Array()
	for index in range(25):
		var angle: float = TAU * float(index) / 24.0
		ring_points.append(finish + Vector2(cos(angle) * ring_radius, sin(angle) * ring_radius * 0.42))
	_splash_ring.points = ring_points
	_splash_ring.default_color = Color(1.0, 1.0, 1.0, ring_alpha)


func _update_bare_stream() -> void:
	# Rebuild only the bare ribbon from the current spout and receiver surface.
	# No glows, highlights, droplets, ripples, opacity pulses, or layer changes
	# are enabled, so this isolates whether moving geometry causes the flash.
	var source: Control = bottle_nodes[_pour_source]
	var target: Control = bottle_nodes[_pour_target]
	var start: Vector2 = _get_pour_stream_start(source)
	var finish: Vector2 = target.call("get_liquid_surface_position_in_parent")
	var span: Vector2 = finish - start
	if span.length() < 1.0:
		return

	var horizontal_bend: float = clampf(span.x * 0.18, -42.0, 42.0)
	var vertical_fall: float = maxf(28.0, span.y * 0.36)
	var control_one := start + Vector2(horizontal_bend, vertical_fall * 0.28)
	var control_two := finish - Vector2(horizontal_bend, -vertical_fall * 0.28)

	var centres := PackedVector2Array()
	var left_edge := PackedVector2Array()
	var right_edge := PackedVector2Array()
	var left_glow := PackedVector2Array()
	var right_glow := PackedVector2Array()
	const POINT_COUNT := 48
	for index in range(POINT_COUNT):
		var t: float = float(index) / float(POINT_COUNT - 1)
		var point: Vector2 = start.bezier_interpolate(control_one, control_two, finish, t)
		var tangent: Vector2 = _get_stream_tangent(control_one, start, control_two, finish, t)
		var normal := Vector2(-tangent.y, tangent.x)
		centres.append(point)
		var half_width: float = 1.8 + 1.2 * sin(PI * t)
		left_edge.append(point + normal * half_width)
		right_edge.append(point - normal * half_width)
		left_glow.append(point + normal * half_width * 3.1)
		right_glow.append(point - normal * half_width * 3.1)

	var polygon := PackedVector2Array()
	for point in left_edge:
		polygon.append(point)
	for index in range(right_edge.size() - 1, -1, -1):
		polygon.append(right_edge[index])

	var glow_polygon := PackedVector2Array()
	for point in left_glow:
		glow_polygon.append(point)
	for index in range(right_glow.size() - 1, -1, -1):
		glow_polygon.append(right_glow[index])
	_stream_glow.polygon = glow_polygon
	_stream_glow.color = Color(
		_pour_color.r,
		_pour_color.g,
		_pour_color.b,
		0.16 + 0.12 * sin(PI * _pour_progress)
	)

	_stream_shape.polygon = polygon
	_stream_shape.color = Color(_pour_color.r, _pour_color.g, _pour_color.b, 1.0)
	_stream_highlight.points = centres
	_stream_highlight.default_color = Color(
		1.0,
		1.0,
		1.0,
		0.25 + 0.12 * sin(PI * _pour_progress)
	)

	var glint_progress: float = clampf(_pour_progress, 0.0, 1.0)
	var glint_start: float = lerpf(0.08, 0.76, glint_progress)
	var glint_end: float = minf(0.98, glint_start + 0.16)
	var glint_points := PackedVector2Array()
	const GLINT_SAMPLES := 9
	for index in range(GLINT_SAMPLES):
		var glint_t: float = lerpf(
			glint_start,
			glint_end,
			float(index) / float(GLINT_SAMPLES - 1)
		)
		glint_points.append(start.bezier_interpolate(control_one, control_two, finish, glint_t))
	_stream_glint.points = glint_points
	_stream_glint.default_color = Color(
		1.0,
		1.0,
		1.0,
		0.52 * sin(PI * glint_progress)
	)

	for index in range(_stream_drops.size()):
		var travel: float = clampf(_pour_progress * 1.5 - float(index) * 0.25, 0.0, 1.0)
		var drop_position: Vector2 = start.bezier_interpolate(control_one, control_two, finish, travel)
		var drop: Polygon2D = _stream_drops[index]
		drop.position = drop_position
		drop.rotation = atan2(span.y, span.x) + PI * 0.5
		drop.scale = Vector2(0.75 + 0.25 * sin(PI * travel), 0.90 + 0.4 * sin(PI * travel))
		drop.color = Color(1.0, 1.0, 1.0, 0.46 * sin(PI * travel))

	var ring_radius: float = 4.5 + 13.0 * _pour_progress
	var ring_alpha: float = 0.16 * sin(PI * _pour_progress)
	var ring_points := PackedVector2Array()
	for index in range(25):
		var angle: float = TAU * float(index) / 24.0
		ring_points.append(finish + Vector2(cos(angle) * ring_radius, sin(angle) * ring_radius * 0.42))
	_splash_ring.points = ring_points
	_splash_ring.default_color = Color(1.0, 1.0, 1.0, ring_alpha)

func _get_stream_centre_point(
	start: Vector2,
	control_one: Vector2,
	control_two: Vector2,
	finish: Vector2,
	t: float
) -> Vector2:
	# Diagnostic: remove the spatial centreline drift while preserving the
	# original adaptive sampling, ribbon width, glow and all other FX.
	return start.bezier_interpolate(control_one, control_two, finish, t)


func _get_stream_tangent(
	control_one: Vector2,
	start: Vector2,
	control_two: Vector2,
	finish: Vector2,
	t: float
) -> Vector2:
	# Analytic cubic-Bezier derivative avoids a sample-spacing-dependent normal.
	var inverse_t: float = 1.0 - t
	var tangent: Vector2 = (
		3.0 * inverse_t * inverse_t * (control_one - start)
		+ 6.0 * inverse_t * t * (control_two - control_one)
		+ 3.0 * t * t * (finish - control_two)
	)
	if tangent.length_squared() <= 0.000001:
		tangent = finish - start
	return tangent.normalized()


func _load_level() -> void:
	_drag_hover_index = -1
	_drag_pointer_velocity = Vector2.ZERO
	_drag_follow_velocity = Vector2.ZERO
	_pour_stream_active = false
	_pour_source = -1
	_pour_target = -1
	super._load_level()
	if is_instance_valid(_slot_surface):
		_slot_surface.set_completion_state(round_complete, bottle_nodes, PALETTE)
	if is_instance_valid(_mouth_mote_layer):
		_mouth_mote_layer.configure(bottle_nodes, PALETTE)


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
