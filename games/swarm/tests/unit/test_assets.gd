extends GodotGoTest
## Import pipeline and project wiring: the generated art and audio, the
## autoload, the input map, the physics layer names and the hand-written uids.


func test_generated_textures_import_at_their_authored_size() -> void:
	var sizes := {"ship": 20, "drone": 18, "brute": 26, "bullet": 8, "spawn_ring": 28}
	for name in sizes:
		var texture := load("res://assets/textures/%s.png" % name) as Texture2D
		assert_not_null(texture, name)
		assert_eq(texture.get_size(), Vector2(sizes[name], sizes[name]), name)


func test_generated_audio_imports_as_wav_streams() -> void:
	for name in ["shoot", "hit", "wave"]:
		var stream := load("res://assets/audio/%s.wav" % name)
		assert_is(stream, AudioStreamWAV, name)
		assert_true(stream.get_length() > 0.05, "%s has an audible length" % name)


func test_project_settings_declare_the_game_wiring() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/main.tscn")
	assert_eq(ProjectSettings.get_setting("autoload/Game"), "*res://scripts/game.gd")
	assert_is(Game, Session, "the game's autoload extends the framework session")
	assert_true(is_instance_valid(Game), "the autoload is instantiated")


func test_the_input_map_covers_movement_and_firing() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "fire", "restart"]:
		assert_true(InputMap.has_action(action), action)
	var mouse_trigger := false
	for event in InputMap.action_get_events(&"fire"):
		mouse_trigger = mouse_trigger or event is InputEventMouseButton
	assert_true(mouse_trigger, "the trigger is the left mouse button")


func test_physics_layer_names_follow_the_workspace_convention() -> void:
	var expected := [
		"world", "player", "pickups", "triggers", "enemies", "player_bullets", "enemy_bullets"
	]
	for i in expected.size():
		var key := "layer_names/2d_physics/layer_%d" % (i + 1)
		assert_eq(ProjectSettings.get_setting(key), expected[i], key)


func test_scenes_and_resources_carry_registered_uids() -> void:
	for path in [
		"res://scenes/main.tscn",
		"res://scenes/ship.tscn",
		"res://scenes/enemy.tscn",
		"res://scenes/bullet.tscn",
		"res://scenes/ui/hud.tscn",
		"res://resources/drone.tres",
		"res://resources/brute.tres"
	]:
		var id := ResourceLoader.get_resource_uid(path)
		assert_ne(id, ResourceUID.INVALID_ID, "%s has a uid" % path)
		assert_eq(ResourceUID.get_id_path(id), path)


func test_the_stats_resources_load_with_their_art() -> void:
	for stem in ["drone", "brute"]:
		var stats := load("res://resources/%s.tres" % stem) as EnemyStats
		assert_not_null(stats, stem)
		assert_eq(stats.kind, StringName(stem))
		assert_not_null(stats.texture, "%s texture" % stem)
		assert_true(stats.max_health >= 1, stem)
		assert_true(stats.score_value > 0, stem)
		assert_true(stats.spawn_time > 0.0, "%s telegraphs before it is dangerous" % stem)
