extends GodotGoTest
## The real main scene, driven the way a player drives it: keys in, board, HUD
## and save file out.
##
## The scene's own [ProgressStore] is swapped for a scratch slot before anything
## can be solved, so a test run never rewrites the best scores of whoever is
## actually playing this game.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SLOT := "shift-test-level"
## Solves level 1. Level 1 exists to be short enough to type into a test.
const LEVEL_1_SOLUTION := "URDRUU"

const LETTERS := {
	"U": Puzzle.UP,
	"D": Puzzle.DOWN,
	"L": Puzzle.LEFT,
	"R": Puzzle.RIGHT,
}

var _level: Level


func before_each() -> void:
	Game.reset()
	SaveSystem.erase(SLOT)
	_level = add_scene(MAIN_SCENE) as Level
	await tree.process_frame
	_level.progress_store = ProgressStore.new(SLOT)
	_level.load_level(1)


func after_each() -> void:
	# Silence first, then give the audio server a moment of real time: it retires
	# a stopped playback on its next mix, and a level freed before that happens
	# leaves the playback (and its sample) alive until the process exits.
	_level.silence()
	await tree.create_timer(0.05).timeout
	await free_node(_level)
	SaveSystem.erase(SLOT)
	Game.reset()


## Plays a move-letter string through the scene's own input path.
func play(moves: String) -> void:
	for letter in moves:
		var direction: Vector2i = LETTERS[letter]
		_level.try_move(direction)


## Sends an action press the way the OS would, so _unhandled_input is exercised
## rather than bypassed.
func press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await tree.process_frame


func test_the_scene_opens_the_first_level() -> void:
	assert_true(Game.is_playing())
	assert_eq(_level.level_number, 1)
	assert_eq(_level.level_id(), "level_1")
	assert_eq(Game.goal, _level.puzzle.crate_count(), "every crate is one objective unit")
	assert_eq(Game.time_limit, 0.0, "no countdown, by design")
	assert_eq(_level.hud.title_text(), "Shift")
	assert_eq(_level.hud.level_text(), "Level 1/4 - First Push")
	assert_eq(_level.hud.moves_text(), "Moves 0")
	assert_eq(_level.hud.best_text(), "Best -")


func test_the_scene_has_no_physics_bodies_at_all() -> void:
	var bodies := 0
	for node in _descendants(_level):
		if node is PhysicsBody2D or node is Area2D or node is CollisionObject2D:
			bodies += 1
	assert_eq(bodies, 0, "a grid puzzle proves the framework is not physics-bound")


func test_the_board_view_draws_the_whole_grid() -> void:
	var puzzle := _level.puzzle
	var cells := puzzle.size.x * puzzle.size.y
	var expected := cells + puzzle.target_count() + puzzle.crate_count() + 1
	assert_eq(_level.board.sprite_count(), expected, "one per cell, plus targets, crates and mover")
	assert_eq(_level.board.mover_cell(), puzzle.player)


func test_a_move_updates_the_puzzle_the_session_and_the_view() -> void:
	var before := _level.puzzle.player
	assert_true(_level.try_move(Puzzle.UP))
	assert_eq(_level.puzzle.player, before + Puzzle.UP)
	assert_eq(Game.moves, 1)
	assert_eq(_level.hud.moves_text(), "Moves 1")
	assert_eq(_level.board.mover_cell(), _level.puzzle.player, "the view followed the puzzle")


func test_a_refused_move_costs_nothing() -> void:
	assert_false(_level.try_move(Puzzle.DOWN), "a wall is below the start cell")
	assert_eq(Game.moves, 0)
	assert_eq(_level.hud.moves_text(), "Moves 0")


func test_a_push_onto_a_target_shows_up_in_the_hud() -> void:
	play(LEVEL_1_SOLUTION.substr(0, 5))
	assert_eq(_level.hud.crates_text(), "Crates 0 / 1")
	assert_true(_level.try_move(Puzzle.UP), "the last push")
	assert_eq(_level.hud.crates_text(), "Crates 1 / 1")


func test_undo_takes_back_the_move_and_the_count() -> void:
	_level.try_move(Puzzle.UP)
	_level.try_move(Puzzle.RIGHT)
	assert_eq(Game.moves, 2)
	assert_true(_level.undo_move())
	assert_eq(Game.moves, 1)
	assert_eq(_level.puzzle.move_count(), 1, "session and puzzle stay in step")
	assert_eq(_level.board.mover_cell(), _level.puzzle.player)


func test_undo_at_the_start_of_a_level_does_nothing() -> void:
	assert_false(_level.undo_move())
	assert_eq(Game.moves, 0)


func test_restart_puts_the_level_back_without_reloading_the_scene() -> void:
	var start := LevelBuilder.to_text(_level.puzzle)
	play("URD")
	assert_ne(LevelBuilder.to_text(_level.puzzle), start)
	_level.restart_level()
	assert_eq(LevelBuilder.to_text(_level.puzzle), start)
	assert_eq(Game.moves, 0)
	assert_eq(_level.hud.moves_text(), "Moves 0")
	assert_true(Game.is_playing())
	assert_true(is_instance_valid(_level), "the scene itself is never reloaded")


