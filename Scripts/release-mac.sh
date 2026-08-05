#!/bin/bash
#
# Builds, signs, notarises and staples the Mac app for distribution.
#
# Prerequisites, both one-off and both things only you can do:
#
#   1. A "Developer ID Application" certificate for team X84MQ7N5KN, created at
#      developer.apple.com ▸ Certificates, then downloaded and double-clicked so
#      it lands in your login keychain with its private key.
#
#   2. A stored notarytool credential, so no password lives in this script:
#
#        xcrun notarytool store-credentials "RelayAir" \
#          --apple-id "you@example.com" \
#          --team-id X84MQ7N5KN \
#          --password <app-specific-password>
#
#      Generate the app-specific password at appleid.apple.com ▸ Sign-In and
#      Security ▸ App-Specific Passwords. It is not your Apple ID password.
#
# Usage: Scripts/release-mac.sh [output-directory]

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$PROJECT_DIR/build/release}"
ARCHIVE="$OUT_DIR/RelayAir.xcarchive"
EXPORT_DIR="$OUT_DIR/export"
KEYCHAIN_PROFILE="RelayAir"
APP_NAME="Relay Air.app"

cd "$PROJECT_DIR"

echo "==> Checking for a Developer ID certificate"
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    cat <<'EOF'
error: no "Developer ID Application" certificate found in your keychain.

Relay Air's Mac app runs unsandboxed so it can drive other apps through the
Accessibility API, which rules out the Mac App Store — Developer ID is the only
distribution route.

Create one at https://developer.apple.com/account/resources/certificates ,
download it, and double-click to install. Then run this script again.

Development builds are unaffected: they sign with Apple Development and run
fine on this machine.
EOF
    exit 1
fi

echo "==> Archiving"
rm -rf "$ARCHIVE" "$EXPORT_DIR"
mkdir -p "$OUT_DIR"
xcodebuild \
    -project RelayAir.xcodeproj \
    -scheme RelayAirMac \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" \
    archive

echo "==> Exporting with Developer ID"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist ExportOptions.plist \
    -exportPath "$EXPORT_DIR"

APP="$EXPORT_DIR/$APP_NAME"

echo "==> Verifying the signature before we bother Apple with it"
codesign --verify --deep --strict --verbose=2 "$APP"
# Hardened Runtime is mandatory for notarisation, and is what lets an
# unsandboxed app still be trusted.
if ! codesign -dv "$APP" 2>&1 | grep -q "flags=0x10000(runtime)"; then
    echo "error: Hardened Runtime is not enabled — notarisation will be rejected." >&2
    exit 1
fi

echo "==> Zipping for submission"
ZIP="$OUT_DIR/RelayAir.zip"
rm -f "$ZIP"
# ditto preserves the bundle structure and signature; `zip` does not.
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Notarising (this usually takes a few minutes)"
xcrun notarytool submit "$ZIP" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "==> Stapling the ticket so it validates offline"
xcrun stapler staple "$APP"

echo "==> Final Gatekeeper check"
spctl -a -vv -t exec "$APP"

echo
echo "Done: $APP"
echo
echo "Note: changing the signing identity invalidates the app's existing"
echo "Accessibility grant. Remove the old entry under System Settings ▸ Privacy"
echo "& Security ▸ Accessibility and approve the new build."
