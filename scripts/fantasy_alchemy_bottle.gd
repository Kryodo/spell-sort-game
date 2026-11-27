extends "res://scripts/alchemy_bottle.gd"

# A fantasy-first vessel renderer. The liquid and the glass remain separate:
# silhouettes and ornaments can evolve without changing sorting behaviour.

var _pose_target := Vector2.ZERO
var _pose_velocity := Vector2.ZERO
var _scale_target: float = 1.0
var _scale_velocity: float = 0.0


func setup(index: int, _label: String, variant: int, palette: Dictionary, contents: Array) -> void:
    # Numbers are useful while debugging, but they are not part of the vessel's
    # fantasy identity or the player's sorting decision.
    super.setup(index, "", variant, palette, contents)


func set_pose(pose: Vector2) -> void:
    _pose_target = Vector2(
        clampf(pose.x, 0.0, 32.0),
        clampf(pose.y, -2.05, 2.05)
    )


func get_pose() -> Vector2:
    return Vector2(_lift, _tilt)


func set_draw_scale(value: float) -> void:
    _scale_target = clampf(value, 0.88, 1.08)


func reset_motion() -> void:
    super.reset_motion()
    _pose_target = Vector2.ZERO
    _pose_velocity = Vector2.ZERO
    _scale_target = 1.0
    _scale_velocity = 0.0


func _process(delta: float) -> void:
    var previous_tilt: float = _tilt

    # Critically damped pose response gives the vessel a little mass.
    var lift_omega: float = 25.0
    var tilt_omega: float = 19.0
    _pose_velocity.x += (
        (_pose_target.x - _lift) * lift_omega * lift_omega
        - 2.0 * lift_omega * _pose_velocity.x
    ) * delta
    _pose_velocity.y += (
        (_pose_target.y - _tilt) * tilt_omega * tilt_omega
        - 2.0 * tilt_omega * _pose_velocity.y
    ) * delta

    _lift += _pose_velocity.x * delta
    _tilt += _pose_velocity.y * delta
    _slosh_velocity += (_tilt - previous_tilt) * 1.65

    var scale_difference := _scale_target - _draw_scale
    _scale_velocity += (scale_difference * 150.0 - _scale_velocity * 22.0) * delta
    _draw_scale = clampf(_draw_scale + _scale_velocity * delta, 0.88, 1.08)

    super._process(delta)


func _profile_points() -> Array[Vector2]:
    # Each profile uses the same glass/liquid pipeline but has a distinct
    # shoulder, body and foot. Values are normalised to the vessel rectangle.
    match procedural_variant:
        0: # Round-bottomed teardrop / classic alchemist flask.
            return [
                Vector2(0.00, 0.125), Vector2(0.06, 0.145),
                Vector2(0.15, 0.215), Vector2(0.27, 0.365),
                Vector2(0.43, 0.465), Vector2(0.62, 0.475),
                Vector2(0.79, 0.415), Vector2(0.91, 0.305),
                Vector2(0.975, 0.195), Vector2(1.00, 0.135)
            ]
        1: # Long-necked flask with a low, generous belly.
            return [
                Vector2(0.00, 0.115), Vector2(0.08, 0.135),
                Vector2(0.20, 0.205), Vector2(0.34, 0.305),
                Vector2(0.49, 0.425), Vector2(0.68, 0.455),
                Vector2(0.83, 0.405), Vector2(0.93, 0.285),
                Vector2(0.985, 0.175), Vector2(1.00, 0.125)
            ]
        2: # Softly squared apothecary vessel with broad shoulders.
            return [
                Vector2(0.00, 0.145), Vector2(0.07, 0.155),
                Vector2(0.17, 0.255), Vector2(0.25, 0.385),
                Vector2(0.34, 0.405), Vector2(0.70, 0.405),
                Vector2(0.81, 0.375), Vector2(0.91, 0.275),
                Vector2(0.975, 0.185), Vector2(1.00, 0.145)
            ]
        _: # Rounded bulb with a slightly pinched lower foot.
            return [
                Vector2(0.00, 0.13), Vector2(0.07, 0.15),
                Vector2(0.18, 0.255), Vector2(0.31, 0.405),
                Vector2(0.51, 0.475), Vector2(0.70, 0.455),
                Vector2(0.84, 0.365), Vector2(0.93, 0.255),
                Vector2(0.985, 0.17), Vector2(1.00, 0.13)
            ]


