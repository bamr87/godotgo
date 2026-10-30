# godotgo tools

> Operator scripts for this repository: verify, test, run, export and scaffold any project, plus the generators behind the committed assets and docs. Nothing here ships to users.

| Where | What |
| --- | --- |
| [`check.sh`](check.sh) | Validate Godot projects headlessly: import, load every script, scene and resource inside a live SceneTree (so autoloads and class_names… |
| [`claude.sh`](claude.sh) | Drive Claude Code non-interactively against any project in this workspace |
| [`docs_index.py`](docs_index.py) | Regenerate the docs index in `docs/README.md` from each document's summary line (`--write`, `--check`, `--lint`); vendored byte-identical from the bamr87 hub, never edited here |
| [`docker.sh`](docker.sh) | Run the workspace's tools inside Docker, so nothing but Docker is needed on the host and CI runs exactly what a laptop runs |
| [`export.sh`](export.sh) | Export a release build of a game |
| [`gen_assets.py`](gen_assets.py) | Generate every placeholder asset in the workspace, deterministically |
| [`gen_framework_api.py`](gen_framework_api.py) | Generate `docs/reference/framework-api.md` from the framework's `##` doc comments (`--check` fails when it is stale; `tools/verify.sh` warns on it) |
| [`godot.sh`](godot.sh) | Locate the Godot 4 binary and exec it with the given arguments |
| [`godot_ai.sh`](godot_ai.sh) | Drive the Godot AI MCP bridge for a project in this workspace |
| [`install_godot.sh`](install_godot.sh) | Download the Godot release this workspace targets into .godot-bin/, so the host runs exactly the engine the container and CI run |
| [`install_godot_ai.sh`](install_godot_ai.sh) | Install the Godot AI editor addon (github.com/hi-godot/godot-ai, MIT) into every project in this workspace, so a live editor can be driven… |
| [`lib.sh`](lib.sh) | Shared helpers for the GodotGo workspace tools: locate the root, enumerate Godot projects, and resolve a friendly project name to a path |
| [`mm.sh`](mm.sh) | Export a Material Maker material into the project with the Docker image |
| [`new_game.sh`](new_game.sh) | Scaffold a new Godot game in games/<slug> from templates/<template> |
| [`run.sh`](run.sh) | Play a game with a window |
| [`smoke.sh`](smoke.sh) | Boot a game's main scene without a window and fail on any error or warning |
| [`test.sh`](test.sh) | Run headless test suites (tests/unit/test_*.gd) with the framework's runner |
| [`verify.sh`](verify.sh) | The full verification pass: check, test and smoke every project (or the ones named) |
