extends "res://scripts/test_tube_vial.gd"

## Performance-oriented liquid renderer transferred from the working
## asset_fantasy_alchemy_bottle.gd pipeline and adapted to the custom lab bottle.
## The source renderer, original test-tube renderer and first liquid experiment
## are kept intact for direct comparison.

const PROFILE_CACHE_SAMPLES := 160
const CACHED_LIQUID_SURFACE_SAMPLES := 48
const CACHED_LIQUID_SIDE_SAMPLES := 32
const CACHED_LIQUID_WALL_INSET := 4.5
const CACHED_LIQUID_BAND_OVERLAP := 0.8
const CACHED_LIQUID_APPEARANCE_FADE := 0.12
const CACHED_LIQUID_MIN_HEIGHT := 0.05
const CACHED_LIQUID_FADE_HEIGHT := 1.5
const CACHED_SURFACE_DEPTH_RATIO := 0.026
const CACHED_SURFACE_DEPTH_MIN := 4.0
const CACHED_SURFACE_DEPTH_MAX := 8.0
const CACHED_BUBBLE_SIZES := [1.65, 2.25, 1.85, 2.35]
const CACHED_BUBBLE_TEXTURE_SIZE := 48

static var _cached_bubble_sprite_library: Dictionary = {}

# This is the same cache lifecycle as the working renderer:
# expensive body polygons and vertex colours rebuild only after state/profile/size changes.
var _cached_profile_liquid_bands: Array[Dictionary] = []
var _cached_profile_liquid_rect := Rect2()
var _cached_profile_liquid_dirty: bool = true
var _cached_inner_profile := PackedVector3Array()


func _ready() -> void:
	super._ready()
	_build_cached_inner_profile()
	if not resized.is_connected(_on_cached_vial_resized):
		resized.connect(_on_cached_vial_resized)
	_invalidate_profile_liquid_geometry()


func _on_cached_vial_resized() -> void:
	_invalidate_profile_liquid_geometry()


func _invalidate_profile_liquid_geometry() -> void:
	_cached_profile_liquid_dirty = true
	queue_redraw()


func setup(index: int, label: String, variant: int, palette: Dictionary, contents: Array) -> void:
	super.setup(index, label, variant, palette, contents)
	_invalidate_profile_liquid_geometry()


func set_contents(contents: Array) -> void:
	super.set_contents(contents)
	_invalidate_profile_liquid_geometry()


func set_preview(contents: Array, level: float) -> void:
	super.set_preview(contents, level)
	_invalidate_profile_liquid_geometry()


func _build_cached_inner_profile() -> void:
	_cached_inner_profile.clear()
	for sample_index in range(PROFILE_CACHE_SAMPLES):
		var y_ratio: float = float(sample_index) / float(PROFILE_CACHE_SAMPLES - 1)
		var profile_point: Vector2 = _get_profile_at(y_ratio)
		# Store normalized Y, left boundary and right boundary for fast lookups.
		_cached_inner_profile.append(Vector3(
			y_ratio,
			0.5 - profile_point.y,
			0.5 + profile_point.y
		))


func _profile_bounds_at(y_ratio: float) -> Vector2:
	if _cached_inner_profile.is_empty():
		return Vector2(0.5, 0.5)

	var y: float = clampf(y_ratio, 0.0, 1.0)
	var profile_count: int = _cached_inner_profile.size()
	var first: Vector3 = _cached_inner_profile[0]
	if y <= first.x:
		return Vector2(first.y, first.z)

	var last: Vector3 = _cached_inner_profile[profile_count - 1]
	if y >= last.x:
		return Vector2(last.y, last.z)

	# Profile samples are uniform, so estimate the segment directly and correct
	# the bracket only when floating-point rounding puts us on a neighbour.
	var normalized_position: float = clampf(y, 0.0, 1.0)
	var low_index: int = clampi(
		floori(normalized_position * float(profile_count - 1)),
		0,
		profile_count - 2
	)
	if _cached_inner_profile[low_index].x > y:
		while low_index > 0 and _cached_inner_profile[low_index].x > y:
			low_index -= 1
	else:
		while (
			low_index < profile_count - 2
			and _cached_inner_profile[low_index + 1].x <= y
		):
			low_index += 1

	first = _cached_inner_profile[low_index]
	last = _cached_inner_profile[low_index + 1]
	var span: float = maxf(0.000001, last.x - first.x)
	var weight: float = clampf((y - first.x) / span, 0.0, 1.0)
	return Vector2(
		lerpf(first.y, last.y, weight),
		lerpf(first.z, last.z, weight)
	)


