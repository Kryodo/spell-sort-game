extends "res://scripts/fantasy_alchemy_bottle.gd"

# Reference-matched rounded laboratory bottle. Liquid and vessel motion remain
# shared with the existing sorting system; the glass surface is a separate
# gradient-rich vector overlay so reflections read as glass, not drawn stripes.

const GLASS_ART: Texture2D = preload("res://assets/environments/SpellSort_LabBottle_Glass.svg")
const BASE_REFRACTION_ART: Texture2D = preload("res://assets/environments/SpellSort_LabBottle_BaseRefraction.svg")
const BOTTLE_BODY_WIDTH_RATIO := 0.70

var _pour_refraction_visible := true
const BOTTLE_BODY_TOP_RATIO := 0.055
const BOTTLE_BODY_HEIGHT_RATIO := 0.89


func _profile_points() -> Array[Vector2]:
	# Short neck, relaxed shoulder, broad body and a full curved glass foot.
	return [
		Vector2(0.000, 0.190),
		Vector2(0.035, 0.192),
		Vector2(0.075, 0.200),
		Vector2(0.110, 0.225),
		Vector2(0.145, 0.285),
		Vector2(0.190, 0.360),
		Vector2(0.245, 0.435),
		Vector2(0.295, 0.470),
		Vector2(0.345, 0.480),
		Vector2(0.735, 0.480),
		Vector2(0.815, 0.475),
		Vector2(0.875, 0.455),
		Vector2(0.920, 0.425),
		Vector2(0.955, 0.385),
		Vector2(0.980, 0.335),
		Vector2(1.000, 0.280)
	]


func _get_vessel_rect() -> Rect2:
	var bottle_width := size.x * BOTTLE_BODY_WIDTH_RATIO
	var bottle_height := size.y * BOTTLE_BODY_HEIGHT_RATIO
	return Rect2(
		Vector2((size.x - bottle_width) * 0.5, size.y * BOTTLE_BODY_TOP_RATIO),
		Vector2(bottle_width, bottle_height)
	)


func set_front_mouth_lip_active(_active: bool) -> void:
	# The glass lip is included in the vector overlay, so no image-crop overlay
	# is needed when a pouring stream crosses the opening.
	pass

func set_pour_refraction_visible(visible: bool) -> void:
	if _pour_refraction_visible == visible:
		return
	_pour_refraction_visible = visible
	queue_redraw()



func _draw_glass_back(rect: Rect2) -> void:
	# Keep the established translucent body shading underneath the live liquid.
	super._draw_glass_back(rect)


func _draw_glass_overlay() -> void:
	# The main vector overlay supplies the bottle contour, wall reflections,
	# shoulder light, rounded base and rolled mouth.
	draw_texture_rect(GLASS_ART, Rect2(Vector2.ZERO, size), false, Color.WHITE)
	# The far-base Fresnel is visible only through empty glass. Any liquid
	# in the vessel obscures this optical detail, even after the pour has ended.
	if _pour_refraction_visible and _liquid_level <= 0.001:
		draw_texture_rect(BASE_REFRACTION_ART, Rect2(Vector2.ZERO, size), false, Color.WHITE)
