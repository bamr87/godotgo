# GodotGo framework

A small, dependency-free Godot 4 addon: the parts every game in this workspace kept rewriting, plus a headless test runner.

Copy this directory into any Godot 4.7+ project as `addons/godotgo`, or symlink it as the games here do. Enabling the plugin in Project Settings is optional and only adds `ObjectPool` and `DebugOverlay` to the "Create New Node" dialog; every class is a global `class_name` either way.

| File | Class | Purpose |
| --- | --- | --- |
| `core/session.gd` | `Session` | Round lifecycle: state machine, score, objective counter, countdown |
| `core/save_system.gd` | `SaveSystem` | Versioned JSON save slots under `user://saves/` |
| `util/object_pool.gd` | `ObjectPool` | Instance reuse with acquire/release and lifecycle callbacks |
| `util/state_machine.gd` | `StateMachine` | Callable-driven finite state machine, no nodes required |
| `util/rng.gd` | `Rng` | Seeded, state-serialisable randomness |
| `util/text_grid.gd` | `TextGrid` | ASCII level maps |
| `util/material_maker_loader.gd` | `MaterialMakerLoader` | Loads Material Maker exports, including packed ORM maps |
| `ui/debug_overlay.gd` | `DebugOverlay` | F3 diagnostics panel that builds its own UI |
| `testing/test_case.gd` | `GodotGoTest` | Test base class: assertions, scene helpers, signal recording |
| `testing/test_runner.gd` | - | `SceneTree` runner; `godot --headless --script res://addons/godotgo/testing/test_runner.gd` |
| `tools/check_scripts.gd` | - | Loads scripts, scenes and resources in a live tree to validate them |
| `tools/new_uid.gd` | - | Prints a fresh `uid://` for hand-written scenes |

Usage, conventions and the reasoning behind each piece are in [docs/framework.md](../../../docs/framework.md).