func test_solving_the_level_wins_the_round_and_saves_a_best() -> void:
	var won := record(Game.won)
	play(LEVEL_1_SOLUTION)
	assert_true(_level.puzzle.is_solved())
	assert_eq(Game.state, Session.State.WON)
	assert_eq(won.size(), 1)
	assert_eq(_level.hud.message_text(), HUD.message_for(Session.State.WON))
	assert_eq(_level.progress_store.best_moves("level_1"), LEVEL_1_SOLUTION.length())
	assert_eq(_level.hud.best_text(), "Best %d moves" % LEVEL_1_SOLUTION.length())
	assert_true(SaveSystem.has_slot(SLOT), "and it is on disk, not just in memory")


func test_a_sloppier_replay_keeps_the_better_best() -> void:
	play(LEVEL_1_SOLUTION)
	_level.restart_level()
	play("LR" + LEVEL_1_SOLUTION)
	assert_true(_level.puzzle.is_solved(), "two wasted moves still solve it")
	assert_eq(Game.moves, LEVEL_1_SOLUTION.length() + 2)
	assert_eq(
		_level.progress_store.best_moves("level_1"),
		LEVEL_1_SOLUTION.length(),
		"the tidier solve still stands"
	)


func test_a_solved_board_takes_no_more_input() -> void:
	play(LEVEL_1_SOLUTION)
	var settled := LevelBuilder.to_text(_level.puzzle)
	assert_false(_level.try_move(Puzzle.LEFT))
	assert_false(_level.undo_move())
	assert_eq(LevelBuilder.to_text(_level.puzzle), settled)
	assert_eq(Game.moves, LEVEL_1_SOLUTION.length())


func test_next_level_is_refused_until_the_board_is_solved() -> void:
	assert_false(_level.next_level(), "N is not a skip button")
	assert_eq(_level.level_number, 1)


func test_next_level_loads_the_following_board() -> void:
	play(LEVEL_1_SOLUTION)
	assert_true(_level.next_level())
	assert_eq(_level.level_number, 2)
	assert_eq(_level.level_id(), "level_2")
	assert_eq(_level.hud.level_text(), "Level 2/4 - Twin Crates")
	assert_eq(Game.goal, 2, "level 2 has two crates")
	assert_eq(Game.moves, 0, "a fresh round")
	assert_true(Game.is_playing())
	assert_eq(_level.board.mover_cell(), _level.puzzle.player, "and a redrawn board")


func test_next_level_wraps_past_the_last_one() -> void:
	_level.load_level(LevelBuilder.level_count())
	# Win without playing it out: the wrap is what is under test, not level 4.
	Game.set_crates_placed(Game.goal)
	assert_true(_level.next_level())
	assert_eq(_level.level_number, 1)


func test_loading_a_level_shows_its_stored_best() -> void:
	play(LEVEL_1_SOLUTION)
	_level.load_level(2)
	assert_eq(_level.hud.best_text(), "Best -", "level 2 has never been solved")
	_level.load_level(1)
	assert_eq(_level.hud.best_text(), "Best %d moves" % LEVEL_1_SOLUTION.length())


func test_the_board_sits_beside_the_hud_rather_than_under_it() -> void:
	assert_true(
		_level.board.position.x >= _level.board_margin_left,
		"board starts at x=%s" % _level.board.position.x
	)
	var extent := _level.board.board_size()
	assert_true(extent.x > 0.0 and extent.y > 0.0)
	assert_true(
		_level.board.position.y + extent.y <= 540.0, "and fits inside the 960 x 540 viewport"
	)


func test_the_move_actions_reach_the_level_through_unhandled_input() -> void:
	await press(&"move_up")
	assert_eq(Game.moves, 1, "arrow keys and WASD both map to move_up")
	assert_eq(_level.puzzle.player, Vector2i(2, 3))
	await press(&"undo")
	assert_eq(Game.moves, 0)


func test_the_restart_action_reaches_the_level() -> void:
	play("URD")
	await press(&"restart")
	assert_eq(Game.moves, 0)
	assert_eq(LevelBuilder.to_text(_level.puzzle), LevelBuilder.to_text(LevelBuilder.load_level(1)))


func _descendants(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		found.append(child)
		found.append_array(_descendants(child))
	return found


func test_wedging_a_crate_loses_the_round_instead_of_leaving_it_unwinnable() -> void:
	# Replace the loaded board with one that is a single push from a deadlock.
	_level.puzzle = LevelBuilder.parse(TextGrid.parse("#####\n#.$@#\n#...#\n#*..#\n#####"))
	_level.puzzle.moved.connect(_level._on_puzzle_moved)
	_level.board.render(_level.puzzle)
	Game.start(_level.puzzle.crate_count(), 0.0)
	Game.seed_crates_placed(_level.puzzle.crates_on_targets())
	var lost := record(Game.lost)

	assert_true(_level.try_move(Puzzle.LEFT), "the push is legal")
	assert_true(_level.puzzle.is_deadlocked())
	assert_eq(Game.state, Session.State.LOST)
	assert_eq(lost[0][0], Game.REASON_STUCK)
	assert_eq(_level.hud.message_text(), HUD.message_for(Session.State.LOST))
	assert_false(_level.try_move(Puzzle.DOWN), "a lost round takes no more moves")
