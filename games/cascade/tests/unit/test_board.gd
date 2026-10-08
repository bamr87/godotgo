extends GodotGoTest
## Every rule of the game, asserted directly against [Board].
##
## Not one test here instantiates a node. A board is two lines of ASCII and a pop
## is a function call, so the awkward cases -- the column that empties, the tile
## that has to move twice, the board that jams -- are cheap enough that all of
## them get covered instead of just the happy path.


func before_each() -> void:
	Game.reset()


func after_each() -> void:
	Game.reset()


## Builds a board from an inline map, through the same parser the shipped levels
## use.
func board(text: String) -> Board:
	return LevelBuilder.from_text(text)


func test_a_board_keeps_the_shape_it_was_written_at() -> void:
	var subject := board("aab\nbba")
	assert_eq(subject.size, Vector2i(3, 2))
	assert_eq(subject.remaining(), 6)
	assert_false(subject.is_empty())


func test_cells_outside_the_board_read_as_empty() -> void:
	var subject := board("aa\naa")
	assert_false(subject.in_bounds(Vector2i(-1, 0)))
	assert_eq(subject.colour_at(Vector2i(-1, 0)), Board.EMPTY)
	assert_eq(subject.colour_at(Vector2i(2, 0)), Board.EMPTY, "past the right edge")
	assert_eq(subject.colour_at(Vector2i(0, 9)), Board.EMPTY, "below the bottom")
	assert_false(subject.is_filled(Vector2i(5, 5)))


func test_a_group_grows_through_orthogonal_neighbours_only() -> void:
	# The two 'a's touch corner to corner; a diagonal is not a connection.
	var subject := board("ab\nba")
	assert_eq(subject.group_at(Vector2i(0, 0)), [Vector2i(0, 0)] as Array[Vector2i])
	assert_false(subject.can_pop(Vector2i(0, 0)))


func test_a_group_comes_back_in_reading_order() -> void:
	var subject := board("aab\naab")
	var group := subject.group_at(Vector2i(1, 1))
	var expected: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	assert_eq(group, expected)


func test_an_empty_cell_has_no_group() -> void:
	var subject := board("a.\n..")
	assert_eq(subject.group_at(Vector2i(9, 9)).size(), 0, "off the board")
	assert_eq(subject.group_at(Vector2i(1, 0)).size(), 0, "and a blank cell")


func test_popping_a_group_under_the_minimum_changes_nothing() -> void:
	var subject := board("ab\nba")
	var before := subject.cells()
	assert_eq(subject.pop(Vector2i(0, 0)), 0, "a lone tile is not a group")
	assert_eq(subject.cells(), before, "and a refused pop leaves the board alone")
	assert_eq(subject.remaining(), 4)


func test_popping_reports_the_size_of_what_it_took() -> void:
	var subject := board("ab\naa")
	assert_eq(subject.pop(Vector2i(0, 0)), 3)
	assert_eq(subject.remaining(), 1, "only the odd tile is left")


func test_a_pop_announces_the_whole_group_and_its_colour() -> void:
	var subject := board("ab\naa")
	var events := record(subject.cleared)
	subject.pop(Vector2i(0, 0))
	assert_eq(events.size(), 1)
	var cells: Array = events[0][0]
	assert_eq(cells.size(), 3)
	assert_eq(events[0][1], LevelBuilder.colour_for("a"))


func test_survivors_fall_to_the_bottom_of_their_column() -> void:
	# Popping the 'b' pair leaves the 'c' hanging over two empty cells.
	var subject := board("c\nb\nb")
	assert_eq(subject.pop(Vector2i(0, 1)), 2)
	assert_eq(LevelBuilder.to_text(subject), ".\n.\nc")


func test_an_emptied_column_closes_up_to_the_left() -> void:
	var subject := board("aab\naab")
	assert_eq(subject.pop(Vector2i(0, 0)), 4, "the whole left block goes")
	# Both 'a' columns emptied, so the 'b' column slides over to become column 0.
	assert_eq(LevelBuilder.to_text(subject), "b..\nb..")


func test_settling_reports_only_the_cells_that_moved() -> void:
	var subject := board("ab\naa")
	var events := record(subject.settled)
	subject.pop(Vector2i(0, 0))
	assert_eq(events.size(), 1)
	var moves: Dictionary = events[0][0]
	# The lone 'b' loses its own column and lands at the bottom of the new one.
	assert_eq(moves, {Vector2i(1, 0): Vector2i(0, 1)})


func test_settling_a_packed_board_moves_nothing() -> void:
	var subject := board("ab\nba")
	assert_eq(subject.settle().size(), 0)
	assert_eq(LevelBuilder.to_text(subject), "ab\nba")


func test_a_board_is_stuck_once_no_two_like_tiles_touch() -> void:
	assert_false(board("ab\nba").can_pop(Vector2i(0, 0)))
	assert_true(board("ab\nba").is_stuck(), "a chequerboard has no legal pop")
	assert_false(board("aa\nbb").is_stuck(), "a pair anywhere is enough")
	assert_true(board("..\n..").is_stuck(), "and an empty board takes no more")


func test_clearing_the_last_group_empties_the_board() -> void:
	var subject := board("aa")
	assert_eq(subject.pop(Vector2i(0, 0)), 2)
	assert_true(subject.is_empty())
	assert_true(subject.is_stuck())
	assert_eq(subject.remaining(), 0)


func test_cells_hands_back_a_copy() -> void:
	var subject := board("aa")
	var snapshot := subject.cells()
	subject.pop(Vector2i(0, 0))
	assert_eq(snapshot.size(), 2)
	assert_ne(snapshot[0], Board.EMPTY, "the snapshot predates the pop")


func test_a_seed_always_grows_the_same_board() -> void:
	var first := Board.generate(Vector2i(6, 5), 3, Rng.new(4242))
	var second := Board.generate(Vector2i(6, 5), 3, Rng.new(4242))
	assert_eq(first.cells(), second.cells())
	assert_ne(
		Board.generate(Vector2i(6, 5), 3, Rng.new(99)).cells(),
		first.cells(),
		"and a different seed grows a different one"
	)


func test_a_generated_board_is_full_and_never_opens_stuck() -> void:
	for seed_value in [0, 1, 7, 20260911, 999999]:
		var subject := Board.generate(Vector2i(8, 6), 4, Rng.new(seed_value))
		assert_eq(subject.remaining(), 48, "every cell is filled")
		assert_false(subject.is_stuck(), "seed %d opens with a legal pop" % seed_value)


func test_a_cramped_board_still_opens_with_a_pop() -> void:
	# Two by two with five colours is where a uniform fill is most likely to come
	# out with nothing touching, and the level still has to be playable.
	for seed_value in range(12):
		var subject := Board.generate(Vector2i(2, 2), 5, Rng.new(seed_value))
		assert_false(subject.is_stuck(), "seed %d" % seed_value)
