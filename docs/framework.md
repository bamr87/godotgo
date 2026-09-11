# The GodotGo framework

`framework/addons/godotgo/` is a normal Godot 4 addon. Every game in this workspace symlinks it as `addons/godotgo`, so there is one copy and one place to change. This page is the API reference and the reasoning behind each piece.

Run its own suite with `tools/verify.sh framework`.

## Session

`core/session.gd`. The round lifecycle, and the spine of every game here.

```gdscript
# games/<slug>/scripts/game.gd, registered in project.godot as Game="*res://scripts/game.gd"
extends Session

const POINTS_PER_ORB := 100

func collect_orb() -> bool:
	if not advance():
		return false
	add_score(POINTS_PER_ORB)
	return true
```

| Member | Meaning |
| --- | --- |
| `State` | `READY`, `PLAYING`, `PAUSED`, `WON`, `LOST` |
| `start(goal, limit)` | Begins a round. `goal` 0 means no counted objective, `limit` 0 means no countdown |
| `add_score(n)` / `advance(n)` | Score and objective progress. Both return false unless a round is running |
| `objective_complete()` | `progress >= goal`, with a non-zero goal |
| `tick(delta)` | Advances the clock. `_process` calls it; tests call it directly to step time exactly |
| `pause()` / `resume()` | Suspends the clock without ending the round |
| `win()` / `lose(reason)` | Terminal. Both are ignored once the round is over |
| `summary()` | Score, progress, goal, elapsed, time left, state |
| `reset()` | Back to `READY` with every counter cleared |

Signals: `state_changed`, `score_changed`, `progress_changed`, `time_changed`, `objective_reached`, `won`, `lost`.

Three details worth knowing:

- **`objective_reached` fires exactly once per round**, even if the player keeps collecting past the goal.
- **`time_changed` is throttled to tenths of a second.** No HUD displays more precision, and a signal per frame would rebuild a string sixty times a second for no visible change.
- **`start()` prints `[godotgo] session start: ...`**, which is what `tools/smoke.sh` waits for to prove a game actually booted.

The reason a session is a plain `Node` holding no scene references is that it makes rules testable without a display. A game's whole rulebook can be asserted in a few milliseconds, and the scene layer becomes wiring.

## SaveSystem

`core/save_system.gd`, all static. Slots are JSON files under `user://saves/`, wrapped in an envelope carrying a schema `version` and a timestamp.

```gdscript
SaveSystem.store("progress", {"level": 3, "best_moves": 42})
var data := SaveSystem.fetch("progress", {"level": 1})
```

`store`, `fetch`, `has_slot`, `erase`, `slots()`, `sanitize`, `path_for`. A slot written by a newer `VERSION` is refused and the fallback returned, rather than half-read; corrupt JSON does the same without printing an engine error. Slot names are sanitised to `[a-z0-9_-]`, so a name from user input cannot escape the directory.

## ObjectPool

`util/object_pool.gd`, a `Node`. Set `scene`, optionally `initial_size` and `max_size`.

```gdscript
var bullet := pool.acquire()      # not in the tree yet
if bullet:
	add_child(bullet)
	bullet.global_position = muzzle.global_position
# later
pool.release(bullet)              # removed from the tree, back in the pool
```

`acquire()` deliberately returns an un-parented instance so the caller decides where it lives. A pooled scene may implement `pool_acquired()` and `pool_released()` to reset itself. `release()` reports a node the pool never handed out instead of silently accepting it, and leaving the tree frees spares plus any instance that was handed out, never released and never parented, since nothing else owns those.

## StateMachine

`util/state_machine.gd`, a `RefCounted` built from callables, so entity behaviour needs no node hierarchy and can be tested on its own.

```gdscript
var fsm := StateMachine.new()
fsm.add_state(&"idle", _idle_update)
fsm.add_state(&"chase", _chase_update, _on_chase_enter)
fsm.start(&"idle")
# in _physics_process:
fsm.update(delta)
```

`current`, `previous`, `time_in_state`, `has_state`, `states()`, `transition_to`, signal `transitioned`. Transitioning to the current state is a no-op rather than a re-entry.

## Rng

`util/rng.gd`. Seeded randomness, because "the same seed produces the same wave" is the only way to test a spawner.

