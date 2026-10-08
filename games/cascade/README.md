# Cascade

Collapse puzzle: pop colour groups, watch the board fall and the columns close up.

```bash
tools/run.sh cascade          # play
tools/check.sh cascade        # import, load and lint
tools/test.sh cascade         # headless tests
tools/smoke.sh cascade        # windowless boot
```

## How it plays

Click any group of two or more touching tiles of the same colour and they go. What was above them falls, and a column emptied outright is closed up by the columns to its right sliding over. A group is worth `n * (n - 1)`, so six tiles taken together pay 30 and the same six taken as three pairs pay 6: the game is about growing a group and choosing when to spend it.

Clear the target share of the board (70% by default) and the level is beaten. The round does not end there — a board is still worth playing for a perfect clear, which pays a bonus of its own. It ends when no legal pop is left, and the target decides whether that ending was a win or a loss. `R` restarts, `N` moves on once a board is beaten.

## What it is here to prove

Each sample game exercises a different part of the shared framework. Cascade's share is:

| Framework piece | Used for |
| --- | --- |
| `Session` | The objective counter as a **threshold** rather than an ending: `objective_reached` fires as the target is crossed and the board plays on. |
| `Rng` | Level generation. A shipped level is either a text file or five numbers, and a seeded board rebuilds identically, so a restart is a genuine retry. |
| `TextGrid` | The authored levels, and `LevelBuilder.to_text` renders a board back so tests can assert one as a picture. |
| `ObjectPool` | Tile sprites. Every board redresses the same nodes; unlike Swarm's bullets the pool is deliberately **uncapped**, because a cap would leave real tiles undrawn. |
| `StateMachine` | The board's phases — `idle`, `popping`, `falling`. Not entity AI: it sequences the animation *and* locks input, so a second pop cannot land on cells the board has already vacated. |
| `SaveSystem` | Best score, biggest group and perfect clears per level, through `ScoreStore`. |

`Board` is a plain `RefCounted` holding every rule, so all of them are asserted headlessly in `tests/unit/test_board.gd` against boards written as two lines of ASCII.

The framework lives in `addons/godotgo`, symlinked to `framework/addons/godotgo`.