func _profile_liquid_half_width(rect: Rect2, y: float) -> float:
	var y_ratio: float = clampf(
		(y - rect.position.y) / maxf(1.0, rect.size.y),
		0.0,
		1.0
	)
	var bounds: Vector2 = _profile_bounds_at(y_ratio)
	return maxf(
		0.0,
		rect.size.x * (bounds.y - bounds.x) * 0.5 - CACHED_LIQUID_WALL_INSET
	)


func _draw_liquid(_rect: Rect2) -> void:
	if _visual_contents.is_empty() or _liquid_level <= 0.001:
		return

	var rect := _get_vessel_rect()
	if (
		_cached_profile_liquid_dirty
		or rect != _cached_profile_liquid_rect
	):
		_rebuild_cached_profile_liquid_geometry(rect)

	if _cached_profile_liquid_bands.is_empty():
		return

	for band in _cached_profile_liquid_bands:
		var polygon: PackedVector2Array = band["polygon"]
		var vertex_colours: PackedColorArray = band["vertex_colours"]
		draw_polygon(polygon, vertex_colours)
		if bool(band["is_surface"]):
			_draw_cached_profile_liquid_surface(band)

	var visible_layers: int = mini(int(ceil(_liquid_level)), _visual_contents.size())
	_draw_cached_profile_liquid_bubbles(rect, visible_layers)
	_draw_profile_surface_bubble_activity(rect)


func _rebuild_cached_profile_liquid_geometry(rect: Rect2) -> void:
	_cached_profile_liquid_bands.clear()
	_cached_profile_liquid_rect = rect
	_cached_profile_liquid_dirty = false

	if (
		_cached_inner_profile.size() < 8
		or _visual_contents.is_empty()
		or _liquid_level <= 0.001
	):
		return

	var layer_height: float = (LIQUID_BOTTOM_RATIO - LIQUID_TOP_RATIO) / float(CAPACITY)
	var visible_layers: int = mini(int(ceil(_liquid_level)), _visual_contents.size())
	for layer_index in range(visible_layers):
		var amount: float = clampf(_liquid_level - float(layer_index), 0.0, 1.0)
		if amount <= 0.001:
			continue

		var bottom_ratio: float = LIQUID_BOTTOM_RATIO - float(layer_index) * layer_height
		var top_ratio: float = bottom_ratio - layer_height * amount
		var essence: String = String(_visual_contents[layer_index])
		var liquid_color: Color = _palette.get(
			essence,
			Color(0.45, 0.78, 0.75, 1.0)
		)
		liquid_color.a *= smoothstep(0.0, CACHED_LIQUID_APPEARANCE_FADE, amount)

		var band: Dictionary = _build_cached_profile_liquid_band(
			rect,
			top_ratio,
			bottom_ratio,
			liquid_color,
			layer_index == visible_layers - 1,
			layer_index == 0
		)
		if not band.is_empty():
			_cached_profile_liquid_bands.append(band)


