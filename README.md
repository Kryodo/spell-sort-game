# Spell Sort — Alchemy Interaction Test

This branch adds a focused portrait test scene for the core alchemy interaction. It is intentionally separate from the playable sorting screen.

## Run

Open the project in Godot 4.7 and run the project. The configured main scene is `res://scenes/alchemy_interaction_test.tscn`.

The original sorting prototype remains available at `res://scenes/main.tscn`.

## What this test compares

- Two bottle sprites cropped from the first two cells of the 4 × 4 bottle sheet.
- Two procedural bottle silhouettes with different editable shape profiles.
- One shared liquid renderer for both bottle approaches.
- Curved liquid bands that follow each bottle profile rather than rectangular blocks.
- A gently moving liquid surface that reacts to bottle lift and tilt.
- One-finger or mouse press-and-drag interaction.
- Valid-target highlighting, invalid-drop return, animated lifting, directional tilt, a foreground pour stream, fill transfer and return-to-slot movement.

## Controls

1. Press and hold a non-empty bottle.
2. Drag it over an empty vial or one with a matching top essence.
3. Release to pour.
4. Release over an invalid target or outside the bottles to return it to its original slot.
5. Use RESET TEST to restore the opening arrangement.

The source asset sheets are not modified. This test is for evaluating the bottle-rendering and interaction direction before integrating it into the main puzzle flow.
