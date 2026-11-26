# Panable Sorting Workspace Prototype

## Purpose

A focused, playable study of a large fixed-dimension alchemy workspace. The world contains twelve predefined vial positions, while the starting experiment uses eight vials. The camera initially shows only part of the workspace so players must navigate to reach the remaining positions.

This prototype deliberately keeps the existing sorting rules and bottle renderer. It does not introduce free placement, a rack, or a permanent apparatus.

## Open and run

1. Open `scenes/panable_sorting_workspace_prototype.tscn` in Godot.
2. Run the scene with **F6**.
3. The scene starts on Track B, Trial 08, an eight-vial experiment.

The project startup scene is not changed.

## Interaction

- **Pan:** Drag empty workspace space with the mouse or one finger.
- **Zoom:** Use the mouse wheel, pinch with two fingers, or tap the fixed + / − controls.
- **Pour mode:** Drag a vial onto another vial to use the existing sorting transfer rules.
- **Swap mode:** Toggle **SWAP MODE**. Drag a vial to another occupied position to swap the two vessels, or to an empty position to move it there.
- **Undo / Restart / Next Trial:** Use the fixed HUD controls. Spatial moves are included in undo history.

The workspace is a fixed 1720 × 1500 world with twelve automatically spaced positions in a 4 × 3 arrangement. Camera movement is bounded by the world edges. Slot markers remain subtle in pour mode and empty positions are highlighted while Swap Mode is active.

## Implementation boundaries

- The workspace viewport clips its larger child canvas.
- Vials are children of the workspace canvas, while the HUD stays on the screen.
- Vial content and sorting logic remain attached to each vial when it changes position.
- Slot occupancy is stored separately from the fixed slot coordinates.
- The existing `sorting_direction_prototype.gd` remains the source of the pouring rules.

## Verification note

This is a code-level prototype. It has not been launched in the Godot runtime as part of this implementation, so pan/pinch feel, vial hit testing at different zoom levels, and the visual balance still need an in-editor playtest.