# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

GodotGo is a **workspace for building Godot 4 games**, not a single game. It holds one reusable framework, several complete sample games that exercise it, tooling that treats every game identically, and a Claude Code integration that can build, test and improve any of them.

**The repository root is not a Godot project.** A project is any directory containing `project.godot`:

| Path | What it is |
| --- | --- |
| `framework/` | The shared addon (`addons/godotgo`) plus its own test suite |
| `games/orb-run/` | 3D first-person collect-and-escape |
| `games/leap/` | 2D platformer, levels authored as ASCII text |
| `games/swarm/` | 2D arena shooter: pooled bullets, state-machine enemies, seeded waves |
| `games/shift/` | Grid puzzle: pure-logic core, undo, saved progress, no physics |
| `templates/blank/` | What `tools/new_game.sh` copies to start a new game |

Every game symlinks `addons/godotgo` to `framework/addons/godotgo`, so there is exactly one copy of the framework and a change to it is felt everywhere at once.

## Commands

All tools live in `tools/` and take a **project name**: the directory under `games/`, or `framework`. Omitting the name means every project.

The workspace targets **Godot 4.7.2**, recorded once in `tools/lib.sh` as `GODOTGO_GODOT_VERSION`. `tools/install_godot.sh` fetches that release into `.godot-bin/` (gitignored), `tools/docker.sh` passes it to the image build, and the CI action reads it from the same variable, so the host, the container and CI cannot drift apart. Bumping the engine means editing that one line, running the installer, and rebuilding both images (`tools/docker.sh build`, `tools/docker.sh mm-build`). `tools/godot.sh` resolves `$GODOT_BIN` first, then `.godot-bin/godot`, then `godot` on `PATH` and the macOS app bundles; every project declares the matching `config/features` level.

```bash
tools/install_godot.sh               # fetch the pinned engine into .godot-bin (first run)
tools/install_godot_ai.sh            # fetch the Godot AI editor addon (optional, editor-only)
tools/verify.sh [project ...]        # check + test + smoke; this is the gate CI runs
tools/check.sh [project] [file ...]  # import, then load every .gd/.tscn/.tres in a live SceneTree, then gdlint + gdformat --check
tools/test.sh [project] [filter]     # headless suites in each project's tests/unit/
tools/smoke.sh [project]             # windowless boot of each game's main scene; fails on any error or warning
tools/run.sh <project> [scene]       # play with a window
tools/export.sh <project> [preset]   # release build (templates required; use tools/docker.sh export)
tools/new_game.sh <slug> --title T   # scaffold a game from templates/blank and verify it
python3 tools/gen_assets.py [project]  # regenerate every placeholder sprite, sound and mesh
tools/mm.sh <file.ptex> [out]        # Material Maker export via Docker
tools/godot_ai.sh doctor|status|edit # the live-editor MCP bridge
tools/godot.sh --headless --path <project> --script res://addons/godotgo/tools/new_uid.gd   # a real uid://
```

Everything also runs in the container CI uses, which needs nothing but Docker installed:

```bash
tools/docker.sh build                # build the toolchain image
tools/docker.sh verify [project]     # same scripts, in the container
tools/docker.sh export <project>     # needs WITH_EXPORT_TEMPLATES=1 at build time
tools/docker.sh mm-build             # rebuild the Material Maker image (it embeds the engine)
tools/docker.sh shell | mcp | mm
```

Optional local lint and format: `python3 -m venv .venv && .venv/bin/pip install "gdtoolkit==4.*"`. `tools/check.sh` finds it there or on `PATH`, and skips those stages when neither exists.

macOS ships bash 3.2 and no `timeout`; the scripts are written for that. `godot --check-only` is used nowhere: it cannot resolve autoload singletons, and on macOS it exits 0 even for parse errors. `framework/addons/godotgo/tools/check_scripts.gd` loads files inside a live `SceneTree` instead, which is what `tools/check.sh` and the edit hook both call.

## Verification loop

A `PostToolUse` hook (`.claude/hooks/gd-check.sh`) loads every `.gd`, `.tscn` and `.tres` you write, in whichever project owns it, and blocks with Godot's own output on failure. It re-imports first when a file introduces a new `class_name`.

`tools/verify.sh` opens with a `pins` stage before it runs anything: every place that names the engine (both Dockerfiles, compose, each `config/features`) must agree with `GODOTGO_GODOT_VERSION`, the installed Godot AI addon must match `GODOTGO_GODOT_AI_VERSION`, and no `project.godot` may reference an autoload or editor plugin that is not on disk. Those are copies and generated lines; unchecked, they go stale.

Before declaring work done run `tools/verify.sh` (or `tools/verify.sh <project>` while iterating). The `godot-qa` subagent runs exactly that; `gdscript-reviewer` gives a read-only review.

If `check` reports `Could not find base class` or `Identifier not declared` for a framework class, that project has not been imported since the addon changed: `tools/godot.sh --headless --path <project> --import` once, then re-check.

