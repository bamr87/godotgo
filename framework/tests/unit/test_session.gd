extends GodotGoTest
## The round lifecycle every game builds on.

var _session: Session


func before_each() -> void:
	# Not added to the tree, so _process does not tick it and time is explicit.
	_session = Session.new()


func after_each() -> void:
	if is_instance_valid(_session) and _session.get_parent() == null:
		_session.free()


func test_starts_in_ready_with_nothing_counted() -> void:
	assert_eq(_session.state, Session.State.READY)
	assert_eq(_session.score, 0)
	assert_eq(_session.goal, 0)
	assert_false(_session.is_playing())
	assert_false(_session.is_over())


func test_start_announces_the_round() -> void:
	var states := record(_session.state_changed)
	var scores := record(_session.score_changed)
	var progress := record(_session.progress_changed)
	var times := record(_session.time_changed)
	_session.start(5, 90.0)
	assert_true(_session.is_playing())
	assert_eq(states.size(), 1)
	assert_eq(states[0][0], Session.State.PLAYING)
	assert_eq(scores[0][0], 0)
	assert_eq(progress[0][0], 0)
	assert_eq(progress[0][1], 5)
	assert_almost_eq(times[0][0], 90.0)


func test_advance_counts_and_announces_the_objective_once() -> void:
	_session.start(2)
	var done := record(_session.objective_reached)
	assert_true(_session.advance())
	assert_false(_session.objective_complete())
	assert_true(_session.advance())
	assert_true(_session.objective_complete())
	assert_true(_session.advance(), "over-collecting is still allowed")
	assert_eq(_session.progress, 3)
	assert_eq(done.size(), 1, "objective_reached is one-shot")


func test_goal_of_zero_never_completes_the_objective() -> void:
	_session.start(0)
	var done := record(_session.objective_reached)
	_session.advance(10)
	assert_false(_session.objective_complete())
	assert_eq(done.size(), 0)


func test_score_accumulates_only_while_playing() -> void:
	assert_false(_session.add_score(10), "no round in progress")
	_session.start(1)
	assert_true(_session.add_score(30))
	assert_true(_session.add_score(-5))
	assert_eq(_session.score, 25)


func test_countdown_ticks_and_loses_at_zero() -> void:
	_session.start(1, 1.0)
	var lost := record(_session.lost)
	_session.tick(0.4)
	assert_almost_eq(_session.time_left, 0.6)
	assert_true(_session.is_playing())
	_session.tick(0.7)
	assert_almost_eq(_session.time_left, 0.0)
	assert_eq(_session.state, Session.State.LOST)
	assert_eq(lost.size(), 1)
	assert_eq(lost[0][0], Session.REASON_TIME)


func test_time_changed_is_throttled_to_tenths() -> void:
	_session.start(1, 10.0)
	var times := record(_session.time_changed)
	_session.tick(0.01)
	assert_eq(times.size(), 1, "10.0 -> 9.99 crosses into the 9.9 tenth")
	_session.tick(0.01)
	assert_eq(times.size(), 1, "9.99 -> 9.98 stays in the same tenth")
	_session.tick(0.1)
	assert_eq(times.size(), 2)


func test_elapsed_accumulates_without_a_time_limit() -> void:
	_session.start(1, 0.0)
	_session.tick(0.5)
	_session.tick(0.25)
	assert_almost_eq(_session.elapsed, 0.75)
	assert_true(_session.is_playing(), "no limit means no timeout")


func test_pause_stops_the_clock_and_resume_restarts_it() -> void:
	_session.start(1, 10.0)
	assert_true(_session.pause())
	_session.tick(5.0)
	assert_almost_eq(_session.time_left, 10.0, 0.001, "paused rounds do not lose time")
	assert_false(_session.pause(), "already paused")
	assert_true(_session.resume())
	_session.tick(1.0)
	assert_almost_eq(_session.time_left, 9.0)


func test_win_is_terminal_and_reports_a_summary() -> void:
	_session.start(2, 10.0)
	_session.advance(2)
	_session.add_score(40)
	var results := record(_session.won)
	assert_true(_session.win())
	assert_eq(_session.state, Session.State.WON)
	assert_true(_session.is_over())
	assert_eq(results.size(), 1)
	var summary: Dictionary = results[0][0]
	assert_eq(summary["score"], 40)
	assert_eq(summary["progress"], 2)
	assert_eq(summary["goal"], 2)
	assert_false(_session.win(), "winning twice is ignored")
	assert_false(_session.lose(), "losing after a win is ignored")
	assert_false(_session.advance(), "the round is over")


func test_lose_is_terminal() -> void:
	_session.start(1)
	assert_true(_session.lose(Session.REASON_DEATH))
	assert_eq(_session.state, Session.State.LOST)
	assert_false(_session.win())


func test_reset_clears_every_counter() -> void:
	_session.start(3, 20.0)
	_session.advance(2)
	_session.add_score(10)
	_session.reset()
	assert_eq(_session.state, Session.State.READY)
	assert_eq(_session.score, 0)
	assert_eq(_session.progress, 0)
	assert_eq(_session.goal, 0)
	assert_almost_eq(_session.time_left, 0.0)


func test_state_changed_is_silent_for_a_same_state_assignment() -> void:
	_session.start(1)
	var states := record(_session.state_changed)
	_session.start(2)
	assert_eq(states.size(), 0, "PLAYING -> PLAYING emits nothing")
	assert_eq(_session.goal, 2)


func test_process_drives_the_clock_when_the_session_is_in_the_tree() -> void:
	var live := Session.new()
	add_node(live)
	live.start(1, 60.0)
	await physics_frames(3)
	assert_true(live.time_left < 60.0, "time_left should fall while frames run")
	assert_true(live.time_left > 59.0)
	await free_node(live)
