# Greenhouse Journey + Sorting Interface — First Vertical Slice

## Run it

1. Pull `experiment/alchemy-workshop-spatial-v0.2`.
2. Open `scenes/greenhouse_journey.tscn` in Godot 4.7.
3. Press **F6** to run the current scene.
4. Open **Experiments**, then begin **Experiment 03 — A Pure Formula** to enter the new sorting interface.

For a direct interface test, open `scenes/chapter_experiment_03.tscn` and press **F6**.

The project startup scene remains unchanged.

## What is included

- A hand-crafted greenhouse environment block-in made with Godot 2D geometry.
- A reusable `greenhouse_environment.tscn` scene that contains only the location artwork.
- A reusable `journey_hud.tscn` scene for world navigation and journal pages.
- Interactive Botanical Garden and Research Archive hotspots.
- Persistent HUD navigation for Experiments, Codex, Discoveries and Laboratory.
- Experiment chapter list with the first two experiments marked complete, Experiment 03 available and later entries locked.
- A separate sorting interface that reuses the greenhouse environment as its backdrop, with an experiment-only clear tabletop variant so decorative props do not sit underneath the glass vessels.
- Adaptive vial placement: four to six vessels share one shallow tabletop arc; seven or eight expand onto a raised rear tier and the front of the table.
- Individual engraved resting points rather than permanent bottle slots or a fixed rack.
- The existing procedural glass/liquid renderer, drag interaction, pour animation, undo, restart and optional experiment tools remain in use.
- Return from the experiment to the greenhouse hub.

## Sorting interface direction

The first interface test deliberately keeps the bottle renderer and core sorting rules while replacing the old rigid board, comparison-track controls and large status/control layout.

The table is the apparatus. For smaller puzzles, the vessels sit directly on the broad work surface in an adaptive arc. When the count grows beyond six, a shallow raised rear tier creates a second depth plane without forcing all vessels into small uniform grid slots.

The current chapter entry starts on the five-vessel Track B test level so the new layout is immediately exercised with more than four vessels. Later Track B levels continue to six, seven and eight vessels.

This is a functional interface prototype, not final environment or HUD artwork. The purpose is to evaluate scale, readability, depth and the relationship between the sorting interaction and the greenhouse setting before adding further game systems.

## Architecture intention

The environment does not contain vial slots or a fixed sorting board. The experiment screen instances the reusable greenhouse environment behind its own interface script. The sorting interface can choose its own vessel count and arrangement independently of the chapter location.

New chapter scenes can instance the same reusable Journey HUD with a different environment component. The active experiment selects its own apparatus and vial layout; the location artwork does not dictate either one.

## Validation status

Scene and script paths, the inherited sorting logic, launch settings and adaptive layout wiring were checked statically on the experiment branch. Godot 4.7 was not available in the editing environment, so runtime rendering, UI layout, drag/pour input and scene transitions still require a local test.
