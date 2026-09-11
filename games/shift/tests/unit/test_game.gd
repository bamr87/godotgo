extends GodotGoTest
## Shift's session vocabulary on top of the framework's [Session]: the move
## counter, crates as reversible objective progress, and the no-countdown round.


func before_each() -> void:
	Game.reset()


func after_each() -> void:
	Game.reset()


func test_a_round_starts_with_no_moves_and_no_clock() -> void:
	Game.start(3, 0.0)
	assert_true(Game.is_playing())
	assert_eq(Game.moves, 0)
	assert_eq(Game.goal, 3)
	assert_eq(Game.time_limit, 0.0, "a puzzle is judged on moves, not seconds")


func test_the_clock_never_runs_out_without_a_limit() -> void:
	var lost := record(Game.lost)
	Game.start(2, 0.0)
	for i in 10:
		Game.tick(60.0)
	assert_true(Game.is_playing(), "ten minutes later the round is still open")
	assert_eq(lost.size(), 0)
	assert_true(Game.elapsed > 0.0, "elapsed still accumulates, it just does not matter")


func test_record_move_counts_and_announces() -> void:
	Game.start(1, 0.0)
	var counts := record(Game.moves_changed)
	assert_true(Game.record_move())
	assert_true(Game.record_move())
	assert_eq(Game.moves, 2)
	assert_eq(counts.size(), 2)
	assert_eq(counts[1][0], 2)


func test_moves_are_refused_when_no_round_is_running() -> void:
	assert_false(Game.record_move(), "READY is not playing")
	assert_false(Game.take_back_move())
	Game.start(1, 0.0)
	Game.record_move()
	Game.win()
	assert_false(Game.record_move(), "a solved board takes no more moves")
	assert_eq(Game.moves, 1)


func test_take_back_move_gives_the_move_back() -> void:
	Game.start(1, 0.0)
	Game.record_move()
	Game.record_move()
	assert_true(Game.take_back_move())
	assert_eq(Game.moves, 1, "undo is free")


func test_take_back_move_floors_at_zero() -> void:
	Game.start(1, 0.0)
	assert_false(Game.take_back_move(), "nothing to give back")
	assert_eq(Game.moves, 0)


func test_start_clears_the_move_counter() -> void:
	Game.start(1, 0.0)
	Game.record_move()
	Game.start(1, 0.0)
	assert_eq(Game.moves, 0, "restarting a level starts the count again")


func test_crates_placed_drives_objective_progress() -> void:
	Game.start(3, 0.0)
	assert_true(Game.set_crates_placed(2))
	assert_eq(Game.progress, 2)
	assert_eq(Game.score, 2 * Game.POINTS_PER_CRATE)
	assert_false(Game.objective_complete())


func test_a_crate_pushed_off_a_target_takes_its_progress_back() -> void:
	Game.start(3, 0.0)
	Game.set_crates_placed(2)
	assert_true(Game.set_crates_placed(1), "unlike coins, this counter goes both ways")
	assert_eq(Game.progress, 1)
	assert_eq(Game.score, Game.POINTS_PER_CRATE)


func test_the_last_crate_wins_the_round() -> void:
	var won := record(Game.won)
	Game.start(2, 0.0)
	Game.set_crates_placed(1)
	assert_true(Game.is_playing())
	Game.set_crates_placed(2)
	assert_eq(Game.state, Session.State.WON)
	assert_eq(won.size(), 1)
	assert_true(Game.objective_complete())


func test_crates_placed_is_refused_once_the_round_is_over() -> void:
	Game.start(1, 0.0)
	Game.set_crates_placed(1)
	assert_false(Game.set_crates_placed(0), "a won round cannot be un-won")
	assert_eq(Game.progress, 1)


func test_a_tidy_solve_scores_more_than_a_long_one() -> void:
	Game.start(1, 0.0)
	Game.set_crates_placed(1)
	var tidy := Game.score
	Game.reset()
	Game.start(1, 0.0)
	for i in 12:
		Game.record_move()
	Game.set_crates_placed(1)
	assert_true(Game.score < tidy, "%d moves cost points" % 12)
	assert_eq(tidy - Game.score, 12 * Game.POINTS_LOST_PER_MOVE)


func test_the_efficiency_bonus_bottoms_out_rather_than_going_negative() -> void:
	Game.start(1, 0.0)
	assert_eq(Game.efficiency_bonus(), Game.EFFICIENCY_BONUS)
	for i in 500:
		Game.record_move()
	assert_eq(Game.efficiency_bonus(), 0, "a very long solve is worth nothing, never less")


func test_the_autoload_is_a_session() -> void:
	assert_is(Game, Session)
	assert_eq(ProjectSettings.get_setting("autoload/Game"), "*res://scripts/game.gd")
