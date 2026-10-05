# Relay Air

## What is Relay?

Relay moves information from paper documents into online forms, so you don't have to type it again.

Your passport, driver's licence, ID card, or a filled-in paper form already holds the information a website is asking for. Normally you'd read it off the document and type each field by hand. With Relay you:

1. **Capture** — scan or photograph the document.
2. **Review** — check what Relay read and fix anything it got wrong.
3. **Fill** — point Relay at the online form and it fills the matching fields.
4. **Submit** — check the filled form, then submit it yourself.

Relay never submits anything without you seeing it first, which matters for handwriting, old documents, unclear photos, and sensitive information.

It works at two scales. One person can fill in a single form from their passport. An organization, such as a school or hospital moving years of paper records into a new online system, can process thousands of forms, and staff spend their time checking records rather than typing them.

## Current state

Relay Air is being reset for a new Mac and shared-core implementation. The old Mac receiver and `RelayAirCore` package have been removed. The iOS app remains a standalone target and has no source imports or package link to Mac/Core code.

## Project layout

- `RelayAirMobile/` — the iOS app and its saved-item experience. It uses its own storage and Keychain code.
- `RelayAirMobile/Views/` — app destinations and relay-item screens.
- `RelayAirMobile/Sheets/` — sheet and full-screen-cover content, grouped by feature.
- `RelayAirMobile/Components/` — reusable UI, grouped into backgrounds, cards, controls, feedback, icons, menus, relay items, and styling.
- `RelayAirMobile/Cards/` and `RelayAirMobile/RelayItems/` — card design and relay-item models.
- `RelayAirMobile/Stores/` — database, Keychain, and user preference storage.
- `RelayAirMobile/Utils/` and `RelayAirMobile/Navigation/` — non-UI helpers and navigation state.
- `RelayAirMobile/Shaders/` — Metal shader sources used by the app UI.
- `RelayAirMac/` — a minimal SwiftUI macOS app shell for the next implementation.
- `RelayAirBrowserExtension/` — the browser form-detection extension, kept separate from the Apple app targets.
- `Legacy/RelayAirSender/` — archived sender and QR-scanner sources kept for reference. They are outside the Xcode app targets and are not compiled.

The Mac app and any future shared code can be rebuilt without introducing a dependency from the mobile target.

## Build

Build either Apple app from Xcode, or use these commands:

```sh
xcodebuild -project RelayAir.xcodeproj -scheme RelayAirMobile -destination 'generic/platform=iOS Simulator' build
xcodebuild -project RelayAir.xcodeproj -scheme RelayAirMac -destination 'platform=macOS' build
```

Build the browser extension from its directory with `npm run build`.
