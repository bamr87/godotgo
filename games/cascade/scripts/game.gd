extends Session
## Cascade's session, registered in project.godot as the autoload
## [code]Game[/code].
##
## The framework's [Session] already owns the state machine, the score and the
## objective counter. Cascade adds the vocabulary of a collapse puzzle: a pop
## count, the biggest single group of the round, and the rule that decides how a
## round ends.
##
## The objective counter is used here as a [i]threshold[/i] rather than as an
## ending. Reaching it does not win the round, because a board is still worth
## playing after the target is met -- there may be a perfect clear in it. The
## round ends when the board runs out of legal pops, and the counter is what says
## whether that ending was a win or a loss. [signal Session.objective_reached]
## still fires exactly once, as the target is crossed, and the HUD uses it to say
## so; nothing else listens.

## Emitted after every change to [member pops], including the reset at the start
## of a round.
signal pops_changed(pops: int)
## Emitted for each accepted pop, with the group's size and what it paid.
signal popped(count: int, points: int)

## Why a lost round ended: the board jammed with the target still short.
const REASON_STUCK := "stuck"
## Paid on top of everything else for clearing the board down to nothing.
const PERFECT_BONUS := 1000
## A won board that jams with at most this many tiles left earns a near-clear
## bonus; more than this and it earns nothing extra.
const NEAR_CLEAR_MAX := 5
## Paid per tile of headroom under [constant NEAR_CLEAR_MAX]: one stranded tile
## pays the most, [constant NEAR_CLEAR_MAX] stranded tiles pay one step.
const NEAR_CLEAR_STEP := 100

## Groups popped this round.
var pops := 0
## The largest single group popped this round, in tiles.
var best_pop := 0


## Starts a board. [param goal_value] is the tile count that has to be cleared to
## win; [param limit] stays at zero for every shipped level, so nothing in this
## game watches a clock.
func start(goal_value: int = 0, limit: float = 0.0) -> void:
	pops = 0
	best_pop = 0
	super(goal_value, limit)
	pops_changed.emit(pops)


## Clears the pop counters along with the rest of the round. Without this they
## would survive back into [constant Session.State.READY], and a HUD built before
## the next [method start] would open showing the last board's totals.
func reset() -> void:
	pops = 0
	best_pop = 0
	super()
	pops_changed.emit(pops)


## What a group of [param count] tiles pays: [code]count * (count - 1)[/code].
##
## Superlinear on purpose. Popping a group of six in one go is worth 30 while
## popping it as three pairs is worth 6, so the game is about growing a group and
## choosing when to spend it, not about clicking quickly. Groups under
## [constant Board.MIN_GROUP] are worth nothing because they cannot be popped.
static func score_for(count: int) -> int:
	if count < Board.MIN_GROUP:
		return 0
	return count * (count - 1)


## Records a group the board has already cleared, paying for it and counting the
## tiles towards the target. Returns the points awarded, or 0 when the round is
## not running or the group was too small to be legal.
func record_pop(count: int) -> int:
	if not is_playing() or count < Board.MIN_GROUP:
		return 0
	var points := score_for(count)
	pops += 1
	best_pop = maxi(best_pop, count)
	advance(count)
	add_score(points)
	pops_changed.emit(pops)
	popped.emit(count, points)
	return points


## Ends the round now that the board can take no more pops. [param cleared_all]
## is true when nothing is left on it.
##
## A board that jams short of the target is a loss; one that reaches the target
## is a win whether or not a tile is left standing. The perfect-clear bonus is
## paid before the round closes, because [method Session.add_score] is refused
## once the state leaves [constant Session.State.PLAYING].
##
## [param leftover] is the tile count stranded on a board that did not clear. A
## winning board with between one and [constant NEAR_CLEAR_MAX] left earns
## [method near_clear_bonus], so the last few tiles still matter. A lost board
## earns nothing for it.
func finish_board(cleared_all: bool, leftover: int = 0) -> bool:
	if not is_playing():
		return false
	if cleared_all:
		add_score(PERFECT_BONUS)
	elif objective_complete():
		add_score(near_clear_bonus(leftover))
	if objective_complete():
		return win()
	return lose(REASON_STUCK)


## What stranding [param leftover] tiles pays on a won board:
## [code](NEAR_CLEAR_MAX + 1 - leftover) * NEAR_CLEAR_STEP[/code], or 0 outside
## 1..[constant NEAR_CLEAR_MAX]. Zero leftover is the perfect clear, which has its
## own bonus.
static func near_clear_bonus(leftover: int) -> int:
	if leftover < 1 or leftover > NEAR_CLEAR_MAX:
		return 0
	return (NEAR_CLEAR_MAX + 1 - leftover) * NEAR_CLEAR_STEP
