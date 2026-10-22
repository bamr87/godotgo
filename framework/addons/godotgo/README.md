# GodotGo framework

> A small, dependency-free Godot 4 addon: the parts every game in this workspace kept rewriting, plus a headless test runner.

Copy this directory into any Godot 4.7+ project as `addons/godotgo`, or symlink it as the games here do. Enabling the plugin in Project Settings is optional and only adds `ObjectPool` and `DebugOverlay` to the "Create New Node" dialog; every class is a global `class_name` either way.

Every class and script in this directory, with its members and doc comments, is listed in the generated [framework API reference](../../../docs/reference/framework-api.md); `python3 tools/gen_framework_api.py` rebuilds it from the `##` comments here.

Usage, conventions and the reasoning behind each piece are in [docs/framework.md](../../../docs/framework.md).
