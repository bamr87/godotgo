extends GodotGoTest
## Swarm's round rules: the wave ladder, kill scoring and the hull. Every rule
## lives in the session, so none of this needs a scene.


func before_each() -> void:
	Game.reset()


func after_each() -> void:
	Game.reset()


func test_start_clears_every_swarm_counter() -> void:
	Game.start(3, 0.0)
	assert_true(Game.is_playing())
	assert_eq(Game.goal, 3)
	assert_eq(Game.wave, 0)
	assert_eq(Game.kills, 0)
	assert_eq(Game.enemies_left, 0)
	assert_eq(Game.hull, Game.MAX_HULL)


func test_reset_clears_them_too() -> void:
	Game.start(3, 0.0)
	Game.start_wave(2)
	Game.register_kill(40)
	Game.take_damage()
	Game.reset()
	assert_eq(Game.state, Session.State.READY)
	assert_eq(Game.wave, 0)
	assert_eq(Game.kills, 0)
	assert_eq(Game.enemies_left, 0)
	assert_eq(Game.hull, Game.MAX_HULL)


func test_start_wave_counts_up_and_announces_itself() -> void:
	Game.start(3, 0.0)
	var starts := record(Game.wave_started)
	assert_true(Game.start_wave(4))
	assert_eq(Game.wave, 1)
	assert_eq(Game.enemies_left, 4)
	assert_eq(starts.size(), 1)
	assert_eq(starts[0][0], 1)
	assert_eq(starts[0][1], 4)


func test_start_wave_refuses_outside_a_round_or_when_empty() -> void:
	assert_false(Game.start_wave(3), "no round is running")
	Game.start(3, 0.0)
	assert_false(Game.start_wave(0), "an empty wave could never clear itself")
	assert_eq(Game.wave, 0)


func test_a_kill_scores_and_counts_down_the_wave() -> void:
	Game.start(3, 0.0)
	Game.start_wave(2)
	var kills := record(Game.kills_changed)
	assert_true(Game.register_kill(25))
	assert_eq(Game.kills, 1)
	assert_eq(Game.score, 25)
	assert_eq(Game.enemies_left, 1)
	assert_eq(kills.size(), 1)
	assert_eq(kills[0][0], 1)


func test_the_last_kill_clears_the_wave_and_advances_progress() -> void:
	Game.start(3, 0.0)
	Game.start_wave(2)
	var cleared := record(Game.wave_cleared)
	Game.register_kill(25)
	assert_eq(Game.progress, 0, "a wave is not survived until it is empty")
	assert_eq(cleared.size(), 0)
	Game.register_kill(25)
	assert_eq(Game.enemies_left, 0)
	assert_eq(Game.progress, 1)
	assert_eq(cleared.size(), 1)
	assert_eq(cleared[0][0], 1)


func test_the_wave_bonus_scales_with_the_wave_number() -> void:
	Game.start(5, 0.0)
	Game.start_wave(1)
	Game.register_kill(0)
	assert_eq(Game.score, Game.POINTS_PER_WAVE)
	Game.start_wave(1)
	Game.register_kill(0)
	assert_eq(Game.score, Game.POINTS_PER_WAVE * 3, "wave 2 pays twice what wave 1 paid")


func test_wave_in_progress_tracks_the_live_wave() -> void:
	Game.start(3, 0.0)
	assert_false(Game.wave_in_progress())
	Game.start_wave(1)
	assert_true(Game.wave_in_progress())
	Game.register_kill(5)
	assert_false(Game.wave_in_progress())


func test_surviving_every_wave_wins_the_round() -> void:
	Game.start(2, 0.0)
	var won := record(Game.won)
	var announced := record(Game.objective_reached)
	for wave in 2:
		Game.start_wave(1)
		Game.register_kill(10)
	assert_eq(Game.progress, 2)
	assert_eq(Game.state, Session.State.WON)
	assert_eq(won.size(), 1)
	assert_eq(announced.size(), 1)


func test_the_final_wave_clear_reports_a_finished_round() -> void:
	Game.start(1, 0.0)
	var playing_at_clear := [true]
	var watcher := func(_wave: int) -> void: playing_at_clear[0] = Game.is_playing()
	Game.wave_cleared.connect(watcher)
	Game.start_wave(1)
	Game.register_kill(10)
	Game.wave_cleared.disconnect(watcher)
	assert_false(playing_at_clear[0], "listeners must not queue a wave after the win")


func test_damage_spends_hull_and_reports_it() -> void:
	Game.start(3, 0.0)
	var hulls := record(Game.hull_changed)
	assert_true(Game.take_damage())
	assert_eq(Game.hull, Game.MAX_HULL - 1)
	assert_eq(hulls.size(), 1)
	assert_eq(hulls[0][0], Game.MAX_HULL - 1)
	assert_eq(hulls[0][1], Game.MAX_HULL)
	assert_false(Game.take_damage(0), "a zero-point hit is not a hit")


func test_running_out_of_hull_loses_the_round_by_death() -> void:
	Game.start(3, 0.0)
	var lost := record(Game.lost)
	for i in Game.MAX_HULL - 1:
		assert_true(Game.take_damage(), "hit %d should be survivable" % [i + 1])
	assert_false(Game.take_damage(), "the last hull point is fatal")
	assert_eq(Game.hull, 0)
	assert_eq(Game.state, Session.State.LOST)
	assert_eq(lost.size(), 1)
	assert_eq(lost[0][0], Session.REASON_DEATH)


func test_nothing_moves_once_the_round_is_over() -> void:
	Game.start(3, 0.0)
	Game.start_wave(2)
	Game.take_damage(Game.MAX_HULL)
	assert_eq(Game.state, Session.State.LOST)
	assert_false(Game.register_kill(50))
	assert_false(Game.start_wave(3))
	assert_false(Game.take_damage())
	assert_eq(Game.score, 0)
	assert_eq(Game.kills, 0)
