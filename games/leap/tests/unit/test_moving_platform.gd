extends GodotGoTest
## The moving platform's path is pure maths, so it is asserted without running
## the physics server.

var _platform: MovingPlatform


func before_each() -> void:
	_platform = MovingPlatform.new()
	_platform.travel = Vector2(100, 0)
	_platform.duration = 2.0
	_platform.position = Vector2(50, 50)
	add_node(_platform)


func after_each() -> void:
	await free_node(_platform)


func test_starts_at_its_origin() -> void:
	assert_eq(_platform.position_at(0.0), Vector2(50, 50))


func test_reaches_the_far_end_after_one_leg() -> void:
	assert_eq(_platform.position_at(2.0), Vector2(150, 50))


func test_returns_to_the_origin_after_a_full_cycle() -> void:
	assert_almost_eq(_platform.position_at(4.0).x, 50.0, 0.01)


func test_the_cycle_repeats() -> void:
	assert_almost_eq(_platform.position_at(6.0).x, _platform.position_at(2.0).x, 0.01)


func test_motion_eases_rather_than_moving_linearly() -> void:
	var half := _platform.position_at(1.0).x
	assert_almost_eq(half, 100.0, 0.01, "halfway in time is halfway in space")
	var quarter := _platform.position_at(0.5).x - 50.0
	assert_true(quarter < 25.0, "smoothstep starts slow, got %f" % quarter)


func test_phase_offsets_the_starting_point() -> void:
	var staggered := MovingPlatform.new()
	staggered.travel = Vector2(100, 0)
	staggered.duration = 2.0
	staggered.phase = 0.5
	staggered.position = Vector2.ZERO
	add_node(staggered)
	# Phase 0.5 starts the platform half a cycle in, which is the far end.
	await physics_frames(2)
	assert_true(
		staggered.position.x > 50.0,
		"a phased platform starts partway along its path, got %s" % str(staggered.position)
	)
	await free_node(staggered)


func test_reset_origin_moves_the_whole_path() -> void:
	_platform.reset_origin(Vector2(300, 10))
	assert_eq(_platform.position_at(0.0), Vector2(300, 10), "the path moves at once")
	assert_eq(_platform.position_at(2.0), Vector2(400, 10))
	# sync_to_physics means the physics server places the node a frame later.
	await physics_frames(2)
	assert_almost_eq(_platform.position.x, 300.0, 1.0)


func test_it_is_world_geometry_that_carries_riders() -> void:
	assert_eq(_platform.collision_layer, 1, "a platform is world geometry by default")
	assert_true(_platform is AnimatableBody2D, "sync_to_physics is what carries the hero")
