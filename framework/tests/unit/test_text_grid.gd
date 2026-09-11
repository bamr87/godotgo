extends GodotGoTest
## ASCII level maps: the level format shared by the platformer and the puzzle.

const MAP := "###..\n#@#b.\n#####"


func test_parse_measures_and_pads_rows() -> void:
	var grid := TextGrid.parse("##\n#\n###")
	assert_eq(grid.width, 3)
	assert_eq(grid.height, 3)
	assert_eq(grid.cell(2, 0), TextGrid.EMPTY, "short rows pad with the empty symbol")
	assert_eq(grid.cell(1, 1), TextGrid.EMPTY)


func test_blank_leading_and_trailing_lines_are_dropped() -> void:
	var grid := TextGrid.parse("\n\n##\n##\n\n")
	assert_eq(grid.height, 2)
	assert_eq(grid.width, 2)


func test_lookup_by_position() -> void:
	var grid := TextGrid.parse(MAP)
	assert_eq(grid.at(Vector2i(1, 1)), "@")
	assert_eq(grid.cell(0, 0), "#")
	assert_eq(grid.at(Vector2i(3, 1)), "b")


func test_out_of_bounds_reads_are_empty_not_errors() -> void:
	var grid := TextGrid.parse(MAP)
	assert_false(grid.in_bounds(Vector2i(-1, 0)))
	assert_false(grid.in_bounds(Vector2i(0, 99)))
	assert_eq(grid.at(Vector2i(-1, -1)), TextGrid.EMPTY)
	assert_eq(grid.at(Vector2i(99, 99)), TextGrid.EMPTY)


func test_find_first_and_find_all() -> void:
	var grid := TextGrid.parse(MAP)
	assert_eq(grid.find_first("@"), Vector2i(1, 1))
	assert_eq(grid.find_first("z"), Vector2i(-1, -1), "missing symbols report (-1, -1)")
	assert_eq(grid.find_all("#").size(), 3 + 2 + 5)
	assert_eq(grid.count("b"), 1)


func test_find_any_matches_a_symbol_set() -> void:
	var grid := TextGrid.parse(MAP)
	var found := grid.find_any("@b")
	assert_eq(found.size(), 2)
	assert_true(found.has(Vector2i(1, 1)))
	assert_true(found.has(Vector2i(3, 1)))


func test_reading_order_is_row_major() -> void:
	var grid := TextGrid.parse("ab\nab")
	var found := grid.find_all("a")
	assert_eq(found[0], Vector2i(0, 0))
	assert_eq(found[1], Vector2i(0, 1))


func test_set_at_writes_one_cell_and_ignores_bad_input() -> void:
	var grid := TextGrid.parse(MAP)
	grid.set_at(Vector2i(1, 1), ".")
	assert_eq(grid.at(Vector2i(1, 1)), ".")
	grid.set_at(Vector2i(99, 99), "X")
	grid.set_at(Vector2i(0, 0), "too long")
	assert_eq(grid.at(Vector2i(0, 0)), "#", "multi-character writes are refused")


func test_clone_is_independent() -> void:
	var grid := TextGrid.parse(MAP)
	var copy := grid.clone()
	copy.set_at(Vector2i(0, 0), ".")
	assert_eq(copy.at(Vector2i(0, 0)), ".")
	assert_eq(grid.at(Vector2i(0, 0)), "#", "the original is untouched")


func test_round_trips_through_text() -> void:
	var grid := TextGrid.parse(MAP)
	assert_eq(TextGrid.parse(grid.to_text()).to_text(), grid.to_text())


func test_from_file_reads_a_level_and_missing_files_are_empty() -> void:
	var grid := TextGrid.from_file("res://tests/fixtures/levels/sample.txt")
	assert_eq(grid.width, 5)
	assert_eq(grid.height, 3)
	assert_eq(grid.find_first("@"), Vector2i(1, 1))
	var missing := TextGrid.from_file("res://tests/fixtures/levels/nope.txt")
	assert_eq(missing.height, 0)
