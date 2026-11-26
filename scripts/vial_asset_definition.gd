extends Resource
class_name VialAssetDefinition

## Reusable contract for an illustrated vial.
## All anchors and fill limits are normalized to the source artwork rectangle.
## The liquid mask is a separate, authored image: opaque white = liquid may occupy
## this pixel; transparent/black = liquid must not occupy it.

@export_group("Glass layers")
@export var glass_back: Texture2D
@export var glass_front: Texture2D
@export var liquid_mask: Texture2D

@export_group("Artwork")
@export var source_size: Vector2i = Vector2i(1024, 1024)
@export_enum("Contain", "Cover") var scale_mode: String = "Cover"
@export var mouth_position: Vector2 = Vector2(0.5, 0.065)
@export var mouth_hit_radius: Vector2 = Vector2(0.105, 0.04)

@export_group("Liquid chamber")
@export_range(0.0, 1.0, 0.001) var fill_top: float = 0.265
@export_range(0.0, 1.0, 0.001) var fill_bottom: float = 0.79
@export_range(0.0, 1.0, 0.01) var mask_alpha_threshold: float = 0.5

func is_valid() -> bool:
	if source_size.x <= 0 or source_size.y <= 0:
		return false
	if liquid_mask == null:
		return false
	if fill_bottom <= fill_top:
		return false
	if mouth_position.x < 0.0 or mouth_position.x > 1.0:
		return false
	if mouth_position.y < 0.0 or mouth_position.y > 1.0:
		return false
	return true

func get_artwork_rect(control_size: Vector2) -> Rect2:
	var scale_factor: float
	if scale_mode == "Cover":
		scale_factor = maxf(
			control_size.x / float(source_size.x),
			control_size.y / float(source_size.y)
		)
	else:
		scale_factor = minf(
			control_size.x / float(source_size.x),
			control_size.y / float(source_size.y)
		)
	var draw_size := Vector2(source_size) * scale_factor
	return Rect2((control_size - draw_size) * 0.5, draw_size)

func get_mouth_local(control_size: Vector2) -> Vector2:
	var artwork_rect := get_artwork_rect(control_size)
	return artwork_rect.position + mouth_position * artwork_rect.size

func get_mouth_hit_radius_local(control_size: Vector2) -> Vector2:
	var artwork_rect := get_artwork_rect(control_size)
	return mouth_hit_radius * artwork_rect.size
