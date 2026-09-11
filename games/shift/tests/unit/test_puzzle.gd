extends GodotGoTest
## Every rule of the game, asserted directly against [Puzzle].
##
## Not one test here instantiates a node, which is the whole argument for keeping
## the rules out of the scene: a board is three lines of ASCII and a move is a
## function call, so the awkward cases are cheap enough that all of them get
## covered instead of just the happy path.


func before_each() -> void:
	Game.reset()


func after_each() -> void:
	Game.reset()


## Builds a board from an inline map, the same parser the shipped levels use.
func board(text: String) -> Puzzle:
	return LevelBuilder.parse(TextGrid.parse(text))


func test_walking_onto_floor_moves_the_mover() -> void:
	var puzzle := board("#####\n#@..#\n#####")
	assert_true(puzzle.move(Puzzle.RIGHT))
	assert_eq(puzzle.player, Vector2i(2, 1))
	assert_eq(puzzle.move_count(), 1)


func test_walking_into_a_wall_is_refused() -> void:
	var puzzle := board("#####\n#@..#\n#####")
	assert_false(puzzle.move(Puzzle.LEFT), "a wall is to the left")
	assert_false(puzzle.move(Puzzle.UP), "and above")
	assert_eq(puzzle.player, Vector2i(1, 1), "a refused move changes nothing")
	assert_eq(puzzle.move_count(), 0, "and is not recorded in the history")


func test_walking_off_the_board_is_refused() -> void:
	# No wall border at all: the board edge has to block on its own.
	var puzzle := board("@..\n...")
	assert_false(puzzle.move(Puzzle.LEFT))
	assert_false(puzzle.move(Puzzle.UP))
	assert_true(puzzle.is_wall(Vector2i(-1, 0)), "outside the board counts as solid")
	assert_true(puzzle.is_wall(Vector2i(3, 0)))


func test_only_the_four_orthogonal_directions_are_accepted() -> void:
	var puzzle := board("#####\n#@..#\n#####")
	assert_false(puzzle.move(Vector2i.ZERO), "standing still is not a move")
	assert_false(puzzle.move(Vector2i(1, 1)), "no diagonals")
	assert_false(puzzle.move(Vector2i(2, 0)), "no two-cell leaps")
	assert_eq(puzzle.move_count(), 0)


func test_pushing_a_crate_moves_both() -> void:
	var puzzle := board("#######\n#@$..*#\n#######")
	assert_true(puzzle.move(Puzzle.RIGHT))
	assert_eq(puzzle.player, Vector2i(2, 1))
	assert_true(puzzle.has_crate(Vector2i(3, 1)), "the crate moved one cell ahead")
	assert_false(puzzle.has_crate(Vector2i(2, 1)), "and left the cell behind it")


func test_pushing_a_crate_into_a_wall_is_refused() -> void:
	var puzzle := board("#######\n#@$#.*#\n#######")
	assert_false(puzzle.move(Puzzle.RIGHT))
	assert_eq(puzzle.player, Vector2i(1, 1))
	assert_true(puzzle.has_crate(Vector2i(2, 1)), "the crate stayed put")


func test_pushing_two_crates_is_refused() -> void:
	var puzzle := board("#########\n#@$$.*.*#\n#########")
	assert_false(puzzle.move(Puzzle.RIGHT), "a mover shoves one crate, never a train")
	assert_true(puzzle.has_crate(Vector2i(2, 1)))
	assert_true(puzzle.has_crate(Vector2i(3, 1)))


func test_standing_on_a_target_is_allowed() -> void:
	var puzzle := board("#######\n#@*$.*#\n#######")
	assert_true(puzzle.move(Puzzle.RIGHT), "a target is floor a mover may occupy")
	assert_eq(puzzle.player, Vector2i(2, 1))
	assert_true(puzzle.is_target(puzzle.player))
	assert_eq(puzzle.crates_on_targets(), 0, "the mover is not a crate")


func test_pushing_a_crate_onto_a_target_counts_it() -> void:
	var puzzle := board("#######\n#@$*..#\n#######")
	assert_eq(puzzle.crates_on_targets(), 0)
	assert_true(puzzle.move(Puzzle.RIGHT))
	assert_eq(puzzle.crates_on_targets(), 1)
	assert_true(puzzle.is_solved())


