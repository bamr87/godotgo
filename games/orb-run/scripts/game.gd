extends Session
## Orb Run's session, registered in project.godot as the autoload [code]Game[/code].
##
## The framework's [Session] already owns the round state machine, the countdown
## and the objective counter. Orb Run only adds what is specific to it: an orb
## is one unit of objective progress and is also worth points.

## Score awarded for each orb.
const POINTS_PER_ORB := 100
## Bonus per whole second left on the clock when the exit is reached.
const POINTS_PER_SECOND_LEFT := 5


## Records one orb. Returns false when no round is in progress.
func collect_orb() -> bool:
	if not advance():
		return false
	add_score(POINTS_PER_ORB)
	return true


## Ends the round as a win, adding the time bonus first.
func reach_exit() -> bool:
	if not is_playing():
		return false
	add_score(int(time_left) * POINTS_PER_SECOND_LEFT)
	return win()
