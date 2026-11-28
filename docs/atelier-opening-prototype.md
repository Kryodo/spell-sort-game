# SpellSort — Atelier Opening Prototype

## Run

Open the project in Godot 4.7 and press **F5**. The project starts in:

`res://scenes/atelier_hub.tscn`

## Opening sequence

1. The player enters the Atelier. The workbench is available; the Atlas is present but dormant.
2. Select **Approach the Workbench** to enter `scenes/atelier_first_lessons.tscn`.
3. Complete Track B lessons 1–3. These use the existing dark sorting board and standard separation rules; no new puzzle mechanic is introduced.
4. After the third puzzle, the completion action becomes **Return**. Selecting it saves `first_lessons_complete` in `user://spell_sort_progress.cfg` and returns to the Atelier.
5. The Atlas becomes interactive. Opening it reveals the Botanical Garden and its first marked destination, **The Overgrown Entrance**.

The back arrow on the sorting screen returns to the Atelier at any time. Leaving early does not grant the Atlas unlock. Re-entering the workbench starts the three-lesson sequence from its first lesson.

## Construction

- `assets/environments/SpellSort_Atelier_Warm.svg` is the active third visual approach: the same open composition as approach 02, but with a warmer walnut/olive/brass palette, a more organic carved arch, a more crafted Atlas instrument and a curved work surface.
- `assets/environments/SpellSort_Atelier_Candle_Flame.svg` and `SpellSort_Atelier_Candle_Glow.svg` provide separate candle artwork and soft light for animation.
- `scripts/atelier_hub.gd` animates the flame with very small transform changes, gently varies the light intensity and moves a small set of ambient motes. The mote layer is behind interface controls.
- `SpellSort_Atelier_Minimal.svg` and `SpellSort_Atelier_Room.svg` are retained as earlier visual approaches for comparison.
- `scripts/atelier_hub.gd` builds the interactive hotspots, state labels and Atlas reveal panel.
- `scripts/atelier_guided_sorting.gd` extends the existing dark sorting prototype. It restricts the opening to three sequential levels, hides the experiment menu and returns to the Atelier when the sequence is complete.
- `project.godot` now uses the Atelier as the startup scene. Existing sorting prototypes remain available as separate scenes.

The Atlas page currently reveals the next destination as a discovery. The Botanical Garden's playable environment and journey sequence are not part of this first implementation slice.

## Validation

The project files and scene references were checked statically. Godot 4.7 is not installed in the editing environment, so SVG import, GDScript parsing, the first-run flow, save persistence, animation timing and visual layout still need a local Godot 4.7 test. Review whether the warmer materials feel inviting without losing the negative space and silhouette depth that worked in approach 02.

## Scene transitions

- `scripts/scene_transition.gd` is registered as the persistent `SceneTransition` autoload, so scene changes can share one consistent transition system.
- The Atelier-to-board and board-to-Atelier transitions use a restrained 1.8% scale push-in, a very brief warm darkening at the scene swap, and a settle back to normal size. The complete handoff is about 0.42 seconds by default.
- The transition blocks input while active and does not change puzzle state or lesson progression. Future room and HUD navigation can reuse the same manager; frequent low-significance HUD changes can still happen instantly.

## Laboratory test-tube board study

- Open `scenes/test_tube_sorting_board.tscn` and run it as the current scene to compare the laboratory test-tube study against the existing Qwen vessel board.
- `scripts/test_tube_vial.gd` reuses the established liquid, slosh, selection and pour behaviour, but draws a medium-width bottle silhouette with a curved neck, flared rolled glass mouth, rounded glass foot and subtle internal depth reflections entirely in Godot.
- `scripts/test_tube_sorting_board.gd` swaps only the vial renderer and contact-shadow marker proportions. The puzzle rules, levels and board layout remain shared with the existing sorting board.
