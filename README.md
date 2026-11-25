# Spell Sort — Illustrated Workbench Sorting Prototype

This branch resets the active presentation around the sorting mechanic. It uses generated 2D environment artwork as the full-screen setting and keeps the vials, liquids, pouring and puzzle state live in Godot.

## Run

Open the project in Godot 4.7 and run the configured main scene:

`res://scenes/alchemy_interaction_test.tscn`

The design viewport is portrait, 720 × 1280.

## Environment artwork

The four uploaded environment options are kept in `assets/environments/`:

- `SpellSort_Workbench_Variant_1.png`
- `SpellSort_Workbench_Variant_2.png`
- `SpellSort_Workbench_Variant_3.png`
- `SpellSort_Workbench_Variant_4.png`

Variant 4 is selected as the full-screen background in `scripts/alchemy_interaction_test.gd`. The image is used directly as artwork, not reconstructed with 3D meshes or a shared material shader.

## Perspective-aligned sorting layout

The four vessels remain upright, but their resting base centres follow the workbench's projected long axis. Gemini's image analysis supplied these provisional normalized anchor points:

| Vessel | Base anchor (X%, Y%) | Depth scale |
|---|---:|---:|
| I — farthest / upper-right | 63.0%, 44.5% | 0.94 |
| II | 50.5%, 50.0% | 0.98 |
| III | 38.5%, 55.0% | 1.02 |
| IV — nearest / lower-left | 26.5%, 60.0% | 1.06 |

These are estimates, not exact image metadata. The anchors are normalized to the 9:16 design viewport so they can be scaled with the viewport dimensions.

The glass mouth and foot ellipses, internal liquid-layer boundaries and contact shadows follow a provisional -24° tabletop axis. The vessel bodies themselves are not rotated; only their horizontal-plane details follow the illustrated perspective. Warm highlights are emphasized on the upper-right glass edge to relate them to the scene lighting.

Touch detection now tests the visible vessel profile rather than the old broad rectangular control bounds. Vial draw order follows depth, and returns/undo/reset restore the correct order.

## Sorting gameplay

The sorting activity remains implemented in:

- `scripts/alchemy_interaction_test.gd` — level state, drag/drop, pour animation, stream, undo/reset and completion.
- `scripts/alchemy_bottle.gd` — live glass vessel drawing, animated liquid, slosh, lift, tilt and perspective-aligned details.
- `scenes/alchemy_interaction_test.tscn` — screen root.

The current test level has four vessels, three essences and four measures per essence. Drag a vessel and align its open mouth with a valid receiving vessel. A valid transfer moves the matching contiguous run at the top of the source. Undo and Reset are available in the bottom HUD.

The artwork is not obscured by a fake workbench panel, slot panels or pedestals. A compact translucent HUD sits at the top and bottom of the screen.

## Presentation approach

- One illustrated 2D environment background.
- Live vials and liquid remain independently rendered and interactive.
- No procedural 3D room, low-poly props, camera panning or shared painterly shader.
- Perspective cues are applied to the vessel details and placement, while silhouettes stay upright and readable.

## Validation and limitations

This pass uses approximate normalized measurements from image analysis; final alignment must be judged in the actual Godot runtime against Variant 4. In particular, check the four base positions, vessel size progression, touch targets, mouth alignment and liquid stream during diagonal pours.

Godot 4.7 was not available in the editing environment, so a runtime launch and touch-interaction pass still need local confirmation.
