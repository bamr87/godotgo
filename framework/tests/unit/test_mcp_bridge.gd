extends GodotGoTest
## The MCP bridge that offers GodotGo's tools to an agent through Godot AI.
##
## Godot AI is an editor plugin, so its registry is never live in a headless
## run. That is exactly the state worth testing: the framework must behave
## identically whether or not the optional addon is installed, and the tool
## definitions must satisfy Godot AI's registration limits before anyone opens
## an editor to find out.

## Mirrors the budgets in Godot AI's McpCustomToolSpec. Duplicated deliberately:
## these tests must run on a machine that has never installed it, and a silent
## drift here is better caught as a failing assert than as a tool that vanishes
## from the dock.
const MAX_DESCRIPTION_CHARS := 600
const MAX_SCHEMA_BYTES := 8192
const MIN_TIMEOUT_MS := 500
const MAX_TIMEOUT_MS := 120000

var _handlers: RefCounted


func before_each() -> void:
	_handlers = load(GodotGoMcpBridge.HANDLERS_SCRIPT).new()


func after_each() -> void:
	_handlers = null


func test_the_framework_loads_without_godot_ai_registering_anything() -> void:
	# The registry singleton only exists while Godot AI's plugin is loaded, which
	# never happens headlessly, so this is the "not installed" path either way.
	assert_false(GodotGoMcpBridge.is_available(), "no editor, so no live registry")
	var bridge := GodotGoMcpBridge.new()
	assert_eq(bridge.register_tools(), 0, "registering is a no-op, not an error")
	bridge.unregister_tools()


func test_every_tool_is_within_godot_ais_registration_budgets() -> void:
	var definitions := GodotGoMcpBridge._tool_definitions()
	assert_true(definitions.size() >= 5, "the bridge publishes the workspace's tools")
	for definition in definitions:
		var tool_name: String = definition["name"]
		assert_true(
			tool_name.is_valid_ascii_identifier(), "%s must be a valid identifier" % tool_name
		)
		assert_true(
			tool_name.begins_with("godotgo_"),
			"%s must be namespaced so it cannot shadow a built-in tool" % tool_name
		)
		var description: String = definition["description"]
		assert_true(
			description.length() <= MAX_DESCRIPTION_CHARS,
			(
				"%s description is %d chars, over the %d cap"
				% [tool_name, description.length(), MAX_DESCRIPTION_CHARS]
			)
		)
		var schema_bytes := JSON.stringify(definition["schema"]).to_utf8_buffer().size()
		assert_true(
			schema_bytes <= MAX_SCHEMA_BYTES, "%s schema is %d bytes" % [tool_name, schema_bytes]
		)
		var timeout: int = definition.get("timeout_ms", 4500)
		assert_true(
			timeout >= MIN_TIMEOUT_MS and timeout <= MAX_TIMEOUT_MS,
			"%s timeout %d is outside Godot AI's range" % [tool_name, timeout]
		)


func test_tool_names_are_unique() -> void:
	var seen := {}
	for definition in GodotGoMcpBridge._tool_definitions():
		var tool_name: String = definition["name"]
		assert_false(seen.has(tool_name), "%s is registered twice" % tool_name)
		seen[tool_name] = true


func test_every_tool_points_at_a_method_that_exists() -> void:
	# The registry materialises the handler lazily by path, so a typo in `method`
	# would only surface as a failed call in a live editor.
	for definition in GodotGoMcpBridge._tool_definitions():
		var method: StringName = definition["method"]
		assert_true(
			_handlers.has_method(method),
			"%s names the handler method %s, which does not exist" % [definition["name"], method]
		)


func test_a_tool_that_shells_out_declares_itself_deferred() -> void:
	# Godot AI rejects a deferred reply from a spec that did not declare it, so
	# the two must agree: anything running a workspace script answers later.
	for definition in GodotGoMcpBridge._tool_definitions():
		var runs_a_script: bool = (
			definition["name"] in ["godotgo_verify", "godotgo_test", "godotgo_check"]
		)
		assert_eq(
			bool(definition.get("deferred", false)),
			runs_a_script,
			"%s declares the wrong deferred mode" % definition["name"]
		)


