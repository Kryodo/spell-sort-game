# Alchemy Workshop — Reference-First Hybrid Experiment

This is a standalone visual experiment. It does not replace the sorting prototype's configured main scene or change puzzle logic.

## Open the preview

Open the project in Godot 4.7, select `scenes/alchemy_workshop_experiment.tscn`, and use **Run Current Scene (F6)**.

The design viewport is portrait, 720 × 1280. The source composition is `assets/environments/SpellSort_Workbench.png` (768 × 1376). The Qwen image is used as a visual construction reference; it is not rendered as the experiment's background.

## What changed from the first hybrid pass

The first pass was asset-first: it placed a large shelf graphic and a mostly front-facing workbench at fixed screen positions. That gave the room insufficient depth and made tabletop objects feel detached from the surface.

This version is reference-first. It follows the source image's spatial hierarchy:

1. A dark, recessed rear wall and a narrow visible floor zone.
2. A compact central wall shelf above a rear storage cabinet.
3. Side furniture that frames the room and is partly hidden by the main workbench.
4. One large foreground workbench that fills most of the lower scene.
5. Individual tabletop props placed against the projected tabletop plane.

The workbench is intentionally restrained. Its broad trapezoidal top, thick near edge, deep front body and supports follow the reference much more closely than the ornate first-pass bench.

## Reference landmarks

The source image is 768 × 1376. The preview is 720 × 1280, so the reference is mapped with an approximately uniform 0.93 scale.

Approximate construction landmarks in the preview:

- Rear wall / floor transition: around y = 475.
- Main tabletop rear edge: from (150, 455) to (570, 455).
- Main tabletop near edge: from (0, 742) to (720, 742).
- Workbench fascia and legs continue below the near edge to roughly y = 1100.
- Upper wall shelf: x = 140, y = 28, size 440 × 230.
- Rear cabinet: x = 145, y = 270, size 430 × 250.
- Left framing cabinet: x = -48, y = 208.
- Right framing shelf: x = 506, y = 58.

These are practical layout landmarks derived from the reference, not a pixel-perfect trace of every contour. The main goal is to preserve the reference's perspective, proportions, overlap and focal hierarchy.

## Projected tabletop placement

The visible tabletop is represented by four screen-space corners in `scripts/alchemy_workshop_experiment.gd`:

- Rear-left: (150, 455)
- Rear-right: (570, 455)
- Front-right: (720, 742)
- Front-left: (0, 742)

A prop is placed using normalized coordinates `u` and `v` from 0 to 1. The script bilinearly projects that point onto the tabletop. SVG props use their bottom-centre contact point as their anchor. The cauldron uses the centre of its existing ground shadow.

The same depth value also controls object scale and z-order: farther-back props are smaller and render behind props nearer the viewer. This is intended to prevent the book, mortar, bottles and cauldron from floating independently of the surface.

For inspection, select the root `AlchemyWorkshopExperiment` node and enable `show_tabletop_guides` in the Inspector. The overlay shows the four tabletop corners, diagonals and current prop anchors. Leave it disabled for the normal preview.

## Hybrid construction split

- **Godot-native drawing:** wall and floor planes, broad stone tile perspective, room returns, structural framing, wall wear, ambient shadows and light pools.
- **Layered SVGs:** foreground workbench, rear cabinet, upper shelf, left cabinet, right shelf, open book, potion group and mortar.
- **Existing Godot scene:** the animated copper cauldron and its liquid are reused.
- **Godot animation:** candle flames, candlelight, crystal glow, cauldron glow and floating motes.

The SVG materials use the existing walnut, aged brass, dark teal, warm parchment and glass palette. Rear furniture is deliberately darker and less contrasty than the tabletop to preserve the depth separation visible in the Qwen reference.

## Review checklist

1. Does the main tabletop read as a large, slightly top-down 2.5D plane?
2. Are the rear cabinet and shelves clearly behind the table?
3. Does the near tabletop edge have enough thickness to give the bench volume?
4. Do the props visibly rest on the surface, with their contact shadows aligned to their bases?
5. Does the room retain the warm tabletop / dark rear-wall lighting hierarchy?
6. Does the composition feel like the reference without copying its generated surface texture?

## Validation

Godot 4.7 is not available in the editing environment, so runtime parsing, visual comparison and performance checks have not been performed here. Import and run the preview locally before treating the composition as approved. The first local render is still the authoritative visual review point.
