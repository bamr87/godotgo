@tool
class_name GodotGoMcpBridge
extends RefCounted
## Publishes GodotGo's own tools to an MCP agent through the Godot AI addon.
##
## Godot AI (github.com/hi-godot/godot-ai) gives an agent about 120 tools for
## driving a live editor: nodes, scenes, scripts, animation, materials. What it
## cannot know is this workspace — that a round lives in a [Session] subclass,
## that a project is verified by [code]tools/verify.sh[/code], that an empty test
## suite is a failure rather than a pass. This registers that knowledge as
## additional tools, so one agent can both build a scene and prove it still
## works.
##
## Godot AI is an optional dependency. Nothing here references its classes by
## name: the scripts are loaded by path and duck-typed, so the framework parses
## and runs identically on a machine that has never installed it. That is why
## the handler signatures below leave [code]ctx[/code] untyped — naming
## [code]McpCallContext[/code] would make this file fail to parse without it.
##
## [codeblock]
## var bridge := GodotGoMcpBridge.new()
## bridge.register_tools()   # 0 when Godot AI is absent, never an error
## [/codeblock]

## Where the vendored addon puts the pieces we duck-type against.
const REGISTRY_SCRIPT := "res://addons/godot_ai/custom_tools/mcp_tool_registry.gd"
const SPEC_SCRIPT := "res://addons/godot_ai/custom_tools/mcp_custom_tool_spec.gd"

## Identifies these tools as ours in Godot AI's dock and collision policy.
const SOURCE_PATH := "res://addons/godotgo/plugin.cfg"
const SOURCE_NAME := "godotgo"

## The handlers live in a separate script because the registry materialises them
## lazily by path, so a hot reload cannot free an instance mid-call.
const HANDLERS_SCRIPT := "res://addons/godotgo/mcp/mcp_handlers.gd"

## Ceiling Godot AI enforces on a deferred tool. A whole-workspace verify runs
## longer than this, which is why every tool that shells out takes one project.
const MAX_TIMEOUT_MS := 120000

var _registry: Object = null


## True when the Godot AI addon is installed and its registry is live. Both
## halves matter: the scripts can be present while the plugin is disabled.
static func is_available() -> bool:
	return _registry_instance() != null


## Registers every GodotGo tool, replacing any previous registration of the
## same names. Returns how many were accepted; 0 means Godot AI is not
## available, which is a normal state and not an error.
func register_tools() -> int:
	_registry = _registry_instance()
	if _registry == null:
		return 0

	var spec_script: Resource = _load_optional(SPEC_SCRIPT)
	if spec_script == null:
		return 0

	var specs := build_specs(spec_script)
	var accepted := 0
	for spec in specs:
		if _registry.register(spec):
			accepted += 1
		else:
			push_warning("GodotGo: Godot AI refused the tool %s" % spec.name)

	# Godot AI clears the registry when it reloads, so re-register on its way
	# back up rather than leaving the tools silently missing.
	if (
		_registry.has_signal("registry_ready")
		and not _registry.registry_ready.is_connected(_on_registry_ready)
	):
		_registry.registry_ready.connect(_on_registry_ready)
	return accepted


## Removes the tools again, for when the framework plugin is disabled while
## Godot AI stays up.
func unregister_tools() -> void:
	if _registry == null or not is_instance_valid(_registry):
		return
	_registry.unregister_source(SOURCE_PATH)
	_registry = null


## Turns the definitions into Godot AI spec objects. Separate from registration
## so the framework's tests can hand them to Godot AI's own validator, which is
## a far better check of the budgets than a copy of its constants.
static func build_specs(spec_script: Resource) -> Array:
	var specs: Array = []
	for definition in _tool_definitions():
		var spec: Object = spec_script.new()
		spec.name = definition["name"]
		spec.description = definition["description"]
		spec.params_schema = definition["schema"]
		spec.script_path = HANDLERS_SCRIPT
		spec.method = definition["method"]
		spec.source_path = SOURCE_PATH
		spec.source = SOURCE_NAME
		spec.promoted = definition.get("promoted", true)
		spec.deferred = definition.get("deferred", false)
		spec.timeout_ms = definition.get("timeout_ms", 4500)
		# Reads never block on the editor; the shell-outs do not touch it at all.
		spec.requires_writable = false
		spec.undoable = false
		specs.append(spec)
	return specs


