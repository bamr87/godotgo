class_name HUD
extends CanvasLayer
## Heads-up display driven entirely by the [code]Game[/code] session's signals.

@onready var _title_label: Label = %TitleLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _time_label: Label = %TimeLabel
@onready var _message_label: Label = %MessageLabel


func _ready() -> void:
	Game.progress_changed.connect(_on_progress_changed)
	Game.score_changed.connect(_on_score_changed)
	Game.time_changed.connect(_on_time_changed)
	Game.state_changed.connect(_on_state_changed)
	_on_progress_changed(Game.progress, Game.goal)
	_on_score_changed(Game.score)
	_on_time_changed(Game.time_left)
	_on_state_changed(Game.state)


func set_title(title: String) -> void:
	_title_label.text = title


func title_text() -> String:
	return _title_label.text


func progress_text() -> String:
	return _progress_label.text


func score_text() -> String:
	return _score_label.text


func time_text() -> String:
	return _time_label.text


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
			return "Press Space to advance."
		Session.State.WON:
			return "You win! Press R to play again."
		Session.State.LOST:
			return "Out of time. Press R to retry."
	return ""


func _on_progress_changed(progress: int, goal: int) -> void:
	_progress_label.text = "Progress %d / %d" % [progress, goal]


func _on_score_changed(score: int) -> void:
	_score_label.text = "Score %d" % score


func _on_time_changed(time_left: float) -> void:
	_time_label.text = "Time " + format_time(time_left)


func _on_state_changed(state: Session.State) -> void:
	_message_label.text = message_for(state)
