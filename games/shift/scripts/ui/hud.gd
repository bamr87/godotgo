class_name HUD
extends CanvasLayer
## Shift's heads-up display: which level, how many moves, how many crates are
## home, the best solve on record, and what the round is doing.
##
## Pure presentation. The counters arrive as [code]Game[/code] signals; the level
## name and the best score come from [Level], because they outlive a round and so
## are not the session's business.

@onready var _title_label: Label = %TitleLabel
@onready var _level_label: Label = %LevelLabel
@onready var _moves_label: Label = %MovesLabel
@onready var _crates_label: Label = %CratesLabel
@onready var _best_label: Label = %BestLabel
@onready var _message_label: Label = %MessageLabel


func _ready() -> void:
	Game.progress_changed.connect(_on_progress_changed)
	Game.moves_changed.connect(_on_moves_changed)
	Game.state_changed.connect(_on_state_changed)
	_on_progress_changed(Game.progress, Game.goal)
	_on_moves_changed(Game.moves)
	_on_state_changed(Game.state)


func set_title(title: String) -> void:
	_title_label.text = title


## Names the level being played, as "Level 2/4 - Twin Crates".
func set_level(number: int, total: int, level_name: String) -> void:
	_level_label.text = "Level %d/%d - %s" % [number, total, level_name]


## Shows the stored best for this level. 0 means it has never been solved.
func set_best(best: int) -> void:
	_best_label.text = "Best %s" % ("-" if best <= 0 else "%d moves" % best)


func title_text() -> String:
	return _title_label.text


func level_text() -> String:
	return _level_label.text


func moves_text() -> String:
	return _moves_label.text


func crates_text() -> String:
	return _crates_label.text


func best_text() -> String:
	return _best_label.text


func message_text() -> String:
	return _message_label.text


## Status line for a [enum Session.State] value. Shift never loses, but the
## branch is kept so a future hazard level does not need a HUD change.
static func message_for(state: Session.State) -> String:
	match state:
		Session.State.PLAYING:
			return "Arrows or WASD to move. U undo, R restart."
		Session.State.WON:
			return "Solved! N for the next level, R to replay."
		Session.State.LOST:
			return "Stuck. Press R to retry."
	return ""


func _on_progress_changed(progress: int, goal: int) -> void:
	_crates_label.text = "Crates %d / %d" % [progress, goal]


func _on_moves_changed(moves: int) -> void:
	_moves_label.text = "Moves %d" % moves


func _on_state_changed(state: Session.State) -> void:
	_message_label.text = message_for(state)
