---
name: godot-ai
description: Drive a live Godot editor over MCP with the Godot AI addon, and use the GodotGo tools this workspace publishes into it. Use when asked to build scenes or UI interactively in the editor, to check the MCP bridge, or when godot-ai is not connecting.
allowed-tools: Bash(tools/godot_ai.sh doctor*) Bash(tools/godot_ai.sh status*) Bash(tools/install_godot_ai.sh*) Bash(tools/verify.sh*)
---

Godot AI (github.com/hi-godot/godot-ai, MIT) connects an MCP client to a **running Godot editor**. It is the only way to build a scene interactively here; everything else in this workspace is headless.

```bash
tools/install_godot_ai.sh          # fetch the pinned release, link it into every project
tools/godot_ai.sh doctor [project] # check addon, link, enable line, uvx, ports, .mcp.json
tools/godot_ai.sh status           # is an editor serving the bridge, and who holds the ports
tools/godot_ai.sh edit <project>   # open the editor with the bridge live
```

The chain is `MCP client → tools/godot_ai.sh attach → Python server (HTTP) → editor plugin (WebSocket)`. `.mcp.json` registers the `godot-ai` server, so nothing needs configuring through the addon's own dock.

## What it can and cannot do

- **The editor must be running.** With no editor, the server starts and answers, but every editor tool fails. `tools/godot_ai.sh status` says whether one is up.
- **One editor at a time.** Godot AI reads its ports from EditorSettings, which Godot keeps per install rather than per project, so two editors cannot each hold a bridge.
- Prefer the headless `godot-docker` MCP server, or the plain `tools/*.sh` commands, for anything that does not need a live editor. They are faster and need no window.

## GodotGo's own tools

`framework/addons/godotgo/mcp/` registers five extra tools into Godot AI, so the same agent that builds a scene can also prove it works:

| Tool | Does |
| --- | --- |
| `godotgo_verify` | The full gate for one project: check, test, smoke |
| `godotgo_test` | One project's headless tests, optionally filtered |
| `godotgo_check` | Load every script, scene and resource; lint and format-check |
| `godotgo_projects` | The workspace's projects, their kind and main scene |
| `godotgo_framework_api` | The framework's shape: session, testing, utilities, conventions |

They appear only while an editor is running with both addons enabled. `godotgo_verify` is still the gate: a scene built through the editor is not done until it passes.

## Facts that matter

- The version is pinned in `tools/lib.sh` as `GODOTGO_GODOT_AI_VERSION`, and `tools/verify.sh` fails if the installed copy has drifted.
- `vendor/godot_ai` and the per-project `addons/godot_ai` symlinks are **gitignored**. `project.godot` is not: enabling the plugin edits a tracked file, so `tools/godot_ai.sh edit` adds that line only for the length of a session and removes it afterwards, together with the `_mcp_game_helper` autoload the addon writes for itself. Never commit either line. If an editor session is killed, `tools/verify.sh` fails on the dangling reference; `tools/install_godot_ai.sh --uninstall` clears it.
- Open the editor through `tools/godot_ai.sh edit`, not by hand: launching Godot directly leaves the plugin disabled, and enabling it from the dock writes lines into a tracked file that nothing will clean up.
- Never edit anything under `vendor/`. It is a dependency, and the workspace extends it through its published `McpToolRegistry` API instead.
- Telemetry is off, but only because `tools/godot_ai.sh` exports `GODOT_AI_DISABLE_TELEMETRY=1`. The addon defaults to sending usage data, and the editor half is governed by an EditorSetting rather than a flag, so launching the editor any other way on a wired project reports. `GODOTGO_AI_TELEMETRY=1` opts back in.
- `uv` must be installed (`brew install uv`); the server runs through `uvx`.
- Port 8000 is a popular default. `tools/godot_ai.sh doctor` names whatever holds it, and `GODOTGO_AI_HTTP_PORT` moves it, but the editor's own port lives in Editor Settings under `godot_ai/http_port` and must match.
