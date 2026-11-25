# Spell Sort — Illustrated Workbench Sorting Prototype

This branch presents the core 2D sorting activity in a single illustrated alchemy-workbench setting. The background is artwork; the vessels, liquids, pouring and puzzle state remain live and interactive in Godot.

## Run

Open the project in Godot 4.7 and run the configured main scene:

`res://scenes/alchemy_interaction_test.tscn`

The design viewport is portrait, 720 × 1280.

## Environment artwork

The selected full-screen background is:

`assets/environments/SpellSort_Workbench.png`

The source image is 768 × 1376 and is displayed with aspect-cover scaling. The tabletop is part of the background artwork; the scene does not add a second tabletop, slot panel or pedestal layer over it.

## Four-vessel layout

Four upright vessels are arranged in one centred horizontal row on the tabletop. All four use the same control size and the same scale; none is tilted or depth-scaled while resting.

- Vessel control size: 116 × 365
- Horizontal gap: 18
- Row Y position: 520 in the 720 × 1280 design viewport
- The vessel bodies, openings and resting liquid surfaces remain front-facing and level

The row is intentionally simple and readable. Perspective comes from the illustrated workbench background, not from transforming the individual vessels.

## Sorting gameplay

The sorting activity is implemented in:

- `scripts/alchemy_interaction_test.gd` — level state, drag/drop, pour animation, stream, undo/reset and completion.
- `scripts/alchemy_bottle.gd` — live front-facing glass vessel drawing, animated liquid, slosh, lift and tilt.
- `scenes/alchemy_interaction_test.tscn` — screen root.

The current test level has four vessels, three essences and four measures per essence. Drag a vessel and align its open mouth with a valid receiving vessel. A valid transfer moves the matching contiguous run at the top of the source. Undo and Reset are available in the bottom HUD.

A compact translucent HUD sits at the top and bottom of the screen. It leaves the tabletop visible and does not draw artificial bottle slots.

## Presentation approach

- One illustrated 2D environment background.
- Live vessels and liquid remain independently rendered and interactive.
- No procedural 3D room, low-poly props, camera panning or shared painterly shader.
- All resting vessels share one front-facing orientation and scale.

## Validation and limitations

The scene is configured for a 720 × 1280 portrait viewport. The background source is 768 × 1376, so its aspect ratio is close to the design viewport. Final visual alignment, drag targeting, mouth alignment, liquid streams, undo, reset and completion still need a local Godot 4.7 runtime check.

Godot 4.7 was not available in the editing environment, so a runtime launch and interaction pass have not been performed here.
