# AI-assisted development

This workspace is set up so Claude Code can build, test, review and improve any project in it, locally and in GitHub Actions, with the framework's own verification as the gate. `CLAUDE.md` at the repo root is the agent-facing guide; this page is the setup.

## Authenticating with a Claude Code OAuth token

A Claude Pro, Max, Team or Enterprise subscription can issue a long-lived token instead of an API key:

```bash
claude setup-token          # opens a browser, prints a token valid for one year
export CLAUDE_CODE_OAUTH_TOKEN=<token>
```

The CLI picks that variable up automatically in print mode, so `tools/claude.sh` and the GitHub Action both work with nothing else configured. For GitHub, add the value as a repository secret named `CLAUDE_CODE_OAUTH_TOKEN` under Settings, Secrets and variables, Actions. To bill the API instead, set `ANTHROPIC_API_KEY` locally and swap `claude_code_oauth_token:` for `anthropic_api_key:` in the workflows. Only one of the two should be set.

Treat the token like a password. It carries your subscription's usage, cannot be scoped down per run, and lasts a year unless you re-issue it.

## Driving Claude locally

`tools/claude.sh` runs Claude Code non-interactively and always finishes by running `tools/verify.sh`, feeding failures back until the gate passes or the attempt budget runs out.

```bash
tools/claude.sh fix leap                       # make verification green again
tools/claude.sh build leap "add a double jump" # implement a change, with tests
tools/claude.sh improve framework --focus "test coverage"
tools/claude.sh review shift                   # read-only, writes nothing
tools/claude.sh new dodge "endless obstacle dodger"
```

| Option | Effect |
| --- | --- |
| `--attempts N` | Verify-and-repair rounds before giving up (default 3) |
| `--budget USD` | Spend ceiling passed to Claude (default 10) |
| `--model NAME` | Model override |
| `--dry-run` | Print the prompt and the command, spend nothing |
| `--yes` | Skip the confirmation prompt, for unattended runs |

Two things keep an unattended run bounded. Shell access is restricted to this workspace's own scripts, so Claude can run `tools/test.sh` but not arbitrary commands. And every run ends at the same gate a human would use, so "it worked" is a fact rather than a claim.

The `review` subcommand is the cheapest way to see the integration work. It found real defects in this repository the first time it ran, including a platformer level with no goal flag and an empty test directory that was making the verification pass look green.

## What Claude reads in this repository

| Path | Purpose |
| --- | --- |
| `CLAUDE.md` | Conventions, architecture and commands; read automatically |
| `.claude/settings.json` | Pre-approved commands, denied paths, the edit hook. Its `enableAllProjectMcpServers` does **not** auto-approve the servers in `.mcp.json`: a repository cannot approve its own, so Claude Code ignores that setting when it is committed to the project and asks on first run instead |
| `.claude/hooks/gd-check.sh` | Loads every edited `.gd`/`.tscn`/`.tres` through the owning project's Godot and blocks on failure |
| `.claude/agents/godot-qa.md` | Runs the full verification pass and reports verbatim |
| `.claude/agents/gdscript-reviewer.md` | Read-only review of GDScript and scenes |
| `.claude/skills/verify` | The check, test and smoke commands |
| `.claude/skills/new-game` | Scaffolding a game |
| `.claude/skills/new-scene` | Hand-authoring `.tscn`/`.tres` safely |
| `.claude/skills/framework` | The framework API |
| `.claude/skills/mm-export` | Material Maker exports |
| `.claude/skills/godot-ai` | The live-editor MCP bridge |
| `.mcp.json` | Godot MCP servers |

Per-machine settings belong in `.claude/settings.local.json`, which is gitignored. It is usually empty: the engine comes from `.godot-bin/`, put there by `tools/install_godot.sh` at the version pinned in `tools/lib.sh`. Override it only to point at an engine somewhere else:

```json
{ "env": { "GODOT_BIN": "/Applications/Godot.app/Contents/MacOS/Godot" } }
```

## MCP: driving Godot from the agent

`.mcp.json` registers the [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) server twice, with no editor addon required:

- **`godot`** runs via `npx` against the host engine through `tools/godot.sh`.
- **`godot-docker`** runs inside the toolchain container behind a virtual X
display, so `run_project` really boots a game and `get_debug_output` returns its log. Inside the container, project paths are `/workspace/games/<slug>`.

Both expose launch and run with captured debug output, project and version info, scene creation, node insertion and UID utilities. Every call takes an absolute project path, which in this workspace is a game directory and never the repo root. Check them from a session with `/mcp`.

Prefer `godot-docker` when the host has no Godot or when you want behaviour identical to CI. Only the host server can open a real window.

## The live-editor bridge

