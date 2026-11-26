extends "res://scripts/fantasy_alchemy_bottle.gd"
class_name MaskedAssetFantasyAlchemyBottle

## Generic layered-art vial renderer. The dedicated mask is sampled once on
## startup; liquid geometry is never inferred from the glass artwork alpha.

@export var asset_definition: VialAssetDefinition

const MASK_PROFILE_SAMPLES := 128
const LIQUID_SURFACE_SAMPLES := 64
const LIQUID_WALL_INSET := 1.0

var _mask_profile: PackedVector3Array = []


func _ready() -> void:
	super._ready()
	_build_mask_profile()


func set_asset_definition(definition: VialAssetDefinition) -> void:
	asset_definition = definition
	if is_node_ready():
		_build_mask_profile()
	queue_redraw()


func _build_mask_profile() -> void:
	_mask_profile.clear()
	if asset_definition == null or not asset_definition.is_valid():
		push_warning("Masked vial: missing or invalid VialAssetDefinition.")
		return

	var mask_image: Image = asset_definition.liquid_mask.get_image()
	if mask_image == null or mask_image.is_empty():
		push_warning("Masked vial: unable to read the dedicated liquid mask.")
		return

	var image_width: int = mask_image.get_width()
	var image_height: int = mask_image.get_height()
	var top_row: int = clampi(
		int(round(asset_definition.fill_top * float(image_height))),
		0,
		image_height - 1
	)
	var bottom_row: int = clampi(
		int(round(asset_definition.fill_bottom * float(image_height))),
		top_row + 1,
		image_height - 1
	)

	for sample_index in range(MASK_PROFILE_SAMPLES):
		var t: float = float(sample_index) / float(MASK_PROFILE_SAMPLES - 1)
		var row: int = clampi(
			roundi(lerpf(float(top_row), float(bottom_row), t)),
			top_row,
			bottom_row
		)
		var first_x: int = image_width
		var last_x: int = -1
		for x in range(image_width):
			var pixel: Color = mask_image.get_pixel(x, row)
			var mask_value: float = maxf(pixel.r, maxf(pixel.g, pixel.b)) * pixel.a
			if mask_value >= asset_definition.mask_alpha_threshold:
				first_x = mini(first_x, x)
				last_x = maxi(last_x, x)

		if last_x <= first_x:
			continue
		_mask_profile.append(Vector3(
			float(row) / float(image_height),
			float(first_x) / float(image_width),
			float(last_x + 1) / float(image_width)
		))

	if _mask_profile.size() < 8:
		_mask_profile.clear()
		push_warning("Masked vial: dedicated mask does not contain a usable chamber profile.")
		return

	queue_redraw()


func _mask_bounds_at(y_ratio: float) -> Vector2:
	if _mask_profile.is_empty():
		return Vector2.ZERO
	if y_ratio <= _mask_profile[0].x:
		return Vector2(_mask_profile[0].y, _mask_profile[0].z)

	for index in range(_mask_profile.size() - 1):
		var a: Vector3 = _mask_profile[index]
		var b: Vector3 = _mask_profile[index + 1]
		if y_ratio <= b.x:
			var weight: float = clampf(
				(y_ratio - a.x) / maxf(0.0001, b.x - a.x),
				0.0,
				1.0
			)
			return Vector2(lerpf(a.y, b.y, weight), lerpf(a.z, b.z, weight))

	var last: Vector3 = _mask_profile[-1]
	return Vector2(last.y, last.z)


func _get_vessel_rect() -> Rect2:
	if asset_definition == null:
		return super._get_vessel_rect()
	return asset_definition.get_artwork_rect(size)


func get_mouth_local() -> Vector2:
	if asset_definition == null:
		return super.get_mouth_local()
	return asset_definition.get_mouth_local(size)


func get_mouth_hit_radius() -> Vector2:
	if asset_definition == null:
		return super.get_mouth_hit_radius()
	return asset_definition.get_mouth_hit_radius_local(size)


func get_liquid_surface_position_in_parent() -> Vector2:
	var rect := _get_vessel_rect()
	var top_ratio: float = asset_definition.fill_top if asset_definition != null else 0.265
	var bottom_ratio: float = asset_definition.fill_bottom if asset_definition != null else 0.79
	var layer_height: float = (bottom_ratio - top_ratio) / float(CAPACITY)
	var surface_ratio: float = bottom_ratio - layer_height * clampf(
		_liquid_level,
		0.0,
		float(CAPACITY)
	)
	var surface_y: float = rect.position.y + rect.size.y * surface_ratio
	surface_y += _get_surface_wave_offset(0.0)
	var local_surface := Vector2(rect.get_center().x, surface_y)
	return position + get_point_local_for_pose(
		local_surface,
		Vector2(_lift, _tilt),
		_draw_scale
	)


