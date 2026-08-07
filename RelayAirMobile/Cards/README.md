# Relay Air — mini cards

A 200×200 tile for each kind of saved personal information. Each tile holds one
simplified real-world object, rendered as a deep material lit from the top-left.

| File | Card |
| --- | --- |
| `MiniCardKit.swift` | Tokens, materials, shell, type scale, glyph primitives |
| `CreditCardMini.swift` | Card 1 — premium bank card, graphite |
| `PassportMini.swift` | Card 2 — closed passport booklet, navy |
| `AddressMini.swift` | Card 3 — saved address as a mailing envelope, oxblood |
| `MiniCardShowcase.swift` | Horizontal shelf of all three, for looking at them on device |
| `MiniCardGallery.swift` | The three side by side, for checking the set stays even |

## The tile

Identical in all three, defined once in `MiniCardShell`.

| | |
| --- | --- |
| Canvas | 200 × 200 |
| Corner radius | 28, continuous |
| Padding | 24 (content box 152 × 152) |
| Background | `#FFFFFF` → `#F7F7F9`, top to bottom |
| Tint | 2.5% of the object's own colour, so the tile belongs to its card |
| Border | 1pt gradient, `#EBEBEF` → `#DCDCE3` |
| Shadow | black 5%, radius 10, y 3 |

The tile gradient is almost nothing on purpose. It exists so the object never
looks pasted onto flat paper.

## The one object rule

Each card carries exactly one object, centred, straight-on. Sizes are set so the
three carry roughly the same optical mass — that is what makes a mixed-orientation
set feel even.

| Card | Object | Area |
| --- | --- | --- |
| Credit | 144 × 91 — ISO 1.586 : 1 | 13,104 |
| Passport | 90 × 126 — ICAO 0.704 : 1 | 11,340 |
| Address | 140 × 92 | 12,880 |

Object radius is 10 everywhere; the passport's bound edge drops to 3, because that
is what separates a booklet from a rectangle.

## Materials

Every object is built the same way by `.miniObjectSurface(_:material:)` — only the
temperature changes. One light source, top-left, on all three:

1. **Body** — a three-stop gradient, topLeading → bottomTrailing.
2. **Sheen** — one specular pass, 4–10%. The moment it reads as a visible band it
   stops looking like a material and starts looking like a graphic.
3. **Rim** — a 1pt stroke that is bright where the light lands and nearly gone on
   the far side. This is what gives the object a machined edge.
4. **Shadow** — two of them: a tight contact shadow plus a wider ambient one. The
   pair is what actually makes it look lifted rather than blurred.

| Material | Stops | Used by |
| --- | --- | --- |
| `graphite` | `#4E535E` → `#2C3038` → `#181B21` | Credit |
| `navy` | `#2C3E64` → `#18233D` → `#0C1322` | Passport |
| `oxblood` | `#71404A` → `#46232C` → `#2A1319` | Address |

Oxblood rather than brown is deliberate: anything closer to neutral turns olive
against the gilt and drags the set down.

Because the materials are real colours rather than theme tokens, the objects render
identically in light and dark — a navy passport is navy either way. Only the tile
responds to the colour scheme.

## Gilt

One warm thread runs through every card, spent exactly once each: the EMV chip, the
passport emblem and title, the address seal. Four stops, so the highlight rolls
across the form the way foil does instead of sitting there as a flat tan wash.

```
#F9EDCB → #E3C88A → #BE9A55 → #EBD6A6
```

That single note is what makes the three read as a matched collection rather than
three unrelated tiles. If you add a card, spend the gilt once — not twice, not
never.

## Type

SF Pro throughout. Uppercase for all data, so the three cards share one texture.
Ink is white at four levels: .93 primary, .58 secondary, .44 tertiary, .30 mark.

| Style | Size | Weight | Tracking |
| --- | --- | --- | --- |
| `eyebrow` | 7.5 | semibold | 1.4 |
| `title` | 8.5 | bold | 1.5 |
| `data` | 9 | semibold | 0.5–0.6 |
| `dataSub` | 8 | medium | 0.3 |
| `digits` | 9.5 | semibold | 1.1, monospaced |

Applied with `.miniLabel(_:tracking:style:)`, which takes any `ShapeStyle` — so
`PASSPORT` can be filled with the gilt gradient directly — and caps every string to
one line at a 0.75 minimum scale, so long names shrink rather than breaking a
layout.

## Notes on each card

**Credit** — chip and network mark top, name and last four bottom, the entire middle
band empty so the material can show. The network mark is two overlapping translucent
discs: the overlap alone reads as a payment network, so no logo is needed and nothing
is branded. The chip's contacts run in rows, the way they do on a real chip.

**Passport** — the emblem-and-title cluster sits high and the biometric plate anchors
the foot, which is how a real cover is laid out. Everything struck on the cover is
foil. The globe is grid only: no country, no flag. The 5pt spine sits in its own
shadow with a single lit crease where the cover folds over.

**Address** — an envelope rather than a map. The flap is one extra thickness of
paper: a 6% wash, a lit edge, and a dark line 1pt beneath it. That dark line is what
turns a drawn V into an actual fold. Kept to 29% of the height so it stays a detail
instead of becoming a large triangle. The address block is optically centred in the
body the flap leaves free, not resting on the bottom edge. The seal carries a house,
not a GPS pin.

## Adding a fourth card

Build it from `MiniCardShell(material:)` + `.miniObjectSurface(_:material:)`, give
the object an area near 12,000, use the existing type scale, and spend the gilt
exactly once. If it needs a new material, keep the same light — three stops,
topLeading → bottomTrailing, with the rim and sheen values in the same range as the
existing three. Then open `MiniCardGallery` and check no tile pulls the eye first.