Both servers above drive Godot from outside. A third, **`godot-ai`**, drives it from *inside* a running editor, which is the one thing a headless run cannot do: placing nodes in an open scene, building UI hierarchies, editing an AnimationPlayer, authoring materials. It is [Godot AI](https://github.com/hi-godot/godot-ai) (MIT), pinned in `tools/lib.sh` as `GODOTGO_GODOT_AI_VERSION`.

```bash
tools/install_godot_ai.sh     # fetch the pinned release, verify its SHA-256, link it in
brew install uv               # the server runs through uvx
tools/godot_ai.sh doctor      # addon, link, uvx, ports, .mcp.json
tools/godot_ai.sh edit leap   # open the editor with the bridge live
tools/godot_ai.sh status      # which editor is serving it, and who holds the ports
```

Project MCP servers need approving once. Claude Code shows a trust dialog the first time a session starts in this directory; `claude mcp list` shows them as `⏸ Pending approval` until then, `/mcp` manages them afterwards, and `claude mcp reset-project-choices` starts over. Servers attach at startup, so a new entry in `.mcp.json` reaches a session that is already running only after a restart.

The chain is `Claude Code → tools/godot_ai.sh attach → Python server (HTTP) → editor plugin (WebSocket)`. The addon's own setup is a **Configure** button in an editor dock that writes into `~/.claude.json`; this workspace does not use it, because `.mcp.json` is committed and a fresh clone should be wired without anyone pressing anything. Three things are decided in the wrapper rather than by a default: telemetry is off unless `GODOTGO_AI_TELEMETRY=1`, the PyPI server is pinned to the same release as the addon, and `GODOTGO_AI_PROJECT` picks the target without editing a tracked file.

Telemetry is worth a sentence of its own, because switching it off takes two different mechanisms and only one of them is a flag. The Python server accepts `--disable-telemetry`. The editor plugin does not: it reads the `godot_ai/telemetry_enabled` EditorSetting, which defaults to **on** and lives per Godot install rather than per project, so the repository cannot carry the preference. The addon documents `GODOT_AI_DISABLE_TELEMETRY` as an override that is checked before that setting, and `tools/godot_ai.sh` exports it on both paths. Launching the editor any other way on a wired project sends usage data;
the log line to look for is `godot-ai-telemetry | Telemetry disabled`.

Two limits are worth knowing before you rely on it. **The editor must be running** — with none, the server still answers but every editor tool fails. And **one editor at a time** can serve the bridge, because Godot stores EditorSettings per install rather than per project, so the ports cannot differ per game. `tools/godot_ai.sh status` reports both, and names whatever process holds port 8000 when it is not Godot AI, which on a machine running Docker is often the real reason nothing connects.

### What GodotGo adds to it

`framework/addons/godotgo/mcp/` registers five more tools into Godot AI's registry through its published `McpToolRegistry` API, so the agent building a scene can also prove the result:

| Tool | Does |
| --- | --- |
| `godotgo_verify` | The gate for one project: check, test, smoke |
| `godotgo_test` | One project's headless tests, optionally filtered |
| `godotgo_check` | Load every script, scene and resource; lint and format-check |
| `godotgo_projects` | The workspace's projects, their kind and main scene |
| `godotgo_framework_api` | Session, testing, utilities and conventions |

That is the whole reason to extend rather than fork: Godot AI knows Godot, and this makes it know *this workspace* as well, while upstream releases keep arriving. The three that shell out are declared deferred and answer from a worker thread, so a minute-long verify never freezes the editor.

### Keeping a checkout clean

`vendor/godot_ai` and the per-project `addons/godot_ai` symlinks are gitignored. `project.godot` is not, and enabling an editor plugin edits it, so `tools/godot_ai.sh edit` adds the enable line for the length of a session and removes it afterwards, along with the `_mcp_game_helper` autoload Godot AI writes for itself. A wire and unwire round trip leaves the file byte-identical.

Committing either line would break the project for everyone who never installed the addon, CI included: the autoload points at a script that is not there, and Godot refuses to start. `tools/verify.sh` fails on any `project.godot` reference that is not on disk, which is also what an interrupted editor session looks like; `tools/install_godot_ai.sh --uninstall` clears it and leaves no trace.

## Docker toolchain

Nothing but Docker needs to be installed on the host.

```bash
tools/docker.sh build                          # build the toolchain image
tools/docker.sh verify [project]               # the full gate, in the container
tools/docker.sh test leap player               # any tool, any project
WITH_EXPORT_TEMPLATES=1 tools/docker.sh build  # bake the Linux export templates (~130 MB)
tools/docker.sh export orb-run                 # release build into build/
tools/docker.sh shell
```

The image carries Godot 4.7.2 for the host CPU, gdtoolkit, the Godot MCP server and Xvfb with Mesa software rendering. The whole workspace is mounted at `/workspace`, so the container runs the same scripts against the same files.

One cross-environment trap is handled in `tools/lib.sh`: a `.venv` built on the host is visible inside the container but its interpreter is not, so the tool lookup checks that a gdtoolkit binary actually runs before preferring it over the image's own copy.

## GitHub workflows

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `ci.yml` | push, pull request | Discovers every project and verifies each in parallel in the container; separately fails if regenerated assets differ from the committed bytes |
| `claude.yml` | `@claude` in an issue, PR, comment or review | Claude works in the repo with the framework's commands available |
| `claude-code-review.yml` | pull requests touching code | Inline review comments |
| `claude-improve.yml` | weekly cron, or manual dispatch | Picks a project, makes one improvement, opens a pull request |

`claude-improve.yml` is the autonomous path. It verifies the project first so a pre-existing failure is not blamed on the run, takes an optional project and task from `workflow_dispatch` inputs, and can only push a branch and open a pull request, so nothing reaches `main` without review.

All three Claude workflows need the `CLAUDE_CODE_OAUTH_TOKEN` secret and the `anthropics/claude-code-action@v1` permissions block already in the files: `contents: write`, `pull-requests: write`, `issues: write`, `id-token: write`.

## Cost and limits

Each `tools/claude.sh` run passes `--max-budget-usd` (default 10, `--budget` to change) and the improvement workflow passes 15. An OAuth token draws on the subscription's usage pool rather than API billing, so the ceiling is a guard rather than an invoice. `--dry-run` prints exactly what would be sent without spending anything, which is the right way to iterate on a prompt.
