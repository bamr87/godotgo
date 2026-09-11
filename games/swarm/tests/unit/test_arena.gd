extends GodotGoTest
## A real round in the real main scene: seeded wave spawning, pooled shots that
## kill through physics, hull damage, the walls and restarting.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _arena: Arena


func before_each() -> void:
	Game.reset()
	_arena = add_scene(MAIN_SCENE) as Arena
	await tree.physics_frame


func after_each() -> void:
	await free_node(_arena)
	if is_instance_valid(tree.current_scene):
		var current := tree.current_scene
		tree.current_scene = null
		await free_node(current)
	Game.reset()


func test_the_scene_opens_a_round_and_its_first_wave() -> void:
	assert_true(Game.is_playing())
	assert_eq(Game.goal, _arena.waves_to_survive)
	assert_eq(Game.wave, 1)
	assert_eq(Game.enemies_left, _arena.planner.count_for(1))
	assert_eq(_arena.enemies().size(), Game.enemies_left)
	assert_eq(_arena.hud.title_text(), "Swarm")
	assert_eq(_arena.hud.wave_text(), "Wave 1 / %d" % _arena.waves_to_survive)


func test_the_playfield_matches_the_walls_in_the_scene() -> void:
	assert_eq(_arena.playfield, Rect2(16.0, 16.0, 928.0, 508.0))
	assert_eq(_arena.get_node(^"Walls").get_child_count(), 4)
	for wall in _arena.get_node(^"Walls").get_children():
		assert_eq((wall as StaticBody2D).collision_layer, 1, "layer 1 = world")


func test_the_first_wave_is_exactly_what_the_seed_says() -> void:
	var expected := _reference_planner().plan(1)
	var positions: PackedVector2Array = expected["positions"]
	var kinds: Array[StringName] = expected["kinds"]
	var spawned := _arena.enemies()
	assert_eq(spawned.size(), positions.size())
	for i in spawned.size():
		var enemy := spawned[i] as Enemy
		assert_eq(enemy.position, positions[i], "enemy %d spawned off plan" % i)
		assert_eq(enemy.stats, _arena.stats_for(kinds[i]), "enemy %d is the wrong kind" % i)


func test_every_enemy_spawns_inside_the_arena() -> void:
	for node in _arena.enemies():
		var enemy := node as Enemy
		var point := enemy.global_position
		assert_true(
			_arena.playfield.grow(1.0).has_point(point), "%s spawned outside the walls" % point
		)


func test_firing_takes_a_bullet_from_the_pool_and_the_wall_gives_it_back() -> void:
	var ship := _arena.ship
	ship.use_input_override = true
	ship.aim_override = ship.global_position + Vector2(200, 0)
	assert_eq(_arena.bullets().size(), 0)
	assert_true(ship.try_fire())
	assert_eq(_arena.bullets().size(), 1)
	assert_eq(_arena.bullet_pool.in_use(), 1)
	for i in 180:
		await tree.physics_frame
		if _arena.bullets().is_empty():
			break
	assert_eq(_arena.bullets().size(), 0, "the wall ended the shot")
	assert_eq(_arena.bullet_pool.in_use(), 0, "and the pool has it back")
	assert_eq(_arena.bullet_pool.available(), _arena.bullet_pool.initial_size)


func test_a_sustained_burst_never_allocates_a_new_bullet() -> void:
	var ship := _arena.ship
	ship.use_input_override = true
	ship.fire_interval = 0.05
	ship.aim_override = ship.global_position + Vector2(0, -200)
	var before := _arena.bullet_pool.created()
	ship.fire_override = true
	await physics_frames(180)
	ship.fire_override = false
	assert_eq(before, _arena.bullet_pool.initial_size)
	assert_eq(_arena.bullet_pool.created(), before, "three seconds of fire, no new instances")
	assert_true(
		_arena.bullets().size() <= _arena.bullet_pool.max_size,
		"live bullets %d exceeded the cap" % _arena.bullets().size()
	)


