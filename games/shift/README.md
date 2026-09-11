# Shift

Grid puzzle: push every crate onto a target, with undo and saved progress.

```bash
tools/run.sh shift          # play
tools/verify.sh shift       # check, test and smoke it
tools/check.sh shift        # import, load and lint
tools/test.sh shift         # headless tests
tools/smoke.sh shift        # windowless boot
```

## What this sample exists to prove

Every game in this workspace exercises a different corner of the framework. Shift's corner is the one with no physics in it at all.

- **A pure-logic core.** `scripts/puzzle.gd` (`Puzzle`, a `RefCounted`) holds the
board, applies a move, pushes crates, spots the solved state and keeps an undo history. It never touches a node, so `tests/unit/test_puzzle.gd` asserts every rule directly, including the awkward refusals that a scene test would make expensive.
- **ASCII levels through `TextGrid`.** `levels/level_*.txt` are plain text.
`scripts/level_builder.gd` owns the symbol table and turns a parsed grid into a `Puzzle`; it can also render one back to text, which is how the tests assert on a whole board at once.
- **`SaveSystem` for progress.** `scripts/progress_store.gd` keeps the fewest
moves per level and which levels are complete, in a versioned JSON slot under `user://saves/`. A better solve replaces a worse one; a worse one does not.
- **`Session` with no countdown.** `scripts/game.gd` starts every round with a
  time limit of zero, so this is the game that walks the no-timer path.
- **No physics bodies.** The board is a grid of `Sprite2D`s positioned from cell
coordinates by `scripts/board_view.gd`. There is not a single collision shape in the project, and `test_level.gd` asserts it.

## Map symbols

| Symbol | Means                          |
| ------ | ------------------------------ |
| `#`    | wall                           |
| `.`    | floor                          |
| `@`    | the mover                      |
| `&`    | the mover, standing on a target |
| `$`    | crate                          |
| `*`    | target                         |
| `+`    | crate already sitting on a target |

Any other character (a space, most usefully) is solid, so a level may be an irregular room padded out to a rectangle.

## Controls

| Key            | Does                                    |
| -------------- | --------------------------------------- |
| Arrows or WASD | walk, pushing a crate that is in the way |
| `U`            | undo the last move, crate and all        |
| `R`            | restart the level                        |
| `N`            | next level, once the board is solved     |

Undo gives the move back rather than costing one, so the best score is a genuine measure of the solution and not of how carefully it was typed.

## Adding a level

Drop a `levels/level_N.txt` beside the others and add its stem and display name to `LEVEL_IDS` / `LEVEL_NAMES` in `scripts/level_builder.gd`. The suite will then hold the new file to the same standard as the shipped ones: it must parse, it must have as many targets as crates, and it must not already be solved. Add its solution to `SOLUTIONS` in `tests/unit/test_level_builder.gd` and the suite will play it through to prove the level can actually be finished.

The framework lives in `addons/godotgo`, symlinked to `framework/addons/godotgo`.
