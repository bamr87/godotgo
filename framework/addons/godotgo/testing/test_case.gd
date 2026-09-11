class_name GodotGoTest
extends RefCounted
## Base class for headless unit tests, shared by every project in the
## workspace. Subclass in a project's tests/unit/test_*.gd and
## add methods prefixed with test_. Methods may use await (e.g. on
## tree.physics_frame) and the runner will wait for them.

## The running SceneTree, for tests that need to add nodes or await frames.
var tree: SceneTree
var _failures: PackedStringArray = []
var _assert_count := 0
var _skip_reason := ""
var _recordings: Array[Dictionary] = []


## Called before every test_ method.
func before_each() -> void:
	pass


## Called after every test_ method, even when it failed.
func after_each() -> void:
	pass


func fail(message: String) -> void:
	_failures.append(message)


## Marks the current test as skipped. Remaining assertions still run but the
## runner reports the test as skipped rather than passed or failed.
func skip(reason: String) -> void:
	_skip_reason = reason


## True when running without a real display (CI, tools/test.sh).
func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func assert_true(condition: bool, message: String = "") -> void:
	_assert_count += 1
	if not condition:
		fail("expected true" + _suffix(message))


func assert_false(condition: bool, message: String = "") -> void:
	_assert_count += 1
	if condition:
		fail("expected false" + _suffix(message))


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	_assert_count += 1
	if not is_same(actual, expected) and actual != expected:
		fail("expected %s, got %s%s" % [var_to_str(expected), var_to_str(actual), _suffix(message)])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	_assert_count += 1
	if actual == unexpected:
		fail("expected anything but %s%s" % [var_to_str(unexpected), _suffix(message)])


func assert_almost_eq(
	actual: float, expected: float, tolerance: float = 0.0001, message: String = ""
) -> void:
	_assert_count += 1
	if absf(actual - expected) > tolerance:
		fail("expected %f ± %f, got %f%s" % [expected, tolerance, actual, _suffix(message)])


func assert_null(value: Variant, message: String = "") -> void:
	_assert_count += 1
	if value != null:
		fail("expected null, got %s%s" % [var_to_str(value), _suffix(message)])


func assert_not_null(value: Variant, message: String = "") -> void:
	_assert_count += 1
	if value == null:
		fail("expected non-null" + _suffix(message))


func assert_is(value: Variant, type: Variant, message: String = "") -> void:
	_assert_count += 1
	if not is_instance_of(value, type):
		fail("expected instance of %s, got %s%s" % [type, _describe(value), _suffix(message)])


## Instantiates a PackedScene, adds it to the tree root, and returns it.
## Free it with [method free_node] in [method after_each].
func add_scene(scene: PackedScene) -> Node:
	var node := scene.instantiate()
	tree.root.add_child(node)
	return node


## Adds an existing node to the tree root.
func add_node(node: Node) -> Node:
	tree.root.add_child(node)
	return node


## Queues a node for deletion and waits until it is gone. Accepts an already
## freed reference (e.g. a node that freed itself) without complaint.
func free_node(node: Variant) -> void:
	if is_instance_valid(node) and node is Node:
		(node as Node).queue_free()
		await tree.process_frame


## Waits for [param count] physics frames. Resumes inside the physics frame,
## before nodes process, so Input.action_press calls made right after are seen
## as "just pressed" by _physics_process in that same frame.
func physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


## Records every emission of [param sig] until the test ends. Each entry is the
## emitted arguments padded with nulls to three items; use size() for counts.
func record(sig: Signal) -> Array:
	var calls: Array = []
	var callable := func(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
		calls.append([a, b, c])
	sig.connect(callable)
	_recordings.append({"signal": sig, "callable": callable})
	return calls


## Adds a 40 x 1 x 40 static 3D floor on physics layer 1 whose top surface is y = 0.
func add_floor_3d() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	body.add_child(shape)
	body.position.y = -0.5
	tree.root.add_child(body)
	return body


## Adds a 2000 x 40 static 2D floor on physics layer 1 whose top edge is y = 0.
func add_floor_2d() -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(2000, 40)
	shape.shape = box
	body.add_child(shape)
	body.position.y = 20.0
	tree.root.add_child(body)
	return body


## Called by the runner after after_each: disconnects signal recordings.
func _teardown() -> void:
	for recording in _recordings:
		var sig: Signal = recording["signal"]
		var callable: Callable = recording["callable"]
		if is_instance_valid(sig.get_object()) and sig.is_connected(callable):
			sig.disconnect(callable)
	_recordings.clear()


func _suffix(message: String) -> String:
	return "" if message.is_empty() else " (%s)" % message


func _describe(value: Variant) -> String:
	if value is Object:
		return value.get_class()
	return type_string(typeof(value))
