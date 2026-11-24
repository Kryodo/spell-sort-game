# Spell Sort — First Playable Prototype

This branch adds the first playable portrait puzzle screen to the existing Godot project.

## Run

Open the project in Godot 4.7 and run the project (F6 is not required; the main scene is configured in project.godot).

## Prototype loop

- Tap or click a vial to select it.
- Tap an empty vial, or a vial whose top essence matches, to pour.
- A pour transfers the complete contiguous top run that fits.
- Sort the three essences into full, single-colour vials.
- Undo reverses the previous successful pour.
- Reset restores the opening puzzle. After solving it, the same button starts a new shuffled mix.

The puzzle uses four vials, three essences and four layers per vial.

## Art integration

The portrait laboratory background is used directly from assets/environments/laboratory_background.png. The current vials are temporary procedural controls drawn in Godot so the liquid and sorting rules can be tested independently.

The source sheets in assets/ remain untouched. The bottle, ingredient, prop and gameplay-icon sheets can be atlas-sliced and integrated after their individual sprite bounds have been checked in the running project. UI panels, labels and buttons are intentionally built in Godot.
