# Spell Sort — Profile Liquid Comparison

## Purpose

This is an additive visual experiment. It does not replace the primary bottle renderer, the existing test-tube bottle renderer, or the original test-tube comparison board.

## Run

Open `scenes/test_tube_liquid_sorting_board.tscn` and run the current scene with **F6**.

The original glass study remains available at `scenes/test_tube_sorting_board.tscn`. Both boards use the same test-tube bottle shape, levels, sorting rules, interactions, and pour controller.

## Separation

- `scripts/test_tube_vial.gd` remains the original test-tube renderer and is not modified by this experiment.
- `scripts/test_tube_liquid_vial.gd` inherits the original test-tube bottle and replaces only its liquid drawing pass.
- `scripts/test_tube_liquid_sorting_board.gd` reuses the established comparison board and swaps in the new liquid renderer.
- The primary bottle scripts and the original `test_tube_sorting_board.tscn` are unchanged.

## First liquid pass

- Each liquid layer is drawn as a polygon sampled against the test bottle's inner profile, so its sides follow the rounded glass body and foot.
- The topmost liquid layer gets a shallow elliptical surface with a darker rear edge and a soft front meniscus.
- Existing gentle bubble movement is retained, constrained to the new curved liquid volume.
- Existing fill-level interpolation and slosh state are reused. The stream, impact splash, completion motes, and cork are deliberately not changed in this first isolated comparison slice.

## Validation

Static source and scene checks only. Godot 4.7 runtime rendering and interaction still require a local test.
