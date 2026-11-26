# Spell Sort — Ten-Level Gameplay Direction Test

Status: design prototype, not production level data.

Purpose: compare two genuinely different progression models before committing more environment artwork.

- **Track A — Four-vial alchemy:** a fixed four-vial rack; the game must earn variety through sorting decisions and a small set of alchemy mechanics.
- **Track B — Expandable sorting:** conventional liquid sorting; the number of vials and essences grows from four to eight.

Both tracks share the same first three levels. This gives us a common baseline before they diverge.

## Shared baseline rules

- Vial capacity: four layers.
- A normal pour transfers the complete contiguous run of the top essence, limited by destination capacity.
- A destination must be empty or have the same essence on top.
- A pure-sort objective is complete when each essence is consolidated into its own vial.
- Essence symbols below are placeholders: **A = Tide, B = Ember, C = Moon**, with further essences introduced as needed.
- Layout lists are **bottom-to-top**. An em dash means empty.

The first three seed arrangements are shared by both tracks:

### Level 1 — First Separation

Two essences, four rack positions, two empty vials. Teach selecting a source, selecting a valid destination, and completing a simple sort.

Seed:
- Vial 1: A B A B
- Vial 2: B A B A
- Vial 3: empty
- Vial 4: empty

### Level 2 — Third Essence

Three essences, four vials, one empty buffer. Introduce the full four-slot constraint.

Seed:
- Vial 1: C A B A
- Vial 2: A B C B
- Vial 3: B C A C
- Vial 4: empty

### Level 3 — The Tangle

Still three essences and one buffer, but use a more interleaved arrangement. This is the first check that the basic mechanic itself is satisfying, rather than relying on a new rule every level.

Seed:
- Vial 1: A B C B
- Vial 2: C A C B
- Vial 3: A B A C
- Vial 4: empty

For these reference seeds, the shortest standard-pour solutions are 7, 10 and 12 pours respectively. These are reference puzzle seeds for the direction test; final level files still need in-game verification and tuning.

---

# Track A — Four-vial alchemy

**Fixed footprint:** four visible vials, each with four-layer capacity. In conventional pure-sort levels this means at most three essence groups plus one empty buffer. The rack and environment remain fixed; no second vial row is assumed.

The point of this track is not to disguise a four-vial limit. It is to find out whether a small number of reusable alchemy mechanics can create satisfying decisions without feeling like arbitrary exceptions.

| Level | Setup | New decision / mechanic | What we are testing |
|---|---|---|---|
| **A1 — First Separation** | 2 essences, 4 vials, 2 empty | Standard sorting only | Does the basic pour feel good and readable? |
| **A2 — Third Essence** | 3 essences, 4 vials, 1 empty | Standard sorting only | Does the four-slot constraint create useful planning? |
| **A3 — The Tangle** | 3 essences, 4 vials, 1 empty; deeper interleaving | Standard sorting only | Can we make a meaningful difficulty step without adding a rule? |
| **A4 — Pipette** | 3 essences, 4 vials, 1 empty | One-use precision pour: spend the level's pipette charge to move exactly one top layer instead of the complete matching run | Does controlled splitting create a good decision, or just extra tapping? |
| **A5 — The Careful Draught** | 3 essences, 4 vials, 1 empty | A harder layout with one pipette charge; using it too early should make the remaining puzzle harder | Can the pipette support more than its introduction level? |
| **A6 — Rune-Sealed Flask** | 3 essences, 4 vials, 1 empty | One flask is sealed as a receiver. It unlocks when the player joins a marked pair of matching essences in another vial | Does a visible, alchemy-themed subgoal add planning without becoming busywork? |
| **A7 — Breaking the Seal** | 3 essences, 4 vials, 1 empty | A buried marked pair must be exposed and joined before the sealed receiver becomes available; pipette charge is not used here | Can the seal mechanic support a second distinct puzzle, rather than repeating A6? |
| **A8 — Recipe Order** | 3 essences, 4 vials | Replace the pure-sort win condition with a recipe card: a designated vial must contain a specified bottom-to-top sequence; remaining essences are consolidated as far as the recipe permits | Is making a potion recipe more interesting than simply grouping colors? |
| **A9 — Transmutation** | 3 base essences, 4 vials | In a designated retort, an adjacent Tide + Ember pair can transmute into one Dusk layer. The recipe now requires the result | Does a meaningful alchemy reaction expand the puzzle, or distract from sorting? |
| **A10 — The Master Formula** | 3 base essences, 4 vials | A multi-step recipe uses one known transmutation and one pipette charge. No new rule is introduced | Do the mechanics combine naturally into a satisfying finale? |

