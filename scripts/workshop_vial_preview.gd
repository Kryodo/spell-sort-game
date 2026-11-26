extends Control

const BottleScript = preload("res://scripts/alchemy_bottle.gd")

# Keep the bottle script at its native 116 x 365 drawing dimensions.
const VIAL_SOURCE_SIZE := Vector2(116.0, 365.0)
const VIAL_GAP := 18.0
const VIAL_TOP_Y := 500.0
const VIAL_ROW_WIDTH := VIAL_SOURCE_SIZE.x * 4.0 + VIAL_GAP * 3.0
const VIAL_ROW_START_X := (720.0 - VIAL_ROW_WIDTH) * 0.5
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
	for index in range(4):
		var vial := Control.new()
		vial.name = "SortingVial%d" % (index + 1)
		vial.set_script(BottleScript)
		vial.size = VIAL_SOURCE_SIZE
		# Match the original in-world sorting prototype: full native vial size
		# and the same 18 px gap. The row sits slightly higher so the vials
		# overlap the rear tabletop props as deliberate foreground objects.
		vial.position = Vector2(
			VIAL_ROW_START_X + float(index) * (VIAL_SOURCE_SIZE.x + VIAL_GAP),
			VIAL_TOP_Y
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
