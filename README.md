# SpellSort — Atelier Opening and Sorting Prototype

This branch now starts with a hand-authored, dark Atelier hub. The player approaches the workbench, completes three guided sorting lessons, then returns to find the Atlas awakened and the Botanical Garden marked as the first destination.

The Atelier room is a hand-authored SVG composition, not a generated full-screen environment. The existing live vial, liquid, pouring and sorting systems remain separate and reusable.

## Run

Open the project in Godot 4.7 and press **F5** to run the project:

`res://scenes/atelier_hub.tscn`

Opening flow:
1. Select **Approach the Workbench**.
2. Complete the first three classic sorting lessons in sequence.
3. Select **Return** after the third lesson. The Atelier saves the unlock locally and reveals the Atlas.
4. Select the Atlas to view the first marked destination: **The Overgrown Entrance** in the Botanical Garden.

The design viewport is portrait, 720 × 1280. Opening progress is stored at `user://spell_sort_progress.cfg`.

For the unrestricted sorting mechanics prototype, open `scenes/dark_sorting_slots_prototype.tscn` and press **F6**. The earlier four-vial workbench test remains at `scenes/alchemy_interaction_test.tscn`.

## Environment artwork

The selected full-screen background is:

`assets/environments/SpellSort_Workbench.png`

The source image is 768 × 1376 and is displayed with aspect-cover scaling. The tabletop is part of the background artwork. A separate four-position vial rack is layered over the tabletop; no second tabletop or broad tray is drawn.

## Four-vessel layout

Four upright vessels are arranged in one centred horizontal row on the tabletop. All four use the same control size and the same scale; none is tilted or depth-scaled while resting.

- Vessel control size: 116 × 365
- Horizontal gap: 18
- Row Y position: 390 in the 720 × 1280 design viewport
- The vessel bodies, openings and resting liquid surfaces remain front-facing and level
- A separate wooden-and-brass vial rack sits behind the bottle controls, with four aligned empty sockets; the bottles remain independently draggable

The row is intentionally simple and readable. Perspective comes from the illustrated workbench background and the shallow illustrated rack, not from transforming the individual vessels.

The rack asset is `assets/environments/SpellSort_Vial_Rack.svg`.

A matching foreground overlay, `assets/environments/SpellSort_Vial_Rack_Front.svg`, draws only the near/front half of each brass holder above the bottle feet. This small overlap makes the glass appear recessed into the sockets. The foreground lips use z-index 10; resting bottles are at z-index 2, while a bottle being dragged is raised to z-index 50 and lifts visibly clear of its holder. It is a transparent vector overlay with four shallow brass-lined holders and a low rear support rail. The rack is drawn below the bottle controls, so the live bottle artwork covers each socket and can be lifted, dragged and returned independently.

## Dimensional vial glass

Each vessel keeps its original distinct silhouette and live liquid simulation, but now receives a matching transparent SVG glass overlay:

- `SpellSort_Vial_01.svg` through `SpellSort_Vial_04.svg` provide the four individual glass silhouettes.
- The SVGs add translucent edge tint, broad warm/cool reflections, a thicker optical foot, a substantial open glass lip and a small brass neck ferrule matching the rack.
- The live liquid is still drawn by Godot beneath the overlay, so fills, sloshing, pouring and level changes remain dynamic.
- The SVG overlays are drawn in the bottle's existing local transform, so drag lift, tilt and scaling affect the bottle and its reflections together.
 The rack's 620 × 300 screen-space rectangle is positioned at (50, 498). Its new 190-pixel raised rear panel sits behind the vial bodies; the original socket/base line remains unchanged.

## Sorting gameplay

The sorting activity is implemented in:

- `scripts/alchemy_interaction_test.gd` — level state, drag/drop, pour animation, stream, undo/reset and completion.
- `scripts/alchemy_bottle.gd` — live front-facing glass vessel drawing, animated liquid, slosh, lift and tilt.
- `scenes/alchemy_interaction_test.tscn` — screen root.

The current test level has four vessels, three essences and four measures per essence. Drag a vessel and align its open mouth with a valid receiving vessel. A valid transfer moves the matching contiguous run at the top of the source. Undo and Reset are available in the bottom HUD.

A compact translucent HUD sits at the top and bottom of the screen. It leaves the tabletop visible and does not draw artificial bottle slots.

## Presentation approach

- One illustrated 2D environment background.
- Live vessels and liquid remain independently rendered and interactive.
- No procedural 3D room, low-poly props, camera panning or shared painterly shader.
- All resting vessels share one front-facing orientation and scale.

## Validation and limitations

The scene is configured for a 720 × 1280 portrait viewport. The background source is 768 × 1376, so its aspect ratio is close to the design viewport. Final visual alignment, drag targeting, mouth alignment, liquid streams, undo, reset and completion still need a local Godot 4.7 runtime check.

Godot 4.7 was not available in the editing environment, so a runtime launch and interaction pass have not been performed here.


## Workbench cauldron

The layered cauldron is now part of the main sorting gameplay screen, positioned on the back half of the tabletop, slightly right of center and behind the vial row. It is a visual workshop prop and does not cover or intercept bottle interactions.

- `assets/environments/SpellSort_Cauldron_Rear.svg` — copper body, handles, feet, dark inner bowl and rear rim.
- `scripts/alchemy_cauldron.gd` — animated liquid with a full oval fill, moving wave bands, a drifting sheen and continuously moving bubbles.
- `assets/environments/SpellSort_Cauldron_Front.svg` — foreground rolled rim and front-metal highlights.
- `scenes/alchemy_cauldron.tscn` — reusable layered Godot cauldron scene.
- `scenes/alchemy_cauldron_preview.tscn` — isolated development preview using the same workbench background.

The separate preview remains available through **Run Current Scene (F6)**. `fill_level`, `liquid_color` and `animate_liquid` are exported on the cauldron's liquid node for tuning. Brewing interaction and ingredient inputs are not implemented yet.


## Reference-first 2.5D alchemy workshop experiment

A separate room reconstruction is available at:

`scenes/alchemy_workshop_experiment.tscn`

Open that scene and use **Run Current Scene (F6)**. This is a standalone visual experiment and does not replace the configured sorting gameplay scene.

The room is now built around the spatial composition of `assets/environments/SpellSort_Workbench.png`:

- A dark recessed wall with angled side returns and a perspective-drawn stone floor.
- A rear wall shelf, storage counter and separate side furniture placed in depth layers.
- A broad, shallow trapezoidal tabletop with a thick near edge and a deep front workbench body.
- Independent book, potion, mortar and cauldron props projected onto the tabletop using shared four-corner surface geometry.
- Reusable walnut, aged-brass, dark-teal, parchment and glass material treatments.
- Godot-drawn candle flames, ambient light, crystal glow and floating motes.

The root scene exports `show_tabletop_guides`. Enable it in the Inspector to display the tabletop corners, diagonals and prop anchors during layout review.

See `docs/alchemy-workshop-hybrid-experiment.md` for the reference landmarks, projection method, construction split and visual review checklist. Godot 4.7 runtime validation remains to be performed locally.