func _build_cached_profile_liquid_band(
	rect: Rect2,
	top_ratio: float,
	bottom_ratio: float,
	liquid_color: Color,
	is_surface: bool,
	is_bottom: bool
) -> Dictionary:
	var bottom_y: float = rect.position.y + rect.size.y * bottom_ratio
	if not is_bottom:
		bottom_y += CACHED_LIQUID_BAND_OVERLAP
	var top_y: float = rect.position.y + rect.size.y * top_ratio
	var band_height: float = bottom_y - top_y
	if band_height <= CACHED_LIQUID_MIN_HEIGHT:
		return {}

	var band_alpha: float = smoothstep(
		CACHED_LIQUID_MIN_HEIGHT,
		CACHED_LIQUID_FADE_HEIGHT,
		band_height
	)

	var top_bounds := _profile_bounds_at(
		clampf((top_y - rect.position.y) / rect.size.y, 0.0, 1.0)
	)
	var top_left_x: float = rect.position.x + rect.size.x * top_bounds.x + CACHED_LIQUID_WALL_INSET
	var top_right_x: float = rect.position.x + rect.size.x * top_bounds.y - CACHED_LIQUID_WALL_INSET

	var polygon := PackedVector2Array()
	var vertex_colours := PackedColorArray()

	# Upper edge, sampled across the true curved bottle profile.
	for sample_index in range(CACHED_LIQUID_SURFACE_SAMPLES + 1):
		var t: float = float(sample_index) / float(CACHED_LIQUID_SURFACE_SAMPLES)
		var x: float = lerpf(top_left_x, top_right_x, t)
		polygon.append(Vector2(x, top_y))
		var centre_weight: float = pow(maxf(0.0, sin(PI * t)), 0.85) * 0.42
		vertex_colours.append(
			liquid_color.darkened(0.10).lerp(
				liquid_color.lightened(0.18),
				centre_weight
			)
		)

	# Right wall follows the bottle's changing width down to the next layer.
	for side_index in range(1, CACHED_LIQUID_SIDE_SAMPLES + 1):
		var t: float = float(side_index) / float(CACHED_LIQUID_SIDE_SAMPLES)
		var y: float = lerpf(top_y, bottom_y, t)
		var half_width: float = _profile_liquid_half_width(rect, y)
		polygon.append(Vector2(rect.get_center().x + half_width, y))
		vertex_colours.append(liquid_color.darkened(lerpf(0.12, 0.23, t)))

	# Bottom edge, also curved to match the foot instead of a rectangular floor.
	for sample_index in range(CACHED_LIQUID_SURFACE_SAMPLES - 1, -1, -1):
		var t: float = float(sample_index) / float(CACHED_LIQUID_SURFACE_SAMPLES)
		var half_width: float = _profile_liquid_half_width(rect, bottom_y)
		polygon.append(Vector2(
			rect.get_center().x + lerpf(-half_width, half_width, t),
			bottom_y
		))
		vertex_colours.append(liquid_color.darkened(0.22))

	# Left wall closes the volume.
	for side_index in range(CACHED_LIQUID_SIDE_SAMPLES - 1, 0, -1):
		var t: float = float(side_index) / float(CACHED_LIQUID_SIDE_SAMPLES)
		var y: float = lerpf(top_y, bottom_y, t)
		var half_width: float = _profile_liquid_half_width(rect, y)
		polygon.append(Vector2(rect.get_center().x - half_width, y))
		vertex_colours.append(liquid_color.darkened(lerpf(0.12, 0.23, t)))

	# Match the working renderer: very thin bands fade at the geometry edge,
	# so both cached body vertices and the surface plane receive the same fade.
	for colour_index in range(vertex_colours.size()):
		var vertex_colour: Color = vertex_colours[colour_index]
		vertex_colour.a *= band_alpha
		vertex_colours[colour_index] = vertex_colour

	var fill_colour: Color = liquid_color.lerp(liquid_color.lightened(0.12), 0.10)
	fill_colour.a *= band_alpha

	var surface_radius_x: float = maxf(0.0, (top_right_x - top_left_x) * 0.5 - 1.5)
	var surface_depth: float = clampf(
		rect.size.y * CACHED_SURFACE_DEPTH_RATIO,
		CACHED_SURFACE_DEPTH_MIN,
		CACHED_SURFACE_DEPTH_MAX
	)
	var surface_colours := PackedColorArray()
	if is_surface:
		for sample_index in range(CACHED_LIQUID_SURFACE_SAMPLES):
			var angle: float = TAU * float(sample_index) / float(CACHED_LIQUID_SURFACE_SAMPLES)
			var front_weight: float = 0.5 + 0.5 * sin(angle)
			var surface_colour: Color = liquid_color.darkened(0.16).lerp(
				liquid_color.lightened(0.20),
				front_weight
			)
			surface_colour.a *= band_alpha
			surface_colours.append(surface_colour)

	return {
		"polygon": polygon,
		"vertex_colours": vertex_colours,
		"is_surface": is_surface,
		"surface_center": Vector2(rect.get_center().x, top_y),
		"surface_radius_x": surface_radius_x,
		"surface_depth": surface_depth,
		"surface_colours": surface_colours,
		"surface_liquid_colour": fill_colour,
		"surface_alpha": liquid_color.a
	}


