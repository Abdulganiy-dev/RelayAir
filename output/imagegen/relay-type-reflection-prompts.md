# Relay type icons with reflections

> Historical generation notes only. This prompt set is superseded for future regeneration; use the shared seven-asset system in [RelayArtworkGenerationPrompt.json](../../RelayArtworkGenerationPrompt.json).

Generated using the built-in ImageGen tool. Each transparent PNG contains the icon and its fading mirrored reflection.

## Saved assets

- [RelayTypeCreditCard](</Users/lawalabdulganiy/Desktop/Personal App/RelayAir/RelayAirMobile/Assets.xcassets/RelayTypeCreditCard.imageset/RelayTypeCreditCard.png>)
- [RelayTypePassport](</Users/lawalabdulganiy/Desktop/Personal App/RelayAir/RelayAirMobile/Assets.xcassets/RelayTypePassport.imageset/RelayTypePassport.png>)
- [RelayTypeAddress](</Users/lawalabdulganiy/Desktop/Personal App/RelayAir/RelayAirMobile/Assets.xcassets/RelayTypeAddress.imageset/RelayTypeAddress.png>)
- [RelayTypeCustom](</Users/lawalabdulganiy/Desktop/Personal App/RelayAir/RelayAirMobile/Assets.xcassets/RelayTypeCustom.imageset/RelayTypeCustom.png>)

## Final prompt set

Each request used the shared prompt below with its subject and palette line appended. Its corresponding existing asset was attached as the visual reference, with transparent background enabled.

```text
Use case: stylized-concept.
Asset type: a single transparent in-app relay type icon, displayed at about 60 points.
Input image: the attached current icon is the visual reference for its subject, recognizable shape, colors, and polished rounded 3D finish.
Primary request: regenerate this icon with a visible, tasteful mirror reflection directly beneath its bottom edge, as if it is standing on an invisible polished glass floor.
Reflection: a vertically flipped reflection of the lower portion of the SAME object, aligned accurately beneath it, showing recognizable colored edges and details. The reflection starts softly at the contact baseline and fades smoothly downward into actual transparency. It occupies only the bottom 12–16 percent of the square composition. Include a very subtle contact shadow, but make the mirror reflection clearly distinguishable from a shadow.
Composition: square 1:1 canvas, centered object, main silhouette in the upper 70 percent, reflection entirely contained below it, roughly 8–10 percent transparent safety margin at all edges. Keep the main icon large enough to be crisp and readable at small UI sizes; no cropped edges or reflection.
Style: clean premium soft glossy 3D, rounded beveled edges, gentle studio highlights, smooth antialiased contours, broad simple shapes, no tiny textures.
Background: truly transparent alpha everywhere outside the icon and fading reflection. Do not draw a floor plane, horizon, opaque white/black rectangle, checkerboard, tile, or backplate.
Constraints: preserve the existing subject and dominant palette; only introduce the reflection and adjust framing to fit it. No words, letters, logos, watermark, extra icons, or decorative objects.
```

## Subject and palette lines

### RelayTypeCreditCard

```text
Subject and palette: Cobalt blue payment card with cyan edge highlights, silver chip, and simple silver contactless mark; keep the card's slight tilt.
```

### RelayTypePassport

```text
Subject and palette: Deep violet and plum passport booklet with a warm gold globe emblem and ivory page edges; keep the gentle three-quarter angle.
```

### RelayTypeAddress

```text
Subject and palette: Emerald and teal location pin with a raised cream house at its center; keep the bold simple pin silhouette.
```

### RelayTypeCustom

```text
Subject and palette: Vivid magenta and orchid document with pale raised content lines and a yellow circular plus badge at the upper right; keep the rounded silhouette.
```
