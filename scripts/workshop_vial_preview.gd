extends Control

const BottleScript = preload("res://scripts/alchemy_bottle.gd")

# The bottle script uses a 116 x 365 internal drawing coordinate system.
# Scale the whole control to the approved guide footprint instead of resizing
# its internal drawing area, which would offset the liquid geometry.
const VIAL_SOURCE_SIZE := Vector2(116.0, 365.0)
const VIAL_DISPLAY_SCALE := 0.685
const SLOT_BOTTOM_CENTERS: Array[Vector2] = [
	Vector2(207.0, 860.0),
	Vector2(309.0, 860.0),
	Vector2(411.0, 860.0),
	Vector2(513.0, 860.0)
]
const VIAL_LABELS: Array[String] = ["VIAL I", "VIAL II", "VIAL III", "VIAL IV"]

const PALETTE: Dictionary = {
	"tide": Color(0.24, 0.77, 0.76, 1.0),
	"moon": Color(0.66, 0.54, 0.91, 1.0),
	"ember": Color(0.96, 0.51, 0.24, 1.0)
}

# Same starting contents as the current sorting prototype. Bottom-to-top.
const INITIAL_CONTENTS: Array = [
	["moon", "tide", "ember", "moon"],
	["tide", "ember", "moon", "tide"],
	["ember", "moon", "tide", "ember"],
	[]
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_vials()


func _build_vials() -> void:
	for index in range(SLOT_BOTTOM_CENTERS.size()):
		var vial := Control.new()
		vial.name = "SortingVial%d" % (index + 1)
		vial.set_script(BottleScript)
		vial.size = VIAL_SOURCE_SIZE
		vial.scale = Vector2.ONE * VIAL_DISPLAY_SCALE

		var visual_size := VIAL_SOURCE_SIZE * VIAL_DISPLAY_SCALE
		var bottom_center: Vector2 = SLOT_BOTTOM_CENTERS[index]
		vial.position = Vector2(
			bottom_center.x - visual_size.x * 0.5,
			bottom_center.y - visual_size.y
		)
		vial.z_index = 10
		vial.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(vial)

		vial.call(
			"setup",
			index,
			VIAL_LABELS[index],
			index,
			PALETTE,
			INITIAL_CONTENTS[index]
		)
