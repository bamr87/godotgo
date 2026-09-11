extends GodotGoTest
## Pooled bullets: reuse instead of allocation, the hard ceiling the pool puts
## on live bullets, and the two ways a shot ends.

const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const ARENA := Rect2(0.0, 0.0, 960.0, 540.0)

var _pool: ObjectPool
var _holder: Node2D


func before_each() -> void:
	Game.reset()
	_pool = ObjectPool.new()
	_pool.scene = BULLET_SCENE
	_pool.initial_size = 4
	_pool.max_size = 8
	add_node(_pool)
	_holder = Node2D.new()
	add_node(_holder)


func after_each() -> void:
	_pool.release_all()
	await free_node(_holder)
	await free_node(_pool)
	Game.reset()


func test_prewarming_fills_the_pool_without_handing_anything_out() -> void:
	assert_eq(_pool.available(), 4)
	assert_eq(_pool.in_use(), 0)
	assert_eq(_pool.created(), 4)


func test_firing_reuses_an_instance_instead_of_allocating() -> void:
	var first := _fire(Vector2(100, 100), Vector2.RIGHT)
	assert_not_null(first)
	assert_eq(_pool.created(), 4, "a prewarmed bullet was reused")
	_pool.release(first)
	var second := _fire(Vector2(100, 100), Vector2.RIGHT)
	assert_eq(second, first, "the released bullet came straight back")
	assert_eq(_pool.created(), 4)


func test_a_long_burst_never_allocates_past_the_cap() -> void:
	var handed_out: Array[Bullet] = []
	for i in 200:
		var bullet := _fire(Vector2(480, 270), Vector2.RIGHT)
		if bullet != null:
			handed_out.append(bullet)
	assert_eq(_pool.created(), _pool.max_size, "200 shots made %d bullets" % _pool.created())
	assert_eq(_pool.in_use(), _pool.max_size)
	assert_eq(handed_out.size(), _pool.max_size, "the pool refuses every shot past its cap")
	assert_eq(_holder.get_child_count(), _pool.max_size)


func test_recycling_keeps_a_whole_fight_inside_the_prewarmed_set() -> void:
	for i in 200:
		var bullet := _fire(Vector2(480, 270), Vector2.RIGHT)
		assert_not_null(bullet, "shot %d" % i)
		_pool.release(bullet)
	assert_eq(_pool.created(), 4, "200 shots, still only the four prewarmed bullets")
	assert_eq(_pool.in_use(), 0)
	assert_eq(_pool.available(), 4)


func test_launch_sets_the_muzzle_direction_rotation_and_clock() -> void:
	var bullet := _fire(Vector2(100, 200), Vector2(0, 3))
	assert_eq(bullet.global_position, Vector2(100, 200))
	assert_almost_eq(bullet.direction().x, 0.0)
	assert_almost_eq(bullet.direction().y, 1.0, 0.0001, "the aim vector is normalised")
	assert_almost_eq(bullet.rotation, Vector2.DOWN.angle())
	assert_almost_eq(bullet.time_left(), bullet.lifetime)
	assert_false(bullet.is_spent())


func test_a_bullet_travels_along_its_aim_at_its_speed() -> void:
	var bullet := _fire(Vector2(100, 270), Vector2.RIGHT)
	var start := bullet.global_position.x
	await physics_frames(12)
	var travelled := bullet.global_position.x - start
	var expected := bullet.speed * 12.0 / float(Engine.physics_ticks_per_second)
	assert_true(travelled > 0.0, "it moved")
	assert_almost_eq(travelled, expected, expected * 0.2)
	assert_almost_eq(bullet.global_position.y, 270.0, 0.001, "no drift off the firing line")


func test_a_bullet_expires_when_its_clock_runs_out() -> void:
	var bullet := _pool.acquire() as Bullet
	_holder.add_child(bullet)
	bullet.lifetime = 0.05
	bullet.speed = 50.0
	bullet.launch(Vector2(480, 270), Vector2.UP, ARENA)
	var expiries := record(bullet.expired)
	await _wait_until_spent(bullet, 60)
	assert_eq(expiries.size(), 1)
	assert_eq(expiries[0][0], bullet)
	assert_almost_eq(bullet.time_left(), 0.0)


func test_a_bullet_that_leaves_the_arena_expires() -> void:
	var small := Rect2(0.0, 0.0, 200.0, 200.0)
	var bullet := _fire(Vector2(190, 100), Vector2.RIGHT, small)
	var expiries := record(bullet.expired)
	await _wait_until_spent(bullet, 60)
	assert_eq(expiries.size(), 1, "the arena edge ended the shot")
	assert_true(bullet.global_position.x >= small.end.x)
	assert_true(bullet.time_left() > 0.0, "it was the bounds, not the clock")


func test_a_spent_bullet_stops_dead_and_hides() -> void:
	var bullet := _fire(Vector2(100, 100), Vector2.RIGHT, Rect2(0.0, 0.0, 120.0, 200.0))
	await _wait_until_spent(bullet, 60)
	assert_true(bullet.is_spent())
	assert_false(bullet.visible)
	var resting := bullet.global_position
	await physics_frames(5)
	assert_eq(bullet.global_position, resting, "a spent bullet must not drift")


func test_release_detaches_the_bullet_and_parks_it() -> void:
	var bullet := _fire(Vector2(100, 100), Vector2.RIGHT)
	assert_eq(_pool.in_use(), 1)
	_pool.release(bullet)
	assert_null(bullet.get_parent())
	assert_eq(_pool.in_use(), 0)
	assert_eq(_pool.available(), 4)
	assert_true(bullet.is_spent(), "parked, so a reused instance cannot drift for a frame")
	assert_false(bullet.visible)


func test_acquire_rearms_a_parked_bullet() -> void:
	var bullet := _fire(Vector2(100, 100), Vector2.RIGHT)
	_pool.release(bullet)
	var again := _pool.acquire() as Bullet
	assert_eq(again, bullet)
	assert_false(again.is_spent())
	assert_true(again.visible)
	assert_almost_eq(again.time_left(), again.lifetime)
	_pool.release(again)


func test_bullet_physics_layers() -> void:
	var bullet := _fire(Vector2(10, 10), Vector2.RIGHT)
	assert_eq(bullet.collision_layer, 32, "layer 6 = player_bullets")
	assert_eq(bullet.collision_mask, 17, "mask 1 + 5 = world + enemies")


func _fire(from: Vector2, direction: Vector2, bounds: Rect2 = ARENA) -> Bullet:
	var bullet := _pool.acquire() as Bullet
	if bullet == null:
		return null
	_holder.add_child(bullet)
	bullet.launch(from, direction, bounds)
	return bullet


func _wait_until_spent(bullet: Bullet, frames: int) -> bool:
	for i in frames:
		await tree.physics_frame
		if bullet.is_spent():
			return true
	return false
