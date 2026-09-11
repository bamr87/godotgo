extends GodotGoTest
## The custom Resource type and its hand-written .tres instance.

const ARENA_CONFIG := preload("res://resources/arena_config.tres")


func test_arena_config_is_a_level_config_with_designed_values() -> void:
	assert_is(ARENA_CONFIG, LevelConfig)
	assert_eq(ARENA_CONFIG.title, "Orb Run")
	assert_almost_eq(ARENA_CONFIG.time_limit, 90.0)
	assert_almost_eq(ARENA_CONFIG.kill_y, -10.0)
	assert_almost_eq(ARENA_CONFIG.land_sound_min_fall_speed, 6.0)


func test_defaults_are_sane() -> void:
	var config := LevelConfig.new()
	assert_true(config.time_limit > 0.0)
	assert_true(config.kill_y < 0.0)
	assert_false(config.title.is_empty())


func test_resource_round_trips_through_text_format() -> void:
	var config := LevelConfig.new()
	config.title = "Round trip"
	config.time_limit = 12.5
	var path := "user://level_config_roundtrip.tres"
	assert_eq(ResourceSaver.save(config, path), OK)
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as LevelConfig
	assert_not_null(loaded)
	assert_eq(loaded.title, "Round trip")
	assert_almost_eq(loaded.time_limit, 12.5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
