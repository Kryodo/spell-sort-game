# Dark sorting space — Qwen vial composition study

Open `scenes/dark_sorting_slots_prototype.tscn` in Godot and run it with **F6**. The project startup scene remains unchanged.

## Current vessel candidate

The dark prototype currently uses `asset_fantasy_alchemy_bottle.gd` with `assets/bottles/SpellSort_Vial_2.png`.

Vial 2 is a provisional composition candidate, not a locked art direction. It has a clear central front window with subtle illustrated front reflections and a different silhouette from Vial 1. The artwork is fitted uniformly to the test vial height, retaining its square source aspect ratio.

The mouth hit area, liquid chamber rectangle and liquid side profile are adjusted to Vial 2's narrow neck, broad body and tapered lower transition. The slot base alignment is also matched to its pedestal. The current layout still uses the same four-vial test arrangement and preserves the improved spring-based dragging.

## Liquid and compositing

The PNG is drawn above the independently rendered liquid. The old procedural glass-back fill and SVG vial overlays are bypassed for this test. The transparent central window should let the liquid remain vivid, while the sparse painted reflections retain some front-surface glass definition.

The liquid chamber now uses a Vial 2-specific inner contour with a much smaller wall inset. Each essence layer is drawn as a continuous curved polygon instead of stacked horizontal rectangles, so the liquid follows the full tapered window rather than looking like a narrow stack of blocks. The surface retains its animated wave, and the four essence colours remain separate. This pass is for checking composition, style compatibility, transparency, liquid visibility and pour alignment in the actual Godot scene. No decision has been made to lock this vessel style.

## Pickup and pouring

- The player lifts a vial and guides its opening to a compatible receiving opening.
- Target validity uses the artwork-aligned mouth position and hit radius.
- Movement follows the pointer with a small spring response; the vessel pose and scale ease instead of snapping.
- Pour staging aligns the source mouth over the target. The stream follows a curved path to the receiving liquid surface, with a soft glow, travelling droplets and a small impact ripple.
- Existing sorting rules remain authoritative through `_get_transfer_details()`, including recipe, pipette, seal and transmutation requirements.

## Atmosphere and UI

The dark prototype retains its animated candles, drifting motes, adaptive HUD, contextual action icons and nested bottom sheet. No changes are made to the main interaction scene or project startup scene.

## Validation

Run the scene in Godot and inspect:
- Whether Vial 2's silhouette and glass treatment fit the environment.
- Whether the transparent central window shows the liquid colour clearly.
- Whether the liquid stays inside the visible chamber at empty, partial and full levels.
- Whether the mouth position matches drag targeting and pouring.
- Whether the pedestal aligns with the slot marker and the four-vial spacing feels balanced.
- Pickup, release without a target, a normal pour, undo and restart.

Runtime validation is required in Godot. This repository-side integration has not been launched in the Godot runtime.
