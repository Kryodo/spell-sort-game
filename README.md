# Spell Sort — Hybrid World and Alchemy Prototype

This branch explores a hybrid 2.5D direction: 3D laboratory and chapter environments, with the proven 2D sorting interaction retained as the main alchemy activity. This is a playable direction test, not a final art-direction or production-art commitment.

## Run the prototype

Open the project in Godot 4.7 and run it. The configured main scene is `res://scenes/lab_room_prototype.tscn`.

## Laboratory hub

The laboratory is one continuous room rather than three fixed camera stops.

- Drag or swipe to pan around the room within bounded camera limits.
- Tap objects to inspect or open their activities.
- The workbench launches the original 2D sorting puzzle with a brief fade and close-up camera zoom, making the change of presentation intentional.
- The world map / Verdant Hollow entrance opens the chapter environment.
- The ingredient storage and research archive remain parts of the same room, not separate page scenes.

Main implementation: `scripts/lab_room_prototype.gd` and `scenes/lab_room_prototype.tscn`.

## Main sorting activity — 2D

The hub workbench now launches `scenes/alchemy_interaction_test.tscn`, retaining the previous working puzzle presentation and mechanics:

- Four vessels, three essences, four measures per essence.
- Drag a vial and align its mouth with a receiving vial.
- Transfer the matching contiguous top run, respecting vessel capacity.
- The liquid surface, pouring stream, splashes, vial tilt and settling animation are preserved.
- Undo, Reset and completion feedback are included.
- **Back to Lab** returns to the continuous hub.

The 2D bottle renderer is in `scripts/alchemy_bottle.gd`.

## 3D vial study — comparison only

The earlier 3D experiment remains available as a separate comparison scene: `scenes/alchemy_3d_experiment.tscn`.

To run it directly in Godot, open that scene and press **F6** (Run Current Scene). It is not the main workbench route in this hybrid build.

Implementation: `scripts/alchemy_3d_experiment.gd` and `scenes/alchemy_3d_experiment.tscn`.

## Verdant Hollow — playable discovery loop

Verdant Hollow is a separate 3D chapter environment with its own lighting, atmosphere and landmarks. It now includes a small environmental activity:

1. Tap the Ancient Gate and begin the rune trial.
2. Remember the displayed order: **Moon → Ember → Tide**.
3. Find and tap the three glowing rune stones in that order. An incorrect input resets the sequence.
4. The altar awakens and reveals its seed.
5. Return to the altar and claim the Verdant Seed to finish the chapter discovery.

**Back to Lab** remains available from the chapter header.

Implementation: `scripts/chapter_forest_prototype.gd` and `scenes/chapter_forest_prototype.tscn`.

## Other preserved prototype

- `scenes/main.tscn`: original sprite-based sorting prototype.

## What to evaluate next

1. Does the continuously pannable hub feel like one enclosed, inviting place?
2. Does the old 2D sorting activity feel natural as the workbench activity, despite using a different presentation from the 3D world?
3. Is the Verdant Hollow rune activity engaging enough to establish a chapter gameplay loop?
4. Do the 3D environment and 2D puzzle feel like parts of the same game?
5. What needs to change in silhouette, proportions, material treatment and lighting to reach the intended painterly-stylized asset direction?

## Known limitations and validation

The hub and chapter still use procedural placeholder geometry; object silhouettes, proportions, material detail and painterly art treatment have **not** been upgraded in this pass. The 3D vial study also remains experimental.

The scenes and scripts have been updated on this branch, but a Godot 4.7 runtime launch and interaction pass still need to be performed locally. No final art-direction or production-pipeline decision has been made.
