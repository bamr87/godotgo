class_name HUD
extends CanvasLayer
## Cascade's heads-up display: which level, the score, how much of the target is
## gone, how the popping is going and the best run on record.
##
## Pure presentation. The counters arrive as [code]Game[/code] signals; the level
## name and the best score come from [Level], because they outlive a round and so
## are not the session's business.
##
## The one piece of state kept here is whether the target has been met, because
## [signal Session.objective_reached] fires once and then never again while the
## board is still worth playing. Holding the flag is what lets the status line
## change from "clear the target" to "go for the perfect clear" without the
## session having to invent a state for it.

var _target_met := false

@onready var _margin: MarginContainer = $Margin
@onready var _title_label: Label = %TitleLabel
@onready var _level_label: Label = %LevelLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _cleared_label: Label = %ClearedLabel
@onready var _pops_label: Label = %PopsLabel
@onready var _best_label: Label = %BestLabel
@onready var _message_label: Label = %MessageLabel


func _ready() -> void:
	Game.score_changed.connect(_on_score_changed)
	Game.progress_changed.connect(_on_progress_changed)
	Game.pops_changed.connect(_on_pops_changed)
	Game.objective_reached.connect(_on_objective_reached)
	Game.state_changed.connect(_on_state_changed)
	_on_score_changed(Game.score)
	_on_progress_changed(Game.progress, Game.goal)
	_on_pops_changed(Game.pops)
	_on_state_changed(Game.state)


func set_title(title: String) -> void:
	_title_label.text = title


## Names the level being played, as "Level 2/5 - Four Colours".
func set_level(number: int, total: int, level_name: String) -> void:
	_level_label.text = "Level %d/%d - %s" % [number, total, level_name]


## Shows the stored best for this level. [param has_record] is false until the
## level has been played to an ending, which a score of zero cannot express.
func set_best(score: int, biggest_pop: int, has_record: bool, perfect: bool) -> void:
	if not has_record:
		_best_label.text = "Best -"
		return
	var mark := " (perfect)" if perfect else ""
	_best_label.text = "Best %d, group %d%s" % [score, biggest_pop, mark]


## Width of the column the HUD occupies. The board is laid out clear of this, and
## the status line wraps inside it rather than running out across the tiles.
func panel_width() -> float:
	return _margin.size.x


func title_text() -> String:
	return _title_label.text


func level_text() -> String:
	return _level_label.text


func score_text() -> String:
	return _score_label.text


func cleared_text() -> String:
	return _cleared_label.text


func pops_text() -> String:
	return _pops_label.text


func best_text() -> String:
	return _best_label.text


func message_text() -> String:
	return _message_label.text


## True once this round has crossed its target. Reset by the next round's
## [signal Session.state_changed] into [constant Session.State.PLAYING].
func target_met() -> bool:
	return _target_met


## Status line for a [enum Session.State] value. [param met] only matters while
## playing, where it is the difference between chasing the target and playing on
## for a perfect clear.
static func message_for(state: Session.State, met: bool) -> String:
	match state:
		Session.State.PLAYING:
			if met:
				return "Target met. Play on for a perfect clear, or R to restart."
			return "Take a group of two or more: click it, or arrows then Space."
		Session.State.WON:
			return "Target cleared! N for the next level, R to replay."
		Session.State.LOST:
			return "Stuck below the target. Press R to retry."
	return ""


func _on_score_changed(score: int) -> void:
	_score_label.text = "Score %d" % score


func _on_progress_changed(progress: int, goal: int) -> void:
	_cleared_label.text = "Cleared %d / %d" % [progress, goal]
	if progress == 0 and _target_met:
		# A board just started, and the flag belongs to the one before it.
		# [method Session.start] emits this on every round, which matters most
		# when a level is restarted from inside [constant Session.State.PLAYING]:
		# the state never changes there, so state_changed never arrives at all.
		_target_met = false
		_refresh_message()


func _on_pops_changed(pops: int) -> void:
	_pops_label.text = "Pops %d - best group %d" % [pops, Game.best_pop]


func _on_objective_reached() -> void:
	_target_met = true
	_refresh_message()


func _on_state_changed(_state: Session.State) -> void:
	_refresh_message()


func _refresh_message() -> void:
	_message_label.text = message_for(Game.state, _target_met)