func _draw_cached_profile_liquid_surface(band: Dictionary) -> void:
	var centre: Vector2 = band["surface_center"]
	var radius_x: float = float(band["surface_radius_x"])
	var radius_y: float = float(band["surface_depth"])
	if radius_x <= 4.0:
		return

	# The elliptical plane itself is dynamic; its palette and body geometry
	# remain cached. Only the small wave displacement is recalculated per frame.
	var surface_polygon := PackedVector2Array()
	for sample_index in range(CACHED_LIQUID_SURFACE_SAMPLES):
		var angle: float = TAU * float(sample_index) / float(CACHED_LIQUID_SURFACE_SAMPLES)
		var normalized_x: float = cos(angle)
		var wave: float = _get_surface_wave_offset(normalized_x) * 0.24
		surface_polygon.append(Vector2(
			centre.x + normalized_x * radius_x,
			centre.y + sin(angle) * radius_y + wave
		))

	var surface_colours: PackedColorArray = band["surface_colours"]
	draw_polygon(surface_polygon, surface_colours)

	# The rear edge is deliberately darker; the near edge catches a soft,
	# restrained highlight. These are separate arcs, not a hard full outline.
	var rear_edge := PackedVector2Array()
	var front_edge := PackedVector2Array()
	for sample_index in range(CACHED_LIQUID_SURFACE_SAMPLES / 2 + 1):
		var t: float = float(sample_index) / float(CACHED_LIQUID_SURFACE_SAMPLES / 2)
		var rear_angle: float = PI + PI * t
		var front_angle: float = PI * t
		rear_edge.append(Vector2(
			centre.x + cos(rear_angle) * radius_x,
			centre.y + sin(rear_angle) * radius_y
		))
		front_edge.append(Vector2(
			centre.x + cos(front_angle) * radius_x,
			centre.y + sin(front_angle) * radius_y
		))

	var liquid_colour: Color = band["surface_liquid_colour"]
	var surface_alpha: float = float(band["surface_alpha"])
	draw_polyline(
		rear_edge,
		Color(
			liquid_colour.darkened(0.30).r,
			liquid_colour.darkened(0.30).g,
			liquid_colour.darkened(0.30).b,
			0.40 * surface_alpha
		),
		1.1,
		true
	)
	draw_polyline(
		front_edge,
		Color(0.96, 1.0, 0.94, 0.26 * surface_alpha),
		1.2,
		true
	)


