extends GodotGoTest
## Cascade's round: what a pop is worth, what the target means, and which way a
## jammed board ends.
##
## The session owns all of it and touches no nodes, so every case here is a
## handful of calls with no scene in sight.


func before_each() -> void:
	Game.reset()


func after_each() -> void:
	Game.reset()


func test_a_big_group_beats_the_same_tiles_taken_a_pair_at_a_time() -> void:
	assert_eq(Game.score_for(2), 2)
	assert_eq(Game.score_for(6), 30)
	assert_true(Game.score_for(6) > 3 * Game.score_for(2), "which is the whole game")
	assert_eq(Game.score_for(1), 0, "a group too small to pop is worth nothing")
	assert_eq(Game.score_for(0), 0)


func test_a_pop_scores_counts_and_advances_the_target() -> void:
	Game.start(10, 0.0)
	assert_eq(Game.record_pop(4), Game.score_for(4))
	assert_eq(Game.score, 12)
	assert_eq(Game.progress, 4, "tiles cleared, not groups popped")
	assert_eq(Game.pops, 1)
	assert_eq(Game.best_pop, 4)


func test_each_pop_is_announced_with_what_it_paid() -> void:
	Game.start(20, 0.0)
	var events := record(Game.popped)
	Game.record_pop(4)
	assert_eq(events.size(), 1)
	assert_eq(events[0][0], 4)
	assert_eq(events[0][1], Game.score_for(4))


func test_the_biggest_group_of_the_round_is_the_one_kept() -> void:
	Game.start(20, 0.0)
	Game.record_pop(5)
	Game.record_pop(3)
	assert_eq(Game.best_pop, 5, "a later, smaller group does not replace it")
	assert_eq(Game.pops, 2)


func test_a_pop_outside_a_running_round_is_refused() -> void:
	assert_eq(Game.record_pop(4), 0, "before the board starts")
	assert_eq(Game.score, 0)
	Game.start(10, 0.0)
	Game.record_pop(10)
	Game.finish_board(false)
	assert_eq(Game.record_pop(4), 0, "and after it ends")
	assert_eq(Game.pops, 1)


func test_a_group_below_the_minimum_is_refused() -> void:
	Game.start(10, 0.0)
	assert_eq(Game.record_pop(1), 0)
	assert_eq(Game.pops, 0)
	assert_eq(Game.progress, 0)


func test_crossing_the_target_is_announced_once_and_the_board_plays_on() -> void:
	Game.start(6, 0.0)
	var reached := record(Game.objective_reached)
	Game.record_pop(4)
	assert_eq(reached.size(), 0)
	Game.record_pop(4)
	assert_eq(reached.size(), 1)
	assert_true(Game.objective_complete())
	assert_true(Game.is_playing(), "the target is a threshold, not an ending")
	Game.record_pop(3)
	assert_eq(reached.size(), 1, "and it is never announced twice")


func test_a_board_that_reaches_its_target_is_won() -> void:
	Game.start(6, 0.0)
	Game.record_pop(6)
	assert_true(Game.finish_board(false))
	assert_eq(Game.state, Session.State.WON)


func test_a_board_that_jams_short_of_the_target_is_lost() -> void:
	Game.start(20, 0.0)
	Game.record_pop(4)
	var reasons := record(Game.lost)
	assert_true(Game.finish_board(false))
	assert_eq(Game.state, Session.State.LOST)
	assert_eq(reasons[0][0], Game.REASON_STUCK)


func test_a_perfect_clear_is_paid_before_the_round_closes() -> void:
	Game.start(6, 0.0)
	Game.record_pop(6)
	var earned := Game.score
	Game.finish_board(true)
	assert_eq(Game.state, Session.State.WON)
	assert_eq(Game.score, earned + Game.PERFECT_BONUS, "add_score is refused once won")


func test_finishing_a_board_a_second_time_does_nothing() -> void:
	Game.start(6, 0.0)
	Game.record_pop(6)
	Game.finish_board(false)
	var settled_score := Game.score
	assert_false(Game.finish_board(true))
	assert_eq(Game.score, settled_score, "the bonus cannot be claimed afterwards")


func test_starting_a_board_clears_the_last_one_s_counters() -> void:
	Game.start(10, 0.0)
	Game.record_pop(5)
	var changes := record(Game.pops_changed)
	Game.start(10, 0.0)
	assert_eq(Game.pops, 0)
	assert_eq(Game.best_pop, 0)
	assert_eq(Game.score, 0)
	assert_eq(changes.size(), 1, "and the HUD is told")


func test_reset_clears_the_counters_and_says_so() -> void:
	Game.start(10, 0.0)
	Game.record_pop(5)
	var changes := record(Game.pops_changed)
	Game.reset()
	assert_eq(Game.pops, 0)
	assert_eq(Game.best_pop, 0)
	assert_eq(Game.state, Session.State.READY)
	assert_eq(changes.size(), 1)
	assert_eq(changes[0][0], 0)
