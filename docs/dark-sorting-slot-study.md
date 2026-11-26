# Dark sorting space — Qwen vial composition and liquid mask study

Open `scenes/dark_sorting_slots_prototype.tscn` in Godot and run it with **F6**. The project startup scene remains unchanged.

## Current vessel candidate

The dark prototype currently uses `asset_fantasy_alchemy_bottle.gd` with `assets/bottles/SpellSort_Vial_2.png`.

Vial 2 remains a provisional composition candidate, not a locked art direction. It has a transparent central front window with subtle illustrated reflections and a distinctive tapered silhouette.

## Alpha-derived liquid window

The previous manually estimated liquid profile did not match the visible chamber closely enough. The renderer now reads the PNG's alpha channel when the vial enters the scene:

- It scans rows through the central body, starting at the image centre.
- On each row, it searches outward for the continuous opaque glass wall on the left and right.
- Small isolated front highlights are ignored by requiring a short run of opaque pixels before accepting a boundary.
- The detected row boundaries form an interpolated inner-window profile.
- Both the liquid silhouette and its vertical fill range use that measured profile; there is no longer a hand-authored Vial 2 width curve.

Each layer is drawn as a continuous polygon bounded by the measured left and right edges. The top layer retains its animated surface, and subtle bubbles stay within the detected transparent window. The liquid surface position used by the pour stream is calculated from the same detected top and bottom limits.

If the PNG's alpha does not contain a detectable central transparent window, the renderer emits a warning and uses conservative fallback bounds. This needs to be checked in the Godot output after import.

## Compositing

The liquid is drawn first; the complete Qwen PNG is drawn over it. Its transparent central window reveals the vivid liquid while the front-surface reflections and outer glass details remain in front. The old procedural glass-back fill and SVG vial overlays are bypassed for this test.

## Pickup and pouring

The improved dark-prototype interaction remains unchanged:

- The player lifts a vial and guides its opening to a compatible receiving opening.
- Target validity uses the artwork-aligned mouth position and hit radius.
- Movement follows the pointer with a small spring response; the vessel pose and scale ease instead of snapping.
- Pour staging aligns the source mouth over the target. The stream follows a curved path to the receiving liquid surface, with a soft glow, travelling droplets and a small impact ripple.
- Existing sorting rules remain authoritative through `_get_transfer_details()`, including recipe, pipette, seal and transmutation requirements.

## Atmosphere and UI

The dark prototype retains its animated candles, drifting motes, adaptive HUD, contextual action icons and nested bottom sheet. No changes are made to the main interaction scene or project startup scene.

## Validation

Run the scene in Godot and inspect:
- Whether the detected liquid reaches the true inner glass walls at full capacity.
- Whether partial fill levels follow the same chamber shape without clipping through the glass.
- Whether the liquid remains vivid behind the sparse front reflections.
- Whether the detected top/bottom limits align with the open mouth and pedestal.
- Whether Godot reports the transparent-window fallback warning.
- Pickup, release without a target, a normal pour, undo and restart.

Runtime validation is required in Godot. This repository-side integration has not been launched in the Godot runtime.