func test_a_bullet_kills_a_drone_through_physics_and_the_session_banks_it() -> void:
	_arena.clear_field()
	await physics_frames(2)
	var ship := _arena.ship
	ship.use_input_override = true
	var enemy := _arena.spawn_enemy(WavePlanner.KIND_DRONE, ship.global_position + Vector2(200, 0))
	for i in 180:
		await tree.physics_frame
		if enemy.state() != Enemy.STATE_SPAWNING:
			break
	assert_ne(enemy.state(), Enemy.STATE_SPAWNING, "the drone finished telegraphing")
	var kills_before := Game.kills
	ship.aim_override = enemy.global_position
	assert_true(ship.try_fire())
	for i in 180:
		await tree.physics_frame
		if not enemy.is_alive():
			break
	assert_false(enemy.is_alive(), "the bullet found the drone")
	assert_eq(Game.kills, kills_before + 1)
	# The drone was added to the wave by spawn_enemy, so it was also the last one
	# standing: the score is its own value plus the wave-clear bonus.
	assert_eq(Game.score, _arena.drone_stats.score_value + Game.POINTS_PER_WAVE * Game.wave)
	assert_eq(Game.enemies_left, 0, "the wave counter followed the field")
	assert_eq(_arena.hud.kills_text(), "Kills %d" % Game.kills)
	await physics_frames(2)
	assert_eq(_arena.bullets().size(), 0, "the bullet went back in the pool on impact")
	assert_eq(_arena.bullet_pool.in_use(), 0)


func test_a_whole_wave_can_actually_be_shot_down() -> void:
	var ship := _arena.ship
	ship.use_input_override = true
	# A faster trigger than the designer default, so an end-to-end test does not
	# have to be a fair fight to be a meaningful one.
	ship.fire_interval = 0.05
	var wave_one := Game.enemies_left
	for i in 1200:
		await tree.physics_frame
		var prey := _nearest_live_enemy()
		ship.fire_override = prey != null
		if prey != null:
			ship.aim_override = prey.global_position
		if Game.progress >= 1 or Game.is_over():
			break
	ship.fire_override = false
	assert_eq(Game.state, Session.State.PLAYING, "the ship should have out-shot the wave")
	assert_eq(Game.progress, 1, "wave 1 cleared with real bullets")
	assert_eq(Game.kills, wave_one)
	assert_true(Game.score > 0)


func test_a_brute_soaks_more_than_one_hit() -> void:
	_arena.clear_field()
	await physics_frames(2)
	var brute := _arena.spawn_enemy(WavePlanner.KIND_BRUTE, Vector2(200, 200))
	assert_eq(brute.stats, _arena.brute_stats)
	assert_eq(brute.health, _arena.brute_stats.max_health)
	assert_true(brute.take_damage(1))
	assert_true(brute.is_alive(), "one bullet is not enough")
	brute.take_damage(_arena.brute_stats.max_health)
	assert_false(brute.is_alive())


func test_an_enemy_in_range_spends_hull() -> void:
	_arena.clear_field()
	await physics_frames(2)
	var hull_before := Game.hull
	_arena.spawn_enemy(WavePlanner.KIND_DRONE, _arena.ship.global_position)
	for i in 240:
		await tree.physics_frame
		if Game.hull < hull_before:
			break
	assert_eq(Game.hull, hull_before - 1)
	assert_eq(_arena.hud.hull_text(), HUD.format_hull(Game.hull, Game.MAX_HULL))


func test_clearing_a_wave_advances_progress_and_the_next_one_is_bigger() -> void:
	var wave_one := Game.enemies_left
	_kill_everything()
	await physics_frames(2)
	assert_eq(Game.progress, 1, "wave 1 survived")
	assert_eq(Game.kills, wave_one)
	assert_true(Game.is_playing())
	assert_true(_arena.start_next_wave())
	assert_eq(Game.wave, 2)
	assert_eq(Game.enemies_left, _arena.planner.count_for(2))
	assert_true(Game.enemies_left > wave_one, "waves grow")
	assert_eq(_arena.hud.wave_text(), "Wave 2 / %d" % _arena.waves_to_survive)


func test_the_next_wave_arrives_on_its_own_after_the_break() -> void:
	_arena.wave_break = 0.1
	_kill_everything()
	await physics_frames(2)
	assert_eq(Game.wave, 1, "the next wave waits out the break")
	assert_eq(Game.enemies_left, 0)
	for i in 120:
		await tree.physics_frame
		if Game.wave > 1:
			break
	assert_eq(Game.wave, 2, "the wave timer opened the next wave")
	assert_eq(Game.enemies_left, _arena.planner.count_for(2))


func test_surviving_every_wave_wins_and_sweeps_the_field() -> void:
	for wave in _arena.waves_to_survive:
		_kill_everything()
		await physics_frames(2)
		if Game.is_playing():
			_arena.start_next_wave()
	assert_eq(Game.state, Session.State.WON)
	assert_eq(Game.progress, _arena.waves_to_survive)
	assert_eq(_arena.hud.message_text(), HUD.message_for(Session.State.WON))
	await tree.process_frame
	await tree.process_frame
	assert_eq(_arena.enemies().size(), 0, "the field is swept when the round ends")


