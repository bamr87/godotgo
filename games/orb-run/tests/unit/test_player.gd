extends GodotGoTest
## Character controller: scene wiring, input mapping and real physics
## (jumping, landing, sprinting) on a test floor.

const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _player: Player


func before_each() -> void:
	_player = add_scene(PLAYER_SCENE) as Player


func after_each() -> void:
	for action in [Player.ACTION_JUMP, Player.ACTION_FORWARD, Player.ACTION_SPRINT]:
		Input.action_release(action)
	await free_node(_player)


func _settle_on_floor() -> StaticBody3D:
	var floor := add_floor_3d()
	_player.global_position = Vector3(0, 0.02, 0)
	await physics_frames(20)
	return floor


func _horizontal_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func test_resolves_camera_pivot_from_scene() -> void:
	assert_not_null(_player.camera_pivot)
	assert_eq(_player.camera_pivot.name, &"CameraPivot")


func test_physics_layers() -> void:
	assert_eq(_player.collision_layer, 2, "layer 2 = player")
	assert_eq(_player.collision_mask, 1, "collides with world only")


func test_mouse_capture_toggle() -> void:
	if is_headless():
		skip("headless DisplayServer ignores mouse mode")
		return
	_player.set_mouse_captured(true)
	assert_true(_player.is_mouse_captured())
	_player.set_mouse_captured(false)
	assert_false(_player.is_mouse_captured())


func test_wish_direction_is_zero_without_input() -> void:
	assert_eq(_player.get_wish_direction(), Vector3.ZERO)


func test_forward_input_moves_along_negative_z() -> void:
	Input.action_press(Player.ACTION_FORWARD)
	var direction := _player.get_wish_direction()
	assert_almost_eq(direction.z, -1.0)
	assert_almost_eq(direction.x, 0.0)


func test_jump_buffer_defaults_are_sane() -> void:
	assert_true(_player.coyote_time > 0.0)
	assert_true(_player.jump_buffer > 0.0)
	assert_true(_player.jump_velocity > 0.0)


func test_rests_on_floor_under_gravity() -> void:
	var floor := await _settle_on_floor()
	assert_true(_player.is_on_floor())
	assert_almost_eq(_player.global_position.y, 0.0, 0.05)
	await free_node(floor)


func test_jump_from_floor_emits_jumped_and_launches_upward() -> void:
	var floor := await _settle_on_floor()
	var jumps := record(_player.jumped)
	Input.action_press(Player.ACTION_JUMP)
	await physics_frames(2)
	Input.action_release(Player.ACTION_JUMP)
	assert_eq(jumps.size(), 1)
	assert_true(_player.velocity.y > 0.0, "upward velocity after jump")
	assert_false(_player.is_on_floor())
	await free_node(floor)


func test_landing_emits_fall_speed() -> void:
	var floor := add_floor_3d()
	_player.global_position = Vector3(0, 3.0, 0)
	var lands := record(_player.landed)
	for i in 200:
		await tree.physics_frame
		if not lands.is_empty():
			break
	assert_eq(lands.size(), 1)
	assert_true(
		lands[0][0] > 3.0, "fall speed from 3 m should exceed 3 m/s, got %s" % str(lands[0][0])
	)
	await free_node(floor)


func test_walking_and_sprinting_reach_their_target_speeds() -> void:
	var floor := await _settle_on_floor()
	Input.action_press(Player.ACTION_FORWARD)
	await physics_frames(30)
	assert_almost_eq(_horizontal_speed(), _player.speed, 0.2)
	Input.action_press(Player.ACTION_SPRINT)
	await physics_frames(30)
	assert_almost_eq(_horizontal_speed(), _player.speed * _player.sprint_multiplier, 0.2)
	Input.action_release(Player.ACTION_SPRINT)
	Input.action_release(Player.ACTION_FORWARD)
	await physics_frames(30)
	assert_almost_eq(_horizontal_speed(), 0.0, 0.05, "decelerates to rest")
	await free_node(floor)
