extends GodotGoTest
## The entity FSM used by the arena shooter's enemies.

var _log: PackedStringArray = []
var _fsm: StateMachine


func before_each() -> void:
	_log = []
	_fsm = StateMachine.new()
	_fsm.add_state(&"idle", _idle_update, _enter_idle, _exit_idle)
	_fsm.add_state(&"chase", _chase_update, _enter_chase)


func _enter_idle() -> void:
	_log.append("enter:idle")


func _exit_idle() -> void:
	_log.append("exit:idle")


func _idle_update(_delta: float) -> void:
	_log.append("update:idle")


func _enter_chase() -> void:
	_log.append("enter:chase")


func _chase_update(_delta: float) -> void:
	_log.append("update:chase")


func test_states_are_registered() -> void:
	assert_true(_fsm.has_state(&"idle"))
	assert_false(_fsm.has_state(&"flee"))
	assert_eq(_fsm.states(), [&"chase", &"idle"] as Array[StringName])


func test_start_enters_without_an_exit_callback() -> void:
	var moves := record(_fsm.transitioned)
	assert_true(_fsm.start(&"idle"))
	assert_eq(_fsm.current, &"idle")
	assert_eq(_log, ["enter:idle"] as PackedStringArray)
	assert_eq(moves.size(), 1)
	assert_eq(moves[0][0], &"")


func test_start_refuses_an_unknown_state() -> void:
	assert_false(_fsm.start(&"nope"))
	assert_eq(_fsm.current, &"")


func test_transition_runs_exit_then_enter() -> void:
	_fsm.start(&"idle")
	_log.clear()
	assert_true(_fsm.transition_to(&"chase"))
	assert_eq(_log, ["exit:idle", "enter:chase"] as PackedStringArray)
	assert_eq(_fsm.current, &"chase")
	assert_eq(_fsm.previous, &"idle")


func test_transition_to_the_current_state_is_a_no_op() -> void:
	_fsm.start(&"idle")
	_log.clear()
	assert_false(_fsm.transition_to(&"idle"))
	assert_eq(_log.size(), 0)


func test_update_runs_only_the_current_state() -> void:
	_fsm.start(&"idle")
	_log.clear()
	_fsm.update(0.1)
	_fsm.transition_to(&"chase")
	_log.clear()
	_fsm.update(0.1)
	assert_eq(_log, ["update:chase"] as PackedStringArray)


func test_time_in_state_accumulates_and_resets() -> void:
	_fsm.start(&"idle")
	_fsm.update(0.25)
	_fsm.update(0.25)
	assert_almost_eq(_fsm.time_in_state, 0.5)
	_fsm.transition_to(&"chase")
	assert_almost_eq(_fsm.time_in_state, 0.0)


func test_update_before_start_does_nothing() -> void:
	_fsm.update(1.0)
	assert_almost_eq(_fsm.time_in_state, 0.0)
	assert_eq(_log.size(), 0)


func test_states_may_omit_every_callback() -> void:
	var bare := StateMachine.new()
	bare.add_state(&"quiet")
	assert_true(bare.start(&"quiet"))
	bare.update(0.1)
	assert_eq(bare.current, &"quiet")
	assert_almost_eq(bare.time_in_state, 0.1)
