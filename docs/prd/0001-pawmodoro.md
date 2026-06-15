# PRD: Pawmodoro — a focus timer that makes you actually rest

> Working name. Glossary in `CONTEXT.md`; respects `docs/adr/0001` (Coverage + Snap-back enforcement) and `docs/adr/0002` (best-effort fullscreen coverage).

## Problem Statement

I use the Pomodoro technique to stay focused, but the breaks never actually
happen. A chime or a notification when my 25 minutes are up is trivial to
dismiss and ignore, so I work straight through, get eye strain and mental
fatigue, and lose the whole point of the method. The "hardcore" alternatives
that truly lock my screen feel hostile, demand scary Accessibility/Input-
Monitoring permissions, and trap me at exactly the wrong moment (a meeting, a
screen-share). I want something that genuinely makes me pause, without feeling
like adversarial lockware and without surrendering control of my machine.

## Solution

Pawmodoro is a macOS menu-bar app that runs a continuous Work Session → Rest
loop (25 / 5 minutes by default, both adjustable). When a Work Session's timer
elapses, a large, charming cat **Visual** *pounces* onto every display and
covers roughly 80% of each screen, and the Rest begins instantly. The cat is
the deterrent: it's hard to work around, but it never blocks my keyboard or
mouse, so I can still squint into the uncovered 20% if I truly must. I can't
make the cat leave early — if I try to flick it away before the 5-minute Rest is
up, it springs back (**Snap-back**). When the Rest is over, I grab the cat and
**Shoo** it off a screen edge; that flick is what starts my next Work Session,
fresh at the full duration. Because the next session starts on my gesture rather
than a clock, stepping away for a long break never eats into my work time. A
discreet **Emergency Shoo** is always available so I'm never truly trapped. The
app needs no special permissions and runs quietly from the menu bar.

## User Stories

1. As a focused worker, I want a Work Session to count down from a configurable
   length (25 min default), so that I work in disciplined intervals.
2. As a focused worker, I want a Rest to begin automatically the instant my Work
   Session ends, so that I don't have to remember or choose to take a break.
3. As a focused worker, I want a large cat Visual to pounce onto my screen when
   my Work Session ends, so that I'm unmistakably prompted to stop.
4. As a multi-monitor user, I want a cat on every connected display during a
   Rest, so that I can't just drag my work to an uncovered screen.
5. As a worker mid-task, I want the cat to cover most of the screen but never
   block my input, so that I retain control of my machine and can finish a
   keystroke if I absolutely have to.
6. As a worker tempted to cheat, I want the cat to snap back when I try to
   dismiss it before the Rest is over, so that I'm actually held to the break.
7. As a rested worker, I want to grab the cat and flick it off the screen edge
   to end the Rest, so that returning to work feels playful and physical.
8. As a returning worker, I want my next Work Session to start at its full
   length when I Shoo the cat, so that a long real break never shortens my work
   time.
9. As a worker on multiple displays, I want a single Shoo to clear the cats from
   every screen at once, so that I don't have to chase cats around my desk.
10. As someone whose meeting just got called, I want a discreet emergency
    override to clear a Rest immediately, so that the app never truly traps me.
11. As a privacy-conscious user, I want the app to work without Accessibility or
    Input-Monitoring permissions, so that I don't have to grant scary access.
12. As a Mac user, I want the app to live in the menu bar with no Dock icon, so
    that it stays out of my way.
13. As a Mac user, I want to see the live countdown in the menu bar, so that I
    know how long is left in the current Work Session at a glance.
14. As a user, I want to start the work/rest loop once and have it cycle
    continuously, so that I don't need willpower to begin each session.
15. As a user, I want to stop the loop from the menu bar, so that I can end my
    focus run when I'm done for the day.
16. As a user, I want to pause and resume the current Work Session from the menu
    bar, so that I can handle a brief interruption without losing my place.
17. As a user, I want to adjust the Work Session length in settings, so that I
    can match my own focus rhythm.
18. As a user, I want to adjust the Rest length in settings, so that I can take
    longer or shorter breaks.
19. As a daily user, I want the app to launch at login, so that it's always
    running without me starting it.
20. As a user who fullscreens an app to focus, I want the cat to still appear
    over a true-fullscreen app when possible, so that fullscreen isn't an
    obvious loophole.
21. As a user on a future macOS where the fullscreen trick breaks, I want the
    app to keep working on the desktop without crashing or hanging, so that a
    fragile OS path never takes the whole app down.
22. As a user who shut the lid for lunch, I want sensible behavior on wake (the
    timer resumes on wall-clock terms) and an easy way to clear any cat that's
    waiting, so that I'm not stuck.
23. As a user, I want the cat to have a gentle idle animation while it sits on
    screen, so that the experience feels alive and charming rather than like an
    error dialog.
24. As a user, I want the grab-and-throw to feel physical (throw velocity +
    spring), so that Shooing and Snap-back are satisfying.
25. As a user, I want to quit the app entirely from the menu bar, so that I can
    fully shut it down when needed.

## Implementation Decisions

- **Native Swift; AppKit for Visuals, SwiftUI for settings.** AppKit
  `NSWindow`s are the only toolkit giving the precise window-level and
  collection-behavior control the Coverage requirements need; SwiftUI is used
  for the settings pane and menu content.
- **Menu-bar-only `LSUIElement` app** with a live countdown status item and a
  menu offering Start / Stop / Pause-Resume / Settings… / Quit. No Dock icon, no
  main window.
