# GodotGo

A workspace for building Godot 4 games: one reusable framework, several complete sample games that exercise it, tooling that treats every game identically, and a Claude Code integration that can build, test and improve any of them.

The repository root is not a Godot project. Each project is a directory with its own `project.godot`, and every game symlinks `addons/godotgo` to the single shared framework.

```
framework/     the shared addon (addons/godotgo) plus its own tests
vendor/        third-party addons fetched by an installer (gitignored)
games/         orb-run, leap, swarm, shift
templates/     what tools/new_game.sh copies to start a new game
tools/         project-aware scripts: verify, check, test, run, export, scaffold, Claude, Docker
docker/        the container CI and contributors use
docs/          framework guide, game authoring, AI development, verification matrix
.claude/       Claude Code settings, edit hook, subagents, skills
```

## Quick start

```bash
tools/install_godot.sh       # fetch Godot 4.7.2 into .godot-bin (first run only)
tools/install_godot_ai.sh    # optional: the live-editor MCP addon
tools/verify.sh              # check, test and smoke-boot every project
tools/run.sh leap            # play a game
tools/new_game.sh dodge --title "Dodge"   # scaffold a new one, verified before it returns
```

The workspace pins its engine version in `tools/lib.sh`, and the installer puts that exact release in `.godot-bin/` without touching anything already on the machine. An engine already on `PATH` or in `$GODOT_BIN` is used instead if you prefer.

Nothing but Docker is required if you would rather not install Godot at all:

```bash
tools/docker.sh build && tools/docker.sh verify
```

Optional lint and format: `python3 -m venv .venv && .venv/bin/pip install "gdtoolkit==4.*"`.

## The sample games

Each one exists to exercise a different part of the framework. [docs/verification.md](docs/verification.md) maps every feature to the test that proves it.

| Game | Type | What it proves |
| --- | --- | --- |
| [orb-run](games/orb-run/) | 3D first-person | Character controller with coyote time, `Area3D` triggers, particles, a real Material Maker PBR pipeline |
| [leap](games/leap/) | 2D platformer | ASCII level maps parsed into merged collision runs, a life budget, a moving platform |
| [swarm](games/swarm/) | 2D arena shooter | Pooled bullets with a hard ceiling, state-machine enemies, waves composed from a seed so a run replays exactly |
| [shift](games/shift/) | Grid puzzle | A pure-logic core with undo, deadlock detection and no physics node anywhere, plus saved per-level best scores |

Every game is the same shape: rules live in a `Session` subclass registered as the autoload `Game`, scenes wire themselves to its signals, and the whole round is testable without a display.

## The framework

[framework/addons/godotgo/](framework/addons/godotgo/) is a normal Godot addon you can copy into any project.

- **Session** owns the round: state machine, score, objective counter, countdown, and a signal for each.
- **SaveSystem** stores versioned JSON slots and refuses files from a newer schema.
- **ObjectPool**, **StateMachine**, **Rng**, **TextGrid** are the pieces games kept rewriting.
- **DebugOverlay** is an F3 diagnostics panel that builds its own UI.
- **GodotGoTest** and a `SceneTree` test runner give headless tests with physics frames, signal recording and scene helpers, with no third-party dependency.

[docs/framework.md](docs/framework.md) is the API reference; [docs/authoring-games.md](docs/authoring-games.md) walks through building a game on it.

## Placeholder assets are generated

No sprite, sound or mesh in this repository was drawn or recorded. `tools/gen_assets.py` writes all of them from code, byte-identically on every machine, and CI fails if the committed files differ from a fresh run. Restyling the art means editing Python, not opening an image editor.

```bash
python3 tools/gen_assets.py          # every project
python3 tools/gen_assets.py leap     # one
```

3D materials come from [Material Maker](docs/material-maker.md) through a headless Docker export.

## AI-assisted development

[docs/ai-development.md](docs/ai-development.md) covers the whole setup. The short version:

```bash
tools/claude.sh fix leap                     # make verification green again
tools/claude.sh build leap "add a double jump"
tools/claude.sh improve framework
tools/claude.sh new dodge "endless obstacle dodger"
```

Each command runs Claude Code non-interactively, restricted to this workspace's own scripts, and then runs `tools/verify.sh`, feeding failures back until the gate passes. Authentication is a Claude Code OAuth token from `claude setup-token`. The same token drives three GitHub workflows: `@claude` mentions, automatic pull-request review, and a weekly autonomous improvement run that opens a pull request.

For work that needs a **running editor** rather than a headless run, `tools/install_godot_ai.sh` adds [Godot AI](https://github.com/hi-godot/godot-ai), which connects an MCP client to a live Godot editor. This workspace publishes five tools of its own into it, so the agent that builds a scene can also run the gate on it:

```bash
tools/install_godot_ai.sh          # pinned release, checksum-verified, shared by every project
tools/godot_ai.sh doctor           # check the whole chain
tools/godot_ai.sh edit leap        # open the editor with the bridge live
```

It is optional and gitignored: nothing about a checkout, a test run or CI changes if you never install it.

## License

MIT. See [LICENSE](LICENSE).
