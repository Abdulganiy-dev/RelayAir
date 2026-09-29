# Relay Air

Relay Air is being reset for a new Mac and shared-core implementation. The old Mac receiver and `RelayAirCore` package have been removed. The iOS app remains a standalone target and has no source imports or package link to Mac/Core code.

## Project layout

- `RelayAirMobile/` — the iOS app and its saved-item experience. It uses its own storage and Keychain code.
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
