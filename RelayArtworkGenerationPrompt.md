# Relay Air artwork generation prompt

Use the shared prompt below once per asset. Replace `SUBJECT` with one entry from the subject list. Keep the shared art direction unchanged between generations.

```text
Create one premium Relay Air app artwork icon.

SUBJECT: [replace with one icon description below]

Render it as a polished, high-gloss 3D object made from smooth colored enamel. Use the same finish, camera angle, softbox lighting from the upper left, highlight strength, and shadow depth across every icon. Keep colors saturated and clean, with crisp edges and subtle self-shadowing.

Use a square canvas with a transparent background. Show one isolated object centered in its natural orientation, with natural proportions. Keep its visual size consistent with the other icons: roughly 76% of the canvas. Align its lowest visible point to a common baseline touching the very bottom edge; leave no transparent strip underneath.

Do not include text, a backdrop, floor, cast shadow, glow, or reflection beneath the object. The app will add the same length reflection to each icon.
```

## Subjects

- Relay type credit card: landscape-format blue card with natural credit-card proportions, a chip, and contactless mark.
- Relay type passport: violet passport booklet with a simple gold globe emblem.
- Relay type address: teal location pin with an ivory house symbol.
- Relay type custom: magenta document tile with pale lines and a yellow plus badge.
- Saved item delete: coral open-lid trash can.
- Saved item send: orange and ivory paper plane with small motion marks.
- Saved item edit: purple pencil writing on an ivory document.

Generated files contain the icon only. `RelayArtworkIcon` adds the shared 18% height reflection at render time.
