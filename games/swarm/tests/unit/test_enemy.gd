extends GodotGoTest
## Enemy behaviour: the four-state machine, the difference between the two
## kinds, and dying. States are driven by real physics frames.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const DRONE_STATS := preload("res://resources/drone.tres")
const BRUTE_STATS := preload("res://resources/brute.tres")

var _enemy: Enemy
var _target: Node2D


func before_each() -> void:
	Game.reset()
	_target = Node2D.new()
	add_node(_target)
	_target.global_position = Vector2(500, 300)
	_enemy = ENEMY_SCENE.instantiate() as Enemy
	_enemy.stats = DRONE_STATS
	_enemy.position = Vector2(200, 300)
	add_node(_enemy)
	_enemy.target = _target


func after_each() -> void:
	await free_node(_enemy)
	await free_node(_target)
	Game.reset()


func test_an_enemy_starts_by_telegraphing() -> void:
	assert_eq(_enemy.state(), Enemy.STATE_SPAWNING)
	assert_true(_enemy.is_alive())
	assert_eq(_enemy.health, DRONE_STATS.max_health)
	assert_true(_ring().visible)


func test_the_machine_registers_all_four_states() -> void:
	assert_eq(_enemy.state_machine.states().size(), 4)
	for state in [Enemy.STATE_SPAWNING, Enemy.STATE_CHASE, Enemy.STATE_ATTACK, Enemy.STATE_DEAD]:
		assert_true(_enemy.state_machine.has_state(state), String(state))


func test_a_telegraphing_enemy_cannot_be_shot() -> void:
	assert_true(_shape().disabled, "no hitbox while the spawn ring plays")
	assert_true(await _wait_for_state(Enemy.STATE_CHASE, 180))
	assert_false(_shape().disabled, "solid once it is in play")


func test_spawning_hands_over_to_chase() -> void:
	var transitions := record(_enemy.state_machine.transitioned)
	await physics_frames(2)
	assert_eq(_enemy.state(), Enemy.STATE_SPAWNING, "still telegraphing after two frames")
	assert_true(await _wait_for_state(Enemy.STATE_CHASE, 180))
	assert_false(_ring().visible)
	assert_eq(transitions.size(), 1)
	assert_eq(transitions[0][0], Enemy.STATE_SPAWNING)
	assert_eq(transitions[0][1], Enemy.STATE_CHASE)


func test_chasing_closes_the_distance() -> void:
	assert_true(await _wait_for_state(Enemy.STATE_CHASE, 180))
	var before := _enemy.distance_to_target()
	await physics_frames(20)
	assert_true(_enemy.distance_to_target() < before, "the drone closes in")
	assert_true(_enemy.velocity.length() > 0.0)


func test_reaching_range_switches_to_attacking_and_hits_at_once() -> void:
	_enemy.apply_stats(_quick_stats())
	var hits := record(_enemy.attacked)
	_enemy.global_position = _target.global_position
	await physics_frames(6)
	assert_eq(_enemy.state(), Enemy.STATE_ATTACK)
	assert_true(hits.size() >= 1, "closing to melee range must hurt straight away")
	assert_eq(hits[0][0], _enemy)
	assert_eq(hits[0][1], 2, "the damage comes from the stats")


func test_attacks_repeat_on_the_stats_cooldown() -> void:
	_enemy.apply_stats(_quick_stats())
	_enemy.global_position = _target.global_position
	var hits := record(_enemy.attacked)
	await physics_frames(24)
	assert_eq(_enemy.state(), Enemy.STATE_ATTACK)
	assert_true(hits.size() >= 3, "a 0.1 s cooldown over ~0.4 s, got %d hits" % hits.size())


func test_the_ship_escaping_range_puts_the_enemy_back_on_the_chase() -> void:
	_enemy.apply_stats(_quick_stats())
	_enemy.global_position = _target.global_position
	await physics_frames(6)
	assert_eq(_enemy.state(), Enemy.STATE_ATTACK)
	_target.global_position = _enemy.global_position + Vector2(400, 0)
	await physics_frames(4)
	assert_eq(_enemy.state(), Enemy.STATE_CHASE)


func test_losing_the_target_stops_the_attack() -> void:
	_enemy.apply_stats(_quick_stats())
	_enemy.global_position = _target.global_position
	await physics_frames(6)
	assert_eq(_enemy.state(), Enemy.STATE_ATTACK)
	_enemy.target = null
	await physics_frames(4)
	assert_eq(_enemy.state(), Enemy.STATE_CHASE)
	assert_almost_eq(_enemy.distance_to_target(), -1.0)


