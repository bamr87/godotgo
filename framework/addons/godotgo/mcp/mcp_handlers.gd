@tool
extends RefCounted
## Implements the tools [GodotGoMcpBridge] publishes to an MCP agent.
##
## Every method here has the signature Godot AI's dispatcher calls,
## [code](params: Dictionary, ctx) -> Dictionary[/code], and returns either
## [code]{"data": ...}[/code] or [code]{"status": "error", "error": ...}[/code].
## [code]ctx[/code] is deliberately untyped: naming Godot AI's class would stop
## this file parsing on a machine that has not installed it, and the framework
## must load the same everywhere. See [GodotGoMcpBridge] for the whole rationale.
##
## The shell-outs run on a worker thread and answer through
## [code]ctx.send_deferred()[/code], because a synchronous
## [method OS.execute] would freeze the editor for the minute a verify takes.

## Godot AI's marker for "the answer is coming later".
const DEFERRED := {"_deferred": true}


func verify(params: Dictionary, ctx) -> Dictionary:
	return _run_tool(params, ctx, "tools/verify.sh", [])


func check(params: Dictionary, ctx) -> Dictionary:
	return _run_tool(params, ctx, "tools/check.sh", [])


func test(params: Dictionary, ctx) -> Dictionary:
	var extra: Array[String] = []
	var filter := str(params.get("filter", "")).strip_edges()
	if not filter.is_empty():
		extra.append(filter)
	return _run_tool(params, ctx, "tools/test.sh", extra)


func projects(_params: Dictionary, _ctx) -> Dictionary:
	var root := _workspace_root()
	if root.is_empty():
		return _error("this project is not inside a GodotGo workspace")
	var listed: Array[Dictionary] = []
	for name in _project_names(root):
		var path := root.path_join(name)
		(
			listed
			. append(
				{
					"name": name.trim_prefix("games/"),
					"path": name,
					"kind": "framework" if name == "framework" else "game",
					"main_scene": _main_scene(path),
				}
			)
		)
	return {
		"data":
		{
			"workspace": root,
			"projects": listed,
			"note":
			(
				"The repository root is not a Godot project. Every game symlinks"
				+ " addons/godotgo to one shared framework, so a change to the"
				+ " framework is felt by all of them at once."
			),
		}
	}


func framework_api(params: Dictionary, _ctx) -> Dictionary:
	var topic := str(params.get("topic", "")).strip_edges().to_lower()
	var sections := _api_sections()
	if not topic.is_empty():
		if not sections.has(topic):
			return _error(
				(
					"unknown topic '%s'; known topics are %s"
					% [topic, ", ".join(PackedStringArray(sections.keys()))]
				)
			)
		return {"data": {"topic": topic, "api": sections[topic]}}
	return {"data": {"api": sections}}


## Resolves the project, then runs one of the workspace scripts against it on a
## worker thread. The reply arrives through ctx.
func _run_tool(params: Dictionary, ctx, script: String, extra: Array[String]) -> Dictionary:
	var root := _workspace_root()
	if root.is_empty():
		return _error("this project is not inside a GodotGo workspace")
	var project := str(params.get("project", "")).strip_edges()
	if project.is_empty():
		return _error("project is required; call godotgo_projects for the list")
	var known := _project_names(root)
	var resolved := ""
	for name in known:
		if name == project or name == "games/" + project:
			resolved = name
			break
	if resolved.is_empty():
		return _error("unknown project '%s'; known projects are %s" % [project, ", ".join(known)])

	var args: Array[String] = [root.path_join(script), resolved]
	args.append_array(extra)
	# Captured by value; the task owns them once this method returns.
	var task := func() -> void: _run_and_reply(ctx, root, args)
	WorkerThreadPool.add_task(task)
	return DEFERRED


func _run_and_reply(ctx, root: String, args: Array[String]) -> void:
	var out: Array = []
	var started := Time.get_ticks_msec()
	# bash, not the script directly: the container image and a bare checkout do
	# not agree about the executable bit surviving a copy.
	var argv: Array[String] = ["-c", _command_line(root, args)]
	var code := OS.execute("/bin/bash", argv, out, true)
	var text := "" if out.is_empty() else str(out[0])
	var payload := {
		"data":
		{
			"command": " ".join(args).replace(root + "/", ""),
			"exit_code": code,
			"passed": code == 0,
			"duration_ms": Time.get_ticks_msec() - started,
			"output": _tail(text),
		}
	}
	# send_deferred() reaches the WebSocket, which belongs to the main thread.
	ctx.send_deferred.call_deferred(payload)


## Runs from the workspace root so the scripts resolve their own paths, and
## keeps stderr, which is where every failure in this toolchain is written.
func _command_line(root: String, args: Array[String]) -> String:
	var quoted := PackedStringArray()
	for arg in args:
		quoted.append("'" + arg.replace("'", "'\\''") + "'")
	return "cd '%s' && %s 2>&1" % [root.replace("'", "'\\''"), " ".join(quoted)]


## The last of a long run is the part that says what happened; a full verify is
## far more text than an agent needs to read.
func _tail(text: String, limit: int = 6000) -> String:
	if text.length() <= limit:
		return text
	return "...(%d earlier characters omitted)...\n%s" % [text.length() - limit, text.right(limit)]


