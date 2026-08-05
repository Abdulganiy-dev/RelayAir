# Relay Air

**Send. Approve. Fill.**

1. Send from iPhone.
2. Approve the transfer.
3. Automatically fill on the Mac.

The Mac side is a menu-bar agent that knows which text field you're in and fills
it. The iPhone side is the sender. Both ship as `Relay Air.app`.

> Status: the loop is closed. The iPhone pairs by QR, you confirm the transfer
> on the phone, it goes over an authenticated TLS link, and the Mac types it
> into the focused field on arrival and reports back. Screen capture works the
> same way, on demand from the phone.
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

### Two layers, because "Unpair" has to mean something

The QR secret only says *two devices have met*. It can't say *which* phone this
is — every paired phone holds the same secret, so a phone could claim to be any
other. That would make per-device revocation unenforceable.

So identity is a second layer:

| Layer | Secret | Answers |
|---|---|---|
| TLS-PSK | QR pairing secret, shared | "has this device ever been paired?" |
| Device auth | Per-device key, minted by the Mac | "*which* device is this?" |

At enrolment the Mac generates 32 random bytes, stores them against a device
record, and hands a copy to the phone. On every connection the phone sends
`.authenticate` with an HMAC over its device id and a timestamp; **no other
command is honoured until that succeeds**. Unpairing deletes the Mac's copy, so
that phone's proofs stop verifying — even though it still holds the QR secret
and can still complete the TLS handshake.

Deliberately *not* derived from the QR secret: if it were, anyone holding the QR
could forge any device's identity and revocation would be theatre. There's a
test for exactly that (`Knowing the QR secret does not let you forge a device`).

**Enrolment is gated on pairing mode.** A new device is only accepted while the
Mac is actually showing its code, so a photographed QR can't be used to enrol
silently weeks later.

> Attempted and rejected: per-device *TLS* keys via
> `sec_protocol_options_set_pre_shared_key_selection_block`. The block does fire
> on the listener and receives the client's identity hint, but returning a key
> still fails the handshake with `-9864 unknown PSK identity`. Hence
> authentication at the application layer instead.

**Framing.** Length-prefixed JSON — a 4-byte big-endian length, then the payload.
TCP is a byte stream with no message boundaries, so two commands sent
back-to-back arrive coalesced without this.

### Cost

Measured by `ConnectPerformanceTests`, which asserts bounds so this can't
silently regress:

| | Time |
|---|---|
| Reconnect (enrolled device) | ~1.1s |
| First pairing (enrol + authenticate) | ~1.1s |
| **Enrolment + auth overhead** | **~0.05–0.09s** |

Nearly all of it is Bonjour discovery. The two-layer handshake costs under a
tenth of a second, so simplifying *it* would buy nothing — worth knowing before
trading away per-device revocation for speed that isn't there.

Four things were costing bandwidth rather than latency, all now fixed:

- **AWDL is off** (`includePeerToPeer = false`). It keeps the Wi-Fi radio
  time-slicing between the infrastructure and peer-to-peer channels the entire
  time a browser is running, degrading throughput for everything else on the
  device. **Tradeoff: both devices must now be on the same Wi-Fi.** Pass
  `allowPeerToPeer: true` to `NWParameters.relayAir` to get router-free
  operation back.
- **The phone stops browsing once connected.** It used to keep multicasting mDNS
  queries for the whole session.
- **TCP keepalive is 30s idle / 10s interval / 3 probes** (~60s to notice a dead
  peer), not a probe every 2 seconds on an idle link.
- **The QR is cached.** It was regenerated through CoreImage on every SwiftUI
  update, since `qrImage(side:)` is called from `body` — which is what made the
  menu panel feel sluggish.

**Approval happens on the phone, not the Mac.** The confirmation is the last
thing before transmission — "confirm the transfer before anything leaves this
device". Once the Mac has the text, the decision is already made and it types
straight away; a second prompt on the Mac would be the same question asked
twice, and it would mean walking to the Mac to finish something you started on
your phone.

What still gates a `.fill` on the Mac is coarser and always on: the relay has to
be switched on, the device has to be enrolled and authenticated, and
Accessibility has to be granted.

The Mac's menu shows a redacted receipt of the last fill (`Filled 12 characters,
then return · from Abdul's iPhone`) — never the payload, which is routinely a
password or a one-time code, and the menu bar sits in front of whoever is
looking at the screen.

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

### What a capture actually grabs

`.captureScreen` returns **the window under the pointer**, not the whole
display — via `SCContentFilter(desktopIndependentWindow:)`, so the result is
cropped to that window at its own resolution rather than a full-screen shot the
phone has to squint at. It falls back to the display the pointer is on when the
pointer is over the desktop or something uncapturable.

Window selection keeps to `windowLayer == 0` (ordinary app windows — not the
menu bar, Dock, or tooltips), skips anything under 40×40, and never captures
Relay Air's own panel. `SCShareableContent.windows` comes back front-to-back, so
the first match is the one actually being looked at.

The cursor comes from `CGEvent(source: nil)?.location`, which is already in the
top-left-origin global space `SCWindow.frame` uses. `NSEvent.mouseLocation` is
bottom-left-origin and would need flipping against the primary screen's height —
verified on a two-display setup where the two differ by ~1150 points, so getting
this wrong picks a completely different window.

The response carries a `source` string ("Safari — Apple", or "Whole screen"),
shown under the preview on the phone so it's obvious the right thing was caught.

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

## Signing

**Development builds are already signed and need nothing from you.** Automatic
signing picks `Apple Development: Abdulganiy Lawal (GV2S46F4Y5)` (team
`X84MQ7N5KN`), enables Hardened Runtime, and the result passes
`codesign --verify --deep --strict`. `spctl` rejects it, which is correct and
expected — Gatekeeper only accepts Developer ID or App Store signatures, and a
development-signed app runs fine on the machine that built it.

**Distribution needs a Developer ID Application certificate, which isn't
installed yet.** Because the Mac app runs unsandboxed — mandatory for driving
other apps through the Accessibility API — the Mac App Store is not an option,
so Developer ID plus notarisation is the only route. Exporting today fails with:

```
No "Developer ID Application" signing certificate matching team ID "X84MQ7N5KN"
with a private key was found.
```

Create the certificate at
[developer.apple.com ▸ Certificates](https://developer.apple.com/account/resources/certificates),
download it, and double-click to install. Then:

```bash
Scripts/release-mac.sh
```

That archives, exports with Developer ID, verifies the signature and Hardened
Runtime, notarises, staples, and runs a final Gatekeeper check. It refuses to
start if the certificate is missing rather than failing three minutes in.

It needs a stored notarytool credential once, so no password ends up in the
repo — generate an app-specific password at appleid.apple.com first:

```bash
xcrun notarytool store-credentials "RelayAir" --apple-id "you@example.com" --team-id X84MQ7N5KN
```

> **Re-signing invalidates the Accessibility grant.** macOS ties TCC approvals to
> the code signature, so the first Developer ID build is a different app as far
> as the system is concerned. Remove the stale entry under System Settings ▸
> Privacy & Security ▸ Accessibility and approve the new one. The same applies
> when the development certificate expires (23 Aug 2026).

There are two Apple Development identities on this machine — the personal team
`X84MQ7N5KN` and SystemSpecs Limited `QP7F33SX3B`. The project targets the
personal one, matching the `com.ladulghanneey.*` bundle IDs; change
`DEVELOPMENT_TEAM` if it should ship under the company account.

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
