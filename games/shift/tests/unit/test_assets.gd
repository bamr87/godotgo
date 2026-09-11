extends GodotGoTest
## Import pipeline and project wiring: the generated sprites and sounds, the
## level text files, resource UIDs, the input map and the display settings the
## board layout assumes.


func before_each() -> void:
	Game.reset()


func after_each() -> void:
	Game.reset()


func test_generated_textures_import_as_square_tiles() -> void:
	for name in ["wall", "floor", "target", "crate", "crate_done", "mover"]:
		var texture := load("res://assets/textures/%s.png" % name) as Texture2D
		assert_not_null(texture, name)
		assert_eq(texture.get_size(), Vector2(16, 16), name)


func test_generated_audio_imports_as_wav_streams() -> void:
	for name in ["step", "push", "solved"]:
		var stream := load("res://assets/audio/%s.wav" % name)
		assert_is(stream, AudioStreamWAV, name)
		assert_true(stream.get_length() > 0.0, "%s has audible length" % name)


func test_the_main_scene_assigns_every_board_texture() -> void:
	var level := add_scene(preload("res://scenes/main.tscn")) as Level
	await tree.process_frame
	var board := level.board
	for texture in [
		board.wall_texture,
		board.floor_texture,
		board.target_texture,
		board.crate_texture,
		board.crate_done_texture,
		board.mover_texture
	]:
		assert_not_null(texture, "every board texture is wired in the scene")
	assert_true(board.cell_size >= 8)
	await free_node(level)


func test_level_files_ship_as_readable_text() -> void:
	for number in range(1, LevelBuilder.level_count() + 1):
		var path := LevelBuilder.level_path(number)
		var text := FileAccess.get_file_as_string(path)
		assert_false(text.is_empty(), path)
		assert_true(text.contains(LevelBuilder.PLAYER), "%s has a mover" % path)
		assert_true(text.contains(LevelBuilder.CRATE), "%s has a crate" % path)
		assert_true(text.contains(LevelBuilder.TARGET), "%s has a target" % path)


func test_scenes_carry_uids() -> void:
	for path in ["res://scenes/main.tscn", "res://scenes/ui/hud.tscn"]:
		var id := ResourceLoader.get_resource_uid(path)
		assert_ne(id, ResourceUID.INVALID_ID, "%s has a registered uid" % path)
		assert_eq(ResourceUID.get_id_path(id), path)


func test_project_settings_declare_the_game_wiring() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/main.tscn")
	assert_eq(ProjectSettings.get_setting("autoload/Game"), "*res://scripts/game.gd")
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Shift")
	assert_true(is_instance_valid(Game), "the autoload is instantiated")


func test_every_input_action_the_level_uses_exists() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "undo", "restart"]:
		assert_true(InputMap.has_action(action), action)
	assert_true(InputMap.has_action(&"next_level"))
	for action: StringName in Level.MOVE_ACTIONS:
		assert_true(InputMap.has_action(action), "%s is bound" % action)


func test_movement_is_bound_to_both_wasd_and_the_arrow_keys() -> void:
	var codes: Array[int] = []
	for event in InputMap.action_get_events(&"move_up"):
		if event is InputEventKey:
			codes.append((event as InputEventKey).physical_keycode)
	assert_true(codes.has(KEY_W), "W")
	assert_true(codes.has(KEY_UP), "up arrow")


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
