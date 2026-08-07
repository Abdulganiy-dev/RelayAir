# Relay Air — card

One card the user dresses: a gradient, a surface texture, and four corner slots.

| File | What |
| --- | --- |
| `CardStyle.swift` | `CardGradient` — the palette, and the ink derived from it |
| `CardTexture.swift` | Five procedural surface textures |
| `CardContent.swift` | `CardContent`, `CardMark`, tints, artwork helpers |
| `EditableCard.swift` | The card itself, 358 × 225 |
| `CardBackgroundPicker.swift` | Gradient swatch strip |
| `EditCardDesignSheet.swift` | The design sheet — every control lives here |
| `CreateRelayItem.swift` | Holds the state and hands it to the sheet |

## The card

| | |
| --- | --- |
| Size | 358 × 225 standard, 300 × 200 compact |
| Corner radius | 20, continuous |

Three things make a card read as an object rather than a filled rectangle, and they
should survive any change to what sits on top:

1. **Sheen** — one specular pass, weak on purpose. The moment it reads as a visible
   band it stops looking like a material and starts looking like a graphic.
2. **Rim** — a 1pt stroke, bright where the light lands, nearly gone opposite.
3. **Shadow** — what makes it look lifted rather than merely blurred.

The card carries `.compositingGroup()` because the texture blends with the layers
beneath it. Without a compositing boundary that blend reaches *through* the card onto
whatever it is sitting on.

## Gradients only

There was a second background kind — flat colours — and it is gone. A flat colour
never looked like a material beside these, and keeping it meant a mode switch in the
picker that earned nothing. `CardGradient` is used directly; there is no wrapper enum.

Stops are hex strings rather than `Color`, so a chosen gradient encodes and restores
without a custom coder. Every gradient runs top-leading to bottom-trailing, so a card
always reads as lit from one direction.

Twelve, three stops each: a lit face, a body, a shadow. Two stops go chalky across a
card this size — the middle stop is what keeps them rich.

**Ink comes from the gradient's own luminance.** Champagne, Blush and Meadow are light
enough that white on them is unreadable; `isLight` flips the ink instead of banning
them from the palette. Text also carries `inkShadow` in the opposite direction, because
one ink cannot serve both ends of a gradient when the write-ups sit at opposite corners
of exactly that sweep. That shadow is on **text only** — behind a filled glyph the same
shadow reads as a glow.

## Textures

Five, all procedural — no assets, no licences, resolution-independent. They composite
with `.overlay` blend at low opacity, which modulates the light and dark of what is
underneath instead of painting grey over it. That is what lets one texture sit on
Champagne and on Midnight and read correctly on both.

`EditableCard` draws the texture at `standard` and scales the result. Guilloché alone
is tens of thousands of segments; running that `Canvas` against the live size would
redraw all of it every frame of the portal transition.

Strength is tuned per texture — a dense pattern needs far less presence than a sparse
one to read at the same weight.

The picker swatches show a **1:1 crop**, not a shrunken card. At swatch scale carbon,
pinstripe and guilloché fall below a pixel and vanish entirely.

## Content

Four corner slots, all optional:

| | |
| --- | --- |
| top-leading | mark |
| top-trailing | short note |
| bottom-leading | write-up |
| bottom-trailing | mark |

Both mark slots take the same `CardMark` — an SF Symbol with a tint, or imported
artwork — and both are bounded by the same 50 × 50 ceiling, applied in exactly one
frame in `CardContentLayer` so it cannot drift.

Content is laid out once at `standard` and scaled, for a different reason than the
texture: laying out against the live size would reflow the text mid-flight.

Imported photos are downsampled on the way in. A capture straight from the picker is
several megabytes for something drawn at 50pt.

## Adding to the palette

Match the neighbours: three stops with a lit face, a body and a shadow, running the
same direction. Give it a stable `id` — that string is what gets persisted, so renaming
one later orphans whatever the user had chosen.