`Rng.new(seed)`, `reseed`, `get_state`/`set_state` (save and resume a sequence mid-run), `randi`, `randi_range`, `randf`, `randf_range`, `chance`, `pick`, `shuffled` (returns a new array, leaves the input alone), `weighted_pick`, `direction`, `point_in_rect`.

## TextGrid

`util/text_grid.gd`. ASCII level maps, so levels are diffable, editable anywhere and assertable in tests without opening a scene.

`TextGrid.parse(text)`, `TextGrid.from_file(path)`, `at`, `cell`, `set_at`, `find_first`, `find_all`, `find_any`, `count`, `in_bounds`, `clone`, `to_text`. Rows are padded to a common width, blank leading and trailing lines are dropped, and out-of-bounds reads return `TextGrid.EMPTY` rather than erroring, so a builder can look one cell past the edge without guarding every call.

## MaterialMakerLoader

`util/material_maker_loader.gd`, all static. `load_material(dir, name)` returns the exported `.tres` when one exists, and otherwise assembles a `StandardMaterial3D` from whichever PNG maps are next to it. `find_maps(dir, stem)` exposes the discovery step. A packed `_orm.png` is split across the ambient-occlusion, roughness and metallic slots with the right channel selectors, without overriding any map that was exported separately.

## DebugOverlay

`ui/debug_overlay.gd`, a `CanvasLayer`. Add the node; press F3. It builds its own label, so there is no scene to instantiate and no input action to register. It shows frames per second, the current scene, and, when a `Game` autoload exists, the session state, progress, score and clock. `lines()` returns the same text for tests.

## Testing

`testing/test_runner.gd` extends `SceneTree` and is launched with `--script`. It waits one frame so the tree is live, discovers `tests/unit/**/test_*.gd`, runs every `test_*` method of each `GodotGoTest` subclass with `before_each`/`after_each`, drains the deletion queue, prints a summary and exits non-zero on any failure.

`testing/test_case.gd` (`GodotGoTest`) provides:

| Helper | Use |
| --- | --- |
| `assert_eq`, `assert_ne`, `assert_true`, `assert_false`, `assert_null`, `assert_not_null`, `assert_almost_eq`, `assert_is`, `fail` | Assertions |
| `add_scene(packed)`, `add_node(node)` | Put something in the tree |
| `free_node(node)` | Queue-free and wait; tolerates an already-freed node |
| `physics_frames(n)` | Await `n` physics frames. Resumes inside the frame, so an `Input.action_press` right after counts as just-pressed |
| `record(signal)` | An array that fills with emitted arguments and disconnects after the test |
| `add_floor_2d()`, `add_floor_3d()` | A static floor whose top surface is at 0 |
| `skip(reason)`, `is_headless()` | Opt out of what the dummy DisplayServer cannot do |

Tests may `await`. Autoloads are live, so reset `Game` in `before_each` and `after_each`.

## McpBridge

`mcp/mcp_bridge.gd` (`GodotGoMcpBridge`) and `mcp/mcp_handlers.gd`. When the [Godot AI](https://github.com/hi-godot/godot-ai) addon is installed and its plugin is loaded, the framework's `plugin.gd` registers five tools into its `McpToolRegistry`, so an agent driving a live editor can also run this workspace's gate: `godotgo_verify`, `godotgo_test`, `godotgo_check`, `godotgo_projects` and `godotgo_framework_api`.

Two properties are deliberate. Godot AI is loaded **by path, never by `class_name`**, and the handler signatures leave `ctx` untyped, so this file parses and runs on a machine that has never installed it; `is_available()` is false there and `register_tools()` returns 0 rather than failing. And the three tools that shell out are declared `deferred`, running on a worker thread and answering through `ctx.send_deferred()`, because a synchronous `OS.execute` would freeze the editor for as long as a verify takes.

`build_specs()` is separate from registration so `framework/tests/unit/test_mcp_bridge.gd` can hand the specs to Godot AI's own validator, which is a better check of its budgets than a copy of its constants.

## Where code belongs

In the framework if two games would otherwise write it and it can be tested without a scene. In the game otherwise. Changing the framework means updating `framework/tests/unit/` in the same edit, and `tools/verify.sh framework` is the gate. The framework should not grow a feature that exists to make one game easier.
