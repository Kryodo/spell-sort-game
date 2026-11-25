# Alchemy Workshop — Hybrid Visual Experiment

This is a standalone visual experiment. It does not replace the sorting prototype's main scene or alter its puzzle logic.

## Open the preview

Open the project in Godot 4.7, select `scenes/alchemy_workshop_experiment.tscn`, and use **Run Current Scene (F6)**.

The scene uses the portrait 720 × 1280 design space.

## Construction split

- **Godot-native drawing:** large wall and floor planes, wall masonry, structural timber, perspective floor slabs, broad light pools and animated magical accents.
- **SVG artwork:** the two-tier wall shelving, main workbench, tabletop still life and floor plants.
- **Existing Godot scene:** the copper cauldron and its continuously animated liquid are reused without changing their implementation.

The SVG artwork deliberately shares the existing project's walnut, aged brass, deep teal, warm parchment and glass palette. The Godot-drawn architecture uses subdued colours and broad gradients so it supports, rather than competes with, the more detailed props.

## Scene contents

- Old plaster-and-stone wall with timber framing and an alchemical medallion.
- Two stocked shelves with books, potion vessels, jars, herbs, candles and crystals.
- Broad wooden workbench with drawers, carved inset and brass details.
- Open grimoire, potion trio and mortar on the worktop.
- Reused animated copper cauldron.
- Two foreground herb planters.
- Animated candle flames, candlelight pools, crystal glow, cauldron glow and floating motes.

## Scope and validation

This scene is a first visual proof-of-concept, not a final room or a new gameplay screen. The goal is to judge visual cohesion, perceived depth, readability at mobile scale and whether the hybrid workflow is practical to extend.

Godot 4.7 runtime validation has not been performed in the editing environment. Please check the scene visually in the local editor and treat its first render as the review point before expanding the asset set.
