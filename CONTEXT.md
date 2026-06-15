# Pawmodoro (working name)

A macOS focus timer that nudges users into taking breaks. When a Work Session
ends, a large playful Visual pounces onto the screen and a Rest begins
immediately; the user can only return to work by physically flicking the Visual
off the screen edge once the Rest is over. Enforcement is by *visual coverage*
and *snap-back* only — never by blocking keyboard or mouse input.

## Language

**Work Session**:
A fixed-length stretch of focused work, 25 min by default. Ends on a timer.
_Avoid_: Pomodoro, focus block, sprint

**Rest**:
A fixed-length break, 5 min by default, that begins automatically the moment a
Work Session's timer elapses. During Rest the Visual covers most of the screen
and cannot be removed until the Rest timer completes.
_Avoid_: break, pause, recess

**Pounce**:
The Visual's entrance: when a Work Session's timer hits zero, the Visual leaps
onto the screen and the Rest begins in the same instant. Replaces the old
"Nag"/"Start Rest" gate — there is no waiting state and no button.
_Avoid_: nag, alert, popup

**Visual**:
A large playful on-screen graphic (e.g. a cat) that floats over other windows
and covers part of the screen. The unit of obstruction.
_Avoid_: sprite, overlay, widget, cat (cat is one kind of Visual)

**Coverage**:
How much of the screen the Visuals obscure, expressed as a rough percentage.
Coverage is the *only* deterrent — input is never blocked. ~80% is the target
peak.
_Avoid_: blocking, lockout

**Shoo**:
The gesture that ends a Rest and starts the next Work Session: the user grabs
the Visual and drags/flicks it off a screen edge. The only manual action in the
whole loop. Starting the next Work Session on this *gesture* (not a clock) is
what keeps returning-from-a-long-break work time always full.
_Avoid_: dismiss, close, drag-out

**Emergency Shoo**:
A deliberately low-key override (a keyboard shortcut or a small menu-bar item)
that force-clears a Rest immediately, ignoring Snap-back. Always available but
never advertised, so the app never truly traps the user. A Rest is the only
thing it ends; the Work loop continues.
_Avoid_: skip, cancel, force-quit

**Snap-back**:
The rubber-band rejection when the user tries to Shoo the Visual before the Rest
timer has completed — the Visual springs back onto the screen. This is the
enforcement mechanism, in place of any input-blocking.
_Avoid_: bounce, reject