func test_projects_lists_this_workspace() -> void:
	var result: Dictionary = _handlers.projects({}, null)
	assert_true(result.has("data"), "listing projects is a plain success")
	var names := PackedStringArray()
	for entry in result["data"]["projects"]:
		names.append(entry["name"])
	assert_true("framework" in names, "the framework is a project")
	assert_true("leap" in names, "a game is listed by its slug, not its path")
	for entry in result["data"]["projects"]:
		if entry["name"] == "framework":
			assert_eq(entry["kind"], "framework")
		else:
			assert_eq(entry["kind"], "game")
			assert_true(
				str(entry["main_scene"]).begins_with("res://"),
				"%s should report a main scene" % entry["name"]
			)


func test_framework_api_answers_whole_or_by_topic() -> void:
	var whole: Dictionary = _handlers.framework_api({}, null)
	assert_true(whole["data"]["api"].has("session"))
	assert_true(whole["data"]["api"].has("testing"))
	var one: Dictionary = _handlers.framework_api({"topic": "Session"}, null)
	assert_eq(one["data"]["topic"], "session", "the topic is matched case-insensitively")
	assert_true(str(one["data"]["api"]).contains("objective_reached"))


func test_an_unknown_api_topic_is_refused_with_the_known_ones() -> void:
	var result: Dictionary = _handlers.framework_api({"topic": "physics"}, null)
	assert_eq(result.get("status", ""), "error")
	assert_true(
		str(result["error"]["message"]).contains("session"),
		"the refusal names the topics that do exist"
	)


func test_running_a_tool_without_a_project_is_refused_before_anything_spawns() -> void:
	# ctx is null here: a handler that reached the thread would crash on it, so
	# these assertions also prove the validation happens first.
	var missing: Dictionary = _handlers.verify({}, null)
	assert_eq(missing.get("status", ""), "error")
	assert_true(str(missing["error"]["message"]).contains("required"))

	var unknown: Dictionary = _handlers.test({"project": "not-a-game"}, null)
	assert_eq(unknown.get("status", ""), "error")
	assert_true(
		str(unknown["error"]["message"]).contains("framework"),
		"the refusal lists what could have been asked for"
	)


func test_output_is_trimmed_to_something_an_agent_can_read() -> void:
	var short_text := "already short"
	assert_eq(_handlers._tail(short_text), short_text, "short output is left alone")
	var long_text := "x".repeat(9000) + "TAIL"
	var trimmed: String = _handlers._tail(long_text)
	assert_true(trimmed.length() < long_text.length())
	assert_true(trimmed.ends_with("TAIL"), "the end is what says how the run finished")
	assert_true(trimmed.contains("omitted"), "and the reader is told something was dropped")


func test_a_command_line_survives_a_path_with_a_quote_in_it() -> void:
	var argv: Array[String] = ["/tmp/it's here/tools/test.sh", "leap"]
	var line: String = _handlers._command_line("/tmp/it's here", argv)
	assert_true(line.begins_with("cd '/tmp/it'\\''s here'"), "the root is quoted, not broken")
	assert_true(line.ends_with("2>&1"), "stderr is kept: that is where failures are written")


func test_the_specs_pass_godot_ais_own_validator() -> void:
	# The budgets asserted above are a copy; this runs the real thing. When the
	# addon is installed its validator is the authority on what it will accept,
	# so a rule we have not noticed fails here rather than in someone's editor.
	if not ResourceLoader.exists(GodotGoMcpBridge.SPEC_SCRIPT):
		skip("godot-ai is not installed; run tools/install_godot_ai.sh")
		return
	var spec_script := load(GodotGoMcpBridge.SPEC_SCRIPT)
	var specs := GodotGoMcpBridge.build_specs(spec_script)
	assert_eq(specs.size(), GodotGoMcpBridge._tool_definitions().size())
	for spec in specs:
		var errors: Array = spec.validate()
		assert_true(errors.is_empty(), "%s rejected: %s" % [spec.name, ", ".join(errors)])
		assert_eq(spec.source_path, GodotGoMcpBridge.SOURCE_PATH, "ownership is declared")