func _draw_cached_profile_liquid_bubbles(rect: Rect2, visible_layers: int) -> void:
	if visible_layers <= 0 or _cached_inner_profile.is_empty():
		return

	var appearance_alpha: float = smoothstep(
		0.0,
		CACHED_LIQUID_APPEARANCE_FADE,
		_liquid_level
	)
	var layer_height: float = (LIQUID_BOTTOM_RATIO - LIQUID_TOP_RATIO) / float(CAPACITY)
	var surface_ratio: float = LIQUID_BOTTOM_RATIO - layer_height * clampf(
		_liquid_level,
		0.0,
		float(CAPACITY)
	)
	var surface_y: float = rect.position.y + rect.size.y * surface_ratio
	var bottom_y: float = rect.position.y + rect.size.y * LIQUID_BOTTOM_RATIO

	# Four cached sprites replace the old per-frame multi-circle bubble drawing.
	for bubble_index in range(CACHED_BUBBLE_SIZES.size()):
		var speed: float = 0.082 + float(bubble_index % 3) * 0.021 + float(bubble_index / 3) * 0.008
		var phase: float = fposmod(
			_wave_time * speed + float(bubble_index) * 0.163,
			1.0
		)
		var bubble_y: float = lerpf(bottom_y - 5.0, surface_y + 3.0, phase)
		var normalized_y: float = clampf(
			(bubble_y - rect.position.y) / rect.size.y,
			LIQUID_TOP_RATIO,
			LIQUID_BOTTOM_RATIO
		)
		var bounds := _profile_bounds_at(normalized_y)
		var left_x: float = rect.position.x + rect.size.x * bounds.x + 5.0
		var right_x: float = rect.position.x + rect.size.x * bounds.y - 5.0
		if right_x - left_x <= 7.0:
			continue

		var sway: float = sin(
			_wave_time * (0.34 + float(bubble_index % 3) * 0.09)
			+ float(bubble_index) * 1.71
		)
		var bubble_position := Vector2(
			lerpf(left_x, right_x, 0.5 + sway * 0.24),
			bubble_y
		)
		var bubble_size: float = CACHED_BUBBLE_SIZES[bubble_index]
		var travel_fade: float = sin(PI * phase)
		var pulse: float = 0.55 + 0.45 * sin(_wave_time * 1.15 + float(bubble_index) * 1.37)
		var bubble_alpha: float = (0.18 + 0.06 * pulse) * travel_fade * appearance_alpha
		if bubble_alpha <= 0.004:
			continue

		var layer_index: int = clampi(
			int(floor((LIQUID_BOTTOM_RATIO - normalized_y) / maxf(0.0001, layer_height))),
			0,
			mini(_visual_contents.size() - 1, CAPACITY - 1)
		)
		var essence: String = String(_visual_contents[layer_index])
		var bubble_colour: Color = _palette.get(
			essence,
			Color(0.45, 0.78, 0.75, 1.0)
		)
		var bubble_texture := _get_cached_profile_bubble_sprite(
			bubble_colour,
			bubble_colour.lightened(0.56),
			1.0 / 2.35,
			0.34,
			0.52,
			true
		)
		var diameter: float = bubble_size * 4.70
		draw_texture_rect(
			bubble_texture,
			Rect2(
				bubble_position - Vector2.ONE * (diameter * 0.5),
				Vector2.ONE * diameter
			),
			false,
			Color(1.0, 1.0, 1.0, bubble_alpha)
		)

	# Tiny essence motes use the same cached texture path and a single draw call.
	for mote_index in range(2):
		var mote_phase: float = fposmod(
			_wave_time * (0.055 + float(mote_index) * 0.012)
			+ float(mote_index) * 0.317,
			1.0
		)
		var mote_y: float = lerpf(bottom_y - 3.0, surface_y + 2.0, mote_phase)
		var mote_ratio: float = clampf(
			(mote_y - rect.position.y) / rect.size.y,
			LIQUID_TOP_RATIO,
			LIQUID_BOTTOM_RATIO
		)
		var mote_bounds := _profile_bounds_at(mote_ratio)
		var mote_half_width: float = maxf(
			0.0,
			rect.size.x * (mote_bounds.y - mote_bounds.x) * 0.32
		)
		if mote_half_width <= 2.0:
			continue
		var mote_x: float = rect.get_center().x + sin(
			_wave_time * 0.27 + float(mote_index) * 2.1
		) * mote_half_width
		var mote_position := Vector2(mote_x, mote_y)
		var mote_alpha: float = (
			0.065 + 0.035 * sin(_wave_time * 0.8 + float(mote_index))
		) * sin(PI * mote_phase) * appearance_alpha
		var mote_layer: int = clampi(
			int(floor((LIQUID_BOTTOM_RATIO - mote_ratio) / maxf(0.0001, layer_height))),
			0,
			mini(_visual_contents.size() - 1, CAPACITY - 1)
		)
		var mote_colour: Color = _palette.get(
			String(_visual_contents[mote_layer]),
			Color(0.45, 0.78, 0.75, 1.0)
		)
		var mote_texture := _get_cached_profile_bubble_sprite(
			mote_colour,
			Color(0.95, 1.0, 0.92, 1.0),
			0.75 / 2.2,
			0.24,
			0.72,
			false
		)
		var mote_diameter := 4.4
		draw_texture_rect(
			mote_texture,
			Rect2(
				mote_position - Vector2.ONE * (mote_diameter * 0.5),
				Vector2.ONE * mote_diameter
			),
			false,
			Color(1.0, 1.0, 1.0, mote_alpha)
		)