### Track A guardrails

1. Do not add a new mechanic just to make the next level different. The pipette, rune seal and recipe/transmutation systems must each be reusable.
2. Avoid stacking more than two special mechanics in one level until the individual mechanics have proved themselves.
3. Special actions must be visible and understandable from the artwork and interaction feedback.
4. If A4–A10 feel like a sequence of unrelated exceptions, Track A is not succeeding. We should not preserve the four-vial format at any cost.
5. The fixed rack remains a presentation choice only if this track proves viable. No permanent four-vial sockets should be painted into the environment before that decision.

---

# Track B — Expandable classic sorting

**Scalable footprint:** the level decides how many vials are present. All vials keep the same four-layer capacity and the same standard pour rules. The early levels are identical to Track A; progression then comes from additional essence groups, more containers, and the number of available empty buffers.

| Level | Essences | Vials | Empty buffers | Difficulty intent |
|---|---:|---:|---:|---|
| **B1 — First Separation** | 2 | 4 | 2 | Shared tutorial seed; learn the core pour loop |
| **B2 — Third Essence** | 3 | 4 | 1 | Shared introduction to the full four-vial board |
| **B3 — The Tangle** | 3 | 4 | 1 | Shared deeper interleaving; establish a basic difficulty baseline |
| **B4 — A Wider Bench** | 4 | 5 | 1 | Add a fifth vial and a fourth essence; test the first layout expansion |
| **B5 — Extra Reagent** | 4 | 6 | 2 | Keep four colors but add a second buffer; puzzles can require deliberate buffer management |
| **B6 — Five Essences** | 5 | 6 | 1 | Increase color count while returning to one buffer |
| **B7 — The Second Row** | 5 | 7 | 2 | Test a two-row layout with five colors and two buffers |
| **B8 — Six Essences** | 6 | 7 | 1 | Add a sixth color and reduce the buffer to one |
| **B9 — The Full Rack** | 6 | 8 | 2 | Eight-vial layout; more containers but two temporary buffers |
| **B10 — Grand Sorting** | 7 | 8 | 1 | Eight vials, seven colors and one buffer; the first full-scale conventional sorting challenge |

### Track B guardrails

1. Use a neutral placeholder layout for this test. Do not redesign the workshop artwork just to fit eight vials.
2. Do not shrink the vials to the point that essence layers or touch targets become hard to read.
3. The second row must read as a deliberate physical arrangement, not a pile of tiny icons.
4. Keep the rules conventional through B10. This lets us see whether scale alone creates a satisfying progression before introducing special mechanics.
5. If eight vials do not fit comfortably in the available mobile viewport, record that as a presentation constraint; do not silently shrink everything.

---

## How to judge the two tracks

We should play the ten levels in order, not just compare their screenshots.

Record these observations for every level:

- **Clarity:** did the player understand what they can pour and what the goal is?
- **Decision quality:** did the puzzle require planning, or was the solution obvious?
- **Freshness:** did this level feel meaningfully different from the previous one?
- **Friction:** did a mechanic feel clever, or did it feel like an arbitrary restriction?
- **Presentation:** could the vials remain large, legible and grounded in a believable physical setup?
- **Level-authoring cost:** how much extra design work was needed to create one more good level?

### Decision after Level 10

Choose **Track A** only if the small set of alchemy mechanics feels coherent, reusable and genuinely improves the sorting decisions. A beautiful four-vial rack alone is not enough.

Choose **Track B** if conventional sorting remains engaging as the number of essences and vials increases, and the multi-row presentation remains readable. This would justify a gameplay-first environment with a flexible rack or shelving system.

If neither track is convincing, do not force a decision between them. Revisit the core sorting rules before creating more artwork.

## Current production decision

- Keep the generated workshop image and the current four-vial arrangement as a visual reference only.
- Do not add the permanent rack to the background yet.
- Do not add SVG rack parts over the generated artwork.
- Do not commission another environment variant until this ten-level direction test identifies the gameplay footprint.
- Treat all level seeds and mechanics in this document as design prototypes; no production level data or gameplay code is changed by this document.
