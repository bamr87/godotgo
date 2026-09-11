extends GodotGoTest
## Import pipeline and project wiring: the generated tiles and sounds, the level
## text files, resource UIDs, the input map and the display settings the board
## layout assumes.

const MAIN_SCENE := preload("res://scenes/main.tscn")


func before_each() -> void:
	Game.reset()


func after_each() -> void:
	Game.reset()


func test_generated_tiles_import_as_square_sprites() -> void:
	for symbol in LevelBuilder.COLOUR_SYMBOLS:
		var texture := load("res://assets/textures/tile_%s.png" % symbol) as Texture2D
		assert_not_null(texture, symbol)
		assert_eq(texture.get_size(), Vector2(16, 16), symbol)


func test_generated_audio_imports_as_wav_streams() -> void:
	for sound in ["pop", "fall", "clear"]:
		var stream := load("res://assets/audio/%s.wav" % sound)
		assert_is(stream, AudioStreamWAV, sound)
		assert_true(stream.get_length() > 0.0, "%s has audible length" % sound)


func test_the_main_scene_has_a_tile_for_every_colour() -> void:
	var level := add_scene(MAIN_SCENE) as Level
	await tree.process_frame
	var view := level.board_view
	assert_eq(
		view.colour_textures.size(),
		LevelBuilder.COLOUR_SYMBOLS.length(),
		"one texture per symbol the level files may use"
	)
	for colour in view.colour_textures.size():
		assert_not_null(view.texture_for(colour), "colour %d" % colour)
	assert_true(view.cell_size >= 8)
	level.silence()
	await free_node(level)


func test_the_tile_pool_is_wired_and_uncapped() -> void:
	var level := add_scene(MAIN_SCENE) as Level
	await tree.process_frame
	var pool := level.board_view.pool
	assert_not_null(pool.scene, "the pool has a tile scene to instance")
	assert_eq(pool.max_size, 0, "a cap here would leave real tiles undrawn")
	assert_true(pool.initial_size > 0, "and the first board does not allocate")
	level.silence()
	await free_node(level)


func test_the_pool_prewarms_for_the_largest_shipped_board() -> void:
	var largest := 0
	for number in range(1, LevelBuilder.level_count() + 1):
		largest = maxi(largest, LevelBuilder.load_level(number).remaining())
	var level := add_scene(MAIN_SCENE) as Level
	await tree.process_frame
	assert_true(
		level.board_view.pool.initial_size >= largest,
		"the pool is prewarmed for %d tiles" % largest
	)
	level.silence()
	await free_node(level)


func test_level_files_ship_as_readable_text() -> void:
	for number in range(1, LevelBuilder.level_count() + 1):
		if LevelBuilder.is_generated(number):
			continue
		var path := LevelBuilder.level_path(number)
		var text := FileAccess.get_file_as_string(path)
		assert_false(text.is_empty(), path)
		assert_true(text.contains(LevelBuilder.COLOUR_SYMBOLS[0]), "%s has tiles" % path)


func test_scenes_carry_uids() -> void:
	for path in ["res://scenes/main.tscn", "res://scenes/ui/hud.tscn", "res://scenes/tile.tscn"]:
		var id := ResourceLoader.get_resource_uid(path)
		assert_ne(id, ResourceUID.INVALID_ID, "%s has a registered uid" % path)
		assert_eq(ResourceUID.get_id_path(id), path)


func test_project_settings_declare_the_game_wiring() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/main.tscn")
	assert_eq(ProjectSettings.get_setting("autoload/Game"), "*res://scripts/game.gd")
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Cascade")
	assert_true(is_instance_valid(Game), "the autoload is instantiated")


func test_every_input_action_the_level_uses_exists() -> void:
	for action in ["pop", "restart", "next_level"]:
		assert_true(InputMap.has_action(action), action)
	for action: StringName in Level.CURSOR_ACTIONS:
		assert_true(InputMap.has_action(action), "%s is bound" % action)


func test_the_cursor_is_bound_to_both_wasd_and_the_arrow_keys() -> void:
	var codes: Array[int] = []
	for event in InputMap.action_get_events(&"move_up"):
		if event is InputEventKey:
			codes.append((event as InputEventKey).physical_keycode)
	assert_true(codes.has(KEY_W), "W")
	assert_true(codes.has(KEY_UP), "up arrow")


func test_popping_is_bound_to_the_mouse_and_to_a_key() -> void:
	var mouse := false
	var keyboard := false
	for event in InputMap.action_get_events(&"pop"):
		mouse = mouse or event is InputEventMouseButton
		keyboard = keyboard or event is InputEventKey
	assert_true(mouse, "clicking a group is the point")
	assert_true(keyboard, "and a key so the game is playable without one")


func test_the_viewport_is_the_size_the_board_layout_assumes() -> void:
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_width")), 960)
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_height")), 540)
	assert_eq(
		int(
			ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")
		),
		0,
		"nearest-neighbour, so 16 px tiles stay crisp when scaled up"
	)
