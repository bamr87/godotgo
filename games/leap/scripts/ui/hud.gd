class_name HUD
extends CanvasLayer
## Leap's heads-up display: coins, score, lives, countdown and a status line.
## Pure presentation, driven entirely by the [code]Game[/code] session's signals.

@onready var _title_label: Label = %TitleLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _lives_label: Label = %LivesLabel
@onready var _time_label: Label = %TimeLabel
@onready var _message_label: Label = %MessageLabel


func _ready() -> void:
	Game.progress_changed.connect(_on_progress_changed)
	Game.score_changed.connect(_on_score_changed)
	Game.time_changed.connect(_on_time_changed)
	Game.state_changed.connect(_on_state_changed)
	Game.life_lost.connect(_on_life_lost)
	_on_progress_changed(Game.progress, Game.goal)
	_on_score_changed(Game.score)
	_on_time_changed(Game.time_left)
	_on_state_changed(Game.state)
	_on_life_lost(Game.lives_left())


func set_title(title: String) -> void:
	_title_label.text = title


func title_text() -> String:
	return _title_label.text


func coins_text() -> String:
	return _coins_label.text


func score_text() -> String:
	return _score_label.text


func lives_text() -> String:
	return _lives_label.text


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
			return "Reach the flag. Coins are a bonus."
		Session.State.WON:
			return "Level clear! Press R to play again."
		Session.State.LOST:
			return "Out of lives. Press R to retry."
	return ""


func _on_progress_changed(progress: int, goal: int) -> void:
	_coins_label.text = "Coins %d / %d" % [progress, goal]


func _on_score_changed(score: int) -> void:
	_score_label.text = "Score %d" % score


func _on_life_lost(remaining: int) -> void:
	_lives_label.text = "Lives " + ("*".repeat(remaining) if remaining > 0 else "none")


func _on_time_changed(time_left: float) -> void:
	_time_label.text = "Time " + format_time(time_left)


func _on_state_changed(state: Session.State) -> void:
	_message_label.text = message_for(state)