func _draw_liquid(rect: Rect2) -> void:
	super._draw_liquid(rect)
    if _visual_contents.is_empty() or _liquid_level <= 0.02:
        return

    var fill_amount := clampf(_liquid_level, 0.0, float(CAPACITY))
    var layer_height: float = (LIQUID_BOTTOM_RATIO - LIQUID_TOP_RATIO) / float(CAPACITY)
    var surface_ratio: float = LIQUID_BOTTOM_RATIO - layer_height * fill_amount
    var surface_y: float = rect.position.y + rect.size.y * surface_ratio
    var bottom_y: float = rect.position.y + rect.size.y * LIQUID_BOTTOM_RATIO
    var top_layer_index: int = clampi(int(floor(fill_amount - 0.0001)), 0, _visual_contents.size() - 1)
    var top_essence: String = String(_visual_contents[top_layer_index])
    var liquid_color: Color = _palette.get(top_essence, Color(0.45, 0.78, 0.75, 1.0))

    # A restrained inner radiance keeps each essence luminous without turning
    # the liquid into a neon block.
    var glow_center := Vector2(rect.get_center().x, (surface_y + bottom_y) * 0.54)
    var glow_radius := rect.size.x * 0.19
    draw_circle(
        glow_center,
        glow_radius,
        Color(liquid_color.r, liquid_color.g, liquid_color.b, 0.035)
    )

    # Small bubbles rise at different speeds and drift gently with the fluid.
    for bubble_index in range(9):
        var phase: float = fposmod(
            _wave_time * (0.13 + float(bubble_index) * 0.011)
            + float(bubble_index) * 0.137,
            1.0
        )
        var bubble_y: float = lerpf(bottom_y - 7.0, surface_y + 6.0, phase)
        var normalized_y: float = clampf(
            (bubble_y - rect.position.y) / rect.size.y,
            0.0,
            1.0
        )
        var local_half_width: float = rect.size.x * _get_profile_at(normalized_y).y - 8.0
        if local_half_width <= 3.0:
            continue

        var sway: float = sin(_wave_time * 0.72 + float(bubble_index) * 1.71)
        var x_position: float = rect.get_center().x + sway * local_half_width * 0.58
        var bubble_position := Vector2(x_position, bubble_y)
        var bubble_size: float = 1.35 + fposmod(float(bubble_index) * 0.73, 2.4)
        var bubble_alpha: float = 0.15 + 0.10 * (0.5 + 0.5 * sin(_wave_time * 1.6 + float(bubble_index)))
        var bubble_layer_index: int = clampi(
            int(floor((LIQUID_BOTTOM_RATIO - normalized_y) / layer_height)),
            0,
            _visual_contents.size() - 1
        )
        var bubble_essence: String = String(_visual_contents[bubble_layer_index])
        var bubble_color: Color = _palette.get(bubble_essence, liquid_color)

        draw_circle(
            bubble_position,
            bubble_size * 2.25,
            Color(bubble_color.r, bubble_color.g, bubble_color.b, bubble_alpha * 0.18)
        )
        draw_circle(
            bubble_position,
            bubble_size,
            Color(0.91, 1.0, 0.98, bubble_alpha * 0.56)
        )
        draw_arc(
            bubble_position + Vector2(-0.2, -0.2),
            bubble_size,
            deg_to_rad(205.0),
            deg_to_rad(325.0),
            12,
            Color(1.0, 1.0, 1.0, bubble_alpha * 0.85),
            0.9,
            true
        )
        draw_circle(
            bubble_position + Vector2(-bubble_size * 0.30, -bubble_size * 0.34),
            maxf(0.55, bubble_size * 0.22),
            Color(1.0, 1.0, 1.0, bubble_alpha * 0.82)
        )

    # A thin moving glint gives the top layer a rounded, slightly viscous lip.
    var surface_profile := _get_profile_at(surface_ratio)
    var surface_half_width: float = rect.size.x * surface_profile.y - LIQUID_WALL_INSET_PIXELS - 2.0
    if surface_half_width > 4.0:
        var sheen := PackedVector2Array()
        for point_index in range(25):
            var x_norm: float = float(point_index) / 24.0 * 2.0 - 1.0
            var x_value: float = rect.get_center().x + x_norm * surface_half_width * 0.78
            var y_value: float = surface_y + _get_surface_wave_offset(x_norm * 0.78)
            sheen.append(Vector2(x_value, y_value))
        draw_polyline(
            sheen,
            Color(1.0, 0.98, 0.85, 0.10 + _surface_activity * 0.05),
            2.0,
            true
        )

