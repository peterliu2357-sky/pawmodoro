# Notes for Claude

Pawmodoro is a menu-bar (agent) macOS focus-timer app, built with Swift Package
Manager — there is no Xcode project.

## Install & run it for the user

If the user asks to install and start the app, run:

```sh
scripts/install.sh
```

This builds from source, installs `Pawmodoro.app` to `/Applications`, and
launches it. Because it's built locally it isn't quarantined, so **no Apple
Developer account, code-signing, or notarization is needed** to run it. The only
prerequisites are macOS 14+ and the Xcode Command Line Tools (`xcode-select
--install` if `swift` is missing).

Pawmodoro is a menu-bar agent: it has **no Dock icon and no window**. After
launch, confirm it's running with `pgrep -f Pawmodoro` and tell the user to look
for the cat/paw icon in the menu bar (top-right), then click it and choose Start.

## Building and testing

- App build: `swift build` (and `swift run Pawmodoro` to run in place).
- Tests: **`scripts/test.sh`** — this machine has the Command Line Tools only
  (no full Xcode / XCTest), so plain `swift test` fails; the wrapper supplies the
  flags Swift Testing needs. Always use it to run tests.

## Layout

- `Sources/PawmodoroKit/` — pure, unit-tested domain logic (session engine,
  coverage orchestration, geometry, settings, drift). No AppKit.
- `Sources/Pawmodoro/` — the AppKit/SwiftUI presentation (menu bar, cat windows,
  animation). Verified by manual QA, not unit tests.
- `packaging/` — build a signed, notarized DMG for public distribution (needs an
  Apple Developer account; see `packaging/README.md`).
- `CONTEXT.md` — domain glossary. `docs/adr/` — architecture decisions
  (notably ADR-0001: never block input; ADR-0002: best-effort fullscreen).
