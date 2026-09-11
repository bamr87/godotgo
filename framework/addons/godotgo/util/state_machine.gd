class_name StateMachine
extends RefCounted
## A small finite state machine for entity behaviour, built from callables so it
## needs no node hierarchy and can be unit-tested on its own.
##
## [codeblock]
## var fsm := StateMachine.new()
## fsm.add_state(&"idle", _idle_update)
## fsm.add_state(&"chase", _chase_update, _on_chase_enter)
## fsm.start(&"idle")
## # in _physics_process:
## fsm.update(delta)
## [/codeblock]

## Emitted on every accepted transition, including the initial [method start].
signal transitioned(from: StringName, to: StringName)

var current: StringName = &""
var previous: StringName = &""
## Seconds spent in [member current], reset on every transition.
var time_in_state := 0.0

var _states: Dictionary[StringName, Dictionary] = {}


## Registers a state. Every callback is optional; [param on_update] receives the
## frame delta, the others take no arguments.
func add_state(
	state_name: StringName, on_update := Callable(), on_enter := Callable(), on_exit := Callable()
) -> void:
	_states[state_name] = {"update": on_update, "enter": on_enter, "exit": on_exit}


func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)


## Registered state names, in alphabetical order.
func states() -> Array[StringName]:
	var names: Array[StringName] = []
	for key in _states:
		names.append(key)
	# StringName compares by hash, not by text, so Array.sort() would return a
	# stable but arbitrary order. Compare the string values instead.
	names.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return names


## Enters the first state without running an exit callback. Returns false when
## the state is unknown.
func start(state_name: StringName) -> bool:
	if not _states.has(state_name):
		push_error("StateMachine: unknown state %s" % state_name)
		return false
	previous = &""
	current = state_name
	time_in_state = 0.0
	_call(state_name, "enter")
	transitioned.emit(previous, current)
	return true


## Leaves the current state and enters [param state_name]. Returns false when the
## state is unknown or already current.
func transition_to(state_name: StringName) -> bool:
	if not _states.has(state_name):
		push_error("StateMachine: unknown state %s" % state_name)
		return false
	if state_name == current:
		return false
	_call(current, "exit")
	previous = current
	current = state_name
	time_in_state = 0.0
	_call(current, "enter")
	transitioned.emit(previous, current)
	return true


## Runs the current state's update callback and advances [member time_in_state].
func update(delta: float) -> void:
	if current.is_empty():
		return
	time_in_state += delta
	var callback: Callable = _states[current]["update"]
	if callback.is_valid():
		callback.call(delta)


func _call(state_name: StringName, key: String) -> void:
	if not _states.has(state_name):
		return
	var callback: Callable = _states[state_name][key]
	if callback.is_valid():
		callback.call()
