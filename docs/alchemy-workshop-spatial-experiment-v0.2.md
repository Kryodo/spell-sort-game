# Alchemy Workshop — Spatial Hybrid Experiment v0.2

This is a new, standalone experiment built on the existing reference-first prototype. It does not replace the main scene, change sorting gameplay or modify the earlier experiment scene.

## Open the preview

1. Fetch the experiment/alchemy-workshop-spatial-v0.2 branch.
2. Open scenes/alchemy_workshop_spatial_experiment.tscn in Godot 4.7.
3. Run **Current Scene (F6)**.
4. To inspect the tabletop placement plane, select the root AlchemyWorkshopSpatialExperiment node and enable show_surface_guides in the Inspector.

The viewport is 720 × 1280 portrait. assets/environments/SpellSort_Workbench.png remains the visual benchmark; it is not drawn as the preview background.

## What this version changes

The earlier experiment treated the room too much like one projected composition. It also used fixed screen positions for candle effects and placed some props by the edge of their image canvas instead of their actual support points.

Version 0.2 uses separate local coordinate systems:

- **Rear wall:** a mostly front-facing plane, with a restrained floor transition.
- **Central wall shelf and rear cabinet:** independent front-facing furniture layers.
- **Left cabinet and right shelf:** separate side-furniture transforms. The right shelf is mirrored so its board direction matches the reference.
- **Workbench:** a dedicated tabletop plane with its own four corners and a deeper front-to-back shape.
- **Tabletop props:** each has its own contact point, rotation and depth scale.
- **Floor plants:** placed by the pot's bottom-centre contact point, not by the edge of the transparent image.
- **Candle:** extracted from the cabinet art and placed as an independent SVG on the cabinet's top surface. The flame effect is a child of the candle wick, so it follows the candle's transform.

The old scene and its assets remain available for side-by-side comparison.

## Spatial landmarks

The workbench artwork is 720 × 700 and is positioned at (0, 455). The visible tabletop plane is defined in that artwork's local coordinates:

- Rear-left: (148, 0)
- Rear-right: (572, 0)
- Front-right: (697, 462)
- Front-left: (23, 462)

That places the near edge around y = 917 in the preview, closer to the Qwen reference than the previous experiment's shallow tabletop.

Tabletop objects use normalized coordinates (u, v) projected only onto this plane. Their local rotations are independent: a book does not have to share the mortar's angle, and neither has to share the table's coordinate system.

SVG object contact points currently used:

- Cauldron shadow centre: (120, 208)
- Book lower-centre: (95, 124)
- Potion-tray lower-centre: (75, 161)
- Mortar shadow centre: (60, 101)
- Floor-plant pot bottom-centre: (84, 252)
- Shelf-candle holder bottom-centre: (42, 132)

The candle wick effect is positioned from the candle's local anchor, rather than from a hard-coded viewport position.

## Construction split

**Godot-native drawing**
- Rear wall and side returns
- Broad wall joints
- Receding floor seams
- Subtle ambient crystal light
- Tabletop projection, depth order and prop anchors

**SVG artwork**
- Rear shelf, rear cabinet, side furniture
- Deeper workbench with a more reference-matched tabletop proportion
- Candle, book, potion set, mortar and floor plants

**Existing Godot scene**
- Animated copper cauldron and liquid

This is still a hybrid test, not a finished environment. It is deliberately focused on spatial relationships and grounding first. Visual polish and closer Qwen style matching should be judged only after the local render is reviewed.

## Local review checklist

1. Does the tabletop now occupy the correct amount of the portrait composition?
2. Does the central rear shelf read as a mostly front-facing wall fixture?
3. Do the left and right side furniture pieces feel like separate angled surfaces rather than one forced perspective?
4. Does the candle holder visibly rest on the left cabinet, with the flame attached to its wick?
5. Do the floor plants sit on the floor without looking detached from it or accidentally falling outside their support area?
6. Do the tabletop props rest on the same surface while retaining their own rotations?
7. Does the overall material treatment approach the Qwen background's depth and warmth?

## Validation status

Godot 4.7 is not available in the editing environment. The project files have been written to the experiment branch, but runtime parsing, SVG import, visual alignment and performance have not been tested here. The local Godot preview is still required before accepting the result.
