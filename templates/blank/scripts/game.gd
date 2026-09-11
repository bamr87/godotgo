extends Session
## __GAME_TITLE__'s session, registered in project.godot as the autoload
## [code]Game[/code].
##
## The framework's [Session] already owns the state machine, score, objective
## counter and countdown. Add only the rules that are specific to this game.

## Score awarded for each objective step.
const POINTS_PER_STEP := 10


## Records one step of progress. Returns false when no round is in progress.
func take_step() -> bool:
	if not advance():
		return false
	add_score(POINTS_PER_STEP)
	return true
