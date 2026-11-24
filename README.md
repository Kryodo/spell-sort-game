# Spell Sort — Alchemy Interaction Test

This branch contains the focused portrait test scene for the Alchemy Core Loop.

## Run

Open the project in Godot 4.7 and run the project. The configured main scene is `res://scenes/alchemy_interaction_test.tscn`.

The original playable sorting prototype remains available at `res://scenes/main.tscn`.

## Current test

- Four procedural, open-top glass vial profiles: round, tall, squared-shoulder and bulbous.
- Dimensional glass construction using layered polygon geometry, thick rims, an open mouth, side reflections, shoulder facets and a heavier glass base.
- A shared liquid renderer made from narrow, convex polygon strips that follow each vial's interior profile. Adjacent essence regions overlap slightly to avoid visible hairline gaps.
- Animated liquid surfaces, tilt response and damped sloshing.
- Press-and-drag interaction for mouse and touch.
- Target detection around the receiving vial's open mouth rather than its body.
- Invalid releases return to the original slot.
- Valid releases align the source mouth above the target mouth, tilt the source and pour through a tapered, irregular liquid ribbon with moving droplets and a receiving splash ripple.
- Both fill levels animate during transfer and the source returns to its original slot.

The original source asset sheets are unchanged. This is a visual and interaction test, not yet the final puzzle experience.