static func _registry_instance() -> Object:
	var script: Resource = _load_optional(REGISTRY_SCRIPT)
	if script == null:
		return null
	# get_instance() is Godot AI's documented accessor and returns null while
	# its plugin is not loaded.
	return script.get_instance()


## load() that reports nothing when the file is simply not installed, so the
## absence of an optional dependency never reaches the editor's error log.
static func _load_optional(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		return null
	return load(path)


func _on_registry_ready() -> void:
	register_tools()


## One entry per tool. Kept as data so the same list drives registration and
## the framework's own tests, which assert the shape without Godot AI present.
static func _tool_definitions() -> Array[Dictionary]:
	var project_schema := {
		"type": "object",
		"properties":
		{
			"project":
			{
				"type": "string",
				"description": "Project name: 'framework' or a slug under games/, e.g. 'leap'.",
			},
		},
		"required": ["project"],
	}
	return [
		{
			"name": "godotgo_verify",
			"description":
			(
				"Run GodotGo's full verification gate for one project: import and load"
				+ " every script, scene and resource, lint and format-check, run the"
				+ " headless test suite, then smoke-boot the main scene. This is the"
				+ " same command CI runs, and the only evidence that a change is good."
				+ " Takes one project because the whole workspace exceeds the timeout."
			),
			"method": &"verify",
			"schema": project_schema,
			"deferred": true,
			"timeout_ms": MAX_TIMEOUT_MS,
		},
		{
			"name": "godotgo_test",
			"description":
			(
				"Run one project's headless unit tests, optionally narrowed to test"
				+ " files matching a substring. Faster than godotgo_verify while"
				+ " iterating on game rules. A project with no tests fails."
			),
			"method": &"test",
			"schema":
			{
				"type": "object",
				"properties":
				{
					"project": project_schema["properties"]["project"],
					"filter":
					{
						"type": "string",
						"description": "Substring of the test file name, e.g. 'player'.",
					},
				},
				"required": ["project"],
			},
			"deferred": true,
			"timeout_ms": MAX_TIMEOUT_MS,
		},
		{
			"name": "godotgo_check",
			"description":
			(
				"Load every script, scene and resource in one project inside a live"
				+ " SceneTree, so autoloads and class_name lookups resolve, then lint"
				+ " and format-check. Use after writing a scene or script to find"
				+ " broken ext_resource paths and wrong load_steps."
			),
			"method": &"check",
			"schema": project_schema,
			"deferred": true,
			"timeout_ms": MAX_TIMEOUT_MS,
		},
		{
			"name": "godotgo_projects",
			"description":
			(
				"List the projects in this workspace with their kind and main scene."
				+ " The repository root is not a Godot project: each entry is its own,"
				+ " sharing one copy of the framework addon."
			),
			"method": &"projects",
			"schema": {"type": "object", "properties": {}},
		},
		{
			"name": "godotgo_framework_api",
			"description":
			(
				"Describe the GodotGo framework a project is built on: the Session"
				+ " round lifecycle every game subclasses as the Game autoload, the"
				+ " shared utilities, the test helpers, and the conventions this"
				+ " workspace enforces. Read this before writing gameplay code here,"
				+ " so the code matches the framework instead of reinventing it."
			),
			"method": &"framework_api",
			"schema":
			{
				"type": "object",
				"properties":
				{
					"topic":
					{
						"type": "string",
						"description":
						"Narrow to one area: session, testing, utilities or conventions.",
					},
				},
			},
		},
	]
