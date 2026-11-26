# Greenhouse Journey — First Vertical Slice

## Run it

1. Pull `experiment/alchemy-workshop-spatial-v0.2`.
2. Open `scenes/greenhouse_journey.tscn` in Godot 4.7.
3. Press **F6** to run the current scene.

The project startup scene remains unchanged.

## What is included

- A hand-crafted greenhouse environment block-in made with Godot 2D geometry.
- A reusable `greenhouse_environment.tscn` scene that contains only the location artwork.
- A reusable `journey_hud.tscn` scene for world navigation and journal pages.
- A small `greenhouse_journey.gd` scene controller that connects the HUD's experiment request to the chapter entry scene.
- Interactive Botanical Garden and Research Archive hotspots.
- Persistent HUD navigation for Experiments, Codex, Discoveries and Laboratory.
- Experiment chapter list with the first two experiments marked complete, Experiment 03 available and later entries locked.
- Launch from Experiment 03 into `chapter_experiment_03.tscn`, which starts the four-vial prototype at Track A, Level 03.
- Return from the experiment prototype to the greenhouse hub.

## Architecture intention

The environment does not contain vial slots or a fixed sorting board. The experiment screen is a separate scene and can evolve independently of the chapter environment.

New chapter scenes can instance the same reusable Journey HUD with a different environment component. The active experiment selects its own apparatus and vial layout; the location artwork does not dictate either one.

The current greenhouse uses hand-drawn Godot 2D shapes as a functional composition block-in. It is not final environment artwork. The purpose of this first slice is to validate navigation, scene separation, and the relationship between the environment and the experiment system before investing in detailed chapter artwork.

## Validation status

Scene and script references were checked on the experiment branch. Godot 4.7 was not available in the editing environment, so runtime rendering, UI layout, input and scene transitions still require a local test.
