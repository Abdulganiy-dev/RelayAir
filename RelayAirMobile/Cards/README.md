# Relay Air — card

One card the user dresses. Colours and gradients today; background images and
textures next.

| File | What |
| --- | --- |
| `CardStyle.swift` | The `CardBackground` model and both palettes |
| `EditableCard.swift` | The card itself, 358 × 225 |
| `CardBackgroundPicker.swift` | Kind toggle plus the swatch grid |
| `CardEditorView.swift` | The screen — card on top, controls underneath |

Reached from the `rectangle.stack` button in `MainView`'s top-right toolbar.

## The card

| | |
| --- | --- |
| Size | 358 × 225 (1.591 : 1, essentially ISO) |
| Corner radius | 20, continuous |
| Content | none yet — this is the surface, not the layout |

It is deliberately more than a filled rectangle:

1. **Sheen** — one specular pass, 10% white at the lit corner falling to 6% black
   at the far one. Weak on purpose; the moment it reads as a visible band it stops
   looking like a material and starts looking like a graphic.
2. **Rim** — a 1pt stroke, bright where the light lands and nearly gone opposite.
3. **Shadow** — two: a tight contact shadow plus a wider ambient one. The pair is
   what makes the card look lifted rather than merely blurred.

That treatment is why a flat colour still reads as an object. Keep it when content
lands on top.

## The model

`CardBackground` is `.solid` or `.gradient`, and gains a case per new kind. Both
store **hex strings rather than `Color`**, so a chosen background encodes and
restores later without a custom coder.

Adding images or textures means a new case on `CardBackground`, a matching entry in
`CardBackgroundKind`, and a branch in `CardBackgroundPicker.swatches`. Nothing else
on the screen should need to move.

`CardBackground.deepest` returns the darkest stop, for anything that later needs to
sit against the background — a knocked-out mark, a divider, an inner shadow.

## Palettes

Twelve of each, shown three rows of four.

**Colours** walk the wheel: cool neutrals → blues → greens → warms → reds →
violet. Every one is dark enough to carry white content. That constraint is
deliberate — once content lands, a palette where every option guarantees legible
white is worth more than one with wider range. Hold the line when adding to it.

**Gradients** are three stops each, all running topLeading → bottomTrailing so a
card always reads as lit from one direction regardless of which is chosen. Two
stops go chalky across a card this size; the middle stop is what keeps them rich.

Known gap: **Champagne, Blush and Meadow are light in their upper-left** and will
not carry white content. Either deepen them or have the card choose ink from
background luminance — whichever, decide it when content arrives rather than after.

## Adding to a palette

Match the neighbours. For a colour, deep enough for white text. For a gradient,
three stops with a lit face, a body and a shadow, and the same topLeading →
bottomTrailing run. Give it a stable `id` — that string is what gets persisted, so
renaming one later orphans whatever the user had chosen.
