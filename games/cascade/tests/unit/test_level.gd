extends GodotGoTest
## The real main scene, driven the way a player drives it: a cell in, and a
## board, a HUD and a save file out.
##
## The scene's own [ScoreStore] is swapped for a scratch slot before anything can
## be finished, so a test run never rewrites the records of whoever is actually
## playing this game.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SLOT := "cascade-test-level"

var _level: Level


func before_each() -> void:
	Game.reset()
	SaveSystem.erase(SLOT)
	_level = add_scene(MAIN_SCENE) as Level
	await tree.process_frame
	_level.score_store = ScoreStore.new(SLOT)
	_level.load_level(1)


func after_each() -> void:
	# Silence first, then give the audio server a moment of real time: it retires
	# a stopped playback on its next mix, and a level freed before that happens
	# leaves the playback (and its sample) alive until the process exits.
	_level.silence()
	await tree.create_timer(0.05).timeout
	await free_node(_level)
	_level = null
	SaveSystem.erase(SLOT)
	Game.reset()


## The first cell on the board with a legal pop in it, or (-1, -1) when the board
## has jammed.
func first_poppable() -> Vector2i:
	for y in _level.board.size.y:
		for x in _level.board.size.x:
			var cell := Vector2i(x, y)
			if _level.board.can_pop(cell):
				return cell
	return Vector2i(-1, -1)


## Pops greedily until the board jams, landing each animation so the next pop is
## accepted. Reading order rather than anything clever: the point is to reach an
## ending, not to play well.
func play_out() -> void:
	for step in 500:
		if not Game.is_playing():
			return
		var cell := first_poppable()
		if cell.x < 0:
			return
		_level.try_pop(cell)
		_level.board_view.finish_animation()


## Sends an action press the way the OS would, so _unhandled_input is exercised
## rather than bypassed.
func press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await tree.process_frame


func test_the_scene_opens_a_round_sized_to_the_board() -> void:
	assert_true(Game.is_playing())
	assert_eq(_level.level_number, 1)
	assert_eq(_level.level_id(), LevelBuilder.level_id(1))
	assert_eq(Game.goal, Level.goal_for(_level.board.remaining(), _level.target_ratio))
	assert_eq(_level.hud.cleared_text(), "Cleared 0 / %d" % Game.goal)
	assert_eq(
		_level.hud.level_text(),
		"Level 1/%d - %s" % [LevelBuilder.level_count(), LevelBuilder.level_name(1)]
	)


func test_the_target_is_a_share_of_the_board_rounded_up() -> void:
	assert_eq(Level.goal_for(48, 0.7), 34)
	assert_eq(Level.goal_for(10, 1.0), 10)
	assert_eq(Level.goal_for(10, 0.0), 1, "a target of zero could never be missed")
	assert_eq(Level.goal_for(0, 0.7), 1, "and nor could one on an empty board")


func test_the_view_draws_the_board_the_level_loaded() -> void:
	assert_eq(_level.board_view.tile_count(), _level.board.remaining())
	_level.load_level(2)
	assert_eq(_level.board_view.tile_count(), _level.board.remaining())
	assert_eq(_level.level_number, 2)


func test_a_pop_scores_through_the_session() -> void:
	var cell := first_poppable()
	var expected := _level.board.group_at(cell).size()
	assert_true(expected >= Board.MIN_GROUP)
	assert_eq(_level.try_pop(cell), expected)
	assert_eq(Game.progress, expected, "tiles cleared, not groups popped")
	assert_eq(Game.score, Game.score_for(expected))
	assert_eq(Game.pops, 1)
	assert_eq(_level.hud.score_text(), "Score %d" % Game.score)


func test_a_second_pop_is_refused_until_the_board_settles() -> void:
	_level.try_pop(first_poppable())
	assert_false(_level.board_view.is_idle())
	var banked := Game.score
	assert_eq(_level.try_pop(first_poppable()), 0, "the board is still moving")
	assert_eq(Game.score, banked)
	assert_eq(Game.pops, 1)
	_level.board_view.finish_animation()
	assert_true(_level.try_pop(first_poppable()) > 0, "and accepted once it lands")


func test_popping_nothing_changes_nothing() -> void:
	assert_eq(_level.try_pop(Vector2i(-1, -1)), 0, "off the board")
	assert_eq(_level.try_pop(Vector2i(999, 999)), 0)
	assert_eq(Game.score, 0)
	assert_eq(Game.pops, 0)
	assert_true(Game.is_playing())


func test_playing_a_board_out_ends_the_round_and_files_the_result() -> void:
	play_out()
	assert_true(Game.is_over(), "a board with no legal pop left is finished")
	assert_true(_level.board.is_stuck())
	var id := _level.level_id()
	assert_true(_level.score_store.has_record(id))
	assert_eq(_level.score_store.best_score(id), Game.score)
	assert_eq(_level.score_store.best_pop(id), Game.best_pop)
	assert_true(SaveSystem.has_slot(SLOT), "and it is on disk, not just in memory")


