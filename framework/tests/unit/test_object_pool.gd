extends GodotGoTest
## Instance reuse: the pool the arena shooter fires bullets from.

var _pool: ObjectPool


func before_each() -> void:
	_pool = ObjectPool.new()
	_pool.scene = _make_scene()
	add_node(_pool)


func after_each() -> void:
	if is_instance_valid(_pool):
		await free_node(_pool)
	_pool = null


## A one-node PackedScene built in memory, so the test needs no .tscn on disk.
func _make_scene() -> PackedScene:
	var node := Node2D.new()
	node.name = "Pooled"
	var packed := PackedScene.new()
	packed.pack(node)
	node.free()
	return packed


func test_acquire_creates_on_demand_and_tracks_usage() -> void:
	assert_eq(_pool.in_use(), 0)
	var a := _pool.acquire()
	assert_not_null(a)
	assert_null(a.get_parent(), "the caller decides where it goes")
	assert_eq(_pool.in_use(), 1)
	assert_eq(_pool.created(), 1)


func test_release_returns_the_instance_for_reuse() -> void:
	var first := _pool.acquire()
	add_node(first)
	_pool.release(first)
	assert_eq(_pool.in_use(), 0)
	assert_eq(_pool.available(), 1)
	assert_null(first.get_parent(), "release takes it out of the tree")
	var second := _pool.acquire()
	assert_eq(second, first, "the same instance comes back")
	assert_eq(_pool.created(), 1, "no second allocation")


func test_prewarm_allocates_up_front() -> void:
	_pool.prewarm(4)
	assert_eq(_pool.available(), 4)
	assert_eq(_pool.created(), 4)
	_pool.acquire()
	assert_eq(_pool.available(), 3)


func test_max_size_caps_live_instances() -> void:
	_pool.max_size = 2
	assert_not_null(_pool.acquire())
	assert_not_null(_pool.acquire())
	assert_null(_pool.acquire(), "the cap refuses a third instance")
	assert_eq(_pool.created(), 2)


func test_release_all_reclaims_everything() -> void:
	for i in 3:
		add_node(_pool.acquire())
	assert_eq(_pool.in_use(), 3)
	_pool.release_all()
	assert_eq(_pool.in_use(), 0)
	assert_eq(_pool.available(), 3)


func test_signals_report_traffic() -> void:
	var got := record(_pool.acquired)
	var gave := record(_pool.released)
	var node := _pool.acquire()
	_pool.release(node)
	assert_eq(got.size(), 1)
	assert_eq(gave.size(), 1)
	assert_eq(got[0][0], node)


func test_pooled_nodes_get_lifecycle_callbacks() -> void:
	var script := GDScript.new()
	script.source_code = (
		"extends Node2D\n"
		+ "var acquired_count := 0\n"
		+ "var released_count := 0\n"
		+ "func pool_acquired() -> void:\n\tacquired_count += 1\n"
		+ "func pool_released() -> void:\n\treleased_count += 1\n"
	)
	assert_eq(script.reload(), OK)
	var node := Node2D.new()
	node.set_script(script)
	var packed := PackedScene.new()
	packed.pack(node)
	node.free()

	_pool.scene = packed
	var pooled := _pool.acquire()
	assert_eq(pooled.acquired_count, 1)
	_pool.release(pooled)
	assert_eq(pooled.released_count, 1)


func test_leaving_the_tree_frees_instances_nobody_else_owns() -> void:
	var orphan := _pool.acquire()
	var parented := _pool.acquire()
	add_node(parented)
	assert_eq(_pool.in_use(), 2)
	_pool.get_parent().remove_child(_pool)
	assert_false(is_instance_valid(orphan), "an unreleased, unparented instance is freed")
	assert_true(is_instance_valid(parented), "an instance the caller parented stays theirs")
	_pool.free()
	_pool = null
	await free_node(parented)


func test_a_pool_without_a_scene_reports_instead_of_crashing() -> void:
	var empty := ObjectPool.new()
	add_node(empty)
	assert_null(empty.acquire())
	await free_node(empty)
