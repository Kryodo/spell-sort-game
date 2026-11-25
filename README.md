# Spell Sort — Illustrated Workbench Sorting Prototype

This branch resets the active game presentation around the sorting mechanic. It uses a generated 2D environment illustration as the full-screen scene and keeps the vial sorting, pouring, undo, reset, and completion behaviour as live Godot controls.

## Run

Open the project in Godot 4.7 and run the configured main scene:

`res://scenes/alchemy_interaction_test.tscn`

The project remains portrait-first at 720 × 1280.

## Environment artwork

The four uploaded environment options are kept in `assets/environments/`:

- `SpellSort_Workbench_Variant_1.png`
- `SpellSort_Workbench_Variant_2.png`
- `SpellSort_Workbench_Variant_3.png`
- `SpellSort_Workbench_Variant_4.png`

Variant 4 is currently selected as the full-screen background in `scripts/alchemy_interaction_test.gd`. The image is used as artwork, not reconstructed with 3D meshes or a shared material shader.

## Sorting gameplay

The sorting activity remains implemented in:

- `scripts/alchemy_interaction_test.gd` — level state, drag/drop, pour animation, stream, undo/reset, completion.
- `scripts/alchemy_bottle.gd` — live glass vessel drawing, animated liquid, slosh, lift and tilt.
- `scenes/alchemy_interaction_test.tscn` — screen root.

The current test level has four vessels, three essences and four measures per essence. Drag a vessel and align its open mouth with a valid receiving vessel. A valid transfer moves the matching contiguous run at the top of the source. Undo and Reset are available in the bottom HUD.

## Presentation approach

- One illustrated 2D environment background.
- Live vials and liquid remain independently rendered and interactive.
- No procedural 3D room, low-poly props, camera panning or shared painterly shader.
- The environment artwork stays visible; the HUD uses small translucent panels and the vials are drawn directly over the tabletop.

The initial vial placement is a first alignment pass. Run the scene locally and adjust the vial row position/scale against the exact Variant 4 composition if required.

## Validation

This code update was made through the GitHub repository tools; Godot 4.7 is not available in this environment, so a runtime launch and touch-interaction pass still need local confirmation.