func _draw_profile_surface_bubble_activity(rect: Rect2) -> void:
	if _liquid_level <= 0.02 or _visual_contents.is_empty():
		return

	const EVENT_PERIOD := 8.4
	const EVENT_DURATION := 1.15
	const EVENT_COUNT := 2
	var layer_height: float = (LIQUID_BOTTOM_RATIO - LIQUID_TOP_RATIO) / float(CAPACITY)
	var surface_ratio: float = LIQUID_BOTTOM_RATIO - (
		layer_height * clampf(_liquid_level, 0.0, float(CAPACITY))
	)
	var top_index: int = clampi(
		int(floor(_liquid_level - 0.0001)),
		0,
		_visual_contents.size() - 1
	)
	var top_amount: float = clampf(_liquid_level - float(top_index), 0.0, 1.0)
	var appearance_alpha: float = smoothstep(
		0.0,
		CACHED_LIQUID_APPEARANCE_FADE,
		top_amount
	)
	if appearance_alpha <= 0.08:
		return

	var liquid_colour: Color = _palette.get(
		String(_visual_contents[top_index]),
		Color(0.45, 0.78, 0.75, 1.0)
	)
	var base_surface_y: float = rect.position.y + rect.size.y * surface_ratio
	var surface_bounds := _profile_bounds_at(surface_ratio)
	var surface_half_width: float = (
		rect.size.x * (surface_bounds.y - surface_bounds.x) * 0.5 - 3.0
	)
	if surface_half_width <= 4.0:
		return

	for event_index in range(EVENT_COUNT):
		var event_phase: float = fposmod(
			_wave_time
			+ float(vial_index) * 1.71
			+ float(event_index) * EVENT_PERIOD * 0.5
			+ 1.35,
			EVENT_PERIOD
		)
		if event_phase > EVENT_DURATION:
			continue

		var progress: float = event_phase / EVENT_DURATION
		var side: float = -1.0 if event_index == 0 else 1.0
		var x_norm: float = side * (0.27 + 0.035 * float(vial_index % 3))
		x_norm += sin(_wave_time * 0.22 + float(vial_index)) * 0.025
		var surface_wave: float = _get_surface_wave_offset(x_norm) * 1.30
		var surface_height: float = clampf(4.0 + surface_wave, 1.0, 8.0) * appearance_alpha
		var surface_y: float = base_surface_y - surface_height
		var surface_x: float = rect.get_center().x + x_norm * surface_half_width
		var centre := Vector2(surface_x, surface_y)

		if progress < 0.52:
			var swell: float = smoothstep(0.0, 0.46, progress)
			var bubble_radius: float = lerpf(0.95, 2.75, swell)
			var bubble_fade: float = 1.0 - smoothstep(0.34, 0.52, progress)
			var bubble_centre := centre + Vector2(0.0, -bubble_radius * 0.20)
			var bubble_tint: Color = liquid_colour.lerp(
				Color(0.92, 1.0, 0.97, 1.0),
				0.46
			)
			draw_circle(
				bubble_centre,
				bubble_radius * 2.0,
				Color(bubble_tint.r, bubble_tint.g, bubble_tint.b, 0.14 * bubble_fade)
			)
			draw_circle(
				bubble_centre,
				bubble_radius,
				Color(bubble_tint.r, bubble_tint.g, bubble_tint.b, 0.66 * bubble_fade)
			)
			draw_arc(
				bubble_centre + Vector2(-0.25, -0.25),
				bubble_radius * 0.74,
				PI * 1.12,
				PI * 1.88,
				10,
				Color(0.96, 1.0, 0.96, 0.70 * bubble_fade),
				0.9,
				true
			)
		else:
			var pop_progress: float = (progress - 0.52) / 0.48
			var ripple_radius: float = lerpf(2.5, 8.5, pop_progress)
			var ripple_alpha: float = 0.30 * (
				1.0 - smoothstep(0.25, 1.0, pop_progress)
			)
			var ripple_points := PackedVector2Array()
			const RIPPLE_SEGMENTS := 20
			for point_index in range(RIPPLE_SEGMENTS + 1):
				var angle: float = TAU * float(point_index) / float(RIPPLE_SEGMENTS)
				ripple_points.append(
					centre + Vector2(
						cos(angle) * ripple_radius,
						sin(angle) * ripple_radius * 0.28
					)
				)
			draw_polyline(
				ripple_points,
				Color(
					liquid_colour.r,
					liquid_colour.g,
					liquid_colour.b,
					ripple_alpha * appearance_alpha
				),
				1.05,
				true
			)