## Framework architecture

Everything below lives in `framework/addons/godotgo/`. The `framework` skill has the full API; this is the shape.

**`core/session.gd` (`Session`)** is the spine. It owns the round: a `READY / PLAYING / PAUSED / WON / LOST` state machine, a score, an objective counter (`progress` toward `goal`) and an optional countdown, with a signal for each. Each game registers a subclass as the autoload **`Game`** and adds only its own vocabulary, so `Game` is a few dozen lines: Orb Run's `collect_orb()`, Leap's `lose_life()`, Shift's move counting. Because a session touches no nodes, every rule is testable without a scene, and that is the property the whole workspace is built around. Two behaviours are easy to trip over: `objective_reached` fires exactly once per round, and `time_changed` is throttled to tenths of a second because no HUD shows more. `start()` prints the `[godotgo] session start` line that `tools/smoke.sh` looks for.

**Supporting pieces**, each used by at least two games: `core/save_system.gd` (versioned JSON slots under `user://saves/`, refusing files from a newer schema rather than misreading them), `util/object_pool.gd` (instances handed out un-parented and taken back on release, with `pool_acquired()`/`pool_released()` callbacks), `util/state_machine.gd` (a callable-driven FSM with no node hierarchy), `util/rng.gd` (seeded, state-serialisable randomness, which is what makes spawn patterns testable), `util/text_grid.gd` (ASCII level maps), `util/material_maker_loader.gd` (loads a Material Maker export, splitting a packed ORM map across the ambient-occlusion, roughness and metallic channels), `ui/debug_overlay.gd` (F3 diagnostics that builds its own UI, so adding the node is the whole setup).

**`testing/`** holds the zero-dependency runner. `test_runner.gd` extends `SceneTree`, is launched with `--script`, waits a frame so the tree is live, discovers `tests/unit/**/test_*.gd`, and runs every `test_*` method of each `GodotGoTest` subclass with `before_each`/`after_each`, draining the deletion queue before it quits. `test_case.gd` provides the `assert_*` family plus `add_scene`, `add_node`, `free_node` (tolerates an already-freed node), `physics_frames(n)`, `record(signal)` (an array that fills with emitted arguments and disconnects afterwards), `add_floor_2d()`, `add_floor_3d()`, `skip(reason)` and `is_headless()`. Anything the dummy DisplayServer cannot do, such as mouse capture, must `skip` when headless.

**`plugin.cfg` / `plugin.gd`** make it a real editor addon that registers `ObjectPool` and `DebugOverlay` as addable node types. Enabling it is optional; every class is a global `class_name` regardless.

## Sample games

Each exists to prove a different part of the framework, and `docs/verification.md` maps feature to test.

- **orb-run** (3D): `CharacterBody3D` with coyote time and jump buffering, `Area3D` pickups and an exit gated on the objective, `GPUParticles3D`, real Material Maker PBR materials, generated audio and an OBJ mesh.
- **leap** (2D): `CharacterBody2D`, levels parsed from `levels/*.txt` with `TextGrid` and turned into merged collision runs by `LevelBuilder`, coins as optional score, spikes and pits spending a three-life budget, an `AnimatableBody2D` moving platform.
- **swarm** (2D): `Arena` owns an `ObjectPool` of bullets whose `max_size` is a hard ceiling on shots in flight, `Enemy` behaviour is a framework `StateMachine`, and `WavePlanner` composes each wave from `Rng` reseeded per wave, so planning wave 7 directly gives the same answer as planning one through seven in order. Enemy kinds are `EnemyStats` resources.
- **shift** (grid): `Puzzle` is a `RefCounted` holding every rule, including undo and corner-deadlock detection, with no physics node anywhere in the project; `LevelBuilder` reads four ASCII levels through `TextGrid`, `BoardView` draws them, and `ProgressStore` keeps per-level best move counts in a `SaveSystem` slot.

## Conventions that matter here

- Godot 4.4+ writes a `.gd.uid` sidecar next to every script and `.import` files next to every asset. Commit them. Never commit `.godot/`.
- Hand-written `.tscn`/`.tres` need a real `uid://` from `new_uid.gd`. A generated one is 13 characters or fewer; longer invented values are silently accepted through 64-bit wraparound and then rewritten the first time the editor saves. `load_steps` equals the number of `ext_resource` plus `sub_resource` entries, plus one.
- Placeholder art is generated, never drawn: `tools/gen_assets.py` writes every sprite, sound effect and mesh in the workspace, byte-identically on every machine, and CI fails if the committed files differ from a fresh run. Add a new game's assets as a `@project` function there.
- GDScript: tabs, static typing (`:=`, typed parameters and returns), `&"name"` for actions and signals, `^"Path"` for node paths, `@export_range` for tunables, `get_node_or_null` where absence is legal, `##` doc comments on public members. `gdlint` enforces member order: signals, constants, exports, public vars, private vars, `@onready` vars, then methods. `StringName` arrays sort by hash rather than text, so `states()` in the FSM sorts on `String(a) < String(b)`.
- Physics layers are consistent across games: 1 `world`, 2 `player`, 3 `pickups`, 4 `triggers`, and game-specific layers from 5 up. Declare them in `project.godot` `[layer_names]` before using them.
- Values sampled after `move_and_slide()` have already been zeroed by the slide. Landing speed is read before the call, in both character controllers.
- Godot's dummy renderer may print `RID allocations ... were leaked at exit` in headless runs when particle or shader materials are alive at quit. `tools/smoke.sh` filters that one message and nothing else.

