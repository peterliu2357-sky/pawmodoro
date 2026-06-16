# Packaging Pawmodoro

Builds Pawmodoro into a distributable macOS app — a `.app` bundle, code-signed
with a Developer ID, packaged in a DMG, and notarized + stapled so it installs
cleanly outside the Mac App Store (the distribution decision in #1 / ADR-0002).

Everything here is driven by **`package.sh`**, which degrades gracefully: it runs
today with no credentials (producing an unsigned app for local testing) and
produces a fully notarized DMG once you plug in a signing identity.

## Files

| File | Purpose |
|------|---------|
| `package.sh` | The one entry point: build → assemble `.app` → sign → DMG → notarize → staple. |
| `Info.plist` | The bundle's metadata. `LSUIElement` marks it a menu-bar agent (no Dock icon). The script stamps in the bundle id / version. |
| `entitlements.plist` | Intentionally empty — Pawmodoro requests no special permissions (ADR-0001). It only exists so the hardened runtime has a file to reference. |
| `AppIcon.icns` | *(optional, not yet present)* the app icon. Bundled automatically if added. |

Output goes to `dist/` (git-ignored): `dist/Pawmodoro.app` and `dist/Pawmodoro-<version>.dmg`.

## Quick start (no credentials — works right now)

```sh
packaging/package.sh
open dist/Pawmodoro.app
```

Produces an **unsigned** `.app` you can run locally. Gatekeeper will block it on
*other* Macs until it's signed + notarized, and launch-at-login (Slice 8) only
registers a real login item once the app is signed.

## Full release (needs your Apple Developer account)

Prerequisites — **these are the parts only you can do**:

1. An **Apple Developer Program** membership.
2. A **Developer ID Application** certificate in your login keychain
   (Xcode → Settings → Accounts → Manage Certificates → +, or developer.apple.com).
   Find its exact name with:
   ```sh
   security find-identity -v -p codesigning
   # → "Developer ID Application: Your Name (TEAMID)"
   ```
3. A **notarytool credential profile** stored once in your keychain, using an
   [App Store Connect API key](https://appstoreconnect.apple.com/access/integrations/api)
   (or an app-specific password):
   ```sh
   xcrun notarytool store-credentials pawmodoro-notary \
     --key /path/to/AuthKey_XXXX.p8 --key-id XXXXXXXXXX --issuer <issuer-uuid>
   ```

Then build the real thing:

```sh
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARIZE=1 NOTARY_PROFILE="pawmodoro-notary" \
packaging/package.sh
```

This signs with the hardened runtime, builds the DMG, submits it to Apple,
waits for the result, and staples the ticket. `dist/Pawmodoro-<version>.dmg` is
then ready to distribute.

## Configuration (environment variables)

| Variable | Default | Meaning |
|----------|---------|---------|
| `BUNDLE_ID` | `com.pawmodoro.Pawmodoro` | Bundle identifier. Set to one under a domain you control before release. |
| `VERSION` | `1.0.0` | Marketing version (`CFBundleShortVersionString`). |
| `BUILD` | git commit count | Monotonic build number (`CFBundleVersion`). |
| `SIGNING_IDENTITY` | *(empty)* | Developer ID name. Empty = unsigned. |
| `NOTARIZE` | `0` | `1` to notarize + staple the DMG. |
| `NOTARY_PROFILE` | *(empty)* | The `notarytool` credential profile name. |
| `MAKE_DMG` | `auto` | `auto` builds a DMG only when signing; force with `1`/`0`. |

## Verifying a release

```sh
spctl --assess --type execute --verbose dist/Pawmodoro.app   # Gatekeeper says "accepted"
xcrun stapler validate dist/Pawmodoro-1.0.0.dmg              # notarization ticket present
```

## App icon (optional, TODO)

No icon ships yet. Drop a `packaging/AppIcon.icns` and it's bundled automatically.
A "Dozy" icon can be generated from the same vector art used for the in-app cat
(render to PNGs at 16…1024 px → `iconutil -c icns`).
