# RelayAir Form Detector

Headless Manifest V3 extension that **detects form fields on a webpage** and reports where they are. No popup UI, no autofill — detection only.

## What it does

On every page, a content script scans for:

- `input` (excluding hidden/submit/button/file)
- `textarea`
- `select`
- checkboxes and radios

For each field it records type, id, name, label, selector, bounding box (`x`, `y`, `width`, `height`), and a simple rule-based classification (email, phone, name, …).

Dynamic pages are covered with a `MutationObserver`.

## Project structure

```
src/
 ├── content/
 │    ├── detector.ts
 │    ├── classifier.ts
 │    └── index.ts
 ├── background/
 │    └── service-worker.ts
 └── types/
      └── index.ts
```

## Install & build

```bash
cd RelayAirBrowserExtension
npm install
npm run build
```

Load `dist/` as an unpacked extension in Chrome (`chrome://extensions` → Developer mode → Load unpacked).

## How to read detections (no UI)

The toolbar badge shows the field count on the active tab. Clicking the icon refreshes detection.

### From the service worker / another extension page

```js
const response = await chrome.runtime.sendMessage({ type: "GET_FIELDS" });
// response.data.fields → [{ selector, position: { x, y, width, height }, classification, ... }]
```

### Example field payload

```json
{
  "fields": [
    {
      "type": "email",
      "label": "Email Address",
      "selector": "#email",
      "position": { "x": 300, "y": 200, "width": 280, "height": 40 },
      "classification": { "fieldType": "email", "confidence": 0.95 }
    }
  ]
}
```

This snapshot is what RelayAir (or a native host later) can consume to know **where** fields are on screen.

## Messages

| Type | Direction | Purpose |
|------|-----------|---------|
| `FIELDS_UPDATED` | content → background | Push latest snapshot when the DOM changes |
| `GET_FIELDS` | caller → background/content | Fetch current snapshot |
| `PING` | any → content | Health check / ensure script is injected |

## Safari

Uses standard MV3 WebExtension patterns (`chrome.*`, content scripts, service worker). Convert the `dist/` package with Safari’s web-extension converter when you need a macOS build.

## Out of scope

- Popup / settings UI
- Filling or submitting forms
- AI / remote APIs
- Auth, payments, native apps
