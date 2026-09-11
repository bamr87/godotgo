class_name Session
extends Node
## The round lifecycle shared by every GodotGo game: a small state machine with
## a score, an objective counter and an optional countdown.
##
## A game adds a subclass as an autoload named [code]Game[/code]:
## [codeblock]
## # scripts/game.gd, registered in project.godot as Game="*res://scripts/game.gd"
## extends Session
## [/codeblock]
## Scenes call [method start], [method advance], [method add_score],
## [method win] and [method lose], and react to the signals. No rule here needs
## a node reference, so every rule stays unit-testable headlessly.

## Emitted when [member state] changes. Never emitted for a same-state assignment.
signal state_changed(state: State)
## Emitted after [method start] and every successful [method add_score].
signal score_changed(score: int)
## Emitted after [method start] and every successful [method advance].
signal progress_changed(progress: int, goal: int)
## Emitted after [method start] and whenever the countdown's tenths digit changes.
signal time_changed(time_left: float)
## Emitted exactly once per round, the moment [member progress] reaches [member goal].
signal objective_reached
## Emitted by [method win] with the round summary from [method summary].
signal won(result: Dictionary)
## Emitted by [method lose] with one of the REASON constants or a game-specific string.
signal lost(reason: String)

enum State { READY, PLAYING, PAUSED, WON, LOST }

## The countdown reached zero.
const REASON_TIME := "time"
## The player died.
const REASON_DEATH := "death"
## The player gave up or left the round.
const REASON_QUIT := "quit"

## Prefix for the framework's stdout lines; [code]tools/smoke.sh[/code] looks for it.
const LOG_PREFIX := "[godotgo]"

var state: State = State.READY
var score := 0
## Objective units completed so far (orbs collected, boxes placed, waves survived).
var progress := 0
## Objective units needed to finish. 0 means the round has no counted objective.
var goal := 0
## Seconds allowed for the round. 0 disables the countdown.
var time_limit := 0.0
var time_left := 0.0
## Seconds spent in [constant State.PLAYING] this round.
var elapsed := 0.0

var _emitted_tenths := -1
var _objective_announced := false


func _process(delta: float) -> void:
	tick(delta)


## Begins a round. [param goal_value] of 0 means no counted objective;
## [param limit] of 0 means no countdown.
func start(goal_value: int = 0, limit: float = 0.0) -> void:
	goal = maxi(goal_value, 0)
	time_limit = maxf(limit, 0.0)
	score = 0
	progress = 0
	elapsed = 0.0
	time_left = time_limit
	_emitted_tenths = -1
	_objective_announced = false
	_set_state(State.PLAYING)
	score_changed.emit(score)
	progress_changed.emit(progress, goal)
	_emit_time()
	print("%s session start: goal=%d time_limit=%.1f" % [LOG_PREFIX, goal, time_limit])


## Adds points. Returns false (and changes nothing) unless a round is running.
func add_score(points: int) -> bool:
	if state != State.PLAYING:
		return false
	score += points
	score_changed.emit(score)
	return true


## Advances the objective counter, emitting [signal objective_reached] the first
## time [member progress] reaches [member goal]. Returns false unless playing.
func advance(amount: int = 1) -> bool:
	if state != State.PLAYING:
		return false
	progress += amount
	progress_changed.emit(progress, goal)
	if not _objective_announced and objective_complete():
		_objective_announced = true
		objective_reached.emit()
	return true


## True once [member progress] has reached a non-zero [member goal].
func objective_complete() -> bool:
	return goal > 0 and progress >= goal


func is_playing() -> bool:
	return state == State.PLAYING


func is_over() -> bool:
	return state == State.WON or state == State.LOST


## Advances the clock. Called every frame by [method _process]; call it directly
## in tests to step time deterministically.
func tick(delta: float) -> void:
	if state != State.PLAYING:
		return
	elapsed += delta
	if time_limit <= 0.0:
		return
	time_left = maxf(time_left - delta, 0.0)
	_emit_time()
	if time_left <= 0.0:
		lose(REASON_TIME)


## Suspends the clock without ending the round.
func pause() -> bool:
	if state != State.PLAYING:
		return false
	_set_state(State.PAUSED)
	return true


func resume() -> bool:
	if state != State.PAUSED:
		return false
	_set_state(State.PLAYING)
	return true


## Ends the round as a win. Ignored unless playing.
func win() -> bool:
	if state != State.PLAYING:
		return false
	_set_state(State.WON)
	var result := summary()
	won.emit(result)
	print("%s session won: %s" % [LOG_PREFIX, result])
	return true


## Ends the round as a loss. Ignored unless playing.
func lose(reason: String = REASON_QUIT) -> bool:
	if state != State.PLAYING:
		return false
	_set_state(State.LOST)
	lost.emit(reason)
	print("%s session lost: %s" % [LOG_PREFIX, reason])
	return true


## A snapshot of the round, used by [signal won] and by save files.
func summary() -> Dictionary:
	return {
		"score": score,
		"progress": progress,
		"goal": goal,
		"elapsed": elapsed,
		"time_left": time_left,
		"state": state,
	}


## Returns to [constant State.READY] with every counter cleared.
func reset() -> void:
	score = 0
	progress = 0
	goal = 0
	time_limit = 0.0
	time_left = 0.0
	elapsed = 0.0
	_emitted_tenths = -1
	_objective_announced = false
	_set_state(State.READY)


func _emit_time() -> void:
	# The clock is only ever displayed to a tenth, so do not wake listeners more
	# often than the displayed value actually changes.
	var tenths := int(time_left * 10.0)
	if tenths == _emitted_tenths:
		return
	_emitted_tenths = tenths
	time_changed.emit(time_left)


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	state_changed.emit(state)
