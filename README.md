# Relay Air

**Send. Approve. Fill.**

1. Send from iPhone.
2. Approve the transfer.
3. Automatically fill on the Mac.

The Mac side is a menu-bar agent that knows which text field you're in and fills
it. The iPhone side is the sender. Both ship as `Relay Air.app`.

> Status: the loop is closed. The iPhone pairs by QR, sends text over an
> authenticated TLS link, the Mac holds it until you approve from the menu bar,
> then types it into the focused field and reports the outcome back to the
> phone. Screen capture works the same way, on demand from the phone.
>
> Not done: any kind of credential store on the phone (you type what you send),
> multi-Mac pairing, and reconnection backoff tuning.

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

## Pairing and transport

The security goal: **only your phone can talk to only your Mac, nobody on the
network can read or inject anything, and the Mac never types something you
didn't approve.**

Three mechanisms, one per property:

| Property | Mechanism |
|---|---|
| Authentication | QR pairing → TLS pre-shared key |
| Confidentiality | TLS over Bonjour/TCP, local network only |
| Intent | The approval step before any `.fill` is typed |

**Pairing.** The Mac mints a 256-bit secret on first launch, keeps it in the
Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, never synced), and
renders it as a QR containing
`relayair://pair?v=1&s=<service>&n=<name>&k=<base64url secret>`. The iPhone scans
it and stores the same payload. "Generate New Code" on the Mac invalidates every
previously paired phone — that's the revoke button.

**Why TLS-PSK and not just encryption.** The secret becomes the TLS pre-shared
key, so a device that never scanned the code **cannot complete the handshake** —
it's rejected during TLS negotiation, before any application data exists. This is
the reason the transport is Network.framework rather than MultipeerConnectivity:
Multipeer encrypts the channel but tells you nothing about who's on the far end,
so its listener has to accept a connection first and check identity afterwards.

**Framing.** Length-prefixed JSON — a 4-byte big-endian length, then the payload.
TCP is a byte stream with no message boundaries, so two commands sent
back-to-back arrive coalesced without this.

**The approval gate is the response.** A `.fill` command's reply is held open by
the Mac until the user approves or rejects, so the phone shows "waiting for
approval" and then reports what actually happened — `.done`, `.rejected`, or a
failure. The alternative (acknowledge on arrival, tell the user "sent") would
claim success for a transfer that may never be typed. This is why `.fill` is
sent with a 120s timeout while everything else uses 20–30s, and why unrelated
commands are tested to keep flowing while an approval is parked.

**Focus returns before typing.** Approving happens from the menu bar, which is
key while its menu is open. `RelayController.approve()` waits 250ms for the
previously frontmost app to take focus back, or the keystrokes land nowhere.

**A handshake against the wrong secret does not surface as `.failed`.**
Network.framework parks the connection in `.waiting` and retries forever, which
would leave the UI stuck on "Connecting…". `RelayConnection` therefore imposes
its own handshake deadline and reports `handshakeFailed`, which `RelayLink`
turns into a terminal error rather than a reconnect loop.

### Local Network — both platforms

Required for Bonjour discovery. `NSLocalNetworkUsageDescription` plus
`NSBonjourServices` (`_relayair._tcp`, `_relayair._udp`) in both Info.plists.
iOS prompts on first use; macOS 15+ does too. **There is no API to query this
permission's state**, so a refusal presents as "never finds a peer" rather than
an error — check System Settings ▸ Privacy & Security ▸ Local Network first when
discovery hangs.

### Camera — iOS only

`NSCameraUsageDescription`, used once to scan the pairing QR. Nothing else on
iOS asks for a permission.

### Why not iCloud for transport

Considered and rejected. CloudKit round trips run 1–5s and silent-push wake-up
on a Mac agent is throttled and best-effort — too slow for "focus a field, tap
send, it fills," especially for an OTP. It would also put secrets in transit and
at rest on Apple's servers, when the LAN path means they never leave the room.
iCloud's legitimate future role here is syncing the *pairing record* across the
user's devices, not carrying payloads.

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

Transport and pairing have test coverage, including that a wrong secret is
rejected at the TLS layer:

```bash
cd RelayAirCore && swift test
```

Pairing can't be completed on the Simulator — it has no camera to scan the QR.
Use a real iPhone on the same Wi-Fi as the Mac.

Because the Mac app is unsandboxed and needs a stable identity for its
Accessibility grant, run it from a consistent build location — bouncing between
DerivedData and an installed copy in `/Applications` means two separate grants.
