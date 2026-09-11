---
name: verify
description: Check, test and smoke-boot Godot projects in this workspace. Use after editing any .gd, .tscn, .tres or project.godot, before declaring work done, or when the user says verify, check, validate, test or lint.
allowed-tools: Bash(tools/verify.sh*) Bash(tools/check.sh*) Bash(tools/test.sh*) Bash(tools/smoke.sh*) Bash(tools/docker.sh*)
arguments: [project]
---

One command runs the whole gate for every project:

```bash
tools/verify.sh                 # framework + every game
tools/verify.sh leap            # just one project
```

It runs three stages, which you can also run alone:

| Stage | Command | What it proves |
| --- | --- | --- |
| check | `tools/check.sh [project] [file ...]` | Godot imports the project, then loads every script, scene and resource inside a live SceneTree, so autoloads and `class_name` lookups resolve. Then gdlint and `gdformat --check`. |
| test | `tools/test.sh [project] [filter]` | The headless suites under each project's `tests/unit/`. |
| smoke | `tools/smoke.sh [project]` | Boots each game's main scene without a window and fails on any error or warning. |

Project names are the directory under `games/`, or `framework`. `tools/check.sh leap scripts/hero.gd` narrows to specific files.

If a project fails `check` with `Could not find base class` or `Identifier not declared` for a framework class, the project has not been imported since the addon changed. Run `tools/godot.sh --headless --path games/<slug> --import` once, then check again.

`tools/docker.sh verify [project]` runs the identical commands in the container CI uses, which is the fallback when no local Godot is installed.
