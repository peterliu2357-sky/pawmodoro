# Cover other apps' fullscreen on a best-effort basis, degrading gracefully

To keep Coverage from leaking when a user fullscreens an app to dodge the cat,
the Visual windows use a high window level (above the screen saver) plus
`canJoinAllSpaces` + `fullScreenAuxiliary` collection behavior so they can appear
over another app's true-fullscreen Space. This path is only semi-supported by
macOS and may glitch or be tightened in future OS releases, so the app is built
to degrade gracefully: if the trick fails, Visuals simply don't reach fullscreen
and everything else keeps working.

## Considered Options

- **Hard requirement** — guarantee fullscreen coverage and test it every macOS
  release. Rejected: makes the whole product hostage to a fragile, unsupported
  path.
- **Skip fullscreen entirely for v1** — desktop/maximized only. Rejected: a
  trivial loophole (just fullscreen your editor).
- **Best-effort with graceful degradation (chosen)** — get fullscreen coverage
  today without a hard dependency on it.

## Consequences

- No code path may assume fullscreen coverage succeeded; the loop and Shoo must
  behave correctly even if a Visual never appears over a fullscreen Space.
- This decision is tied to the choice of native Swift/AppKit, which is the only
  toolkit giving the precise window-level and collection-behavior control
  required.

## Verification

Both Visual windows are configured above the screen saver level with
`canJoinAllSpaces` + `fullScreenAuxiliary` (the dim one step below the cat).

- **macOS 26.3.1 (2026-06):** verified by manual QA — during a Rest, the dim and
  cat appear over an app running in true fullscreen. No gap observed on this
  version.

The graceful-degradation guarantee does not rest on this result: the loop is
pure wall-clock logic that never inspects whether a window appeared, and the
Emergency Shoo ends a Rest without any Visual, so a future OS that tightens this
path leaves the user able to escape and the loop correct.
