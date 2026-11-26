# Dark sorting space — adaptive gameplay UI study

Open `scenes/dark_sorting_slots_prototype.tscn` in Godot and run it with **F6**. The project startup scene remains unchanged.

## Gameplay screen

The sorting view is intentionally quiet. It keeps only:

- A compact chapter label, experiment title, and objective.
- A back control and a contextual menu control.
- The live vials and understated recessed slot markers.
- Small action icons for Undo and only the special tools relevant to the current experiment.

The objective is tappable and opens the experiment notes. Feedback such as selecting a vial, invalid pours, and successful transfers fades in near the top of the play space, then fades away. While dragging, valid destination vials receive a subtle highlight.

When the experiment is complete, the normal action row gives way to a larger Continue action.

## Nested sheets

The top-right menu opens a bottom sheet with:

- Experiment notes.
- Arrangement and vial-count comparison controls.
- A restart confirmation.
- Return to the greenhouse.

The arrangement and vial-count controls are intentionally hidden in this sheet rather than occupying the gameplay screen. Changing either setting reloads the sample puzzle.

Sheets animate out from the bottom, use a dimmed backdrop, and can be dismissed by tapping outside or using the close control.

## Layout comparison

- **Line** — one horizontal row for four or six vials; two rows for eight.
- **Arc** — a shallow curved row, or two slightly curved rows for eight.
- **Two rows** — aligned upper and lower rows for four, six, or eight.

The prototype continues to use the existing sorting controller and bottle renderer. Drag-and-pour rules, undo, pipette, transmutation, and completion remain owned by the inherited sorting logic. The main project startup scene is not changed.

Runtime validation is still required in Godot. This branch update is a UI and interaction prototype, not a replacement for the chapter gameplay scene.
