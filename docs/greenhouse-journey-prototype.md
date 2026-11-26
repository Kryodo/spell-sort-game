# Greenhouse Journey — First Vertical Slice

## Run it

1. Pull `experiment/alchemy-workshop-spatial-v0.2`.
2. Open `scenes/greenhouse_journey.tscn` in Godot 4.7.
3. Press **F6** to run the current scene.

The project startup scene remains unchanged.

## What is included

- A hand-crafted greenhouse block-in drawn with Godot 2D geometry.
- A separate world layer and interface layer.
- Interactive Botanical Garden and Research Archive hotspots.
- Persistent HUD navigation for Experiments, Codex, Discoveries and Laboratory.
- Experiment chapter list with the first three experiments marked complete, the third available, and later entries locked.
- Launch from Experiment 03 into a dedicated chapter entry scene that starts the four-vial prototype at Track A, Level 03. The standalone direction comparison remains available separately.
- Return from the experiment prototype to the greenhouse hub.

## Architecture intention

The environment does not contain vial slots or a fixed sorting board. The experiment screen is a separate scene and can evolve independently of the chapter environment. The current hub uses one authored greenhouse block-in as a first navigation test; additional chapter scenes can later reuse the same HUD and content-page pattern.

## Validation status

The scene and script references were checked on the experiment branch. Godot 4.7 was not available in the editing environment, so runtime rendering, UI layout and scene transitions still require a local test. This is a functional architecture block-in, not final environment artwork.