func test_damage_only_kills_once_the_health_is_gone() -> void:
	_enemy.apply_stats(BRUTE_STATS)
	var deaths := record(_enemy.died)
	for i in BRUTE_STATS.max_health - 1:
		assert_true(_enemy.take_damage())
		assert_true(_enemy.is_alive(), "hit %d of %d" % [i + 1, BRUTE_STATS.max_health])
	assert_true(_enemy.take_damage())
	assert_false(_enemy.is_alive())
	assert_eq(_enemy.state(), Enemy.STATE_DEAD)
	assert_eq(deaths.size(), 1, "died fires exactly once")
	assert_eq(deaths[0][0], _enemy)


func test_a_dead_enemy_absorbs_nothing_more() -> void:
	_enemy.kill()
	var deaths := record(_enemy.died)
	assert_false(_enemy.take_damage(), "already dead")
	assert_eq(deaths.size(), 0)
	assert_eq(_enemy.health, 0)
	assert_eq(_enemy.state(), Enemy.STATE_DEAD)


func test_a_corpse_frees_itself_after_its_fade() -> void:
	_enemy.death_fade = 0.1
	_enemy.kill()
	await tree.create_timer(0.5).timeout
	assert_false(is_instance_valid(_enemy), "corpses must not pile up in the arena")


func test_the_two_kinds_really_are_different() -> void:
	assert_eq(DRONE_STATS.kind, WavePlanner.KIND_DRONE)
	assert_eq(BRUTE_STATS.kind, WavePlanner.KIND_BRUTE)
	assert_true(BRUTE_STATS.max_health > DRONE_STATS.max_health, "brutes soak more")
	assert_true(BRUTE_STATS.speed < DRONE_STATS.speed, "brutes are slower")
	assert_true(BRUTE_STATS.radius > DRONE_STATS.radius, "brutes are bigger")
	assert_true(BRUTE_STATS.score_value > DRONE_STATS.score_value, "brutes pay more")


func test_stats_size_the_body_and_dress_the_sprite() -> void:
	_enemy.apply_stats(BRUTE_STATS)
	assert_almost_eq(_circle().radius, BRUTE_STATS.radius)
	assert_eq(_sprite().texture, BRUTE_STATS.texture)
	assert_eq(_enemy.health, BRUTE_STATS.max_health)
	var other := ENEMY_SCENE.instantiate() as Enemy
	other.stats = DRONE_STATS
	add_node(other)
	var other_circle := (other.get_node(^"CollisionShape2D") as CollisionShape2D).shape
	assert_almost_eq((other_circle as CircleShape2D).radius, DRONE_STATS.radius)
	assert_ne(other_circle, _circle(), "each enemy owns its own collision circle")
	await free_node(other)


func test_enemy_physics_layers() -> void:
	assert_eq(_enemy.collision_layer, 16, "layer 5 = enemies")
	assert_eq(_enemy.collision_mask, 17, "mask 1 + 5 = walls and each other")


func _sprite() -> Sprite2D:
	return _enemy.get_node(^"Sprite2D") as Sprite2D


func _ring() -> Sprite2D:
	return _enemy.get_node(^"SpawnRing") as Sprite2D


func _shape() -> CollisionShape2D:
	return _enemy.get_node(^"CollisionShape2D") as CollisionShape2D


func _circle() -> CircleShape2D:
	return _shape().shape as CircleShape2D


## Stats with no spawn delay and a fast trigger, so a transition test does not
## have to sit through a telegraph it is not testing.
func _quick_stats() -> EnemyStats:
	var stats := EnemyStats.new()
	stats.kind = WavePlanner.KIND_DRONE
	stats.texture = DRONE_STATS.texture
	stats.radius = 9.0
	stats.max_health = 3
	stats.speed = 200.0
	stats.acceleration = 2000.0
	stats.attack_range = 24.0
	stats.attack_damage = 2
	stats.attack_cooldown = 0.1
	stats.spawn_time = 0.0
	stats.score_value = 10
	return stats


func _wait_for_state(state: StringName, frames: int) -> bool:
	for i in frames:
		await tree.physics_frame
		if _enemy.state() == state:
			return true
	return false
