<!-- kit: sdlc v0.1.0 · AGENTS.md is the CANONICAL agent instructions file (decision D4, UPS-AGENT-07/08). -->

# godotgo

> A workspace for building Godot 4 games: one shared framework addon, five sample games that exercise it, tooling that treats every project the same, and a Claude Code integration that can build, test and improve any of them.

## What this repo is

GodotGo is a workspace, not a single game, and **the repository root is not a Godot project**. A project is any directory containing `project.godot`: `framework/` (the addon plus its own test suite) and each game under `games/`. Every game symlinks `addons/godotgo` to `framework/addons/godotgo`, so there is exactly one copy of the framework and a change to it is felt everywhere at once. It serves people (and agents) building small Godot games on a shared, tested core. A change is done when `tools/verify.sh` (or `tools/verify.sh <project>` while iterating) passes.

## Stack & commands

Godot 4.7.2 (GDScript), bash tooling, a stdlib-only Python asset and docs generator, and a Docker toolchain image. Quick start (the same block as the README):

```bash
tools/install_godot.sh       # fetch Godot 4.7.2 into .godot-bin (first run only)
tools/install_godot_ai.sh    # optional: the live-editor MCP addon
tools/verify.sh              # check, test and smoke-boot every project
tools/run.sh leap            # play a game
tools/new_game.sh dodge --title "Dodge"   # scaffold a new one, verified before it returns
```

Every tool takes a **project name** — the directory under `games/`, or `framework` — and omitting it means every project:

```bash
tools/verify.sh [project ...]        # pins + check + test + smoke; the gate CI runs
tools/check.sh [project] [file ...]  # import, load every .gd/.tscn/.tres in a live SceneTree, then gdlint + gdformat --check
tools/test.sh [project] [filter]     # headless suites in each project's tests/unit/
tools/smoke.sh [project]             # windowless boot of each game's main scene; fails on any error or warning
tools/run.sh <project> [scene]       # play with a window
tools/export.sh <project> [preset]   # release build (needs export templates: use tools/docker.sh export)
tools/new_game.sh <slug> --title T   # scaffold a game from templates/blank and verify it
python3 tools/gen_assets.py [project]       # regenerate every placeholder sprite, sound and mesh
python3 tools/gen_framework_api.py [--check] # regenerate docs/reference/framework-api.md
python3 tools/docs_index.py --write         # regenerate the docs index in docs/README.md
tools/mm.sh <file.ptex> [out]        # Material Maker export via Docker
tools/godot_ai.sh doctor|status|edit <project>   # the live-editor MCP bridge
tools/godot.sh --headless --path <project> --script res://addons/godotgo/tools/new_uid.gd   # a real uid://
```

The same scripts run in the container CI uses, which needs nothing but Docker:

```bash
tools/docker.sh build                # build the toolchain image
tools/docker.sh verify [project]     # the gate, in the container
tools/docker.sh export <project>     # needs WITH_EXPORT_TEMPLATES=1 at build time
tools/docker.sh mm-build             # rebuild the Material Maker image (it embeds the engine)
tools/docker.sh shell | mcp | mm
```

Optional lint and format: `python3 -m venv .venv && .venv/bin/pip install "gdtoolkit==4.*"`. `tools/check.sh` finds it there or on `PATH` and skips those stages when neither exists.

## Layout

| Path | What it is |
| --- | --- |
| `framework/` | The shared addon (`addons/godotgo`) plus its own test suite |
| `games/orb-run/` | 3D first-person collect-and-escape |
| `games/leap/` | 2D platformer, levels authored as ASCII text |
| `games/swarm/` | 2D arena shooter: pooled bullets, state-machine enemies, seeded waves |
| `games/shift/` | Grid puzzle: pure-logic core, undo, saved progress, no physics |
| `games/cascade/` | Collapse puzzle: pooled tile views, a board state machine, levels from ASCII or a seed |
| `templates/blank/` | What `tools/new_game.sh` copies to start a new game |
| `tools/` | The project-aware scripts above ([tools/README.md](tools/README.md)) |
| `docker/` | The toolchain image and the Material Maker image |
| `docs/` | Framework guide, generated API reference, game authoring, AI development, verification matrix ([docs/README.md](docs/README.md)) |
| `features/`, `verify/` | The fleet feature index and verification scenarios |
| `.claude/` | Settings, the edit hook, subagents and skills |
| `vendor/` | Third-party addons fetched by an installer (gitignored) |

What each sample game proves about the framework is in [docs/verification.md](docs/verification.md).

## Conventions

