extends Session
## Swarm's session, registered in project.godot as the autoload [code]Game[/code].
##
## The round is a wave ladder: [member Session.progress] counts waves survived
## and [member Session.goal] is how many are needed, so the framework's
## objective machinery does the winning. Kills only pay score, which keeps
## "how well you played" separate from "did you finish" -- the opposite of Orb
## Run, where the collectible count gates the exit.
##
## The hull is the failure budget. It lives here rather than on [Ship] because
## losing is a rule, not a scene detail, and rules must stay testable with no
## nodes in the tree.

## Emitted by [method start_wave] once the wave's enemies are on their way in.
signal wave_started(wave: int, enemy_count: int)
## Emitted by [method register_kill] when the last enemy of a wave dies.
## Fired after the win check, so listeners can ask [method Session.is_playing]
## to tell "next wave please" from "that was the final wave".
signal wave_cleared(wave: int)
## Emitted after every hull change, including the full hull handed out by
## [method start], so a HUD can render itself from one connection.
signal hull_changed(hull: int, max_hull: int)
## Emitted by [method register_kill]. Separate from [signal Session.score_changed]
## because a wave-clear bonus moves the score without anything having died.
signal kills_changed(kills: int)

## Score for clearing a wave, multiplied by the wave number: later waves are
## worth more, so surviving beats farming the easy ones.
const POINTS_PER_WAVE := 100
## Hits the ship absorbs before the round is lost.
const MAX_HULL := 3

## Waves begun so far. 1 while the first wave is being fought.
var wave := 0
## Enemies destroyed this round, across every wave.
var kills := 0
## Remaining hull points; 0 ends the round with [constant Session.REASON_DEATH].
var hull := MAX_HULL
## Enemies of the current wave still alive. The wave clears when it hits zero.
var enemies_left := 0


## Begins a round. [param goal_value] is the number of waves to survive.
func start(goal_value: int = 0, limit: float = 0.0) -> void:
	wave = 0
	kills = 0
	hull = MAX_HULL
	enemies_left = 0
	super(goal_value, limit)
	hull_changed.emit(hull, MAX_HULL)
	kills_changed.emit(kills)


## Opens the next wave with [param enemy_count] enemies inbound. Returns false
## when no round is running or the wave would be empty, because an empty wave
## could never clear itself and would stall the ladder.
func start_wave(enemy_count: int) -> bool:
	if not is_playing() or enemy_count <= 0:
		return false
	wave += 1
	enemies_left = enemy_count
	wave_started.emit(wave, enemies_left)
	return true


## Banks one destroyed enemy worth [param points] and clears the wave when it
## was the last one standing. Returns false unless a round is running.
func register_kill(points: int) -> bool:
	if not is_playing():
		return false
	kills += 1
	kills_changed.emit(kills)
	add_score(points)
	if enemies_left > 0:
		enemies_left -= 1
		if enemies_left == 0:
			_clear_wave()
	return true


## Adds [param count] enemies to the wave being fought, for a caller that puts
## something on the field after the wave opened. Without this the arena could
## hold more enemies than the wave believes it has, and the wave would clear
## while some were still alive.
func reinforce_wave(count: int) -> bool:
	if not is_playing() or count <= 0:
		return false
	enemies_left += count
	return true


## Writes off the enemies of the wave in progress without clearing the wave or
## scoring it, for a caller that removes them rather than killing them.
##
## The counter is only ever decremented by a death, so an enemy taken off the
## field another way would otherwise be subtracted from the field and not from
## the count. The wave would then never reach zero, the ladder would never
## advance, and the round could be neither won nor lost.
func forget_wave() -> bool:
	if enemies_left == 0:
		return false
	enemies_left = 0
	return true


## Spends [param amount] hull points. Returns true while the ship survives,
## false once the hull is gone and the round has been lost.
func take_damage(amount: int = 1) -> bool:
	if not is_playing() or amount <= 0:
		return false
	hull = maxi(hull - amount, 0)
	hull_changed.emit(hull, MAX_HULL)
	if hull == 0:
		lose(REASON_DEATH)
		return false
	return true


## Clears Swarm's counters alongside the framework's, so a session that is
## reset between rounds (or between tests) really is a blank one.
func reset() -> void:
	wave = 0
	kills = 0
	hull = MAX_HULL
	enemies_left = 0
	super()


## True while a wave is being fought, i.e. enemies are still expected.
func wave_in_progress() -> bool:
	return is_playing() and enemies_left > 0


func _clear_wave() -> void:
	add_score(POINTS_PER_WAVE * wave)
	# advance() may announce the objective, and the win must land before
	# wave_cleared so listeners see a finished round rather than queueing
	# a wave that will never be fought.
	advance()
	if objective_complete():
		win()
	wave_cleared.emit(wave)
