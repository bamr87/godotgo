# Leap

2D platformer: run and jump through an ASCII-authored level, collect coins for score, and reach the flag before the timer runs out. Spikes and pits cost one of three lives.

```bash
tools/run.sh leap        # play
tools/verify.sh leap     # check, test and smoke
```

Controls: **A/D** move, **Space** jump, **R** restart.

## What it demonstrates

- **Levels as text.** `levels/level_1.txt` is parsed by the framework's
`TextGrid`, and `scripts/level_builder.gd` turns it into nodes, merging runs of solid cells into one collision shape per run instead of one per tile. A test asserts the shipped level actually has a spawn, ground and a goal, because a level that cannot be finished otherwise looks exactly like one that can.
- **A round shaped unlike Orb Run's.** The flag is always reachable: coins are a
  bonus, not a gate, and the failure budget is lives rather than a countdown.
- **Feel.** `scripts/hero.gd` has acceleration, friction, air control, a heavier
fall than rise, coyote time and jump buffering, all as `@export_range` tunables, all covered by tests that run real physics frames.
- **`AnimatableBody2D`** for a platform that carries the hero, with its path
  asserted as pure maths rather than by watching it move.