func test_the_first_level_can_be_beaten() -> void:
	# Level 1 is the teaching board: solid blocks, and clearing it needs no
	# foresight at all. If reading-order greedy play cannot pass its target, the
	# level is too hard to open a game with.
	play_out()
	assert_eq(Game.state, Session.State.WON)
	assert_true(Game.progress >= Game.goal)


func test_the_next_level_is_locked_until_the_board_is_beaten() -> void:
	assert_false(_level.next_level(), "not while the round is still running")
	assert_eq(_level.level_number, 1)
	play_out()
	assert_true(_level.next_level())
	assert_eq(_level.level_number, 2)
	assert_true(Game.is_playing(), "and the next board starts fresh")
	assert_eq(Game.score, 0)


func test_the_last_level_wraps_round_to_the_first() -> void:
	_level.load_level(LevelBuilder.level_count())
	play_out()
	if Game.state == Session.State.WON:
		assert_true(_level.next_level())
		assert_eq(_level.level_number, 1)


func test_restarting_rebuilds_the_very_same_board() -> void:
	var opening := _level.board.cells()
	_level.try_pop(first_poppable())
	_level.board_view.finish_animation()
	assert_ne(_level.board.cells(), opening)
	_level.restart_level()
	assert_eq(_level.board.cells(), opening, "the same level, not a new one")
	assert_eq(Game.score, 0)
	assert_eq(Game.pops, 0)
	assert_true(Game.is_playing())


func test_a_seeded_level_restarts_identically_too() -> void:
	var seeded := LevelBuilder.level_count()
	assert_true(LevelBuilder.is_generated(seeded), "the last level is a seed")
	_level.load_level(seeded)
	var opening := _level.board.cells()
	_level.try_pop(first_poppable())
	_level.board_view.finish_animation()
	_level.restart_level()
	assert_eq(_level.board.cells(), opening, "a restart is a retry, not a new board")


func test_the_restart_key_reaches_the_level() -> void:
	_level.try_pop(first_poppable())
	_level.board_view.finish_animation()
	assert_true(Game.score > 0)
	await press(&"restart")
	assert_eq(Game.score, 0, "the action went through _unhandled_input")
	assert_true(Game.is_playing())


func test_the_cursor_stays_on_the_board() -> void:
	assert_eq(_level.move_cursor_to(Vector2i(-5, -5)), Vector2i.ZERO)
	var last := Vector2i(_level.board.size.x - 1, _level.board.size.y - 1)
	assert_eq(_level.move_cursor_to(Vector2i(999, 999)), last)
	assert_eq(_level.cursor, last)


func test_the_arrow_keys_step_the_cursor() -> void:
	_level.move_cursor_to(Vector2i.ZERO)
	await press(&"move_right")
	assert_eq(_level.cursor, Vector2i(1, 0))
	await press(&"move_down")
	assert_eq(_level.cursor, Vector2i(1, 1))
	await press(&"move_up")
	await press(&"move_left")
	assert_eq(_level.cursor, Vector2i.ZERO)
	await press(&"move_left")
	assert_eq(_level.cursor, Vector2i.ZERO, "and hold at the edge rather than wrapping")


func test_the_pop_key_takes_the_group_the_cursor_is_in() -> void:
	var cell := first_poppable()
	_level.move_cursor_to(cell)
	var expected := _level.board.group_at(cell).size()
	await press(&"pop")
	assert_eq(Game.progress, expected, "the keyboard plays the game with no pointer")
	assert_eq(Game.pops, 1)


func test_loading_a_smaller_board_pulls_the_cursor_onto_it() -> void:
	_level.load_level(3)
	_level.move_cursor_to(Vector2i(999, 999))
	assert_true(_level.cursor.y > 5, "level 3 is the tall one")
	_level.load_level(1)
	assert_true(_level.cursor.x < _level.board.size.x, "still on the board")
	assert_true(_level.cursor.y < _level.board.size.y)


func test_a_level_number_out_of_range_clamps() -> void:
	_level.load_level(99)
	assert_eq(_level.level_number, LevelBuilder.level_count())
	_level.load_level(0)
	assert_eq(_level.level_number, 1)


func test_the_hud_column_never_runs_under_the_board() -> void:
	for number in range(1, LevelBuilder.level_count() + 1):
		_level.load_level(number)
		await tree.process_frame
		assert_true(
			_level.hud.panel_width() <= _level.board_view.position.x,
			"level %d: the board starts clear of the HUD text" % number
		)


func test_the_board_is_centred_in_the_space_left_beside_the_hud() -> void:
	for number in range(1, LevelBuilder.level_count() + 1):
		_level.load_level(number)
		var origin := _level.board_view.position
		var extent := _level.board_view.board_size()
		var view := _level.get_viewport_rect().size
		assert_true(origin.x >= _level.board_margin_left, "level %d clears the HUD" % number)
		assert_true(origin.x + extent.x <= view.x, "level %d fits across" % number)
		assert_true(origin.y >= 0.0, "level %d fits from the top" % number)
		assert_true(origin.y + extent.y <= view.y, "level %d fits to the bottom" % number)
