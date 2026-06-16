# Pawmodoro 🐾

A menu-bar focus timer for macOS that actually makes you rest. You work for a set
time; when it's up, a big sleepy cat — **Dozy** — pounces and covers the screen.
You can't dismiss her until the rest is over: try to flick her away early and she
rubber-bands back. When the rest finishes, flick her off a screen edge and a
fresh work session begins.

Pawmodoro never blocks your keyboard or mouse and needs **no special
permissions** — the rest is enforced by gentle screen coverage, not by trapping
your input.

## Install & run

You build it on your own Mac, so there's nothing to download and no security
warnings to click through.

**Requirements:** macOS 14 or later, and the Xcode Command Line Tools. If you
don't have the tools, run `xcode-select --install` first (one-time).

Then, from the repo:

```sh
scripts/install.sh
```

That builds Pawmodoro, puts it in your **Applications** folder, and launches it.
Look for the **cat/paw icon in your menu bar** (top-right of the screen) — click
it and choose **Start**.

> Prefer to just try it without installing? `swift run Pawmodoro` builds and runs
> it in place (quit with the menu, or Ctrl-C in the terminal).

## Using it

Click the menu-bar icon for:

- **Start / Stop** — begin or end the work→rest loop.
- **Pause / Resume** — freeze the work countdown (rests can't be paused).
- **Settings…** — set your work and rest lengths, and launch-at-login.
- **Emergency Shoo** — a global **⌃⌥⌘.** shortcut that ends a rest immediately, so
  you're never truly stuck (handy for an urgent call).

During a rest: drag Dozy and flick her off any screen edge to return to work.
Too early, and she springs back.

## Development

- **Run the tests:** `scripts/test.sh` (this machine builds with the Command
  Line Tools, so tests run through this wrapper rather than `swift test`).
- **Architecture:** pure domain logic lives in the `PawmodoroKit` library
  (fully unit-tested); the AppKit/SwiftUI presentation lives in `Pawmodoro`.
  See `CONTEXT.md` for the glossary and `docs/adr/` for key decisions.
- **Packaging a signed, notarized release for distribution:** see
  `packaging/README.md` (needs an Apple Developer account — not required just to
  build and run locally).
