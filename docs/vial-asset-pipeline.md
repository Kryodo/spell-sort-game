# Vial asset pipeline

## Decision

Vials use a data-driven, layered asset contract. The liquid renderer must never infer the chamber from the transparency or reflections of the finished glass illustration.

Each vial is one `VialAssetDefinition` resource with:

- **Glass back** — rear wall, silhouette shading and rear reflections, drawn behind liquid.
- **Liquid mask** — a separate, clean chamber mask. Opaque white marks the area liquid may occupy; transparent/black marks everything else.
- **Glass front** — front rim, restrained highlights and any front-facing glass details, drawn above liquid.
- **Anchors** — normalized mouth position and hit radius.
- **Fill limits** — normalized top and bottom of the playable chamber.

The same generic renderer handles every vial. A new silhouette requires a new asset definition and its own mask, not a new liquid algorithm or code subclass.

## Why the previous approach is retired

The Vial 2 renderer attempted to recover the chamber by flood-filling transparent pixels in the final PNG. That couples gameplay geometry to incidental art details: reflections, antialiasing, transparency, and any future art edits can change the inferred bounds. It is not a reliable production interface and must not be extended.

The old alpha-derived renderer is therefore a disposable experiment, not the template for future vessels.

## Mask authoring rules

- The mask uses the same canvas dimensions and alignment as the glass layers.
- White/opaque means liquid is allowed; black/transparent means it is forbidden.
- The mask describes the complete internal cavity, including a narrow neck only if the neck is intended to hold liquid.
- The playable fill range is separately defined so the mouth and decorative foot do not become fill space.
- The mask is authored once per vial and remains independent of essence colours, layer count, capacity and animation.

A mask must be checked over the glass artwork before a vial is approved. Do not derive it at runtime from the finished glass PNG.

## Rendering order

1. Rear glass.
2. Liquid layers, all clipped to the dedicated chamber mask.
3. Front glass and rim.
4. External pour stream.

The pour stream begins at the authored mouth anchor. Its start is not drawn across an opaque front neck/rim. The mouth aperture remains visually open.

## Art direction constraints

- Stylized hand-painted 2.5D casual-fantasy shapes; broad, soft colour transitions.
- Muted smoky glass tints that sit comfortably in the dark workshop.
- No broad solid-white reflections, razor-sharp outlines, etched micro-detail or photoreal glass.
- Highlights should be sparse and low contrast so the essence remains the strongest colour inside the vessel.
- The outside canvas is transparent. The central chamber is genuinely transparent in the glass layers; the separate mask is not visible in-game.

## Current migration status

The resource contract and generic masked renderer are now in the project:

- `scripts/vial_asset_definition.gd` stores the layer textures, mask, normalized anchors and fill range.
- `scripts/masked_asset_fantasy_alchemy_bottle.gd` samples the dedicated mask row-by-row once and uses that profile for every liquid layer. It does not flood-fill or inspect the glass artwork.
- Artwork can use contain or cover fitting, so a square source illustration can retain the intended tall crop inside the vial control.

The new renderer is not yet wired into the active prototype because the existing Vial 2 PNG is a provisional single-layer illustration and does not satisfy the layered contract. It must not be treated as a production-ready vial or used to validate the final glass treatment. The current prototype remains an isolated visual experiment until replacement back/front artwork and a matching mask are authored and inspected together.

## Acceptance checks

- A full vial fills to the authored chamber walls without gaps.
- Partial fills remain clipped to the same mask.
- Changing essence colours or layer count requires no mask changes.
- A second vial with a different silhouette works by swapping only its asset definition.
- No liquid appears outside the glass or across an opaque neck.
- The glass remains subdued against the dark workshop and does not wash out the liquid.
- Pickup, tilt, pour, undo and restart retain the existing sorting rules.
