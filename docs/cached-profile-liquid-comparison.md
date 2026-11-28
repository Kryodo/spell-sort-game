# Spell Sort — Cached Profile Liquid Comparison

## Purpose

This is a new, isolated transfer of the working liquid-rendering architecture from `scripts/asset_fantasy_alchemy_bottle.gd` into the custom laboratory bottle study.

It does not replace the live Atelier/main-scene renderer, the original test-tube renderer, or the first profile-liquid experiment.

## Run

Open `scenes/test_tube_cached_liquid_sorting_board.tscn` and run the current scene with **F6**.

## What was transferred

The new renderer ports the working pipeline's performance structure and adapts it to the hand-authored bottle profile:

- A cached 160-sample internal profile, stored in a `PackedVector3Array`, provides fast left/right boundary lookups.
- Liquid body polygons and vertex colours are cached per vial.
- Geometry is invalidated by contents, fill previews, setup and resize changes, then rebuilt only when dirty.
- The liquid body's sides and foot follow the custom laboratory bottle profile.
- The dynamic elliptical top surface is a separate, lightweight draw pass. Its colour gradient is cached; only its wave-displaced points are recalculated.
- Bubble sprites are generated once per appearance and reused from a static texture cache.
- The working renderer's timed surface-bubble swell/pop/ripple events are retained and adapted to the custom bottle profile.

## Separation

- `asset_fantasy_alchemy_bottle.gd` remains the working source renderer and is not modified.
- `test_tube_vial.gd` and `test_tube_sorting_board.tscn` remain the first glass baseline and are not modified.
- `test_tube_liquid_vial.gd` and `test_tube_liquid_sorting_board.tscn` remain the first uncached profile-liquid experiment and are not modified.
- `test_tube_cached_liquid_vial.gd` and its board are entirely new.

## Adaptation boundary

The original asset renderer's image-based chamber detection and illustrated-vial artwork layers are not copied because this experiment uses the new SVG glass and a hand-authored profile. Its cache lifecycle, profile lookup strategy, cached band geometry, dynamic surface separation, bubble sprite cache and timed surface activity are transferred.

## Validation

Static source checks only. Godot 4.7 rendering, input, pours and performance profiling still require a local test.
