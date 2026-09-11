class_name DebugOverlay
extends CanvasLayer
## A drop-in diagnostics panel: frames per second, the running [Session]'s state
## and the current scene. Press F3 to toggle it.
##
## It builds its own label, so adding the node to a scene is the whole setup and
## no extra input action is required.

## Autoload path of the game's [Session] subclass.
const SESSION_PATH := ^"/root/Game"

@export var visible_at_start := false
@export var toggle_key: Key = KEY_F3

var _label: Label
var _session: Session


func _ready() -> void:
	layer = 128
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 14)
	_label.add_theme_color_override(&"font_color", Color(0.85, 1.0, 0.85))
	_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override(&"outline_size", 4)
	_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.offset_left = -320.0
	_label.offset_top = 12.0
	_label.offset_right = -12.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_session = get_node_or_null(SESSION_PATH) as Session
	visible = visible_at_start


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == toggle_key:
			visible = not visible


func _process(_delta: float) -> void:
	if not visible or _label == null:
		return
	_label.text = "\n".join(lines())


## The lines the overlay draws, exposed so tests can assert on them without a display.
func lines() -> PackedStringArray:
	var out: PackedStringArray = []
	out.append("%d fps" % Engine.get_frames_per_second())
	var scene := get_tree().current_scene if get_tree() != null else null
	if scene != null:
		out.append(scene.name)
	if _session != null:
		out.append("state %s" % Session.State.keys()[_session.state])
		if _session.goal > 0:
			out.append("progress %d/%d" % [_session.progress, _session.goal])
		out.append("score %d" % _session.score)
		if _session.time_limit > 0.0:
			out.append("time %.1f" % _session.time_left)
	return out