## Walks up from this project until it finds the workspace's own marker. The
## editor's working directory is not reliable, but res:// always is.
func _workspace_root() -> String:
	var dir := ProjectSettings.globalize_path("res://").rstrip("/")
	for _step in 4:
		dir = dir.get_base_dir()
		if dir.is_empty() or dir == "/":
			return ""
		if FileAccess.file_exists(dir.path_join("tools/lib.sh")):
			return dir
	return ""


func _project_names(root: String) -> PackedStringArray:
	var names := PackedStringArray()
	if FileAccess.file_exists(root.path_join("framework/project.godot")):
		names.append("framework")
	var games := DirAccess.open(root.path_join("games"))
	if games != null:
		for slug in games.get_directories():
			if FileAccess.file_exists(root.path_join("games/%s/project.godot" % slug)):
				names.append("games/" + slug)
	return names


func _main_scene(project_dir: String) -> String:
	var config := ConfigFile.new()
	if config.load(project_dir.path_join("project.godot")) != OK:
		return ""
	return str(config.get_value("application", "run/main_scene", ""))


func _error(message: String) -> Dictionary:
	return {"status": "error", "error": {"code": "INVALID_PARAMS", "message": message}}


## The framework's shape, in the words an agent needs to write code that fits.
## Kept here rather than read from the docs so the answer does not depend on a
## file layout that a game project may not even have checked out.
static func _api_sections() -> Dictionary:
	return {
		"session":
		(
			"Session (core/session.gd) owns a round and touches no nodes, which is"
			+ " what makes every rule testable without a scene. It has a"
			+ " READY/PLAYING/PAUSED/WON/LOST state machine, a score, an objective"
			+ " counter (progress toward goal) and an optional countdown, with a"
			+ " signal for each: state_changed, score_changed, progress_changed,"
			+ " time_changed, objective_reached, won(result), lost(reason).\n"
			+ "Each game registers a subclass as the autoload named Game and adds"
			+ " only its own vocabulary, so Game stays a few dozen lines. Call"
			+ " start(goal, time_limit) to begin; it prints the '[godotgo] session"
			+ " start' line the smoke test requires. objective_reached fires exactly"
			+ " once per round, and time_changed is throttled to tenths of a second."
		),
		"testing":
		(
			"Tests are plain GDScript under a project's tests/unit/, named"
			+ " test_*.gd, extending GodotGoTest, with every test_* method run"
			+ " between before_each and after_each. There is no third-party"
			+ " dependency and no scene: the runner extends SceneTree and is"
			+ " launched headless.\n"
			+ "Helpers: the assert_* family, add_scene, add_node, free_node,"
			+ " physics_frames(n), record(signal) returning an array that fills with"
			+ " emitted arguments, add_floor_2d(), add_floor_3d(), skip(reason) and"
			+ " is_headless(). Anything the dummy DisplayServer cannot do, such as"
			+ " capturing the mouse, must skip when headless.\n"
			+ "A project with no tests fails: an empty suite is indistinguishable"
			+ " from a passing one."
		),
		"utilities":
		(
			"SaveSystem: versioned JSON slots under user://saves/, refusing a file"
			+ " written by a newer schema instead of misreading it.\n"
			+ "ObjectPool: instances handed out un-parented and taken back on"
			+ " release, with pool_acquired()/pool_released() callbacks and a"
			+ " max_size that is a hard ceiling.\n"
			+ "StateMachine: a callable-driven FSM with no node hierarchy.\n"
			+ "Rng: seeded, state-serialisable randomness, which is what makes"
			+ " spawn patterns testable.\n"
			+ "TextGrid: ASCII level maps.\n"
			+ "MaterialMakerLoader: loads a Material Maker export, splitting a"
			+ " packed ORM map across the AO, roughness and metallic channels.\n"
			+ "DebugOverlay: F3 diagnostics that builds its own UI."
		),
		"conventions":
		(
			'Tabs, static typing (:=, typed parameters and returns), &"name" for'
			+ ' actions and signals, ^"Path" for node paths, @export_range for'
			+ " tunables, get_node_or_null where absence is legal, and ## doc"
			+ " comments on public members. gdlint enforces member order: signals,"
			+ " constants, exports, public vars, private vars, @onready vars, then"
			+ " methods.\n"
			+ "Physics layers are consistent across games: 1 world, 2 player,"
			+ " 3 pickups, 4 triggers, and game-specific layers from 5 up.\n"
			+ "Hand-written .tscn/.tres need a real uid:// from new_uid.gd, and"
			+ " load_steps equals the ext_resource plus sub_resource count, plus one.\n"
			+ "Values sampled after move_and_slide() have already been zeroed by the"
			+ " slide, so landing speed is read before the call.\n"
			+ "Placeholder art is generated by tools/gen_assets.py, never drawn, and"
			+ " CI fails if a regenerated asset differs from the committed bytes.\n"
			+ "Code belongs in the framework if two games would otherwise write it"
			+ " and it can be tested without a scene; in the game otherwise."
		),
	}
