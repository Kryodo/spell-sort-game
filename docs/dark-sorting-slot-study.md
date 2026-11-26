# Dark sorting space — Qwen relic vial integration study

Open `scenes/dark_sorting_slots_prototype.tscn` in Godot and run it with **F6**. The project startup scene remains unchanged.

## Qwen vessel test

The dark prototype now uses `asset_fantasy_alchemy_bottle.gd` and the single Qwen-generated asset `assets/bottles/SpellSort_Vial_1.png` for every test vial.

The square artwork is fitted uniformly to each vial's height so its original proportions are preserved. The widened test layout gives the visible glass silhouette room without changing the overall interaction flow. The mouth position and liquid chamber profile are mapped to the artwork rather than reusing the earlier procedural-vessel geometry.

The PNG is drawn above the live liquid. The old procedural glass-back fill and the previous SVG overlays are bypassed for this test. This deliberately tests whether the artwork's alpha transparency allows coloured liquid to remain readable while preserving its painted glass reflections. The asset is currently a single combined layer; rear/front glass separation can be considered only if the compositing test demonstrates that it is needed.

## Liquid

The existing layered liquid rendering and motion remain in place for this first integration test. Its fill profile is adjusted to the visible interior chamber of the Qwen vessel. The purpose of this pass is to validate fit, transparency, visible colour and pouring alignment—not to redesign the liquid effects.

## Pickup and pouring

The improved dark-prototype interaction remains unchanged:

- The player lifts a vial and guides its opening to a compatible receiving opening.
- Target validity uses the artwork-aligned mouth position and hit radius.
- Movement follows the pointer with a small spring response; the vessel pose and scale ease instead of snapping.
- Pour staging aligns the source mouth over the target. The stream follows a curved path to the receiving liquid surface, with a soft glow, travelling droplets and a small impact ripple.
- Existing sorting rules remain authoritative through `_get_transfer_details()`, including recipe, pipette, seal and transmutation requirements.

## Atmosphere and UI

The dark prototype retains its two small animated candles, drifting motes, adaptive HUD, contextual action icons and nested bottom sheet. No changes are made to the main interaction scene or project startup scene.

## Validation

Run the scene in Godot and inspect:
- Whether the liquid colours are clearly visible through the Qwen glass.
- Whether the liquid follows the actual interior shape and stays inside the vessel.
- Whether the open mouth position matches drag targeting and pouring.
- Whether all four test vessels fit the slot layout without visual overlap.
- Pickup, release without a target, a normal pour, undo and restart.

Runtime validation is required in Godot. This repository-side integration has not been launched in the Godot runtime.
