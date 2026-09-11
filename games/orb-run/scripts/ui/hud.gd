class_name HUD
extends CanvasLayer
## Heads-up display bound to the [code]Game[/code] session's signals: orb tally,
## score, countdown and a status line. Pure presentation; it never mutates state.

@onready var _title_label: Label = %TitleLabel
@onready var _orbs_label: Label = %OrbsLabel
@onready var _time_label: Label = %TimeLabel
@onready var _message_label: Label = %MessageLabel


func _ready() -> void:
	Game.progress_changed.connect(_on_progress_changed)
	Game.time_changed.connect(_on_time_changed)
	Game.state_changed.connect(_on_state_changed)
	_on_progress_changed(Game.progress, Game.goal)
	_on_time_changed(Game.time_left)
	_on_state_changed(Game.state)


## Sets the level title shown in the corner.
func set_title(title: String) -> void:
	_title_label.text = title


## Current title text (for tests and tools).
func title_text() -> String:
	return _title_label.text


## Current orb tally text, e.g. "Orbs 2 / 5".
func orbs_text() -> String:
	return _orbs_label.text


## Current countdown text, e.g. "Time 01:29.5".
func time_text() -> String:
	return _time_label.text


## Current status line.
func message_text() -> String:
	return _message_label.text


## Formats seconds as mm:ss.t, clamped at zero.
static func format_time(seconds: float) -> String:
	var tenths := int(round(maxf(seconds, 0.0) * 10.0))
	@warning_ignore("integer_division")
	var minutes := tenths / 600
	@warning_ignore("integer_division")
	var whole_seconds := (tenths / 10) % 60
	return "%02d:%02d.%d" % [minutes, whole_seconds, tenths % 10]


## Status line for a [enum Session.State] value.
static func message_for(state: Session.State) -> String:
	match state:
		Session.State.PLAYING:
			return "Collect every orb, then reach the portal."
		Session.State.WON:
			return "You escaped! Press R to play again."
		Session.State.LOST:
			return "Time's up. Press R to retry."
	return ""


func _on_progress_changed(progress: int, goal: int) -> void:
	_orbs_label.text = "Orbs %d / %d" % [progress, goal]


func _on_time_changed(time_left: float) -> void:
	_time_label.text = "Time " + format_time(time_left)


func _on_state_changed(state: Session.State) -> void:
	_message_label.text = message_for(state)
