# Spell Sort — Playable Direction Prototype

## Open it

1. Pull `experiment/alchemy-workshop-spatial-v0.2`.
2. Open `scenes/sorting_direction_prototype.tscn` in Godot 4.7.
3. Run **Current Scene (F6)**.

The project startup scene is unchanged. This is a standalone mechanics test and does not replace the workshop or existing sorting prototype.

## Controls

- **Drag a vial onto another vial** to pour.
- A normal pour moves the complete contiguous top group, limited by the receiving vial's free capacity.
- The receiver must be empty or have the same essence on top.
- **Undo** reverses the last pour or alchemy action.
- **Restart** resets the current level.
- Use the top arrows or bottom **Next Level** button to move between levels.
- Switch between **Track A** and **Track B** at the top.

## Track A — Four-vial alchemy

Ten levels use a fixed four-vial layout.

- Levels 1–3: conventional sorting, shared with the opening levels of Track B.
- Levels 4–5: arm the one-use pipette, then use it to split a multi-layer top group. The level requires the pipette to be used.
- Levels 6–7: the fourth vial starts sealed. Create a matching pair at the top of a vial to unlock it.
- Level 8: fill the fourth recipe vial bottom-to-top in the displayed order, then sort the remaining essences.
- Level 9: select the retort vial by dragging it onto itself, then press **Transmute** to convert adjacent Tide + Ember into Dusk.
- Level 10: use both transmutation and the one-use pipette before sorting.

## Track B — Expandable classic sorting

Ten levels use only conventional sorting rules. The vial count grows from four to eight, with the later levels arranged in two rows. The vial art is scaled for the layout test; this is not a final touch-target or visual-quality decision.

## Important presentation note

The prototype uses a neutral mechanics-test surface so the two gameplay footprints can be compared without committing more environment artwork. It deliberately does not composite SVG rack pieces over the generated workshop. No Qwen environment edits, permanent rack artwork, or production UI are included.

## Validation

The level layouts were checked against the standard pour rules and the defined special actions. Godot 4.7 was not available in the editing environment, so the scene still needs a local Godot runtime check for parsing, input routing, animation and visual fit.