- **Session Engine (pure domain module).** Owns the loop as a state machine,
  with no dependency on AppKit. Configured with Work/Rest durations and an
  injected `Clock`. Consumes events; exposes the current phase. State machine:

  ```
  Idle ──start──▶ Working(remaining)
  Working ──clock reaches end──▶ Resting(remaining)            // the Pounce trigger
  Resting + attemptShoo (remaining > 0)  ──▶ Resting           // Snap-back: rejected
  Resting + attemptShoo (remaining == 0) ──▶ Working(full)     // Shoo accepted
  Resting + emergencyShoo (any time)     ──▶ Working(full)     // Emergency Shoo
  Working + pause ──▶ Paused ; Paused + resume ──▶ Working(remaining)
  any + stop ──▶ Idle
  ```
  Invariant: every transition into `Working` uses the *full* configured Work
  duration (the "work-time-always-full" guarantee from ADR-0001).
- **Wall-clock timing.** The engine derives remaining time from an injected
  `Clock` (target end-time vs. now), not from accumulated ticks. Simplest robust
  approach; v1 does not pause on system sleep.
- **Coverage Orchestrator.** Given the current phase and an injected
  `DisplayProvider` (set of screens), produces the set of Visuals: none during
  Working, exactly one per display during Resting. A Rest is a single global
  state — one accepted Shoo (or Emergency Shoo) resolves it for all displays.
  Reacts to displays being added/removed mid-Rest.
- **Visual windows.** Borderless `NSWindow`s at a level above the screen saver
  with `canJoinAllSpaces` + `fullScreenAuxiliary` collection behavior so they
  can appear over other apps' true-fullscreen Spaces on a best-effort basis
  (ADR-0002); no code path assumes this succeeded. Windows are click-through
  except for the draggable cat region, preserving "Coverage, never input
  blocking" (ADR-0001).
- **Drag + spring physics.** The cat is a draggable object with throw-velocity
  detection. Releasing after the Rest completes and clearing a screen edge =
  Shoo; releasing before completion = Snap-back (spring back to rest position).
- **Emergency Shoo.** A deliberately low-key override (keyboard shortcut with a
  fixed default + a small menu-bar item) that force-ends a Rest regardless of
  Snap-back. Ends only the Rest; the loop continues into a fresh Work Session.
- **One cat, simple looping idle animation** + a Pounce entrance. Single
  character/asset set for v1.
- **Settings:** Work duration, Rest duration, Launch at login. Persisted locally.
- **Distribution:** signed + notarized `.app` shipped directly (DMG), not via the
  Mac App Store.

## Testing Decisions

- **What makes a good test here:** assert *external behavior* — phase
  transitions, gating rules, and the set of Visuals produced — never internal
  representation. Time and hardware are made deterministic by injecting a `Clock`
  and a `DisplayProvider`; tests never touch real `NSScreen`, real timers, real
  windows, or animation.
- **Session Engine (primary, highest seam).** Drive it with a controllable
  `Clock` and assert: Work elapsing transitions to Rest (Pounce trigger);
  `attemptShoo` before the Rest completes is rejected and stays in Rest
  (Snap-back); `attemptShoo` after completion yields a fresh full-length Work
  Session; `emergencyShoo` at any point in a Rest ends it and continues the loop;
  advancing the clock past the Work end reaches Rest (wall-clock); pause freezes
  the countdown; every entry into Working is full-length.
- **Coverage Orchestrator (secondary).** With a fake `DisplayProvider`: no
  Visuals during Working; one Visual per display during Resting (1 screen → 1,
  2 screens → 2); a single Shoo resolves the global Rest; adding/removing a
  display mid-Rest updates the Visual set.
- **Explicitly not unit-tested (manual QA only):** window levels and
  `canJoinAllSpaces`/`fullScreenAuxiliary` behavior over fullscreen, drag
  throw-velocity, spring Snap-back animation, idle/Pounce animation rendering,
  menu-bar countdown rendering.
- **Prior art:** none — greenfield project. This PRD establishes the testing
  pattern: a pure engine plus injected `Clock` and `DisplayProvider`, exercised
  with the project's chosen test framework (Swift Testing preferred, XCTest
  acceptable).

## Out of Scope

- Audio of any kind (the v1 experience is silent).
- Multiple cat skins / non-cat themes and any Visual picker.
- Rich reactive animations (grabbed reaction, snap-back wiggle, leap-off).
- Rebindable Emergency-Shoo hotkey (ships with a fixed default).
- Pausing the timer on system sleep/lock (v1 is wall-clock; pause-on-sleep is a
  small, self-contained later addition).
- Classic Pomodoro long breaks (e.g. a longer Rest every 4th cycle).
- Activity / idle / keystroke detection of any kind.
- Any form of input blocking, screen locking, or OS permission requests.
- Usage statistics, history, or streaks.
- Mac App Store distribution and auto-update (Sparkle) — later.
- Non-macOS platforms.

## Further Notes

- **Name is not final.** `Pawmodoro` is a placeholder; the folder and this PRD
  can be renamed once the real name is chosen.
- **Wall-clock sleep trade-off:** after a long lid-closed break, the user may
  wake to a cat already waiting and be held by Snap-back through a Rest they
  didn't need; the Emergency Shoo is the relief valve. If this proves annoying,
  pause-on-sleep (via `NSWorkspace` sleep/wake notifications) is an easy follow-up.
- **Fullscreen coverage is fragile by design** (ADR-0002) — treat any test or
  behavior that depends on it as best-effort, and ensure graceful degradation.
