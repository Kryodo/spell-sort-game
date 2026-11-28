# Spell Sort — Working Main Renderer Transfer

## Purpose

This is an isolated full copy of the renderer used by the working Atelier/main-scene sorting experience, adapted to the custom laboratory bottle. The live source file `scripts/asset_fantasy_alchemy_bottle.gd` is not modified and the new file does not inherit from it, so later main-scene changes cannot silently change this comparison.

## Run

Open `scenes/test_tube_cached_liquid_sorting_board.tscn` and run the current scene with **F6**.

## What was transferred

`scripts/test_tube_cached_liquid_vial.gd` began as a full copy of `scripts/asset_fantasy_alchemy_bottle.gd`. It retains the working renderer's:

- Cached liquid-band polygons and vertex colours, rebuilt only when contents, preview, profile or size changes.
- 160-sample packed chamber profile and fast profile-bound lookup.
- Separate dynamic meniscus reflection.
- Cached bubble-sprite texture library.
- Timed surface-bubble swell/pop/ripple activity.
- Layered glass reflection geometry and the retained artwork transform used for bottle motion.
- Working fill-level, slosh, selection, pour and interaction state through the existing base classes.

## Adaptations for the new bottle

- The copied renderer uses `SpellSort_LabBottle_Glass.svg` as its vessel artwork.
- Texture-alpha chamber detection is replaced by the hand-authored lab-bottle profile, mapped into the copied renderer's original normalized image coordinates.
- The liquid top is enhanced into a shallow elliptical surface with a darker rear meniscus and softer front highlight; its colour palette stays cached.
- The far-base Fresnel is a separate overlay and is shown only when the bottle is empty and no pour is actively hiding it.
- The mouth-lip crop is adjusted to the new bottle's compact rolled rim.

## Separation

- `asset_fantasy_alchemy_bottle.gd` remains the working main-scene renderer and is not modified.
- `test_tube_vial.gd` and `test_tube_sorting_board.tscn` remain the original new-glass baseline.
- `test_tube_liquid_vial.gd` and `test_tube_liquid_sorting_board.tscn` remain the first simple profile-liquid experiment.
- `test_tube_cached_liquid_vial.gd` is an independent full copy of the working renderer adapted for the lab bottle.

## Validation

Static source and scene checks only. Godot 4.7 rendering, pouring, undo and performance profiling still require local testing.