func test_pushing_a_crate_off_a_target_uncounts_it() -> void:
	var puzzle := board("#######\n#@.+..#\n#######")
	assert_eq(puzzle.crates_on_targets(), 1, "'+' starts a crate already home")
	assert_true(puzzle.is_solved(), "a one-crate board can start solved")
	assert_true(puzzle.move(Puzzle.RIGHT))
	assert_true(puzzle.move(Puzzle.RIGHT), "and shove it back off again")
	assert_eq(puzzle.crates_on_targets(), 0)
	assert_false(puzzle.is_solved())


func test_solved_only_when_every_crate_is_home() -> void:
	var puzzle := board("#######\n#.*.*.#\n#.$.$.#\n#.@...#\n#######")
	assert_eq(puzzle.crate_count(), 2)
	assert_eq(puzzle.target_count(), 2)
	assert_true(puzzle.move(Puzzle.UP), "first crate home")
	assert_eq(puzzle.crates_on_targets(), 1)
	assert_false(puzzle.is_solved(), "one of two is not solved")
	for direction: Vector2i in [Puzzle.DOWN, Puzzle.RIGHT, Puzzle.RIGHT]:
		assert_true(puzzle.move(direction), "walk round to the second crate")
	assert_true(puzzle.move(Puzzle.UP), "second crate home")
	assert_eq(puzzle.crates_on_targets(), 2)
	assert_true(puzzle.is_solved())


func test_an_empty_board_is_never_solved() -> void:
	var puzzle := board("###\n#@#\n###")
	assert_eq(puzzle.crate_count(), 0)
	assert_false(puzzle.is_solved(), "no crates is not a win")
	assert_false(puzzle.is_valid())


func test_solved_signal_fires_once() -> void:
	var puzzle := board("#######\n#@$.*.#\n#######")
	var wins := record(puzzle.solved)
	puzzle.move(Puzzle.RIGHT)
	assert_eq(wins.size(), 0, "not solved yet")
	puzzle.move(Puzzle.RIGHT)
	assert_eq(wins.size(), 1)
	puzzle.move(Puzzle.LEFT)
	assert_eq(wins.size(), 1, "wandering around a solved board does not re-announce it")


func test_undo_re_arms_the_solved_signal() -> void:
	var puzzle := board("#######\n#@$.*.#\n#######")
	var wins := record(puzzle.solved)
	puzzle.move(Puzzle.RIGHT)
	puzzle.move(Puzzle.RIGHT)
	assert_eq(wins.size(), 1)
	assert_true(puzzle.undo())
	assert_false(puzzle.is_solved())
	puzzle.move(Puzzle.RIGHT)
	assert_eq(wins.size(), 2, "solving it again announces it again")


func test_moved_signal_reports_whether_a_crate_was_pushed() -> void:
	var puzzle := board("#######\n#@.$.*#\n#######")
	var moves := record(puzzle.moved)
	puzzle.move(Puzzle.RIGHT)
	assert_eq(moves.size(), 1)
	assert_eq(moves[0][0], Puzzle.RIGHT)
	assert_false(moves[0][1], "a plain step")
	puzzle.move(Puzzle.RIGHT)
	assert_true(moves[1][1], "a push")
	puzzle.move(Puzzle.UP)
	assert_eq(moves.size(), 2, "a refused move is not announced")


func test_can_move_agrees_with_move() -> void:
	var puzzle := board("#######\n#@$#.*#\n#######")
	assert_false(puzzle.can_move(Puzzle.RIGHT), "crate against a wall")
	assert_false(puzzle.can_move(Puzzle.LEFT))
	assert_false(puzzle.can_move(Puzzle.UP))
	assert_false(puzzle.can_move(Puzzle.DOWN))
	assert_eq(puzzle.player, Vector2i(1, 1), "asking never moves anything")
	assert_false(puzzle.move(Puzzle.RIGHT))


func test_undo_takes_back_a_step() -> void:
	var puzzle := board("#####\n#@..#\n#####")
	puzzle.move(Puzzle.RIGHT)
	assert_true(puzzle.undo())
	assert_eq(puzzle.player, Vector2i(1, 1))
	assert_eq(puzzle.move_count(), 0)


func test_undo_takes_back_a_push_with_the_crate() -> void:
	var puzzle := board("#######\n#@$..*#\n#######")
	puzzle.move(Puzzle.RIGHT)
	assert_true(puzzle.has_crate(Vector2i(3, 1)))
	assert_true(puzzle.undo())
	assert_eq(puzzle.player, Vector2i(1, 1), "the mover stepped back")
	assert_true(puzzle.has_crate(Vector2i(2, 1)), "and dragged the crate back with it")
	assert_false(puzzle.has_crate(Vector2i(3, 1)))


