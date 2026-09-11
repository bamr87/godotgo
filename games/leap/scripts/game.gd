extends Session
## Leap's session, registered in project.godot as the autoload [code]Game[/code].
##
## Coins are objective progress but are not required to finish: reaching the
## flag wins whatever the tally. Deaths are the failure budget, which is what
## makes this round different from Orb Run's gated exit.

## Emitted when a life is spent, with the number remaining.
signal life_lost(remaining: int)

const POINTS_PER_COIN := 50
## Bonus per whole second left on the clock when the flag is reached.
const POINTS_PER_SECOND_LEFT := 10
## Bonus for finishing with every coin collected.
const ALL_COINS_BONUS := 250
## Deaths allowed before the round is lost.
const MAX_DEATHS := 3

var deaths := 0


func start(goal_value: int = 0, limit: float = 0.0) -> void:
	deaths = 0
	super(goal_value, limit)


## Clears the life budget along with the framework's counters, so a reset round
## does not inherit the previous round's deaths.
func reset() -> void:
	deaths = 0
	super()


func lives_left() -> int:
	return maxi(MAX_DEATHS - deaths, 0)


## Records one coin. Returns false when no round is in progress.
func collect_coin() -> bool:
	if not advance():
		return false
	add_score(POINTS_PER_COIN)
	return true


## Spends a life. Returns true while the player still has one left, false once
## the round has been lost.
func lose_life() -> bool:
	if not is_playing():
		return false
	deaths += 1
	life_lost.emit(lives_left())
	if lives_left() <= 0:
		lose(REASON_DEATH)
		return false
	return true


## Ends the round as a win, adding the time and completion bonuses first.
func reach_goal() -> bool:
	if not is_playing():
		return false
	add_score(int(time_left) * POINTS_PER_SECOND_LEFT)
	if objective_complete():
		add_score(ALL_COINS_BONUS)
	return win()
