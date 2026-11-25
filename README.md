# Spell Sort — World and 3D Alchemy Evaluation

This branch contains three connected visual/technical prototypes to evaluate a possible stylized 3D/2.5D foundation for Spell Sort. This is an exploration build, not a final art-direction commitment.

## Run

Open the project in Godot 4.7 and run it. The configured main scene is `res://scenes/lab_room_prototype.tscn`.

## Prototype A — Swipeable laboratory hub

The main room now sits between two adjoining hub areas:

- **Ingredient Stores:** ingredient shelves, potion stock and storage work island.
- **Main Lab:** the workbench, cauldron, grimoire and current laboratory props.
- **Research Archive:** bookcases, research desk, crystal and chapter map.

Swipe horizontally to move between the three areas, or use the navigation buttons near the bottom. Tap highlighted/interactive objects for their prototype descriptions. The archive's chapter landmark opens Verdant Hollow. The main workbench opens the 3D alchemy experiment.

Main implementation: `scripts/lab_room_prototype.gd` and `scenes/lab_room_prototype.tscn`.

## Prototype B — 3D alchemy experiment

The close-up experiment uses a 3D workbench and 3D glass vials with visible layered liquids. It keeps the first experiment's Tide, Moon and Ember sorting rules:

- Four vessels, three essences, four measures per essence.
- Drag a vial onto an empty receiver or one with a matching top essence.
- The contiguous matching top run transfers, respecting vessel capacity.
- Invalid drops return to their slot.
- Undo, Reset and completion feedback are included.
- **Back to Lab** returns to the hub.

This is intentionally an early visual and interaction proof. The 3D bottle interaction is separate from the earlier 2D prototype so the two approaches can be compared without losing the working baseline.

Main implementation: `scripts/alchemy_3d_experiment.gd` and `scenes/alchemy_3d_experiment.tscn`.

## Prototype C — Verdant Hollow chapter environment

Open the chapter from the Research Archive's map. Verdant Hollow is a small, fixed-camera exploration location built from the same simple geometry/material approach, with stylized trees, a stone gate, altar, crystals, moonlit spring, animated fireflies and clickable discovery points. **Back to Lab** returns to the hub.

Main implementation: `scripts/chapter_forest_prototype.gd` and `scenes/chapter_forest_prototype.tscn`.

## Comparison and fallback scenes

- `scenes/alchemy_interaction_test.tscn`: previous 2D alchemy interaction/puzzle presentation.
- `scenes/main.tscn`: original sprite-based sorting prototype.

The procedural 2D bottle renderer remains in `scripts/alchemy_bottle.gd`.

## What to evaluate

1. Does the hub feel like a larger place, and is swipe navigation comfortable on mobile?
2. Do the 3D vials and workbench feel like they belong to the laboratory?
3. Does the chapter environment feel like a natural extension of the hub's art direction?
4. Are silhouettes, colours, lighting and scene detail readable and appealing?
5. Does the 3D approach feel practical to expand across more objects, chapters and UI?

## Validation status

The prototype scenes and scripts have been committed to this feature branch, but a Godot 4.7 runtime launch, interaction pass and visual evaluation still need to be performed locally. No final art-direction or production-pipeline decision has been made.
