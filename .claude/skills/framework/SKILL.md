---
name: framework
description: Reference for the shared GodotGo framework API (Session, SaveSystem, ObjectPool, StateMachine, Rng, TextGrid, DebugOverlay, GodotGoTest). Use before writing gameplay code in any project, or when deciding whether something belongs in a game or in the framework.
allowed-tools: Read Glob Grep
---

The framework lives in `framework/addons/godotgo/` and is symlinked into every game as `addons/godotgo`. Every class is a global `class_name`, so no preload is needed.

## Session (`core/session.gd`)

The round lifecycle. Each game registers a subclass as the autoload `Game`.

```gdscript
extends Session          # scripts/game.gd, autoload "Game"
func collect() -> bool:
    if not advance(): return false
    add_score(10)
    return true
```

State: `READY, PLAYING, PAUSED, WON, LOST`. Data: `score`, `progress`, `goal`, `time_limit`, `time_left`, `elapsed`. Methods: `start(goal, limit)`, `add_score(n)`, `advance(n)`, `objective_complete()`, `is_playing()`, `is_over()`, `tick(delta)`, `pause()`, `resume()`, `win()`, `lose(reason)`, `summary()`, `reset()`. Signals: `state_changed`, `score_changed`, `progress_changed`, `time_changed`, `objective_reached`, `won`, `lost`.

Two behaviours worth knowing: `objective_reached` fires exactly once per round, and `time_changed` is throttled to tenths of a second because that is all any HUD displays. `start()` prints the `[godotgo] session start` line that `tools/smoke.sh` looks for.

## SaveSystem (`core/save_system.gd`)

Static, versioned JSON slots under `user://saves/`. `store(slot, dict)`, `fetch(slot, fallback)`, `has_slot`, `erase`, `slots()`, `sanitize`, `path_for`. A slot written by a newer schema version is refused rather than misread, and corrupt files fall back instead of raising.

## ObjectPool (`util/object_pool.gd`)

A Node. Set `scene`, optionally `initial_size` and `max_size`. `acquire()` returns an instance that is **not** in the tree, for the caller to place; `release(node)` removes it from the tree and takes it back. `release_all()`, `in_use()`, `available()`, `created()`. A pooled scene may implement `pool_acquired()` and `pool_released()` to reset itself.

## StateMachine (`util/state_machine.gd`)

A RefCounted FSM built from callables, so entity behaviour needs no node hierarchy. `add_state(name, on_update, on_enter, on_exit)`, `start(name)`, `transition_to(name)`, `update(delta)`, `current`, `previous`, `time_in_state`, signal `transitioned`.

## Rng (`util/rng.gd`)

Deterministic randomness: `Rng.new(seed)`, `reseed`, `get_state`/`set_state`, `randi_range`, `randf_range`, `chance`, `pick`, `shuffled`, `weighted_pick`, `direction`, `point_in_rect`. Seeding is what makes spawn patterns and shuffles testable.

## TextGrid (`util/text_grid.gd`)

ASCII level maps. `TextGrid.parse(text)`, `TextGrid.from_file(path)`, `at`, `cell`, `set_at`, `find_first`, `find_all`, `find_any`, `count`, `in_bounds`, `clone`, `to_text`. Out-of-bounds reads return `TextGrid.EMPTY` rather than erroring.

## DebugOverlay (`ui/debug_overlay.gd`)

A CanvasLayer that builds its own label. Add the node and press F3. It shows frames per second, the current scene and, when a `Game` autoload exists, the session state, progress, score and clock. `lines()` returns the same text for tests.

## GodotGoTest (`testing/test_case.gd`)

The test base class. Beyond the `assert_*` family it gives you `add_scene`, `add_node`, `free_node` (tolerates already-freed nodes), `physics_frames(n)`, `record(signal)` (an array that fills with emitted arguments and is disconnected afterwards), `add_floor_2d()`, `add_floor_3d()`, `skip(reason)` and `is_headless()`.

## Where does code belong?

In the framework if two games would otherwise write it, and it can be tested without a scene. In the game otherwise. Changing the framework means updating `framework/tests/unit/` in the same edit; `tools/verify.sh framework` is the gate.
