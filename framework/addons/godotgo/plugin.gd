@tool
extends EditorPlugin
## Adds GodotGo's node types to the editor's "Create New Node" dialog.
##
## The framework works whether or not this plugin is enabled: every class is a
## global [code]class_name[/code] and can be attached or instantiated from code.
## Enabling it only makes the nodes discoverable in the editor.

const CUSTOM_TYPES := {
	"ObjectPool": {"base": "Node", "script": "res://addons/godotgo/util/object_pool.gd"},
	"DebugOverlay": {"base": "CanvasLayer", "script": "res://addons/godotgo/ui/debug_overlay.gd"},
}

var _mcp_bridge: GodotGoMcpBridge = null


func _enter_tree() -> void:
	for type_name in CUSTOM_TYPES:
		var info: Dictionary = CUSTOM_TYPES[type_name]
		add_custom_type(type_name, info["base"], load(info["script"]), null)
	_publish_mcp_tools()


func _exit_tree() -> void:
	for type_name in CUSTOM_TYPES:
		remove_custom_type(type_name)
	if _mcp_bridge != null:
		_mcp_bridge.unregister_tools()
		_mcp_bridge = null


## Offers this workspace's own tools to an MCP agent when the Godot AI addon is
## installed. Its absence is the normal case and says nothing on the console.
func _publish_mcp_tools() -> void:
	if not GodotGoMcpBridge.is_available():
		return
	_mcp_bridge = GodotGoMcpBridge.new()
	var count := _mcp_bridge.register_tools()
	if count > 0:
		print("[godotgo] published %d tools to Godot AI" % count)