func _get_surface_wave_offset(normalized_x: float) -> float:
    var inherited_wave: float = super._get_surface_wave_offset(normalized_x)
    var slow_roll: float = sin(_wave_time * 1.45 + normalized_x * 4.2) * 0.55
    return inherited_wave + slow_roll


func _draw_wavy_surface_fill(
    rect: Rect2,
    surface_y: float,
    fill_bottom: float,
    first_strip_bottom: float,
    liquid_color: Color
) -> void:
    super._draw_wavy_surface_fill(rect, surface_y, fill_bottom, first_strip_bottom, liquid_color)

    var profile := _get_profile_at(clampf(
        (surface_y - rect.position.y) / rect.size.y,
        0.0,
        1.0
    ))
    var half_width: float = rect.size.x * profile.y - LIQUID_WALL_INSET_PIXELS - 3.0
    if half_width <= 4.0:
        return

    var meniscus := PackedVector2Array()
    for point_index in range(33):
        var x_norm: float = float(point_index) / 32.0 * 2.0 - 1.0
        var x_value: float = rect.get_center().x + x_norm * half_width * 0.82
        var y_value: float = surface_y + _get_surface_wave_offset(x_norm * 0.82)
        meniscus.append(Vector2(x_value, y_value))
    draw_polyline(
        meniscus,
        Color(1.0, 0.98, 0.88, 0.14 + _surface_activity * 0.06),
        2.2,
        true
    )


func _draw_glass_overlay() -> void:
    var rect := _get_vessel_rect()
    _draw_glass_front(rect)
    _draw_neck_ornament(rect)
    _draw_base_ornament(rect)
    _draw_side_charm(rect)
    _draw_neck_motes()


func _draw_neck_ornament(rect: Rect2) -> void:
    var centre_x: float = size.x * 0.5
    var neck_ratio := 0.075
    var neck_profile := _get_profile_at(neck_ratio)
    var half_width: float = rect.size.x * neck_profile.y
    var band_y: float = rect.position.y + rect.size.y * neck_ratio

    var fabric_color: Color
    match procedural_variant:
        0:
            fabric_color = Color("#526b4e")
        1:
            fabric_color = Color("#71526c")
        2:
            fabric_color = Color("#8c6042")
        _:
            fabric_color = Color("#476a72")

    var band := PackedVector2Array([
        Vector2(centre_x - half_width, band_y - 1.0),
        Vector2(centre_x + half_width, band_y + 1.0),
        Vector2(centre_x + half_width * 0.96, band_y + 7.0),
        Vector2(centre_x - half_width * 0.96, band_y + 5.0)
    ])
    draw_colored_polygon(band, fabric_color)
    draw_line(
        Vector2(centre_x - half_width, band_y - 1.0),
        Vector2(centre_x + half_width, band_y + 1.0),
        Color(0.91, 0.79, 0.55, 0.68),
        1.5,
        true
    )
    draw_line(
        Vector2(centre_x - half_width * 0.92, band_y + 5.0),
        Vector2(centre_x + half_width * 0.92, band_y + 7.0),
        Color(0.08, 0.11, 0.10, 0.42),
        1.0,
        true
    )

    # A tiny tied knot and two short tails sit to the side of the neck,
    # leaving the open mouth and the visible liquid unobstructed.
    var knot := Vector2(centre_x + half_width * 0.74, band_y + 5.0)
    var bow_left := PackedVector2Array([
        knot + Vector2(-1.0, 0.0),
        knot + Vector2(-9.0, -6.0),
        knot + Vector2(-7.0, 2.0),
        knot + Vector2(-1.0, 3.0)
    ])
    var bow_right := PackedVector2Array([
        knot + Vector2(1.0, 0.0),
        knot + Vector2(9.0, -5.0),
        knot + Vector2(7.0, 3.0),
        knot + Vector2(1.0, 3.0)
    ])
    draw_colored_polygon(bow_left, fabric_color.lightened(0.12))
    draw_colored_polygon(bow_right, fabric_color.darkened(0.08))
    draw_circle(knot, 2.3, Color("#c7a66e"))

    var tail := PackedVector2Array([
        knot + Vector2(1.0, 2.0),
        knot + Vector2(7.0, 7.0),
        knot + Vector2(4.0, 15.0),
        knot + Vector2(0.0, 10.0)
    ])
    draw_colored_polygon(tail, fabric_color)


