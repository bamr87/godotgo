class_name HUD
extends CanvasLayer
## Swarm's heads-up display: wave, kills, score, hull and a status line.
##
## Pure presentation. Every label is a reaction to a [code]Game[/code] signal,
## so the HUD has no update loop and cannot drift out of step with the session.
## The two formatters are static because a test should be able to assert what
## the player reads without building a CanvasLayer.

@onready var _title_label: Label = %TitleLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _kills_label: Label = %KillsLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _hull_label: Label = %HullLabel
@onready var _message_label: Label = %MessageLabel


func _ready() -> void:
	Game.wave_started.connect(_on_wave_started)
	Game.progress_changed.connect(_on_progress_changed)
	Game.kills_changed.connect(_on_kills_changed)
	Game.score_changed.connect(_on_score_changed)
	Game.hull_changed.connect(_on_hull_changed)
	Game.state_changed.connect(_on_state_changed)
	_refresh_wave()
	_on_kills_changed(Game.kills)
	_on_score_changed(Game.score)
	_on_hull_changed(Game.hull, Game.MAX_HULL)
	_on_state_changed(Game.state)


func set_title(title: String) -> void:
	_title_label.text = title


func title_text() -> String:
	return _title_label.text


func wave_text() -> String:
	return _wave_label.text


func kills_text() -> String:
	return _kills_label.text


func score_text() -> String:
	return _score_label.text


func hull_text() -> String:
	return _hull_label.text


func message_text() -> String:
	return _message_label.text


## Hull drawn as pips, because a shooter's damage state has to be readable at a
## glance rather than counted.
static func format_hull(hull: int, max_hull: int) -> String:
	var left := clampi(hull, 0, max_hull)
	return "Hull " + "|".repeat(left) + ".".repeat(max_hull - left)


## Status line for a [enum Session.State] value.
static func message_for(state: Session.State) -> String:
	match state:
		Session.State.PLAYING:
			return "WASD to fly, aim and hold fire with the mouse."
		Session.State.WON:
			return "Arena held! Press R to play again."
		Session.State.LOST:
			return "Hull breached. Press R to retry."
	return ""


func _refresh_wave() -> void:
	_wave_label.text = "Wave %d / %d" % [maxi(Game.wave, 0), Game.goal]


func _on_wave_started(_wave: int, _enemy_count: int) -> void:
	_refresh_wave()


func _on_progress_changed(_progress: int, _goal: int) -> void:
	_refresh_wave()


func _on_kills_changed(kills: int) -> void:
	_kills_label.text = "Kills %d" % kills


func _on_score_changed(score: int) -> void:
	_score_label.text = "Score %d" % score


func _on_hull_changed(hull: int, max_hull: int) -> void:
	_hull_label.text = format_hull(hull, max_hull)


func _on_state_changed(state: Session.State) -> void:
	_message_label.text = message_for(state)