func test_undo_with_no_history_is_refused() -> void:
	var puzzle := board("#####\n#@..#\n#####")
	assert_false(puzzle.undo(), "undo at the start of a level is harmless")
	assert_eq(puzzle.player, Vector2i(1, 1))


func test_undo_unwinds_the_whole_history_in_order() -> void:
	var puzzle := board("#######\n#@$...#\n#..*..#\n#######")
	puzzle.move(Puzzle.RIGHT)
	puzzle.move(Puzzle.DOWN)
	puzzle.move(Puzzle.RIGHT)
	assert_eq(puzzle.move_count(), 3)
	for i in 3:
		assert_true(puzzle.undo(), "undo %d" % i)
	assert_eq(puzzle.player, Vector2i(1, 1))
	assert_true(puzzle.has_crate(Vector2i(2, 1)))
	assert_eq(puzzle.move_count(), 0)
	assert_false(puzzle.undo(), "and then there is nothing left to undo")


func test_undone_signal_reports_the_move_it_reversed() -> void:
	var puzzle := board("#######\n#@$..*#\n#######")
	var undos := record(puzzle.undone)
	puzzle.move(Puzzle.RIGHT)
	puzzle.undo()
	assert_eq(undos.size(), 1)
	assert_eq(undos[0][0], Puzzle.RIGHT)
	assert_true(undos[0][1], "the reversed move was a push")


func test_move_count_tracks_moves_and_undos() -> void:
	var puzzle := board("#######\n#@....#\n#######")
	for i in 4:
		puzzle.move(Puzzle.RIGHT)
	assert_eq(puzzle.move_count(), 4)
	puzzle.undo()
	puzzle.undo()
	assert_eq(puzzle.move_count(), 2, "undo costs the move back, it does not add one")


func test_reset_restores_the_start_and_clears_the_history() -> void:
	var puzzle := board("#######\n#@$..*#\n#######")
	puzzle.move(Puzzle.RIGHT)
	puzzle.move(Puzzle.RIGHT)
	assert_eq(puzzle.player, Vector2i(3, 1))
	puzzle.reset()
	assert_eq(puzzle.player, Vector2i(1, 1))
	assert_true(puzzle.has_crate(Vector2i(2, 1)))
	assert_eq(puzzle.move_count(), 0)
	assert_false(puzzle.undo(), "reset forgets the history rather than hiding it")


func test_cell_accessors_come_back_in_reading_order() -> void:
	var puzzle := board("#####\n#*.*#\n#$@$#\n#####")
	var crates := puzzle.crates()
	assert_eq(crates.size(), 2)
	assert_eq(crates[0], Vector2i(1, 2))
	assert_eq(crates[1], Vector2i(3, 2))
	var targets := puzzle.targets()
	assert_eq(targets[0], Vector2i(1, 1))
	assert_eq(targets[1], Vector2i(3, 1))
	var walls := puzzle.walls()
	assert_eq(walls.size(), 14, "five top, five bottom and two per inner row")
	assert_eq(walls[0], Vector2i(0, 0))
	assert_eq(walls[walls.size() - 1], Vector2i(4, 3))


func test_is_valid_rejects_a_board_that_cannot_be_finished() -> void:
	assert_false(board("#####\n#@$.#\n#####").is_valid(), "a crate with nowhere to go")
	assert_false(board("#####\n#@.*#\n#####").is_valid(), "a target with no crate")
	assert_false(board("########\n#@$$.*.#\n########").is_valid(), "two crates, one target")
	assert_true(board("#####\n#@$*#\n#####").is_valid())


func test_create_builds_a_board_with_no_file_involved() -> void:
	var walls: Array[Vector2i] = [Vector2i(0, 0)]
	var crates: Array[Vector2i] = [Vector2i(2, 1)]
	var targets: Array[Vector2i] = [Vector2i(3, 1)]
	var puzzle := Puzzle.create(Vector2i(4, 2), Vector2i(1, 1), walls, crates, targets)
	assert_eq(puzzle.size, Vector2i(4, 2))
	assert_true(puzzle.is_wall(Vector2i(0, 0)))
	assert_true(puzzle.is_valid())
	assert_true(puzzle.move(Puzzle.RIGHT))
	assert_true(puzzle.is_solved(), "one push and the hand-built board is done")


