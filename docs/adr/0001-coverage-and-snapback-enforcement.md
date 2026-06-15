# Enforce breaks by visual coverage and snap-back, never by blocking input

When a Work Session ends, a large Visual pounces and covers ~80% of every
display for the Rest; the user returns to work only by Shooing it off the edge,
and an early Shoo triggers a Snap-back. We deliberately do **not** block keyboard
or mouse input, lock the screen, or capture events. Coverage is the deterrent
and Snap-back is the lock.

## Considered Options

- **Hard lockout / input capture** — truly prevents work, but requires intrusive
  Accessibility/Input-Monitoring permissions (scary OS prompts, privacy optics)
  and feels hostile.
- **Idle/keystroke detection to gate behavior** — more accurate but still needs
  permissions and adds complexity.
- **Coverage + Snap-back only (chosen)** — needs *zero* special permissions, is
  charming rather than adversarial, and is honest about being a strong nudge
  rather than a jail.

## Consequences

- A determined user can still work in the uncovered ~20% or Cmd-Tab away. This
  is accepted: the product promise is "make resting the path of least
  resistance," not "physically imprison you."
- Because there is no activity detection, the next Work Session must start on the
  Shoo *gesture* rather than a clock — which is what keeps returning-from-a-long-
  break work time always full.
- An Emergency Shoo exists so the app never truly traps anyone.
