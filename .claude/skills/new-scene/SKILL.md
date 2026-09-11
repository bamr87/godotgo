---
name: new-scene
description: Author a .tscn or .tres by hand safely, with a valid uid and correct ext_resource/sub_resource layout. Use when creating scenes or resources without the Godot editor.
allowed-tools: Bash(tools/godot.sh --headless*) Bash(tools/check.sh*) Bash(tools/verify.sh*)
---

Godot scene files are text and can be written directly, but three things must be right or the editor will silently rewrite or reject the file.

1. **UID.** Every `.tscn`/`.tres` should carry a unique `uid="uid://..."`. Generate one inside the project that will own it:

   ```bash
   tools/godot.sh --headless --path games/<slug> --script res://addons/godotgo/tools/new_uid.gd
   ```

   Never invent a uid string and never copy one from another file. Hand-invented values are silently accepted through 64-bit wraparound and then rewritten the first time the editor saves. For an `ext_resource` pointing at another scene or script, use the uid from that file's header or its `.gd.uid` sidecar.

2. **Layout.** Header `[gd_scene load_steps=N format=3 uid="..."]` where `N` = number of `ext_resource` + `sub_resource` entries + 1. Then `ext_resource` lines, `sub_resource` blocks, then nodes in tree order with `parent="."` for children of the root and `parent="Child/Grandchild"` deeper. Scripts attach with `script = ExtResource("id")`.

3. **Verify.** `tools/check.sh <project>` re-imports and loads the scene, which catches missing resources, bad paths and wrong `load_steps`. Then boot it: `HEADLESS=1 tools/run.sh <project> res://scenes/<new>.tscn`.

Reference layouts: `games/leap/scenes/hero.tscn` (2D body with sprite and camera), `games/leap/scenes/main.tscn` (exported scene references and audio), `games/orb-run/scenes/player.tscn` (3D body with a camera pivot).
