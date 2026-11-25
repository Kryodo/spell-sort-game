# Spell Sort — Square Hub and In-World Alchemy Prototype

This branch tests a hybrid 2.5D direction: a continuous 3D laboratory and separate chapter environments, with the proven 2D vial-sorting interaction presented as an activity on the laboratory workbench. This is an evaluation prototype, not a final art-direction or production-art commitment.

## Run the prototype

Open the project in Godot 4.7 and run the configured main scene: `res://scenes/lab_room_prototype.tscn`.

## Laboratory hub — four connected areas

The laboratory is one enclosed, square-ish environment with four areas arranged around a shared central space:

- Ingredient storage — potion shelves, supplies and crates.
- Research archive — bookcases, field notes, a map and a crystal.
- Restoration corner — herb bench, growing plants and a seed tray.
- Main laboratory — workbench, cauldron, Grimoire and experiment props.

Drag or swipe in both directions to pan smoothly around the environment. Camera movement is bounded so it stays inside the laboratory rather than exposing empty space outside the room. The fireplace provides a central warm focal point.

Tap an interactable object to inspect it or open its activity. The four areas are not separate scenes or fixed camera stops.

Implementation: `scripts/lab_room_prototype.gd` and `scenes/lab_room_prototype.tscn`.

## Main sorting activity — 2D interaction on the 3D workbench

Tap the main workbench and choose **Begin Experiment**. The camera moves closer to the actual 3D table, and the 2D sorting interaction fades into view over it. The laboratory remains loaded behind the puzzle, rather than changing to a separate full-screen scene. **Back to Lab** fades the puzzle away and returns the camera to its saved hub view.

The original 2D mechanics are retained:

- Four vessels, three essences, four measures per essence.
- Drag a vial and align its open mouth with a receiving vial.
- Transfer the matching contiguous top run, respecting vessel capacity.
- Animated liquid surfaces, pouring stream, splashes, vial tilt and settling.
- Undo, Reset and completion feedback.

The in-world mode uses a more compact vial scale and a lighter interface so the tabletop remains visible. The standalone scene is still available unchanged for comparison: open `scenes/alchemy_interaction_test.tscn` and press **F6**.

The 2D bottle renderer is in `scripts/alchemy_bottle.gd`; the puzzle presentation and behaviour are in `scripts/alchemy_interaction_test.gd`.

## Early painterly-stylized material and silhouette study

The new `shaders/painterly_surface.gdshader` adds restrained procedural pigment variation, soft surface noise, roughness and controlled emission to both the hub and Verdant Hollow chapter materials. The study also begins moving key props away from primitive silhouettes:

- The cauldron uses a rounded body, foot and softer handles.
- Potion props use rounded bodies, shoulders and corks.
- The restoration corner uses clustered plant forms and a seed tray.
- A shared warm fireplace focal point contrasts with the cooler ambient lighting.

This is an initial material/silhouette direction test, not finished painterly art. The assets still use procedural placeholder geometry; they do not yet have hand-authored painted textures or production-ready silhouettes. The purpose is to assess the direction at the actual hub camera scale before creating a larger asset set.

## Verdant Hollow — chapter prototype

Verdant Hollow remains a separate 3D chapter environment with its own atmosphere and landmarks. It includes a small rune-order discovery activity:

1. Begin the Ancient Gate trial.
2. Remember the displayed sequence: **Moon → Ember → Tide**.
3. Find and activate the three runes in that order.
4. Awaken the altar and claim the Verdant Seed.

**Back to Lab** returns to the hub.

Implementation: `scripts/chapter_forest_prototype.gd` and `scenes/chapter_forest_prototype.tscn`.

## 3D vial study — comparison only

The earlier 3D vial experiment remains available separately: open `scenes/alchemy_3d_experiment.tscn` and press **F6**. It is not the main workbench route.

## What to evaluate

1. Does the 2×2 room read as one connected laboratory, and does free two-axis panning feel natural?
2. Do all four areas feel like useful places to explore rather than four disconnected corners?
3. Does the workbench transition make the 2D puzzle feel like an activity taking place in the 3D world?
4. Are the vials legible at the new scale, and does enough of the tabletop/environment remain visible?
5. Does the new surface treatment and the rounder prop silhouettes move the visuals in the intended direction, or do they still feel too geometric?

## Validation and limitations

The branch has been updated structurally, but it still needs a Godot 4.7 runtime launch and interaction pass. The camera framing, clickable areas, overlay alignment, and shader appearance must be checked locally. No Godot runtime validation was performed during this code update.

The painterly shader is deliberately a first-pass procedural material study; it does not replace a properly designed asset set. The hub and chapter still need distinct, readable, production-quality assets.
