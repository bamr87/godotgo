extends Session
## Shift's session, registered in project.godot as the autoload [code]Game[/code].
##
## The framework's [Session] already owns the state machine, the score and the
## objective counter. Shift adds two things to that vocabulary: a move counter,
## because moves are the score a puzzle is judged by, and crates-on-targets as
## objective progress, which unlike Leap's coins can go *down* again when a crate
## is pushed back off. There is no countdown: the round is started with a limit
## of zero, which is exactly the no-timer path through [Session].

## Emitted after every change to [member moves], including an undo.
signal moves_changed(moves: int)

## Why a lost round ended: the board can no longer be solved.
const REASON_STUCK := "stuck"

## Awarded when a crate is seated on a target, and taken back when one leaves.
const POINTS_PER_CRATE := 100
## Solving the level at zero moves is worth this much on top.
const EFFICIENCY_BONUS := 500
## ...and each move spent eats into it, down to nothing.
const POINTS_LOST_PER_MOVE := 10

## Moves made this round, matching the puzzle's own history depth.
var moves := 0


## Starts a puzzle. [param goal_value] is the crate count; [param limit] stays at
## zero for every shipped level, so nothing in this game watches a clock.
func start(goal_value: int = 0, limit: float = 0.0) -> void:
	moves = 0
	super(goal_value, limit)
	moves_changed.emit(moves)


## Clears the move counter along with the rest of the round. Without this the
## count would survive back into [constant Session.State.READY], and a HUD built
## before the next [method start] would open showing the last round's total.
func reset() -> void:
	moves = 0
	super()
	moves_changed.emit(moves)


## Counts one move. Returns false when no round is running, which is what stops
## a solved board from accepting further input.
func record_move() -> bool:
	if not is_playing():
		return false
	moves += 1
	moves_changed.emit(moves)
	return true


## Gives a move back after an undo. Undo is meant to be free, so the counter
## returns to exactly where it was before the move it erased.
func take_back_move() -> bool:
	if not is_playing() or moves <= 0:
		return false
	moves -= 1
	moves_changed.emit(moves)
	return true


## Records how many crates a freshly loaded board already has on targets,
## without paying for them or winning the round.
##
## A level may be authored with a crate already home, and the player did not put
## it there. Scoring the baseline would hand out points before the first
## keypress, and a level authored fully solved would win itself during loading.
func seed_crates_placed(placed: int) -> bool:
	if not is_playing():
		return false
	var delta := placed - progress
	if delta != 0:
		advance(delta)
	return true


## Syncs objective progress with the board's crate tally, scoring the difference
## and winning the round once every crate is home. Returns false unless playing.
func set_crates_placed(placed: int) -> bool:
	if not is_playing():
		return false
	var delta := placed - progress
	if delta != 0:
		advance(delta)
		add_score(delta * POINTS_PER_CRATE)
	if objective_complete():
		add_score(efficiency_bonus())
		win()
	return true


## The tidiness bonus: full value for a flawless solve, nothing once the solution
## has taken [constant EFFICIENCY_BONUS] / [constant POINTS_LOST_PER_MOVE] moves.
func efficiency_bonus() -> int:
	return maxi(EFFICIENCY_BONUS - moves * POINTS_LOST_PER_MOVE, 0)