func _draw_base_ornament(rect: Rect2) -> void:
    var centre_x: float = size.x * 0.5
    var base_ratio := 0.965
    var profile := _get_profile_at(base_ratio)
    var half_width: float = rect.size.x * profile.y * 0.92
    var base_y: float = rect.position.y + rect.size.y * base_ratio

    draw_line(
        Vector2(centre_x - half_width, base_y),
        Vector2(centre_x + half_width, base_y),
        Color(0.70, 0.54, 0.31, 0.52),
        2.4,
        true
    )
    draw_line(
        Vector2(centre_x - half_width * 0.78, base_y + 3.5),
        Vector2(centre_x + half_width * 0.78, base_y + 3.5),
        Color(0.91, 0.80, 0.57, 0.42),
        1.1,
        true
    )
    draw_arc(
        Vector2(centre_x, base_y + 1.0),
        maxf(4.0, half_width * 0.70),
        deg_to_rad(10.0),
        deg_to_rad(170.0),
        24,
        Color(0.96, 0.84, 0.62, 0.34),
        1.0,
        true
    )


func _draw_side_charm(rect: Rect2) -> void:
    if procedural_variant == 2:
        return
    var centre_x: float = size.x * 0.5
    var body_profile := _get_profile_at(0.20)
    var side_x: float = centre_x + rect.size.x * body_profile.y * 0.86
    var charm_y: float = rect.position.y + rect.size.y * 0.23
    var chain := PackedVector2Array([
        Vector2(side_x - 2.0, charm_y - 10.0),
        Vector2(side_x + 1.0, charm_y - 2.0),
        Vector2(side_x + 3.0, charm_y + 4.0)
    ])
    draw_polyline(chain, Color(0.77, 0.65, 0.43, 0.60), 1.2, true)
    draw_arc(
        Vector2(side_x + 3.0, charm_y + 8.0),
        4.0,
        0.0,
        TAU,
        20,
        Color(0.86, 0.73, 0.49, 0.78),
        1.4,
        true
    )
    draw_circle(
        Vector2(side_x + 3.0, charm_y + 8.0),
        1.8,
        Color("#d0b27a")
    )


func _draw_neck_motes() -> void:
    if _visual_contents.is_empty():
        return
    var centre_x: float = size.x * 0.5
    for mote_index in range(2):
        var phase: float = fposmod(_wave_time * 0.14 + float(mote_index) * 0.53, 1.0)
        var x_offset: float = -14.0 if mote_index == 0 else 16.0
        var mote_position := Vector2(
            centre_x + x_offset + sin(_wave_time * 0.8 + float(mote_index)) * 3.0,
            66.0 - phase * 24.0
        )
        var alpha: float = (1.0 - phase) * 0.18
        draw_circle(mote_position, 3.2, Color(0.65, 0.89, 0.79, alpha * 0.18))
        draw_circle(mote_position, 1.1, Color(0.88, 1.0, 0.84, alpha))
