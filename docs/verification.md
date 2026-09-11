# Verification: what proves the framework works

The sample games are not decoration. Each one puts a different part of the framework on the critical path of something playable, so a green run is evidence that the framework, the toolchain and the integrations actually work rather than merely compile.

Everything below runs against the Godot release pinned in `tools/lib.sh` (currently 4.7.2). `tools/install_godot.sh` puts that exact build in `.godot-bin/`, the image build receives the same version, and the CI action reads it from the same variable, so "it passes on my machine" and "it passes in CI" mean the same engine.

## Run everything

```bash
tools/install_godot.sh                       # the pinned engine, first run only
tools/verify.sh                              # check + test + smoke, every project
tools/verify.sh leap                         # one project
tools/docker.sh verify                       # the same, in the container CI uses
python3 tools/gen_assets.py && git diff --exit-code   # assets are reproducible
WITH_EXPORT_TEMPLATES=1 tools/docker.sh build && tools/docker.sh export orb-run
```

`ci.yml` discovers the project list at run time and verifies each one in parallel in the container, then separately checks that regenerating every asset produces the bytes that are committed.

## The stages

| Stage | Command | What it proves |
| --- | --- | --- |
| pins | `tools/verify.sh` | Every place that names the engine — both Dockerfiles, compose, and each project's `config/features` — still agrees with `GODOTGO_GODOT_VERSION`, an installed Godot AI addon matches `GODOTGO_GODOT_AI_VERSION`, and no `project.godot` references an autoload or editor plugin that is not on disk. Those are copies and generated lines; unchecked, they go stale. |
| check | `tools/check.sh [project] [file ...]` | Godot imports the project, then loads every script, scene and resource inside a live `SceneTree`, so autoloads resolve, `class_name` lookups work, and broken `ext_resource` paths or wrong `load_steps` fail loudly. Then gdlint and `gdformat --check`. |
| test | `tools/test.sh [project] [filter]` | The headless suites. A project with no tests **fails**, because an empty suite is indistinguishable from a passing one. |
| smoke | `tools/smoke.sh [project]` | Boots each game's main scene without a window and fails on any error or warning, requiring the `[godotgo] session start` line that `Session.start()` prints. |

## Framework feature to the test that proves it

| Framework piece | Used by | Proven by |
| --- | --- | --- |
| `Session` round lifecycle, one-shot `objective_reached`, throttled `time_changed`, terminal win/lose | every game | `framework/tests/unit/test_session.gd`, plus each game's `test_game.gd` |
| Autoload wiring (`Game` extends `Session`) | every game | `games/orb-run/tests/unit/test_assets.gd` asserts the setting and that `Game` is a `Session` |
| `SaveSystem` versioned slots, refusal of newer schemas, corrupt-file fallback | shift | `framework/tests/unit/test_save_system.gd` |
| `ObjectPool` acquire/release, prewarm, caps, lifecycle callbacks, orphan cleanup | swarm | `framework/tests/unit/test_object_pool.gd` |
| `StateMachine` enter/exit ordering, `time_in_state`, unknown-state refusal | swarm | `framework/tests/unit/test_state_machine.gd` |
| `Rng` determinism, saved state, weighted picks | swarm | `framework/tests/unit/test_rng.gd` |
| `TextGrid` parsing, padding, bounds, mutation, round-trip | leap, shift | `framework/tests/unit/test_text_grid.gd` |
| `MaterialMakerLoader`, including packed ORM channel splitting | orb-run | `framework/tests/unit/test_material_maker_loader.gd` against generated fixtures, and `games/orb-run/tests/unit/test_assets.gd` against a real 2048 px export |
| `DebugOverlay` self-built UI, F3 toggle, session readout | template, leap | `framework/tests/unit/test_debug_overlay.gd` |
| `GodotGoTest` helpers: physics frames, signal recording, floors, skips | every suite | every suite |

## Game feature to the test that proves it

