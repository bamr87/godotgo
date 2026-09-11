extends GodotGoTest
## The ASCII symbol table, the shipped level files, and a worked solution for
## each one.
##
## The solutions are the point of this file: a Sokoban level that cannot be
## finished looks exactly like one that can until somebody plays it, so each
## level ships with the move list that clears it and the suite plays them.

## Move lists that solve each shipped level, in level order. Keeping them here
## rather than in a fixture file means a level edit that breaks the solve fails
## the suite immediately, with the level number in the test name.
const SOLUTIONS: Array[String] = [
	"URDRUU",
	"LLUUDDRRRUU",
	"LLUUUDDRRUURRRDLLLDLUU",
	"UUURUULDULLLLDLDDRD",
]

const LETTERS := {
	"U": Puzzle.UP,
	"D": Puzzle.DOWN,
	"L": Puzzle.LEFT,
	"R": Puzzle.RIGHT,
}


func before_each() -> void:
	Game.reset()


func after_each() -> void:
	Game.reset()


## Plays a move-letter string and returns how many of the moves were accepted.
func play(puzzle: Puzzle, moves: String) -> int:
	var made := 0
	for letter in moves:
		var direction: Vector2i = LETTERS[letter]
		if not puzzle.move(direction):
			break
		made += 1
	return made


func test_every_symbol_lands_in_the_right_bucket() -> void:
	var puzzle := LevelBuilder.parse(TextGrid.parse("#####\n#@$*#\n#.+.#\n#####"))
	assert_eq(puzzle.size, Vector2i(5, 4))
	assert_eq(puzzle.player, Vector2i(1, 1), "'@' is the mover")
	assert_true(puzzle.has_crate(Vector2i(2, 1)), "'$' is a crate")
	assert_true(puzzle.is_target(Vector2i(3, 1)), "'*' is a target")
	assert_true(puzzle.is_wall(Vector2i(0, 0)), "'#' is a wall")
	assert_false(puzzle.is_wall(Vector2i(1, 2)), "'.' is floor")


func test_a_crate_already_on_a_target_is_both() -> void:
	var puzzle := LevelBuilder.parse(TextGrid.parse("#####\n#@.+#\n#####"))
	assert_true(puzzle.has_crate(Vector2i(3, 1)))
	assert_true(puzzle.is_target(Vector2i(3, 1)))
	assert_eq(puzzle.crates_on_targets(), 1)


func test_a_mover_standing_on_a_target_is_both() -> void:
	var puzzle := LevelBuilder.parse(TextGrid.parse("#####\n#&$.#\n#####"))
	assert_eq(puzzle.player, Vector2i(1, 1))
	assert_true(puzzle.is_target(Vector2i(1, 1)), "'&' leaves the target behind")
	assert_eq(puzzle.crates_on_targets(), 0, "the mover is not standing in for a crate")
	assert_true(puzzle.is_valid(), "one crate, one target")


func test_unknown_characters_are_solid() -> void:
	# The blank column is padding, not a hole to walk out of.
	var puzzle := LevelBuilder.parse(TextGrid.parse("#### \n#@$*#\n#### "))
	assert_true(puzzle.is_wall(Vector2i(4, 0)), "a space blocks like a wall")
	assert_true(puzzle.is_wall(Vector2i(2, 0)), "and so does '#'")
	assert_eq(puzzle.size, Vector2i(5, 3), "rows are padded to the widest one")


func test_only_the_first_mover_symbol_counts() -> void:
	var puzzle := LevelBuilder.parse(TextGrid.parse("######\n#@.@.#\n######"))
	assert_eq(puzzle.player, Vector2i(1, 1))


func test_to_text_round_trips_a_level() -> void:
	var text := "#######\n#@.$.*#\n#..+..#\n#######"
	assert_eq(LevelBuilder.to_text(LevelBuilder.parse(TextGrid.parse(text))), text)


func test_to_text_shows_the_board_after_a_push() -> void:
	var puzzle := LevelBuilder.parse(TextGrid.parse("#####\n#@$*#\n#####"))
	assert_true(puzzle.move(Puzzle.RIGHT))
	assert_eq(LevelBuilder.to_text(puzzle), "#####\n#.@+#\n#####")


func test_the_level_catalogue_is_consistent() -> void:
	assert_eq(LevelBuilder.level_count(), 4)
	assert_eq(LevelBuilder.LEVEL_NAMES.size(), LevelBuilder.level_count(), "a name per level")
	assert_eq(SOLUTIONS.size(), LevelBuilder.level_count(), "a solution per level")
	assert_eq(LevelBuilder.level_id(1), "level_1")
	assert_eq(LevelBuilder.level_path(2), "res://levels/level_2.txt")
	assert_eq(LevelBuilder.level_name(1), "First Push")


func test_level_numbers_outside_the_catalogue_clamp() -> void:
	assert_eq(LevelBuilder.level_id(0), "level_1", "a corrupt save cannot ask for level 0")
	assert_eq(LevelBuilder.level_id(-5), "level_1")
	assert_eq(LevelBuilder.level_id(99), "level_4")


func test_every_shipped_level_file_exists_and_parses() -> void:
	for number in range(1, LevelBuilder.level_count() + 1):
		var path := LevelBuilder.level_path(number)
		assert_true(FileAccess.file_exists(path), path)
		var puzzle := LevelBuilder.load_level(number)
		assert_true(puzzle.is_valid(), "%s is playable" % path)
		assert_false(puzzle.is_solved(), "%s does not start solved" % path)
		assert_true(puzzle.size.x > 0 and puzzle.size.y > 0, "%s has extent" % path)


func test_the_levels_get_harder() -> void:
	var crates: Array[int] = []
	for number in range(1, LevelBuilder.level_count() + 1):
		crates.append(LevelBuilder.load_level(number).crate_count())
	assert_eq(crates[0], 1, "level 1 teaches one push")
	assert_true(crates[1] >= crates[0], "level 2 is no easier")
	assert_true(crates[2] >= crates[1], "level 3 is no easier")
	assert_true(SOLUTIONS[2].length() > SOLUTIONS[0].length(), "and takes more moves")


func test_level_1_is_solved_by_its_solution() -> void:
	_assert_solves(1)


func test_level_2_is_solved_by_its_solution() -> void:
	_assert_solves(2)


func test_level_3_is_solved_by_its_solution() -> void:
	_assert_solves(3)


func test_level_4_is_solved_by_its_solution() -> void:
	_assert_solves(4)


func test_undoing_a_whole_solution_returns_to_the_start() -> void:
	var puzzle := LevelBuilder.load_level(2)
	var start := LevelBuilder.to_text(puzzle)
	play(puzzle, SOLUTIONS[1])
	assert_true(puzzle.is_solved())
	while puzzle.undo():
		pass
	assert_eq(LevelBuilder.to_text(puzzle), start, "undo is a complete inverse of every move")
	assert_eq(puzzle.move_count(), 0)


func _assert_solves(number: int) -> void:
	var puzzle := LevelBuilder.load_level(number)
	var moves: String = SOLUTIONS[number - 1]
	var made := play(puzzle, moves)
	assert_eq(made, moves.length(), "level %d: move %d was refused" % [number, made + 1])
	assert_true(puzzle.is_solved(), "level %d is solved by its %d-move solution" % [number, made])
	assert_eq(puzzle.move_count(), moves.length())
