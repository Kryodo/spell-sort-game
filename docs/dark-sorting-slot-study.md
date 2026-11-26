# Dark sorting space — fantasy vial, liquid and interaction study

Open `scenes/dark_sorting_slots_prototype.tscn` in Godot and run it with **F6**. The project startup scene remains unchanged.

## Fantasy vessels

The dark prototype now uses a dedicated `fantasy_alchemy_bottle.gd` renderer. Four distinct procedural silhouettes share the existing glass/liquid pipeline. Small fabric neck wraps, tied details, brass accents, base bands and occasional side charms stay near the edges so the coloured liquid remains visible.

The existing SVG vial overlays are not drawn by this renderer. Glass edges and reflections are rendered procedurally around the new silhouettes.

## Magical liquid

The liquid keeps its separate layered colour data and now has restrained inner radiance, rising bubbles, moving highlights and a more pronounced surface meniscus. Bubbles are subtle and varied rather than a constant stream of particles.

## Pickup and pouring

The dark prototype now ports the proven mouth-alignment interaction pattern from `alchemy_interaction_test.gd`:

- The player lifts a vial and guides its opening to a compatible receiving opening.
- Target validity uses the vial mouth position and hit radius, not a broad vial-body rectangle.
- Movement follows the pointer with a small spring response; the vessel pose and scale ease instead of snapping.
- Pour staging aligns the source mouth over the target. The stream follows a curved path to the receiving liquid surface, with a soft glow, travelling droplets and a small impact ripple.
- Existing expanded sorting rules remain authoritative through `_get_transfer_details()`, including recipe, pipette, seal and transmutation requirements.

## Atmosphere

Two small animated candles frame the lower action area. A restrained set of drifting motes adds depth without competing with the vials. Tiny motes can also occasionally rise near filled vial necks.

## UI and comparison controls

The screen retains the adaptive HUD: compact chapter and experiment identity, tappable objective, back/menu controls, transient feedback and only relevant action icons. The menu bottom sheet contains experiment notes, arrangement/vial-count comparison, restart confirmation and return to the greenhouse.

## Validation

Run the scene in Godot and test pickup, releasing without a target, mouth alignment, a normal pour, undo, restart, pipette and transmutation. Also compare all four vial silhouettes and inspect the liquid at partial and full levels.

This is a visual/game-feel prototype. The project startup scene is not changed. Runtime validation is required in Godot.
