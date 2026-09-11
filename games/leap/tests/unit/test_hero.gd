extends GodotGoTest
## The platformer controller, on a real physics floor.

const HERO_SCENE := preload("res://scenes/hero.tscn")

var _hero: Hero
var _floor: StaticBody2D


func before_each() -> void:
	_hero = add_scene(HERO_SCENE) as Hero
	_hero.use_input_override = true
	_hero.input_override = 0.0


func after_each() -> void:
	if is_instance_valid(_floor):
		await free_node(_floor)
	_floor = null
	await free_node(_hero)


func _settle() -> void:
	_floor = add_floor_2d()
	_hero.teleport_to(Vector2(0, -20))
	await physics_frames(20)


func test_physics_layers() -> void:
	assert_eq(_hero.collision_layer, 2, "layer 2 = player")
	assert_eq(_hero.collision_mask, 1, "collides with world only")


func test_direction_follows_the_override() -> void:
	_hero.input_override = -1.0
	assert_almost_eq(_hero.direction(), -1.0)
	_hero.input_override = 1.0
	assert_almost_eq(_hero.direction(), 1.0)


func test_teleport_clears_momentum() -> void:
	_hero.velocity = Vector2(300, -400)
	_hero.teleport_to(Vector2(64, 64))
	assert_eq(_hero.global_position, Vector2(64, 64))
	assert_eq(_hero.velocity, Vector2.ZERO)


func test_falls_and_comes_to_rest_on_the_floor() -> void:
	await _settle()
	assert_true(_hero.is_on_floor())
	assert_almost_eq(_hero.velocity.y, 0.0, 1.0)


func test_landing_reports_the_fall_speed() -> void:
	_floor = add_floor_2d()
	_hero.teleport_to(Vector2(0, -300))
	var lands := record(_hero.landed)
	for i in 240:
		await tree.physics_frame
		if not lands.is_empty():
			break
	assert_eq(lands.size(), 1, "landed fires once on touchdown")
	assert_true(
		lands[0][0] > 100.0, "falling 300 px should exceed 100 px/s, got %s" % str(lands[0][0])
	)


func test_jump_leaves_the_ground_and_announces_itself() -> void:
	await _settle()
	var jumps := record(_hero.jumped)
	_hero.request_jump()
	await physics_frames(2)
	assert_eq(jumps.size(), 1)
	assert_true(_hero.velocity.y < 0.0, "negative Y is upward")
	assert_false(_hero.is_on_floor())


func test_a_jump_request_in_mid_air_is_ignored_once_the_coyote_window_closes() -> void:
	_floor = add_floor_2d()
	_hero.teleport_to(Vector2(0, -400))
	await physics_frames(30)
	var jumps := record(_hero.jumped)
	_hero.request_jump()
	await physics_frames(2)
	assert_eq(jumps.size(), 0, "no ground and no coyote time means no jump")


func test_coyote_time_allows_a_jump_just_after_leaving_a_ledge() -> void:
	await _settle()
	assert_true(_hero.is_on_floor())
	await free_node(_floor)
	_floor = null
	await physics_frames(1)
	var jumps := record(_hero.jumped)
	_hero.request_jump()
	await physics_frames(1)
	assert_eq(jumps.size(), 1, "the grace window is still open one frame after the floor vanished")


func test_jump_buffer_fires_on_landing() -> void:
	_floor = add_floor_2d()
	_hero.jump_buffer = 1.0  # generous, so the window rather than the fall time is under test
	_hero.teleport_to(Vector2(0, -60))
	var jumps := record(_hero.jumped)
	# Press while still falling; the buffer should remember it until touchdown.
	await physics_frames(1)
	_hero.request_jump()
	for i in 60:
		await tree.physics_frame
		if not jumps.is_empty():
			break
	assert_eq(jumps.size(), 1, "the remembered press fires as soon as the hero lands")


func test_running_reaches_top_speed_and_stops() -> void:
	await _settle()
	_hero.input_override = 1.0
	await physics_frames(40)
	assert_almost_eq(absf(_hero.velocity.x), _hero.speed, 5.0)
	_hero.input_override = 0.0
	await physics_frames(40)
	assert_almost_eq(_hero.velocity.x, 0.0, 1.0, "friction brings the hero to rest")


func test_running_left_moves_left() -> void:
	await _settle()
	var start_x := _hero.global_position.x
	_hero.input_override = -1.0
	await physics_frames(20)
	assert_true(_hero.global_position.x < start_x)


func test_falling_is_faster_than_rising() -> void:
	assert_true(_hero.fall_gravity_scale > 1.0, "a heavier fall keeps the arc from feeling floaty")
