---
name: new-game
description: Scaffold a new Godot game project in this workspace from the blank template, already wired to the shared framework. Use when the user wants to start a new game, sample or prototype.
allowed-tools: Bash(tools/new_game.sh*) Bash(tools/verify.sh*) Bash(python3 tools/gen_assets.py*)
arguments: [slug, title]
---

```bash
tools/new_game.sh <slug> --title "Nice Name" --desc "One line about the game"
```

The slug is lower-case letters, digits and dashes; it becomes `games/<slug>`. The scaffolder copies `templates/blank`, symlinks `addons/godotgo` to the shared framework, generates real resource UIDs with Godot, substitutes the name into every file, and then runs check, test and smoke. It refuses to finish if the new project does not verify.

What you get is a small but complete game: a `Session` subclass in `scripts/game.gd`, a main scene wired to it, a HUD driven by its signals, a debug overlay and three passing tests.

Then replace the placeholder gameplay. Keep the shape:

- Rules go in `scripts/game.gd`. It extends the framework's `Session`, which already owns the state machine, score, objective counter and countdown. Add only what is specific to the game.
- Scenes call into the session and react to its signals. No rule should need a node reference, so rules stay testable headlessly.
- Place art by adding a project entry in `tools/gen_assets.py` and running `python3 tools/gen_assets.py <slug>`. Do not commit hand-made binaries.
- Write tests under `tests/unit/`, resetting `Game` in `before_each` and `after_each`.

`docs/authoring-games.md` is the long form of this, and `games/leap` is the reference implementation.