| Feature | Game | Proven by |
| --- | --- | --- |
| 3D character controller: gravity, jump, coyote time, sprint, landing speed sampled before `move_and_slide` | orb-run | `test_player.gd` on a real physics floor |
| `Area3D` pickups, an exit gated on the objective, per-instance materials | orb-run | `test_orb.gd`, `test_exit_portal.gd` |
| Full 3D round: collect, gate, win, timeout, respawn, restart | orb-run | `test_level.gd` |
| 2D controller: acceleration, friction, air control, heavier fall, jump buffer | leap | `test_hero.gd` |
| ASCII levels merged into single collision runs per row | leap | `test_level_builder.gd`, including that the shipped level has a spawn, a goal and ground |
| One-shot versus re-arming triggers | leap | `test_triggers.gd` |
| A life budget, hazards, pits, and a goal that is not gated on collectibles | leap | `test_game.gd`, `test_level.gd` |
| `AnimatableBody2D` platform path and phase offset | leap | `test_moving_platform.gd` |
| Pooled bullets with a hard ceiling, state-machine enemies, waves reproducible from a seed | swarm | `test_bullet.gd`, `test_enemy.gd`, `test_wave_planner.gd`, `test_arena.gd` playing a full round to a win and to a loss |
| The wave counter never drifting from the enemies actually on the field | swarm | `test_arena.gd` clears the field mid-round and spawns into a live wave, asserting the ladder still advances |
| Corner deadlock ending the round instead of stranding it | shift | `test_puzzle.gd`, `test_level.gd` |
| A pure-logic puzzle core with undo, corner-deadlock detection and no physics node anywhere | shift | `test_puzzle.gd`, and `test_level.gd` asserting the scene contains no `CollisionObject2D` |
| Levels proven solvable by replaying a stored solution | shift | `test_level_builder.gd` plays a move string through each shipped level |
| Saved per-level best move counts | shift | `test_progress_store.gd` |

## Toolchain and integration

| Piece | Proven by |
| --- | --- |
| Multi-project tooling | `tools/verify.sh` resolving `framework`, a game slug, several names, or none at all |
| Version-pin guard | Editing a Dockerfile and a `config/features` to a stale version and watching `tools/verify.sh` name both files and stop before the check stage |
| Dangling-reference guard | Godot AI writes a `_mcp_game_helper` autoload into a tracked `project.godot` while its own tree is gitignored. Committing that line breaks the project for everyone who never installed it; the guard caught exactly that during the integration. Enabling is now scoped to an editor session, and a wire/unwire round trip leaves `project.godot` byte-identical. |
| Optional-dependency isolation | Moving `vendor/godot_ai` away and re-running `tools/check.sh` and `tools/test.sh`: everything passes and the validator test skips, so the framework behaves identically without the addon |
| MCP tool specs | `framework/tests/unit/test_mcp_bridge.gd` builds the five published tools and runs them through **Godot AI's own** `McpCustomToolSpec.validate()`, so a budget or naming rule we have not noticed fails at the gate instead of vanishing from a dock |
| Scaffolder | `tools/new_game.sh` runs check, test and smoke before it returns, and refuses to finish otherwise |
| Empty-suite guard | Scaffolding a project, deleting its tests, and watching `tools/test.sh` fail with `no tests found` |
| Script-fault guard | A test calling a method that does not exist reports `ok` for its own assertion, and `tools/test.sh` still fails the run on the `SCRIPT ERROR`. This caught a stale call left in Orb Run by the migration onto the framework. |
| Deterministic assets | Regenerating every asset and diffing against the committed bytes, enforced in CI |
| Docker toolchain | The same check, test and smoke commands passing inside `godotgo-tools:local` |
| Engine export | All four games exported with `tools/docker.sh export <game>` and booted headless, each printing its session line with the right objective count. This caught text levels being stripped from builds: `.txt` files are not imported resources, so `export_filter="all_resources"` left them out and the exported platformer loaded an empty map. The presets now name them in `include_filter`. |
| Edit hook | Every `.gd`/`.tscn`/`.tres` Claude writes is loaded by the owning project's Godot before Claude continues; it caught several errors while this workspace was built |
| MCP servers | Probed over stdio: version, project info, and `run_project` plus `get_debug_output` returning a game's log from inside the container |
| Claude driver | `tools/claude.sh review leap` found real defects, including a level with no goal flag and an empty test directory that was making verification falsely green |
| Reviewer subagent | Reviews of the two agent-built games found five real defects in the puzzle (a board could be made unsolvable with nothing detecting it, and a level could win itself while loading) and an invariant hole in the shooter (removing enemies without killing them stranded the wave counter, so the round could be neither won nor lost). All are fixed and covered by tests. |
| Subagents | `godot-qa` and `gdscript-reviewer` both run against this workspace |

## Known noise

Godot's dummy (headless) renderer sometimes prints `N RID allocations of type 'N13RendererDummy...DummyShader' were leaked at exit` when particle or shader materials are still alive at quit. It is nondeterministic, does not happen with a real renderer, and is the only line `tools/smoke.sh` tolerates. Everything else fails the run.
