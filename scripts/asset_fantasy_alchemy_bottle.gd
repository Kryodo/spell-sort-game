extends "res://scripts/fantasy_alchemy_bottle.gd"

# Single Qwen-generated vessel used to validate the real glass artwork against
# the existing live liquid and interaction pipeline.
const VIAL_ART: Texture2D = preload("res://assets/bottles/SpellSort_Vial_1.png")


func get_mouth_local() -> Vector2:
	# The sprite is drawn as a height-fitted square; its open lip sits just
	# above the shoulder, at approximately 11% of the source image height.
	return Vector2(size.x * 0.5, size.y * 0.11)


func get_mouth_hit_radius() -> Vector2:
	return Vector2(size.y * 0.09, size.y * 0.05)


func _get_vessel_rect() -> Rect2:
	# The artwork's clear inner chamber occupies roughly y=34%-80% of the
	# square source image. Map the inherited 4-layer fill interval to that area.
	var width: float = size.x * 0.91
	var height: float = size.y * 0.733
	return Rect2(
		Vector2((size.x - width) * 0.5, size.y * 0.118),
		Vector2(width, height)
	)


func _profile_points() -> Array[Vector2]:
	# Normalized half-widths follow the visible inner chamber of SpellSort_Vial_1.
	return [
		Vector2(0.00, 0.15),
		Vector2(0.18, 0.18),
		Vector2(0.30, 0.245),
		Vector2(0.42, 0.285),
		Vector2(0.60, 0.30),
		Vector2(0.76, 0.285),
		Vector2(0.89, 0.245),
		Vector2(1.00, 0.18)
	]


func _draw_glass_back(_rect: Rect2) -> void:
	# The Qwen asset already contains the rear glass and its painted reflections.
	# Do not add the old procedural glass fill behind it.
	pass


func _draw_glass_overlay() -> void:
	# Preserve the square source aspect ratio while fitting the artwork to the
	# vial's height. Transparent margins intentionally extend beyond the control
	# width; the actual glass silhouette aligns with the widened hit/slot width.
	var source_size: Vector2 = VIAL_ART.get_size()
	var draw_scale: float = size.y / source_size.y
	var draw_size: Vector2 = source_size * draw_scale
	var draw_position := Vector2(
		(size.x - draw_size.x) * 0.5,
		(size.y - draw_size.y) * 0.5
	)
	draw_texture_rect(
		VIAL_ART,
		Rect2(draw_position, draw_size),
		false,
		Color.WHITE
	)
