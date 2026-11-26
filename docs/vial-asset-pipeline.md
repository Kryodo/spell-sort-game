# Single-image vial pipeline

## Decision

Each vial is one complete PNG illustration. The PNG contains the full glass artwork, a genuinely transparent outer background, and a genuinely transparent central chamber. Godot draws the live liquid first and the same PNG over it.

There are no separate rear-glass, front-glass, or mask images. Qwen only has to produce one finished vial.

## Shared rendering

The shared renderer in scripts/asset_fantasy_alchemy_bottle.gd handles every illustrated vial. It:

- analyses the texture's transparent centre once and caches the result for all vial instances using that texture;
- finds the broad body region from its scanline widths, excluding the narrower neck and foot;
- builds a smoothed chamber profile from those rows;
- derives a mouth anchor from the transparent opening near the top;
- draws all liquid layers, surface motion and bubbles inside that profile;
- draws the complete source PNG over the liquid with one shared, subdued glass tint.

A new design uses the same script and liquid renderer. It does not require a new subclass, Qwen-generated layers, a hand-aligned mask, or manually tuned liquid coordinates.

## Artwork requirements

- One centered vessel on a fully transparent canvas.
- The inside of the main chamber must be genuinely transparent, not painted pale blue or white.
- The neck should be open and transparent; no cork, stopper or sealed cap.
- The main body should be wider than the neck and decorative foot so the shared profile detector can identify the fillable chamber.
- Keep the style broad, soft and painterly, with muted glass reflections. The shared renderer applies a restrained cool-sage tint to reduce the bright white glass against the dark workshop.
- Keep highlights away from the centre of the chamber so the transparent scanline remains continuous.

## Current proof of concept

The active prototype uses assets/bottles/SpellSort_Vial_2.png as its single-image test asset. The old per-pixel connected-component flood fill has been replaced by a simpler centre-scanline detector with a relative body-width cutoff. A narrow neck therefore does not become part of the liquid fill range.

SpellSort_Vial_1.png is not used as the second test shape: it has a stopper and a much more opaque-looking centre, so it is not a valid open, transparent vessel for this rendering test. A second suitable one-piece illustration is still needed before shape-independence can be confirmed visually.

## Acceptance checks in Godot

1. Full, partial and nearly empty fills remain inside the body and do not climb into the neck or foot.
2. The PNG's front reflections remain visible over the liquid, while the liquid remains clearly readable.
3. The glass sits more comfortably against the dark workshop because of the shared tint.
4. Pouring begins at the automatically detected mouth opening.
5. A second open, transparent vial with a different silhouette works by assigning its PNG to the same renderer, without changing the liquid code.

The renderer is implemented, but the visual checks still need to be run in the Godot project.