func test_losing_the_hull_ends_the_round_and_sweeps_the_field() -> void:
	_arena.ship.use_input_override = true
	_arena.ship.aim_override = _arena.ship.global_position + Vector2(200, 0)
	_arena.ship.try_fire()
	assert_eq(_arena.bullets().size(), 1)
	Game.take_damage(Game.MAX_HULL)
	assert_eq(Game.state, Session.State.LOST)
	assert_eq(_arena.hud.message_text(), HUD.message_for(Session.State.LOST))
	await tree.process_frame
	await tree.process_frame
	assert_eq(_arena.enemies().size(), 0)
	assert_eq(_arena.bullet_pool.in_use(), 0, "bullets go back in the pool too")


func test_the_walls_keep_the_ship_in_the_arena() -> void:
	var ship := _arena.ship
	ship.use_input_override = true
	ship.input_override = Vector2(1, 1)
	await physics_frames(180)
	assert_true(ship.global_position.x < _arena.playfield.end.x, "held by the right wall")
	assert_true(ship.global_position.y < _arena.playfield.end.y, "held by the bottom wall")
	assert_true(_arena.playfield.grow(2.0).has_point(ship.global_position))


func test_the_walls_keep_an_enemy_in_the_arena() -> void:
	_arena.clear_field()
	await physics_frames(2)
	var lure := Node2D.new()
	add_node(lure)
	lure.global_position = Vector2(-600, 270)
	var enemy := _arena.spawn_enemy(WavePlanner.KIND_DRONE, Vector2(80, 270))
	enemy.target = lure
	await physics_frames(180)
	assert_true(
		enemy.global_position.x >= _arena.playfield.position.x - 2.0,
		"the left wall held at %s" % enemy.global_position
	)
	await free_node(lure)


func test_restart_without_a_current_scene_only_resets() -> void:
	assert_null(tree.current_scene)
	_arena.restart()
	assert_eq(Game.state, Session.State.READY)
	assert_true(is_instance_valid(_arena), "the arena is left in place")


func test_restart_reloads_the_scene_with_a_fresh_round() -> void:
	tree.current_scene = _arena
	Game.register_kill(10)
	assert_true(Game.kills > 0)
	_arena.restart()
	await tree.process_frame
	await tree.process_frame
	var reloaded := tree.current_scene
	assert_not_null(reloaded)
	assert_true(reloaded is Arena)
	assert_true(reloaded != _arena, "a new Arena replaces the old one")
	assert_true(Game.is_playing())
	assert_eq(Game.kills, 0)
	assert_eq(Game.wave, 1)


func _reference_planner() -> WavePlanner:
	var planner := WavePlanner.new(_arena.wave_seed, _arena.playfield.grow(-_arena.spawn_inset))
	planner.base_count = _arena.base_enemies
	planner.growth = _arena.enemies_per_wave
	planner.max_count = _arena.max_enemies_per_wave
	return planner


func _nearest_live_enemy() -> Enemy:
	var best: Enemy = null
	var best_distance := INF
	for node in _arena.enemies():
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive() or enemy.state() == Enemy.STATE_SPAWNING:
			continue
		var distance := enemy.global_position.distance_to(_arena.ship.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func _kill_everything() -> void:
	for node in _arena.enemies():
		var enemy := node as Enemy
		if enemy != null and enemy.is_alive():
			enemy.kill()


func test_clearing_the_field_does_not_strand_the_wave_ladder() -> void:
	# Enemies removed rather than killed report no death, so without telling the
	# session the wave is gone the counter would never reach zero: the ladder
	# would stall and the round could be neither won nor lost.
	assert_true(Game.enemies_left > 0)
	_arena.clear_field()
	await physics_frames(2)
	assert_eq(_arena.enemies().size(), 0, "the field is empty")
	assert_eq(Game.enemies_left, 0, "and the session knows it")
	assert_false(Game.wave_in_progress())
	assert_true(_arena.start_next_wave(), "the ladder can still advance")
	assert_eq(Game.wave, 2)
	assert_eq(Game.enemies_left, _arena.enemies().size())


func test_spawning_into_a_live_wave_keeps_the_counter_honest() -> void:
	var before := Game.enemies_left
	_arena.spawn_enemy(WavePlanner.KIND_DRONE, Vector2(300, 300))
	assert_eq(Game.enemies_left, before + 1, "an extra enemy joins the wave")
	assert_eq(_arena.enemies().size(), Game.enemies_left, "field and counter agree")
