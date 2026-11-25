# Spell Sort — First Alchemy Experiment

This branch combines the procedural alchemy-vial interaction test with the original playable sorting rules. The configured startup scene is an interactive, procedural 3D laboratory room prototype. The first experiment, **Separation of Essences**, opens from the workbench.

## Run

Open the project in Godot 4.7 and run it. The configured main scene is `res://scenes/lab_room_prototype.tscn`. Tap the alchemy workbench to open the experiment. Use **Back to Lab** in the experiment header to return to the room.

The original tap-to-select prototype remains available at `res://scenes/main.tscn`.

## Laboratory room prototype

The room is built at runtime from simple Godot 3D primitives and shared flat-colour materials; it does not depend on a texture or external model pack. It uses a fixed orthographic camera with a slight 3/4 angle, warm key lighting, cool fill lighting and small animated candle flames.

Clickable areas are provided for the alchemy table, grimoire, ingredient cabinet, cauldron and world map. The workbench launches the existing experiment scene. The other objects currently show prototype interaction descriptions so the room's future hub navigation can be evaluated before those systems are built.

Main implementation: `scripts/lab_room_prototype.gd` and `scenes/lab_room_prototype.tscn`.

## Experiment 01 — Separation of Essences

The player must separate Tide, Moon and Ember into three pure vials. Each essence has four measures. The experiment starts with four partially mixed vessels and one empty vessel.

- Four procedural open-top glass profiles: round, tall, squared-shoulder and bulbous.
- Hold and drag a vial. The source mouth is measured against each receiving vial's actual open mouth; release only pours when the openings are aligned.
- Grip position influences tilt, and the source remains anchored to the touch point while being moved.
- A valid pour stages the source above the target, then transfers the matching top run through the animated stream. The stream ends at the receiving vial's live liquid surface.
- An empty vial or a vial topped with the same essence can receive a pour. A full vial cannot receive more. The complete contiguous top run transfers, limited by the target's remaining capacity.
- Invalid drops return the source to its original slot.
- Undo restores the previous arrangement and move count. Reset restores the exact opening experiment.
- The interface presents the puzzle as a laboratory experiment, with an objective card, essence references, a dedicated workbench, purity progress and a completion state.

## Bottle and liquid implementation

The procedural bottle renderer remains in `scripts/alchemy_bottle.gd`. It draws the open mouth, dimensional glass, profile-fitted liquid bands, animated meniscus and sloshing. The same renderer is used for all four vial profiles.

The original asset sheets are unchanged. The older sprite-based sorting scene is retained for comparison.

## Validation

The code has been committed to the feature branch, but a Godot 4.7 runtime launch and interaction pass still need to be checked locally.
