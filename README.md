# Relay Air

**Send. Approve. Fill.**

1. Send from iPhone.
2. Approve the transfer.
3. Automatically fill on the Mac.

The Mac side is a menu-bar agent that knows which text field you're in and fills
it. The iPhone side is the sender. Both ship as `Relay Air.app`.

> Scaffolding status: permissions, focus watching, and text injection are
> implemented and building. The transport between the two devices and the
> approval step are **not** wired up yet — `FillRequest` is the seam they will
> meet at.

## Layout

```
RelayAir.xcodeproj
├── RelayAirMac/            Mac receiver (LSUIElement, unsandboxed)
│   ├── RelayAirMacApp.swift       @main + MenuBarExtra
│   ├── AppDelegate.swift          accessory policy, onboarding window, teardown
│   ├── AppServices.swift          container for the long-lived objects
│   ├── RelayController.swift      Send → Approve → Fill state machine
│   ├── Permissions/               Capability + SystemPermission + observable state
│   ├── Capture/                   ScreenCaptureService
│   ├── Input/                     CursorController + TextInjector
│   └── UI/                        menu bar menu + setup window
├── RelayAirMobile/         iPhone sender (no permissions)
└── RelayAirCore/           local Swift package shared by both targets
```

`RelayAirCore` holds platform-neutral models (`RelayStep`, `RelayState`,
`FillRequest`, `AppIdentifiers`) so both targets describe the same flow in the
same words — the iPhone's onboarding list and the Mac's menu bar read from the
same `RelayStep`.

**The Mac does not inspect the focused field.** There is no Accessibility
element reading here: the app types into whatever has keyboard focus and never
learns what that is. That is why the approval step exists — the user is the one
who confirms the destination is right.

Deployment targets: macOS 14.0, iOS 17.0.

## Permissions (macOS)

Three capabilities, **two** system permissions — moving the cursor and typing
are both "post a `CGEvent`", which macOS gates behind a single Accessibility
grant. `Capability` holds the mapping; `SystemPermission` does the checking and
requesting.

| Capability | Implemented in | Permission |
|---|---|---|
| Move the cursor | `Input/CursorController.swift` | Accessibility |
| Type text | `Input/TextInjector.swift` | Accessibility |
| Capture the screen | `Capture/ScreenCaptureService.swift` | Screen Recording |

The setup window groups the capability rows under the permission that backs
them, so granting one and watching two rows light up isn't a surprise.

### Accessibility — required

- `SystemPermission.accessibility.isGranted` → `AXIsProcessTrusted()`
- `SystemPermission.accessibility.request()` → `AXIsProcessTrustedWithOptions`
  with `kAXTrustedCheckOptionPrompt`

Things that bite:

- **No Info.plist key exists** for this permission, and none is needed.
- **The app must not be sandboxed.** A sandboxed process cannot use the
  Accessibility API against other apps, so `ENABLE_APP_SANDBOX = NO` and
  `com.apple.security.app-sandbox` is `false`. Hardened Runtime stays on
  (`flags=0x10000(runtime)` on the signed binary), which is compatible.
  Consequence: distribute with Developer ID + notarisation, not the Mac App
  Store.
- **The system prompt appears at most once** per code-signed identity. After the
  user dismisses it there is no way to re-prompt, so `PermissionsModel` tracks
  what it has already asked for and the card switches to "Open Settings".
- **Re-signing invalidates the grant.** During development the user has to
  re-approve after signing-identity changes; stale entries may need removing from
  the Accessibility list first.
- TCC changes arrive with no notification, so `PermissionsModel` polls once a
  second while the app is open.

### Screen Recording — for screenshots

macOS gates screenshots behind the screen-*recording* permission. Used by
`Capture/ScreenCaptureService.swift` (ScreenCaptureKit + `SCScreenshotManager`).

- `SystemPermission.screenRecording.isGranted` → `CGPreflightScreenCaptureAccess()`
- `SystemPermission.screenRecording.request()` → `CGRequestScreenCaptureAccess()`

Notes:

- Also no Info.plist key.
- `CGRequestScreenCaptureAccess()` blocks until the prompt is dismissed, so
  `PermissionsModel` calls it off the main actor (`SystemPermission.requestBlocks`
  flags which ones need that).
- Nothing is requested automatically on launch — every prompt is behind a button
  in the setup window. The app still runs with only Accessibility; it just can't
  screenshot.

### Not requested, but worth knowing

If you ever add a global `CGEventTap` to *observe* keystrokes (hotkeys, trigger
detection), that is a **third** permission — Input Monitoring. *Posting* events
needs Accessibility; *listening* to them needs Input Monitoring. Prefer
`NSEvent.addGlobalMonitorForEvents` or a `Carbon` hotkey, both of which stay
within Accessibility.

`com.apple.security.automation.apple-events` is declared for a possible
AppleScript fallback. It is inert until used, and each target app still needs
per-app approval under Privacy ▸ Automation.

### iOS

No permissions, no usage-description keys. Deliberately.

## Relay states

`RelayController` holds a `RelayState`, and the menu bar reports it verbatim:

| State | Menu reads | Step | Symbol |
|---|---|---|---|
| `.paused` | Paused | — | `pause.circle` |
| `.waiting` | Waiting for iPhone | 1 · Send | `paperplane` |
| `.awaitingApproval` | Waiting for approval | 2 · Approve | `checkmark.shield` |
| `.filling` | Filling… | 3 · Fill | `cursorarrow.rays` |
| `.failed(reason)` | the reason | — | `exclamationmark.triangle` |

`receive(_:)` moves 1 → 2, `approve()` moves 2 → 3, `reject()` returns to 1.
Nothing advances past `.waiting` on its own yet — those are the entry points a
real transport will call.

## Lifecycle

Nothing runs when the app is not open:

- `applicationDidFinishLaunching` → `AppServices.begin()`: start permission
  polling, start the relay if permitted, show the setup window only if
  Accessibility is missing.
- `applicationWillTerminate` → `AppServices.end()`: `RelayController.stop()`
  drops any pending transfer and stops polling.
- The menu bar toggle calls the same start/stop pair, so the user can pause
  without quitting.

There is no login item and no `SMAppService` registration — the agent only runs
when launched.

## Filling text

`TextInjector` has two routes, tried in this order under `.automatic`:

| Route | Speed | Compatibility |
|---|---|---|
| pasteboard + ⌘V | fast | almost everything; pasteboard is saved and restored |
| synthesised typing | slow | everything, including fields that validate keystrokes |

## Building

```bash
xcodebuild -project RelayAir.xcodeproj -scheme RelayAirMac -configuration Debug -destination 'platform=macOS' build
```

```bash
xcodebuild -project RelayAir.xcodeproj -scheme RelayAirMobile -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

Because the Mac app is unsandboxed and needs a stable identity for its
Accessibility grant, run it from a consistent build location — bouncing between
DerivedData and an installed copy in `/Applications` means two separate grants.
