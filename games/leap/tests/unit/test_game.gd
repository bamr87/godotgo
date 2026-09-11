extends GodotGoTest
## Leap's session rules: coins are optional score, lives are the failure budget.


func before_each() -> void:
	Game.reset()


func after_each() -> void:
	Game.reset()


func test_a_fresh_round_has_a_full_life_budget() -> void:
	Game.start(5, 60.0)
	assert_eq(Game.deaths, 0)
	assert_eq(Game.lives_left(), Game.MAX_DEATHS)
	assert_true(Game.is_playing())


func test_coins_score_and_advance_progress() -> void:
	Game.start(2, 0.0)
	assert_true(Game.collect_coin())
	assert_eq(Game.progress, 1)
	assert_eq(Game.score, Game.POINTS_PER_COIN)
	assert_true(Game.collect_coin())
	assert_true(Game.objective_complete())


func test_coins_are_refused_once_the_round_is_over() -> void:
	Game.start(1, 0.0)
	Game.lose(Session.REASON_DEATH)
	assert_false(Game.collect_coin())
	assert_eq(Game.score, 0)


func test_each_death_spends_a_life_and_announces_the_remainder() -> void:
	Game.start(1, 0.0)
	var losses := record(Game.life_lost)
	assert_true(Game.lose_life(), "still alive after the first death")
	assert_eq(Game.lives_left(), Game.MAX_DEATHS - 1)
	assert_eq(losses.size(), 1)
	assert_eq(losses[0][0], Game.MAX_DEATHS - 1)


func test_running_out_of_lives_loses_the_round() -> void:
	Game.start(1, 0.0)
	var lost := record(Game.lost)
	for i in Game.MAX_DEATHS - 1:
		assert_true(Game.lose_life())
	assert_false(Game.lose_life(), "the last life ends the round")
	assert_eq(Game.state, Session.State.LOST)
	assert_eq(lost[0][0], Session.REASON_DEATH)
	assert_eq(Game.lives_left(), 0)


func test_losing_a_life_outside_a_round_does_nothing() -> void:
	assert_false(Game.lose_life())
	assert_eq(Game.deaths, 0)


func test_starting_again_restores_the_life_budget() -> void:
	Game.start(1, 0.0)
	Game.lose_life()
	Game.start(1, 0.0)
	assert_eq(Game.deaths, 0)
	assert_eq(Game.lives_left(), Game.MAX_DEATHS)


func test_reaching_the_goal_wins_with_a_time_bonus() -> void:
	Game.start(2, 10.0)
	assert_true(Game.reach_goal())
	assert_eq(Game.state, Session.State.WON)
	assert_eq(Game.score, 10 * Game.POINTS_PER_SECOND_LEFT, "no coins, but 10 seconds left")


func test_finishing_with_every_coin_pays_the_completion_bonus() -> void:
	Game.start(2, 0.0)
	Game.collect_coin()
	Game.collect_coin()
	Game.reach_goal()
	var expected := 2 * Game.POINTS_PER_COIN + Game.ALL_COINS_BONUS
	assert_eq(Game.score, expected)


func test_the_goal_is_reachable_without_collecting_anything() -> void:
	Game.start(5, 0.0)
	assert_false(Game.objective_complete())
	assert_true(Game.reach_goal(), "coins gate the bonus, not the exit")
	assert_eq(Game.state, Session.State.WON)


func test_the_goal_cannot_be_reached_twice() -> void:
	Game.start(1, 0.0)
	assert_true(Game.reach_goal())
	assert_false(Game.reach_goal())
