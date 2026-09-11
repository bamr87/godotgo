extends GodotGoTest
## End-to-end round in the real main scene: wiring, physics pickups, the exit
## gate, respawn, timeout, landing audio and restart.

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


func test_round_starts_from_scene_contents() -> void:
	assert_true(Game.is_playing())
	assert_eq(Game.goal, 5)
	assert_eq(_level.get_orbs().size(), 5)
	assert_almost_eq(Game.time_limit, _level.config.time_limit)
	assert_eq(_level.hud.title_text(), _level.config.title)
	assert_eq(_level.hud.orbs_text(), "Orbs 0 / 5")
	assert_false(_level.exit_portal.active)


func test_scene_uses_both_material_maker_exports() -> void:
	var ground := _level.get_node(^"Ground/MeshInstance3D") as MeshInstance3D
	var platform := _level.get_node(^"Platforms/Platform1/MeshInstance3D") as MeshInstance3D
	assert_true(ground.get_surface_override_material(0).resource_path.ends_with("starter_pbr.tres"))
	assert_true(platform.get_surface_override_material(0).resource_path.ends_with("metal.tres"))
	assert_eq(_level.get_node(^"Platforms").get_child_count(), 3)


func test_collecting_every_orb_opens_the_exit_and_reaching_it_wins() -> void:
	var won := record(Game.won)
	for orb in _level.get_orbs():
		orb.collect()
	assert_true(Game.objective_complete())
	assert_true(_level.exit_portal.active, "exit opens once all orbs are collected")
	assert_eq(_level.hud.orbs_text(), "Orbs 5 / 5")
	_level.player.global_position = _level.exit_portal.global_position + Vector3(0, 0.1, 0)
	await physics_frames(3)
	assert_eq(Game.state, Session.State.WON)
	assert_eq(won.size(), 1)
	assert_eq(_level.hud.message_text(), HUD.message_for(Session.State.WON))


func test_exit_stays_closed_until_every_orb_is_collected() -> void:
	_level.get_orbs()[0].collect()
	_level.player.global_position = _level.exit_portal.global_position + Vector3(0, 0.1, 0)
	await physics_frames(3)
	assert_true(Game.is_playing())
	assert_false(_level.exit_portal.active)


func test_touching_an_orb_collects_it_through_physics_and_plays_audio() -> void:
	var orb := _level.get_orbs()[0]
	_level.player.global_position = orb.global_position - Vector3(0, 0.8, 0)
	await physics_frames(3)
	assert_eq(Game.progress, 1)
	assert_true(orb.is_collected())
	var pickup := _level.get_node(^"PickupSound") as AudioStreamPlayer
	assert_not_null(pickup.stream)


func test_falling_below_kill_y_respawns_at_spawn_point() -> void:
	_level.player.global_position = Vector3(3, _level.config.kill_y - 1.0, 3)
	await physics_frames(2)
	var spawn := _level.spawn_point.global_position
	assert_true(_level.player.global_position.distance_to(spawn) < 0.5, "player back at spawn")


func test_hard_landing_reports_fall_speed_above_threshold() -> void:
	var lands := record(_level.player.landed)
	_level.player.global_position = _level.spawn_point.global_position + Vector3(0, 7.5, 0)
	for i in 240:
		await tree.physics_frame
		if not lands.is_empty():
			break
	assert_eq(lands.size(), 1, "landed should fire once after the drop")
	assert_true(
		lands[0][0] >= _level.config.land_sound_min_fall_speed, "fall speed %s" % str(lands[0][0])
	)


func test_timeout_loses_the_round() -> void:
	var lost := record(Game.lost)
	Game.time_left = 0.05
	await physics_frames(6)
	assert_eq(Game.state, Session.State.LOST)
	assert_eq(lost.size(), 1)
	assert_eq(_level.hud.message_text(), HUD.message_for(Session.State.LOST))


func test_restart_without_a_current_scene_only_resets() -> void:
	assert_null(tree.current_scene)
	_level.restart()
	assert_eq(Game.state, Session.State.READY)
	assert_true(is_instance_valid(_level), "level is left in place")


func test_restart_reloads_the_scene_with_a_fresh_round() -> void:
	tree.current_scene = _level
	Game.collect_orb()
	assert_eq(Game.progress, 1)
	_level.restart()
	await tree.process_frame
	await tree.process_frame
	var reloaded := tree.current_scene
	assert_not_null(reloaded)
	assert_true(reloaded is Level)
	assert_true(reloaded != _level, "a new Level instance replaces the old one")
	assert_true(Game.is_playing())
	assert_eq(Game.progress, 0)
	assert_eq(Game.goal, 5)
