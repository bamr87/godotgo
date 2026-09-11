# Authoring a game

Every game in this workspace has the same shape, and the shape is what makes the tooling, the tests and the AI integration work the same way for all of them.

## Before anything

The workspace targets one Godot release, pinned in `tools/lib.sh`. Fetch it once:

```bash
tools/install_godot.sh
```

It lands in `.godot-bin/` and is used ahead of anything installed system-wide, so the engine you build against is the engine CI builds against.

## Start from the scaffolder

```bash
tools/new_game.sh dodge --title "Dodge" --desc "Endless obstacle dodger."
```

That copies `templates/blank`, symlinks `addons/godotgo` to the shared framework, generates real resource UIDs with Godot, substitutes the name everywhere, and then runs check, test and smoke. It refuses to finish unless the new project verifies, so `games/dodge` is playable and green from its first minute.

You now have a small complete game: a `Session` subclass, a main scene wired to it, a HUD driven by its signals, a debug overlay and three passing tests.

## The shape

**Rules live in `scripts/game.gd`**, a subclass of the framework's `Session` registered as the autoload `Game`. `Session` already owns the state machine, score, objective counter and countdown, so this file is short and holds only the vocabulary of your game:

```gdscript
extends Session

const POINTS_PER_COIN := 50

func collect_coin() -> bool:
	if not advance():
		return false
	add_score(POINTS_PER_COIN)
	return true
```

Anything that overrides a `Session` method must call `super`. Leap's `Game` clears its life budget in both `start()` and `reset()`, and forgetting the second one is exactly the kind of bug the test suite exists to catch.

**Scenes wire themselves to the session and react to its signals.** A level node connects its pickups, hazards and exits to `Game`, and the HUD listens to `progress_changed`, `score_changed`, `time_changed` and `state_changed`. No rule needs a node reference, which is what keeps the rulebook testable without a display.

**Tests go under `tests/unit/test_*.gd`** and extend `GodotGoTest`. Reset `Game` in `before_each` and `after_each`, because autoloads are live and shared. A project with no tests now fails `tools/test.sh` rather than reporting a false green.

## Art and audio

Nothing in this repository was drawn or recorded. Add a section to `tools/gen_assets.py`:

```python
@project("games/dodge")
def _dodge(base: str) -> None:
    tex = os.path.join(base, "assets/textures")
    write_png(os.path.join(tex, "ship.png"), 20, 20, disc(20, (110, 210, 255, 255)))
    write_wav(os.path.join(base, "assets/audio/hit.wav"), noise_burst(0.12, 34, 11, 0.45))
```

Then `python3 tools/gen_assets.py dodge`. The helpers cover discs, rounded boxes, triangles, rings, brick patterns, frequency sweeps, thuds, blips and noise bursts. Everything is deterministic, and CI fails if the committed bytes differ from a fresh run, so the generator and the files can never drift apart.

3D materials come from [Material Maker](material-maker.md) instead, exported headlessly through Docker.

## Levels

For anything grid-shaped, author levels as ASCII text and parse them with `TextGrid`. Leap's `levels/level_1.txt` is a platformer map; Shift's are puzzle boards. Text levels diff cleanly, can be edited anywhere, and can be asserted on in tests without opening a scene, which is how Leap's suite proves its shipped level is actually winnable.

`games/leap/scripts/level_builder.gd` shows the pattern: read the grid, merge runs of solid cells into single collision shapes, instantiate a scene per symbol, and hand back what was created.

One export detail catches everyone once: a `.txt` file is not an imported resource, so a preset set to `all_resources` silently leaves it out and the exported game loads an empty map. Name them in the preset's `include_filter`, as `games/leap/export_presets.cfg` does.

## Scenes by hand

Scene files are text and can be written directly. Three things must be right:

1. A real `uid://`, from
`tools/godot.sh --headless --path games/<slug> --script res://addons/godotgo/tools/new_uid.gd`. Never invent one: an over-long value is silently accepted through 64-bit wraparound and then rewritten the first time the editor saves.
2. `load_steps` equal to the number of `ext_resource` plus `sub_resource` entries,
   plus one.
3. Nodes in tree order, with `parent="."` for children of the root.

Then `tools/check.sh <slug>`, which loads every scene and catches missing resources and wrong counts.

## Physics layers

Keep the shared meaning so a reader moving between games is never surprised: 1 `world`, 2 `player`, 3 `pickups`, 4 `triggers`, and game-specific layers from 5 up. Declare them in `project.godot` under `[layer_names]`.

## Verifying

```bash
tools/verify.sh dodge
```

Check imports the project and loads every script, scene and resource inside a live `SceneTree`, then runs gdlint and `gdformat --check`. Test runs the suite. Smoke boots the main scene without a window and fails on any error or warning. CI runs the same three commands in a container for every project.

## When to change the framework

Put code in `framework/` if two games would otherwise write it and it can be tested without a scene. Put it in the game otherwise. A framework change means updating `framework/tests/unit/` in the same edit, and it must not exist to make one game easier at every other game's expense.
