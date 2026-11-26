extends "res://scripts/fantasy_alchemy_bottle.gd"

# Current composition candidate: Qwen's second transparent-front vessel.
# The style remains provisional until checked inside the workshop environment.
const VIAL_ART: Texture2D = preload("res://assets/bottles/SpellSort_Vial_2.png")


func get_mouth_local() -> Vector2:
	# The open rim is near 6.5% of the square source image height.
	return Vector2(size.x * 0.5, size.y * 0.065)


func get_mouth_hit_radius() -> Vector2:
	# Match the relatively broad mouth while keeping alignment precise vertically.
	return Vector2(size.y * 0.105, size.y * 0.04)


func _get_vessel_rect() -> Rect2:
	# Vial 2 has a tall, narrow neck and a large central transparent window.
	# The inherited four-layer interval maps from roughly 26.5% to 76% of
	# the source image, leaving the shoulders and pedestal clear.
	var width: float = size.x
	var height: float = size.y * 0.79
	return Rect2(
		Vector2((size.x - width) * 0.5, size.y * 0.02),
		Vector2(width, height)
	)


func _profile_points() -> Array[Vector2]:
	# Half-widths follow the hourglass-like transparent chamber of Vial 2.
	# The fill narrows near the upper shoulder and the lower glass transition.
	return [
		Vector2(0.00, 0.035),
		Vector2(0.20, 0.065),
		Vector2(0.28, 0.095),
		Vector2(0.34, 0.155),
		Vector2(0.42, 0.225),
		Vector2(0.53, 0.255),
		Vector2(0.65, 0.245),
		Vector2(0.77, 0.215),
		Vector2(0.87, 0.155),
		Vector2(0.94, 0.075),
		Vector2(1.00, 0.025)
	]


func _draw_glass_back(_rect: Rect2) -> void:
	# The Qwen asset supplies the rear glass and outer painted reflections.
	# Keep the transparent body clear for the live liquid drawn underneath.
	pass


func _draw_glass_overlay() -> void:
	# Preserve the square source aspect ratio while fitting the artwork to the
	# vial's height. Its transparent margins leave the actual silhouette aligned
	# with the interaction control and the wider gameplay slot.
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
