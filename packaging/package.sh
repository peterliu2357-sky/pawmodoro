#!/usr/bin/env bash
#
# Builds Pawmodoro into a distributable macOS app: a .app bundle, optionally
# code-signed with a Developer ID, packaged into a DMG, and notarized + stapled.
#
# The script degrades gracefully so you can use it before you have credentials:
#   - with no SIGNING_IDENTITY it produces an unsigned .app for local testing;
#   - with SIGNING_IDENTITY it signs (hardened runtime) and builds a DMG;
#   - with NOTARIZE=1 (+ a notarytool credential profile) it also notarizes
#     and staples the DMG for distribution outside the Mac App Store.
#
# Usage:
#   packaging/package.sh                       # unsigned .app (local only)
#   SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#     packaging/package.sh                     # signed .app + DMG
#   SIGNING_IDENTITY="..." NOTARIZE=1 NOTARY_PROFILE=pawmodoro-notary \
#     packaging/package.sh                     # signed + notarized + stapled DMG
#
# See packaging/README.md for how to fill in the credentials.

set -euo pipefail

# ---- Configuration (override via environment) --------------------------------
APP_NAME="${APP_NAME:-Pawmodoro}"
BUNDLE_ID="${BUNDLE_ID:-com.pawmodoro.Pawmodoro}"
VERSION="${VERSION:-1.0.0}"
# Monotonic build number; defaults to the commit count so it always increases.
BUILD="${BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"     # "Developer ID Application: … (TEAMID)"; empty = don't sign
NOTARIZE="${NOTARIZE:-0}"                     # 1 = notarize + staple the DMG
NOTARY_PROFILE="${NOTARY_PROFILE:-}"         # `notarytool store-credentials` profile name
MAKE_DMG="${MAKE_DMG:-auto}"                 # auto | 1 | 0  (auto = only when signed)

# ---- Paths -------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
DIST="$REPO_ROOT/dist"
APP_BUNDLE="$DIST/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

step() { printf '\n\033[1;36m▶ %s\033[0m\n' "$1"; }
info() { printf '  %s\n' "$1"; }

# ---- 1. Build the release executable ----------------------------------------
step "Building release executable"
swift build -c release
EXECUTABLE="$(swift build -c release --show-bin-path)/$APP_NAME"
[ -f "$EXECUTABLE" ] || { echo "error: built executable not found at $EXECUTABLE" >&2; exit 1; }
info "built $EXECUTABLE"

# ---- 2. Assemble the .app bundle --------------------------------------------
step "Assembling $APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$EXECUTABLE" "$CONTENTS/MacOS/$APP_NAME"
cp "$REPO_ROOT/packaging/Info.plist" "$CONTENTS/Info.plist"

# Stamp identity/version into the bundle's Info.plist.
plist() { /usr/libexec/PlistBuddy -c "$1" "$CONTENTS/Info.plist"; }
plist "Set :CFBundleIdentifier $BUNDLE_ID"
plist "Set :CFBundleShortVersionString $VERSION"
plist "Set :CFBundleVersion $BUILD"

# Bundle the app icon if one has been generated (see README — optional).
if [ -f "$REPO_ROOT/packaging/AppIcon.icns" ]; then
  cp "$REPO_ROOT/packaging/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
  info "bundled AppIcon.icns"
else
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$CONTENTS/Info.plist" 2>/dev/null || true
  info "no packaging/AppIcon.icns — bundling without an icon"
fi
info "assembled $APP_BUNDLE  (v$VERSION build $BUILD, $BUNDLE_ID)"

# ---- 3. Code-sign (optional) -------------------------------------------------
if [ -n "$SIGNING_IDENTITY" ]; then
  step "Code-signing with hardened runtime"
  codesign --force --deep --options runtime --timestamp \
    --entitlements "$REPO_ROOT/packaging/entitlements.plist" \
    --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
  info "signed and verified"
else
  step "Skipping code-signing"
  info "SIGNING_IDENTITY not set — produced an UNSIGNED app for local testing only."
  info "Gatekeeper will block it on other Macs until it is signed + notarized."
fi

# Decide whether to build a DMG.
if [ "$MAKE_DMG" = "auto" ]; then
  [ -n "$SIGNING_IDENTITY" ] && MAKE_DMG=1 || MAKE_DMG=0
fi

# ---- 4. Package into a DMG (optional) ----------------------------------------
DMG=""
if [ "$MAKE_DMG" = "1" ]; then
  step "Building DMG"
  DMG="$DIST/$APP_NAME-$VERSION.dmg"
  STAGING="$(mktemp -d)"
  cp -R "$APP_BUNDLE" "$STAGING/"
  ln -s /Applications "$STAGING/Applications"   # drag-to-install target
  rm -f "$DMG"
  hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
  rm -rf "$STAGING"
  info "created $DMG"
else
  step "Skipping DMG"
fi

# ---- 5. Notarize + staple (optional) ----------------------------------------
if [ "$NOTARIZE" = "1" ]; then
  step "Notarizing"
  [ -n "$DMG" ] || { echo "error: NOTARIZE=1 but no DMG was built (needs SIGNING_IDENTITY)" >&2; exit 1; }
  [ -n "$NOTARY_PROFILE" ] || { echo "error: NOTARIZE=1 requires NOTARY_PROFILE (see README)" >&2; exit 1; }
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  info "notarized and stapled"
else
  step "Skipping notarization"
  [ -n "$DMG" ] && info "DMG is signed but NOT notarized; set NOTARIZE=1 for distribution."
fi

step "Done"
info "App:  $APP_BUNDLE"
[ -n "$DMG" ] && info "DMG:  $DMG"