## Where code belongs

In the framework if two games would otherwise write it and it can be tested without a scene; in the game otherwise. Changing the framework means updating `framework/tests/unit/` in the same edit, and `tools/verify.sh framework` is the gate. Do not weaken the framework to suit one game.

## AI integration

`tools/claude.sh` drives Claude Code non-interactively against any project and always finishes by running `tools/verify.sh`, re-feeding failures until the gate passes or the attempt budget runs out:

```bash
tools/claude.sh fix <project>                  # make verification green again
tools/claude.sh build <project> "<what>"       # implement a change, with tests
tools/claude.sh improve <project> [--focus X]  # pick and apply one improvement
tools/claude.sh review <project>               # read-only review, writes nothing
tools/claude.sh new <slug> "<concept>"         # scaffold a game and build the concept
```

It authenticates with `CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token`, falling back to an interactive login. Shell access is restricted to this workspace's own scripts, and `--dry-run` prints the prompt without spending anything.

`.claude/` holds the settings, the edit hook, two subagents (`godot-qa`, `gdscript-reviewer`) and six skills (`verify`, `new-game`, `new-scene`, `mm-export`, `framework`, `godot-ai`). `.mcp.json` registers three MCP servers: `godot` against the host engine, `godot-docker` inside the container under Xvfb (project paths are `/workspace/games/<slug>`), and `godot-ai` against a **running editor**.

## The live-editor bridge

Everything above is headless. [Godot AI](https://github.com/hi-godot/godot-ai) (MIT, pinned as `GODOTGO_GODOT_AI_VERSION`) is the exception: `tools/install_godot_ai.sh` fetches the release, verifies its published SHA-256, unpacks one copy into `vendor/godot_ai` and symlinks it into every project the way the framework addon is shared. `tools/godot_ai.sh edit <project>` opens an editor serving the bridge; `doctor` checks the whole chain and `status` says which editor holds it. It needs `uv`, and only one editor can serve at a time because Godot keeps EditorSettings per install rather than per project. Telemetry is off unless `GODOTGO_AI_TELEMETRY=1`: the addon sends usage data by default, the server takes a `--disable-telemetry` flag but the editor plugin reads an EditorSetting that defaults to on, so `tools/godot_ai.sh` exports `GODOT_AI_DISABLE_TELEMETRY=1`, which the addon documents as winning over that setting. Only launch the editor through that wrapper — a bare `tools/godot.sh --editor` on a wired project reports.

It is an **optional dependency and never a build input**. `vendor/` and the `addons/godot_ai` symlinks are gitignored, and the framework loads Godot AI's classes by path rather than by `class_name`, so every project parses, tests and verifies identically on a machine that has never installed it.

Enabling an editor plugin means editing `project.godot`, which *is* tracked, so the installer does not do it. `tools/godot_ai.sh edit` adds the enable line for the length of a session and removes it on the way out, along with the `_mcp_game_helper` autoload Godot AI writes for itself while running; a checkout is never left carrying a reference it cannot resolve. If a session is interrupted, `tools/verify.sh` fails on the dangling reference and `tools/install_godot_ai.sh --uninstall` clears it. Never commit those lines, and never edit anything under `vendor/` — the workspace extends the addon through its published `McpToolRegistry` API instead.

`framework/addons/godotgo/mcp/` is that extension. It publishes five tools of our own into Godot AI's registry — `godotgo_verify`, `godotgo_test`, `godotgo_check`, `godotgo_projects`, `godotgo_framework_api` — so an agent driving the editor can also run this workspace's gate and read the framework's conventions instead of guessing them. `framework/tests/unit/test_mcp_bridge.gd` runs the specs through Godot AI's own validator when it is installed and skips when it is not.

`.github/workflows/` has four: `ci.yml` verifies every project in parallel in the container and fails if regenerated assets differ from the committed ones; `claude.yml` answers `@claude`; `claude-code-review.yml` reviews pull requests; `claude-improve.yml` runs weekly or on demand, improves one project and opens a pull request. All three Claude workflows authenticate with the `CLAUDE_CODE_OAUTH_TOKEN` repository secret. Setup is in `docs/ai-development.md`.
