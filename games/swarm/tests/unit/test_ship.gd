extends GodotGoTest
## The player ship: the input map, the override that replaces it in tests,
## aiming, and the fire cadence.

const SHIP_SCENE := preload("res://scenes/ship.tscn")
const ACTIONS: Array[StringName] = [
	Ship.ACTION_UP, Ship.ACTION_DOWN, Ship.ACTION_LEFT, Ship.ACTION_RIGHT, Ship.ACTION_FIRE
]

var _ship: Ship


func before_each() -> void:
	Game.reset()
	_ship = add_scene(SHIP_SCENE) as Ship
	_ship.use_input_override = true
	_ship.teleport_to(Vector2(480, 270))


func after_each() -> void:
	for action in ACTIONS:
		Input.action_release(action)
	await free_node(_ship)
	Game.reset()


func test_ship_physics_layers() -> void:
	assert_eq(_ship.collision_layer, 2, "layer 2 = player")
	assert_eq(_ship.collision_mask, 1, "it only collides with the arena walls")


func test_wasd_drives_the_ship_through_the_input_map() -> void:
	_ship.use_input_override = false
	assert_eq(_ship.move_direction(), Vector2.ZERO)
	Input.action_press(Ship.ACTION_RIGHT)
	Input.action_press(Ship.ACTION_UP)
	var direction := _ship.move_direction()
	assert_true(direction.x > 0.0, "D moves right")
	assert_true(direction.y < 0.0, "W moves up")
	assert_almost_eq(direction.length(), 1.0, 0.001, "diagonals are not faster")


func test_the_override_replaces_movement_aim_and_trigger() -> void:
	_ship.input_override = Vector2(3, 0)
	assert_almost_eq(_ship.move_direction().length(), 1.0, 0.0001, "clamped to one unit")
	_ship.aim_override = _ship.global_position + Vector2(0, -50)
	assert_almost_eq(_ship.aim_direction().y, -1.0)
	assert_false(_ship.wants_fire())
	_ship.fire_override = true
	assert_true(_ship.wants_fire())


func test_aim_holds_its_last_direction_when_the_cursor_sits_on_the_ship() -> void:
	_ship.aim_override = _ship.global_position + Vector2(0, 40)
	assert_almost_eq(_ship.aim_direction().y, 1.0)
	_ship.aim_override = _ship.global_position
	assert_almost_eq(_ship.aim_direction().y, 1.0, 0.0001, "no snap back to east")


func test_it_accelerates_to_its_top_speed_and_stops_again() -> void:
	_ship.input_override = Vector2.RIGHT
	await physics_frames(40)
	assert_almost_eq(_ship.velocity.length(), _ship.speed, 1.0)
	_ship.input_override = Vector2.ZERO
	await physics_frames(40)
	assert_almost_eq(_ship.velocity.length(), 0.0, 0.5, "friction brings it to rest")


func test_firing_reports_a_muzzle_and_a_direction() -> void:
	_ship.aim_override = _ship.global_position + Vector2(100, 0)
	var shots := record(_ship.fired)
	assert_true(_ship.try_fire())
	assert_eq(shots.size(), 1)
	var from: Vector2 = shots[0][0]
	var direction: Vector2 = shots[0][1]
	assert_almost_eq(direction.x, 1.0)
	assert_almost_eq(from.distance_to(_ship.global_position), _ship.muzzle_offset, 0.01)
	assert_almost_eq(from.y, _ship.global_position.y, 0.01)


func test_the_cooldown_paces_the_trigger() -> void:
	var shots := record(_ship.fired)
	assert_true(_ship.try_fire())
	assert_false(_ship.can_fire())
	assert_false(_ship.try_fire(), "the cooldown holds the trigger")
	assert_eq(shots.size(), 1)
	await physics_frames(int(_ship.fire_interval * Engine.physics_ticks_per_second) + 4)
	assert_true(_ship.can_fire())


func test_holding_the_trigger_fires_at_about_the_interval() -> void:
	_ship.aim_override = _ship.global_position + Vector2(100, 0)
	_ship.fire_override = true
	var shots := record(_ship.fired)
	await physics_frames(Engine.physics_ticks_per_second)
	_ship.fire_override = false
	var expected := int(1.0 / _ship.fire_interval)
	var got := shots.size()
	assert_true(got >= expected - 2, "about %d shots a second, got %d" % [expected, got])
	assert_true(got <= expected + 3, "and no more than that, got %d" % got)


func test_teleport_cancels_momentum_and_the_pending_shot() -> void:
	_ship.input_override = Vector2.RIGHT
	await physics_frames(20)
	assert_true(_ship.velocity.length() > 0.0)
	_ship.try_fire()
	_ship.teleport_to(Vector2(100, 100))
	assert_eq(_ship.global_position, Vector2(100, 100))
	assert_eq(_ship.velocity, Vector2.ZERO)
	assert_true(_ship.can_fire())
