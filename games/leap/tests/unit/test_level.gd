extends GodotGoTest
## The whole level: built from its map, wired to the session, played to a win
## and to a loss.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _level: Level


func before_each() -> void:
	Game.reset()
	_level = add_scene(MAIN_SCENE) as Level
	await tree.physics_frame


func after_each() -> void:
	await free_node(_level)
	if is_instance_valid(tree.current_scene):
		var current := tree.current_scene
		tree.current_scene = null
		await free_node(current)
	Game.reset()


func _goal() -> GoalFlag:
	for child in _level.get_node(^"World").get_children():
		if child is GoalFlag:
			return child
	return null


func _hazard() -> Hazard:
	for child in _level.get_node(^"World").get_children():
		if child is Hazard:
			return child
	return null


func test_the_level_builds_from_its_map_and_starts_a_round() -> void:
	assert_true(Game.is_playing())
	assert_true(_level.grid.width > 0, "the map file parsed")
	assert_eq(Game.goal, _level.coins().size(), "every coin counts toward the objective")
	assert_true(Game.goal > 0)
	assert_almost_eq(Game.time_limit, _level.time_limit)


func test_the_hero_starts_at_the_maps_spawn_point() -> void:
	assert_ne(_level.spawn_point, Vector2.ZERO)
	assert_eq(_level.hero.global_position, _level.spawn_point)


func test_the_level_is_winnable_as_authored() -> void:
	assert_not_null(_goal(), "the map must place a goal flag or the level cannot be finished")
	assert_not_null(_hazard(), "the map places at least one spike")


func test_collecting_a_coin_scores_it() -> void:
	var coin := _level.coins()[0] as Coin
	coin.fire()
	assert_eq(Game.progress, 1)
	assert_eq(Game.score, Game.POINTS_PER_COIN)


func test_a_spent_coin_pays_nothing_after_the_round_ends() -> void:
	Game.lose(Session.REASON_TIME)
	var coin := _level.coins()[0] as Coin
	coin.fire()
	assert_eq(Game.score, 0, "no payout once the round is over")


func test_touching_a_spike_costs_a_life_and_respawns_the_hero() -> void:
	_level.hero.teleport_to(Vector2(1234, 5678))
	_hazard().fire()
	assert_eq(Game.deaths, 1)
	assert_eq(_level.hero.global_position, _level.spawn_point, "respawned at the map's spawn")


func test_falling_below_kill_y_costs_a_life() -> void:
	_level.hero.teleport_to(Vector2(0, _level.kill_y + 100.0))
	await physics_frames(2)
	assert_eq(Game.deaths, 1)
	assert_true(Game.is_playing(), "one death is survivable")


func test_running_out_of_lives_ends_the_round() -> void:
	for i in Game.MAX_DEATHS:
		_hazard().fire()
	assert_eq(Game.state, Session.State.LOST)
	assert_eq(_level.hud.message_text(), HUD.message_for(Session.State.LOST))


func test_reaching_the_flag_wins_whatever_the_coin_tally() -> void:
	_goal().fire()
	assert_eq(Game.state, Session.State.WON)
	assert_true(Game.score > 0, "the time bonus alone scores")
	assert_eq(_level.hud.message_text(), HUD.message_for(Session.State.WON))


func test_the_hud_tracks_the_session() -> void:
	assert_eq(_level.hud.coins_text(), "Coins 0 / %d" % Game.goal)
	assert_eq(_level.hud.lives_text(), "Lives " + "*".repeat(Game.MAX_DEATHS))
	_level.coins()[0].fire()
	assert_eq(_level.hud.coins_text(), "Coins 1 / %d" % Game.goal)
	assert_eq(_level.hud.score_text(), "Score %d" % Game.score)


func test_timeout_loses_the_round() -> void:
	Game.time_left = 0.05
	await physics_frames(6)
	assert_eq(Game.state, Session.State.LOST)


func test_restart_without_a_current_scene_only_resets() -> void:
	assert_null(tree.current_scene)
	_level.restart()
	assert_eq(Game.state, Session.State.READY)
	assert_true(is_instance_valid(_level))


func test_restart_reloads_the_scene_with_a_fresh_round() -> void:
	tree.current_scene = _level
	_level.coins()[0].fire()
	assert_eq(Game.progress, 1)
	_level.restart()
	await tree.process_frame
	await tree.process_frame
	var reloaded := tree.current_scene
	assert_not_null(reloaded)
	assert_true(reloaded is Level)
	assert_true(reloaded != _level)
	assert_true(Game.is_playing())
	assert_eq(Game.progress, 0)