func _get_cached_profile_bubble_sprite(
	base_colour: Color,
	core_colour: Color,
	core_radius_ratio: float,
	halo_alpha: float,
	core_alpha: float,
	include_glint: bool
) -> Texture2D:
	var cache_key: String = "%s|%s|%.4f|%.4f|%.4f|%s" % [
		base_colour.to_html(true),
		core_colour.to_html(true),
		core_radius_ratio,
		halo_alpha,
		core_alpha,
		str(include_glint)
	]
	if _cached_bubble_sprite_library.has(cache_key):
		return _cached_bubble_sprite_library[cache_key] as Texture2D

	var image := Image.create(
		CACHED_BUBBLE_TEXTURE_SIZE,
		CACHED_BUBBLE_TEXTURE_SIZE,
		false,
		Image.FORMAT_RGBA8
	)
	var outer_radius: float = float(CACHED_BUBBLE_TEXTURE_SIZE) * 0.5 - 1.0
	var core_radius: float = outer_radius * core_radius_ratio
	var glint_centre := Vector2(-0.30 / 2.35, -0.34 / 2.35) * outer_radius
	var glint_radius: float = outer_radius * (0.22 / 2.35)

	for y in range(CACHED_BUBBLE_TEXTURE_SIZE):
		for x in range(CACHED_BUBBLE_TEXTURE_SIZE):
			var local := Vector2(
				float(x) + 0.5 - float(CACHED_BUBBLE_TEXTURE_SIZE) * 0.5,
				float(y) + 0.5 - float(CACHED_BUBBLE_TEXTURE_SIZE) * 0.5
			)
			var distance: float = local.length()
			var outer_coverage: float = clampf(
				outer_radius - distance + 0.5,
				0.0,
				1.0
			)
			if outer_coverage <= 0.0:
				continue

			var alpha: float = halo_alpha * outer_coverage
			var pixel_colour: Color = base_colour
			var core_coverage: float = clampf(
				core_radius - distance + 0.5,
				0.0,
				1.0
			)
			var effective_core_alpha: float = core_alpha * core_coverage
			if effective_core_alpha > 0.0:
				var combined_alpha: float = (
					effective_core_alpha
					+ alpha * (1.0 - effective_core_alpha)
				)
				pixel_colour = (
					core_colour * effective_core_alpha
					+ base_colour * (alpha * (1.0 - effective_core_alpha))
				) / maxf(0.0001, combined_alpha)
				alpha = combined_alpha

			if include_glint:
				var glint_coverage: float = clampf(
					glint_radius - local.distance_to(glint_centre) + 0.5,
					0.0,
					1.0
				)
				var glint_alpha: float = 0.95 * glint_coverage
				if glint_alpha > 0.0:
					var combined_alpha: float = (
						glint_alpha + alpha * (1.0 - glint_alpha)
					)
					pixel_colour = (
						Color.WHITE * glint_alpha
						+ pixel_colour * (alpha * (1.0 - glint_alpha))
					) / maxf(0.0001, combined_alpha)
					alpha = combined_alpha

			image.set_pixel(
				x,
				y,
				Color(pixel_colour.r, pixel_colour.g, pixel_colour.b, alpha)
			)

	var texture := ImageTexture.create_from_image(image)
	_cached_bubble_sprite_library[cache_key] = texture
	return texture
