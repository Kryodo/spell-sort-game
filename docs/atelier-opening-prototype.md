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

- `assets/environments/SpellSort_Atelier_Minimal.svg` is the active second visual approach: a near-black sanctuary, one recessed Atlas focal object, broad shadow masses, restrained workbench plane and subtle edge silhouettes. It deliberately omits small furniture props and individually illustrated shelf contents.
- `assets/environments/SpellSort_Atelier_Room.svg` is retained as the first room experiment for side-by-side comparison; it is no longer loaded by the active Hub scene.
- `scripts/atelier_hub.gd` builds the interactive hotspots, state labels and Atlas reveal panel.
- `scripts/atelier_guided_sorting.gd` extends the existing dark sorting prototype. It restricts the opening to three sequential levels, hides the experiment menu and returns to the Atelier when the sequence is complete.
- `project.godot` now uses the Atelier as the startup scene. Existing sorting prototypes remain available as separate scenes.

The Atlas page currently reveals the next destination as a discovery. The Botanical Garden's playable environment and journey sequence are not part of this first implementation slice.

## Validation

The project files and scene references were checked statically. Godot 4.7 is not installed in the editing environment, so SVG import, GDScript parsing, the first-run flow, save persistence and visual layout still need a local Godot 4.7 test. In particular, review whether the simpler Atlas/arch composition creates enough depth without the earlier room's detailed furniture.
