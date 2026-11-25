# Spell Sort — First Alchemy Experiment

This branch combines the procedural alchemy-vial interaction test with the original playable sorting rules. The configured startup scene is the first complete experiment: **Separation of Essences**.

## Run

Open the project in Godot 4.7 and run the project. The configured main scene is `res://scenes/alchemy_interaction_test.tscn`.

The original tap-to-select prototype remains available at `res://scenes/main.tscn`.

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
