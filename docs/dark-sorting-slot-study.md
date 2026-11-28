# Dark sorting space — Qwen vial composition and liquid mask study

Open `scenes/dark_sorting_slots_prototype.tscn` in Godot and run it with **F6**. The project startup scene remains unchanged.

## Current vessel candidate

The dark prototype currently uses `asset_fantasy_alchemy_bottle.gd` with `assets/bottles/SpellSort_Vial_2.png`.

Vial 2 remains a provisional composition candidate, not a locked art direction. It has a transparent central front window with subtle illustrated reflections and a distinctive tapered silhouette.

## Alpha-derived liquid window

The previous manually estimated liquid profile did not match the visible chamber closely enough. The renderer now reads the PNG's alpha channel when the vial enters the scene:

- It starts from a transparent pixel near the centre of the viewing window.
- A bounded four-connected flood fill identifies the transparent interior component, rather than treating every transparent pixel in the outside background as liquid space.
- The resulting per-row left/right bounds are lightly smoothed and sampled into a compact profile.
- A width threshold trims the narrow connecting neck/foot tails so the main chamber defines the fill range.
- Both the liquid silhouette and its vertical fill range use this measured profile; there is no hand-authored Vial 2 width curve.

Each essence layer is drawn as a single continuous contour. The animated top edge recalculates its left/right limits at the wave's displaced height, so the wave should not pull away from the side walls or leave triangular gaps. Surface motion and bubble visibility have also been made more restrained to reduce flicker.

The renderer prints the detected profile sample count, connected pixel count, maximum chamber width and vertical fill interval to Godot's Output panel. If the transparent component cannot be safely isolated, it emits a warning and uses fallback bounds. Check this output after import.

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