func _draw_liquid(_rect: Rect2) -> void:
	if asset_definition == null or _mask_profile.size() < 8:
		return
	if _visual_contents.is_empty() or _liquid_level <= 0.001:
		return

	var rect := _get_vessel_rect()
	var top_ratio: float = asset_definition.fill_top
	var bottom_ratio: float = asset_definition.fill_bottom
	var layer_height: float = (bottom_ratio - top_ratio) / float(CAPACITY)
	var visible_layers: int = mini(int(ceil(_liquid_level)), _visual_contents.size())

	for layer_index in range(visible_layers):
		var amount: float = clampf(_liquid_level - float(layer_index), 0.0, 1.0)
		if amount <= 0.001:
			continue
		var layer_bottom: float = bottom_ratio - float(layer_index) * layer_height
		var layer_top: float = layer_bottom - layer_height * amount
		var essence: String = String(_visual_contents[layer_index])
		var liquid_color: Color = _palette.get(essence, Color(0.45, 0.78, 0.75, 1.0))
		_draw_masked_liquid_band(
			rect,
			layer_top,
			layer_bottom,
			liquid_color,
			layer_index == visible_layers - 1,
			layer_index == 0
		)


func _draw_masked_liquid_band(
	rect: Rect2,
	top_ratio: float,
	bottom_ratio: float,
	liquid_color: Color,
	is_surface: bool,
	is_bottom: bool
) -> void:
	var bottom_y: float = rect.position.y + rect.size.y * bottom_ratio
	var top_y: float = rect.position.y + rect.size.y * top_ratio
	if not is_bottom:
		bottom_y += 0.8
	if bottom_y - top_y <= 1.0:
		return

	var top_edge := PackedVector2Array()
	for index in range(LIQUID_SURFACE_SAMPLES + 1):
		var t: float = float(index) / float(LIQUID_SURFACE_SAMPLES)
		var x_norm: float = t * 2.0 - 1.0
		var wave: float = _get_surface_wave_offset(x_norm) * 0.30 if is_surface else 0.0
		var y: float = clampf(top_y + wave, top_y - 2.0, bottom_y - 0.8)
		var bounds := _mask_bounds_at(clampf(
			(y - rect.position.y) / rect.size.y,
			asset_definition.fill_top,
			asset_definition.fill_bottom
		))
		var left_x: float = rect.position.x + rect.size.x * bounds.x + LIQUID_WALL_INSET
		var right_x: float = rect.position.x + rect.size.x * bounds.y - LIQUID_WALL_INSET
		top_edge.append(Vector2(lerpf(left_x, right_x, t), y))

	if top_edge.size() < 2:
		return
	var polygon := top_edge.duplicate()
	var right_top_y: float = top_edge[-1].y
	var left_top_y: float = top_edge[0].y

	for side_index in range(1, 49):
		var t: float = float(side_index) / 48.0
		var y: float = lerpf(right_top_y, bottom_y, t)
		var bounds := _mask_bounds_at(clampf(
			(y - rect.position.y) / rect.size.y,
			asset_definition.fill_top,
			asset_definition.fill_bottom
		))
		polygon.append(Vector2(
			rect.position.x + rect.size.x * bounds.y - LIQUID_WALL_INSET,
			y
		))

	var bottom_bounds := _mask_bounds_at(bottom_ratio)
	polygon.append(Vector2(
		rect.position.x + rect.size.x * bottom_bounds.x + LIQUID_WALL_INSET,
		bottom_y
	))

	for side_index in range(1, 48):
		var t: float = float(side_index) / 48.0
		var y: float = lerpf(bottom_y, left_top_y, t)
		var bounds := _mask_bounds_at(clampf(
			(y - rect.position.y) / rect.size.y,
			asset_definition.fill_top,
			asset_definition.fill_bottom
		))
		polygon.append(Vector2(
			rect.position.x + rect.size.x * bounds.x + LIQUID_WALL_INSET,
			y
		))

	var fill_color: Color = liquid_color.lerp(liquid_color.lightened(0.12), 0.08)
	draw_colored_polygon(polygon, fill_color)

	if is_surface:
		var surface_points := PackedVector2Array()
		for index in range(17):
			var t: float = float(index) / 16.0
			var x_norm: float = t * 2.0 - 1.0
			var wave_y: float = top_y + _get_surface_wave_offset(x_norm) * 0.30
			var bounds := _mask_bounds_at(clampf(
				(wave_y - rect.position.y) / rect.size.y,
				asset_definition.fill_top,
				asset_definition.fill_bottom
			))
			var left_x: float = rect.position.x + rect.size.x * bounds.x + LIQUID_WALL_INSET
			var right_x: float = rect.position.x + rect.size.x * bounds.y - LIQUID_WALL_INSET
			surface_points.append(Vector2(lerpf(left_x, right_x, t), wave_y))
		var surface_glint := fill_color
		surface_glint.a = 0.18
		draw_polyline(surface_points, surface_glint, 1.0, true)


func _draw_glass_back(_rect: Rect2) -> void:
	if asset_definition != null and asset_definition.glass_back != null:
		draw_texture_rect(asset_definition.glass_back, _get_vessel_rect(), false)


func _draw_glass_overlay() -> void:
	if asset_definition != null and asset_definition.glass_front != null:
		draw_texture_rect(asset_definition.glass_front, _get_vessel_rect(), false)