- **Backlog of record:** GitHub Issues with the fleet labels (`.github/sdlc.yml`, `backlog.mode: issues`). Pick up issues labelled `agent:ready`; never touch `agent:hold` or `human-review`.
- **Definition of Done:** `tools/verify.sh` green for every project you touched, docs updated, and the fleet default pull-request checklist (this repo has no `.github/pull_request_template.md`, so the owner's default applies).
- **Decisions:** ADRs in `docs/adr/NNNN-slug.md`, indexed in `docs/adr/README.md`. Add one for anything hard to reverse.
- **Commits:** Conventional Commits (`feat fix docs style refactor test chore perf ci build`). The PR title is the squash subject.
- **Branches:** `feature/`, `fix/`, `docs/`, `refactor/`, `test/` or `chore/` off `main`.
- **Changelog:** `CHANGELOG.md` is written by release-please (`release.yml`) from the PR titles. Never edit it, or a version number, by hand.
- **Never:** push to `main` directly, commit lockfiles or secrets, suppress type errors, leave empty exception handlers, or edit generated files by hand (`docs/reference/framework-api.md`, the docs-index span, the assets `tools/gen_assets.py` writes).

## Engine and toolchain rules

- **One engine pin.** The version lives once, as `GODOTGO_GODOT_VERSION` in `tools/lib.sh`. `tools/install_godot.sh` fetches it into `.godot-bin/` (gitignored), `tools/docker.sh` passes it to the image build, and the CI action reads it from the same variable. Bumping the engine means editing that one line, running the installer, and rebuilding both images (`tools/docker.sh build`, `tools/docker.sh mm-build`); every project declares the matching `config/features` level.
- `tools/godot.sh` resolves `$GODOT_BIN`, then `.godot-bin/godot`, then `godot` on `PATH` and the macOS app bundles.
- **Never use `godot --check-only`.** It cannot resolve autoload singletons, and on macOS it exits 0 even for parse errors. `framework/addons/godotgo/tools/check_scripts.gd` loads files inside a live `SceneTree` instead; `tools/check.sh` and the edit hook both call it.
- macOS ships bash 3.2 and no `timeout`; every script is written for that.
- `tools/verify.sh` opens with a `pins` stage: every place that names the engine (both Dockerfiles, compose, each `config/features`) must agree with `GODOTGO_GODOT_VERSION`, the installed Godot AI addon must match `GODOTGO_GODOT_AI_VERSION`, and no `project.godot` may reference an autoload or editor plugin that is not on disk. It also warns (without failing) when `docs/reference/framework-api.md` is stale.

## Verification loop

- A `PostToolUse` hook (`.claude/hooks/gd-check.sh`) loads every `.gd`, `.tscn` and `.tres` you write in the project that owns it and blocks with Godot's own output on failure. It re-imports first when a file introduces a new `class_name`.
- Run `tools/verify.sh` before declaring work done. The `godot-qa` subagent runs exactly that; `gdscript-reviewer` gives a read-only review.
- `Could not find base class` or `Identifier not declared` for a framework class means that project has not been imported since the addon changed: run `tools/godot.sh --headless --path <project> --import` once, then re-check.
- `tools/smoke.sh` waits for the `[godotgo] session start` line that `Session.start()` prints; don't remove it. It filters Godot's dummy-renderer `RID allocations ... were leaked at exit` message and nothing else.
- Tests run headless: anything the dummy DisplayServer cannot do, such as mouse capture, must `skip(reason)` when `is_headless()`.

## Framework and game code

The framework's classes are `Session` (the round lifecycle; each game registers a subclass as the autoload **`Game`** and adds only its own vocabulary), `SaveSystem`, `ObjectPool`, `StateMachine`, `Rng`, `TextGrid`, `MaterialMakerLoader`, `DebugOverlay` and the `GodotGoTest` runner. Why each exists is [docs/framework.md](docs/framework.md); every member is in the generated [docs/reference/framework-api.md](docs/reference/framework-api.md); the `framework` skill is the quick summary. How a game is shaped is [docs/authoring-games.md](docs/authoring-games.md).

- **Where code belongs:** in the framework if two games would otherwise write it and it can be tested without a scene; in the game otherwise. Changing the framework means updating `framework/tests/unit/` in the same edit, and `tools/verify.sh framework` is the gate. Do not weaken the framework to suit one game.
- **Doc comments are the API reference.** Public framework members carry `##` doc comments; after changing one, run `python3 tools/gen_framework_api.py` and commit the result.
- **Sidecars:** Godot 4.4+ writes a `.gd.uid` next to every script and `.import` files next to every asset. Commit them. Never commit `.godot/`.
- **Hand-written `.tscn`/`.tres`** need a real `uid://` from `new_uid.gd`. A generated one is 13 characters or fewer; longer invented values are silently accepted through 64-bit wraparound and then rewritten the first time the editor saves. `load_steps` equals the number of `ext_resource` plus `sub_resource` entries, plus one.
- **Placeholder art is generated, never drawn:** `tools/gen_assets.py` writes every sprite, sound effect and mesh, byte-identically on every machine, and CI fails if the committed files differ from a fresh run. Add a new game's assets as a `@project` function there.
- **GDScript style:** tabs, static typing (`:=`, typed parameters and returns), `&"name"` for actions and signals, `^"Path"` for node paths, `@export_range` for tunables, `get_node_or_null` where absence is legal, `##` doc comments on public members.
- **Member order** (enforced by `gdlint`): signals, constants, exports, public vars, private vars, `@onready` vars, then methods. `StringName` arrays sort by hash rather than text, so sort on `String(a) < String(b)` when order matters.
- **Physics layers** are the same in every game: 1 `world`, 2 `player`, 3 `pickups`, 4 `triggers`, game-specific layers from 5 up. Declare them in `project.godot` `[layer_names]` before using them.
- Values sampled after `move_and_slide()` have already been zeroed by the slide; read landing speed before the call, as both character controllers do.

## AI integration and the live-editor bridge

`tools/claude.sh fix|build|improve|review|new` drives Claude Code non-interactively against any project and always finishes with `tools/verify.sh`, re-feeding failures until the gate passes or the attempt budget runs out. It authenticates with `CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token` (falling back to an interactive login), restricts shell access to this workspace's own scripts, and `--dry-run` prints the prompt without spending anything. `.mcp.json` registers `godot` (host engine), `godot-docker` (inside the container under Xvfb; project paths are `/workspace/games/<slug>`) and `godot-ai` (a running editor). Setup, options and the workflows are in [docs/ai-development.md](docs/ai-development.md).

[Godot AI](https://github.com/hi-godot/godot-ai) (MIT, pinned as `GODOTGO_GODOT_AI_VERSION`) is the one non-headless piece. Its rules:

- **Optional, never a build input.** `tools/install_godot_ai.sh` fetches the release, verifies its SHA-256, unpacks one copy into `vendor/godot_ai` and symlinks it into every project. `vendor/` and the `addons/godot_ai` symlinks are gitignored, and the framework loads Godot AI's classes by path rather than by `class_name`, so every project parses, tests and verifies identically on a machine that has never installed it.
- **Launch the editor only through `tools/godot_ai.sh edit <project>`.** It needs `uv`, only one editor can serve the bridge at a time (Godot keeps EditorSettings per install, not per project), and the wrapper exports `GODOT_AI_DISABLE_TELEMETRY=1` because the editor plugin's telemetry setting defaults to on; telemetry stays off unless `GODOTGO_AI_TELEMETRY=1`. Launching the editor any other way on a wired project (a bare `tools/godot.sh --editor`) sends usage data.
- **Never commit the plugin lines.** Enabling the plugin edits the tracked `project.godot`, so the installer does not; `tools/godot_ai.sh edit` adds the enable line for the session and removes it afterwards, along with the `_mcp_game_helper` autoload Godot AI writes for itself. After an interrupted session `tools/verify.sh` fails on the dangling reference and `tools/install_godot_ai.sh --uninstall` clears it.
- **Never edit anything under `vendor/`.** The workspace extends the addon through its published `McpToolRegistry` API: `framework/addons/godotgo/mcp/` publishes `godotgo_verify`, `godotgo_test`, `godotgo_check`, `godotgo_projects` and `godotgo_framework_api`, and `framework/tests/unit/test_mcp_bridge.gd` runs their specs through Godot AI's own validator when it is installed and skips when it is not.

## Fleet context

Member of the bamr87 fleet, vendored as the submodule `projects/godotgo` of [bamr87/bamr87](https://github.com/bamr87/bamr87): commit and push here first; the hub bumps its pointer afterwards. The standards live in the hub's [specs/](https://github.com/bamr87/bamr87/tree/main/specs) (the Universal Project Standard); this repo's SDLC declaration is `.github/sdlc.yml`. What acts on it:

- `ci.yml` verifies every project in parallel in the container and fails if regenerated assets differ from the committed ones; `conformance.yml` and `verify.yml` call the hub's shared checks; `release.yml` runs release-please.
- `claude.yml` answers `@claude`, `claude-code-review.yml` reviews pull requests, and `claude-improve.yml` runs weekly or on demand, improves one project and opens a pull request (kill switch: repository variable `CLAUDE_IMPROVE_ENABLED=false`). All three authenticate with the `CLAUDE_CODE_OAUTH_TOKEN` secret.
- The hub's fleet loops (fleet-pulse doctor, issue pipeline, standardization fan-outs) open pull requests here; none of them merges.

## Standard deviations

none
