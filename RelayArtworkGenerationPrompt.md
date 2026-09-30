# Relay Air artwork generation prompt

Use the shared art direction below once per asset. Replace `SUBJECT` with one entry from the subject list. Keep the framing, camera, lighting, and level of detail consistent across generations while allowing each object's material to suit its subject.

```text
Create one premium Relay Air app artwork icon.

SUBJECT: [replace with one icon description below]

Render a polished dimensional 3D miniature product illustration. Make the object immediately recognizable at small UI size, with a clean silhouette, natural proportions, and softly rounded, carefully finished edges.

Use a square canvas with actual transparent pixels. Show one isolated object in a subtle front three-quarter view, centered with a consistent visual footprint. Keep the object's longest visible dimension to about 78% of the canvas. Align its lowest visible point to a common baseline at the bottom edge. Preserve natural orientations: the credit card stays landscape, the passport and documents stay upright, and the paper plane stays diagonal.

Use one broad, diffused studio light from the upper left, gentle fill, soft form shading, and subtle self-occlusion. Keep highlights broad and restrained. Use a material that fits the object instead of applying the same enamel finish to every asset. Materials can include satin polycarbonate, pebbled cover stock, ceramic, matte cardstock, powder-coated metal, folded paper, or painted wood. Keep color rich and clear with controlled tonal depth.

Do not include text, logos, a backdrop, floor, cast shadow, glow, bloom, or reflection beneath the object. The app adds the same reflection to every icon. Keep all visual detail within the object's silhouette and preserve clean alpha edges.
```

## Subjects

- Relay type credit card: landscape cobalt card with natural bank-card proportions, a gold-tone chip, and a contactless mark; satin polycarbonate body and softly brushed chip.
- Relay type passport: closed, upright deep-violet passport booklet with warm ivory page edges, a muted-gold longitude-and-latitude globe medallion, and a small biometric chip mark; fine pebbled cover.
- Relay type address: folded warm-ivory paper map with sparse muted-teal route lines and one satin teal location marker.
- Relay type custom: upright magenta document tile with three ivory lines and a mustard-yellow plus badge; matte cardstock and lightly embossed details.
- Saved item delete: coral-red waste bin with its lid open; satin powder-coated metal.
- Saved item send: orange and ivory folded paper airplane pointed upward and to the right; matte paper with clear fold creases.
- Saved item edit: deep-purple painted wooden pencil writing on warm-ivory paper; graphite tip and a small muted-brass ferrule.

Generated files contain the icon only. `RelayArtworkIcon` adds the shared 18% height reflection at render time.