func test_a_crate_cannot_be_pushed_off_the_board_edge() -> void:
	# is_wall() treats out-of-bounds as solid, so the edge blocks a push exactly
	# as a "#" would. This is the one refusal that does not involve a wall cell.
	var puzzle := Puzzle.create(
		Vector2i(3, 1), Vector2i(0, 0), [], [Vector2i(1, 0)], [Vector2i(2, 0)]
	)
	assert_true(puzzle.move(Puzzle.RIGHT), "the first push is legal")
	assert_false(puzzle.move(Puzzle.RIGHT), "the crate is now against the edge")
	assert_true(puzzle.has_crate(Vector2i(2, 0)), "and it did not leave the board")


func test_can_move_reports_true_for_a_legal_step() -> void:
	var puzzle := Puzzle.create(
		Vector2i(3, 1), Vector2i(0, 0), [], [Vector2i(2, 0)], [Vector2i(2, 0)]
	)
	assert_true(puzzle.can_move(Puzzle.RIGHT), "an empty cell to the right")
	assert_false(puzzle.can_move(Puzzle.LEFT), "the board edge")


func test_a_board_that_starts_solved_does_not_announce_an_unrelated_step() -> void:
	# A level authored with its crate already home is solved at construction.
	var puzzle := Puzzle.create(
		Vector2i(4, 1), Vector2i(2, 0), [], [Vector2i(0, 0)], [Vector2i(0, 0)]
	)
	assert_true(puzzle.is_solved())
	var wins := record(puzzle.solved)
	assert_true(puzzle.move(Puzzle.RIGHT), "a plain step, solving nothing")
	assert_eq(wins.size(), 0, "solved must not fire for a move that solved nothing")


func test_pushing_a_crate_off_a_target_and_back_announces_again() -> void:
	# move() and undo() derive the flag the same way, so the signal re-arms
	# whichever mutator broke the solution.
	var puzzle := Puzzle.create(
		Vector2i(5, 1), Vector2i(0, 0), [], [Vector2i(1, 0)], [Vector2i(2, 0)]
	)
	var wins := record(puzzle.solved)
	assert_true(puzzle.move(Puzzle.RIGHT), "push the crate home")
	assert_eq(wins.size(), 1)
	assert_true(puzzle.move(Puzzle.RIGHT), "push it straight off again")
	assert_false(puzzle.is_solved())
	assert_true(puzzle.undo(), "undo puts it back")
	assert_eq(wins.size(), 2, "the solution is announced again")


func test_a_crate_wedged_in_a_corner_is_a_deadlock() -> void:
	# The crate is one push away from the top-left corner, and the only target
	# is elsewhere, so that push makes the level unwinnable.
	var puzzle := LevelBuilder.parse(TextGrid.parse("#####\n#.$@#\n#...#\n#*..#\n#####"))
	assert_true(puzzle.is_valid())
	assert_false(puzzle.is_deadlocked(), "the crate still has room on two axes")
	assert_true(puzzle.move(Puzzle.LEFT), "shove it into the corner")
	assert_true(puzzle.has_crate(Vector2i(1, 1)))
	assert_true(puzzle.is_deadlocked(), "two perpendicular walls and no target under it")


func test_a_crate_resting_on_a_target_is_never_a_deadlock() -> void:
	# Corners are legitimate targets, so a solved crate in one is not stuck.
	var puzzle := Puzzle.create(
		Vector2i(3, 3),
		Vector2i(1, 1),
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)],
		[Vector2i(1, 2)],
		[Vector2i(1, 2)]
	)
	assert_true(puzzle.is_solved())
	assert_false(puzzle.is_deadlocked())


func test_a_crate_buried_in_a_wall_makes_a_level_invalid() -> void:
	var buried := Puzzle.create(
		Vector2i(5, 1), Vector2i(0, 0), [Vector2i(2, 0)], [Vector2i(2, 0)], [Vector2i(3, 0)]
	)
	assert_false(buried.is_valid(), "a crate inside a wall can never be pushed")
	var off_board := Puzzle.create(
		Vector2i(3, 1), Vector2i(0, 0), [], [Vector2i(9, 9)], [Vector2i(2, 0)]
	)
	assert_false(off_board.is_valid(), "and neither can one outside the board")
