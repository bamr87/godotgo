extends GodotGoTest
## The two ways a level reaches the game: typed into a file, or grown from a
## seed. Both arrive as a [Board], and these tests hold the shipped levels of
## either kind to the same standard.


func before_each() -> void:
	Game.reset()


func after_each() -> void:
	Game.reset()


func test_every_shipped_level_loads_and_opens_with_a_legal_pop() -> void:
	for number in range(1, LevelBuilder.level_count() + 1):
		var id := LevelBuilder.level_id(number)
		var level_board := LevelBuilder.load_level(number)
		assert_true(level_board.size.x > 0 and level_board.size.y > 0, id)
		assert_true(level_board.remaining() > 0, "%s has tiles on it" % id)
		assert_false(level_board.is_stuck(), "%s can be played at all" % id)
		assert_false(LevelBuilder.level_name(number).is_empty(), "%s is named" % id)


func test_level_ids_are_unique() -> void:
	var seen := {}
	for number in range(1, LevelBuilder.level_count() + 1):
		var id := LevelBuilder.level_id(number)
		assert_false(seen.has(id), "%s appears once" % id)
		seen[id] = true


func test_an_authored_level_round_trips_through_its_own_symbols() -> void:
	for number in range(1, LevelBuilder.level_count() + 1):
		if LevelBuilder.is_generated(number):
			continue
		var path := LevelBuilder.level_path(number)
		var text := FileAccess.get_file_as_string(path).strip_edges()
		assert_eq(LevelBuilder.to_text(LevelBuilder.from_file(path)), text, path)


func test_an_authored_level_only_uses_colours_the_game_has_tiles_for() -> void:
	for number in range(1, LevelBuilder.level_count() + 1):
		var level_board := LevelBuilder.load_level(number)
		for y in level_board.size.y:
			for x in level_board.size.x:
				var colour := level_board.colour_at(Vector2i(x, y))
				assert_true(
					colour < LevelBuilder.COLOUR_SYMBOLS.length(),
					"level %d uses colour %d" % [number, colour]
				)


func test_a_generated_level_declares_a_size_and_a_seed_instead_of_a_file() -> void:
	var generated := 0
	for number in range(1, LevelBuilder.level_count() + 1):
		if not LevelBuilder.is_generated(number):
			assert_false(LevelBuilder.level_path(number).is_empty(), "level %d" % number)
			continue
		generated += 1
		var entry := LevelBuilder.level_at(number)
		assert_true(entry.has("seed") and entry.has("width") and entry.has("height"))
		assert_eq(LevelBuilder.level_path(number), "", "a seed has no file")
		assert_true(
			int(entry["colours"]) <= LevelBuilder.COLOUR_SYMBOLS.length(),
			"level %d asks for no more colours than there are tiles" % number
		)
	assert_true(generated > 0, "the game ships at least one seeded board")


func test_a_generated_level_rebuilds_identically() -> void:
	for number in range(1, LevelBuilder.level_count() + 1):
		if not LevelBuilder.is_generated(number):
			continue
		var first := LevelBuilder.load_level(number)
		var second := LevelBuilder.load_level(number)
		assert_eq(first.cells(), second.cells(), "level %d replays from its seed" % number)


func test_a_level_number_out_of_range_clamps() -> void:
	assert_eq(LevelBuilder.level_id(0), LevelBuilder.level_id(1))
	assert_eq(LevelBuilder.level_id(-5), LevelBuilder.level_id(1))
	var last := LevelBuilder.level_count()
	assert_eq(LevelBuilder.level_id(last + 99), LevelBuilder.level_id(last))


func test_unknown_characters_read_as_empty_cells() -> void:
	assert_eq(LevelBuilder.colour_for("?"), Board.EMPTY)
	assert_eq(LevelBuilder.colour_for(LevelBuilder.EMPTY_SYMBOL), Board.EMPTY)
	var subject := LevelBuilder.from_text("a?a")
	assert_eq(subject.remaining(), 2, "the stray character left a hole, not a tile")
	# And that hole does not survive loading. Its column held nothing at all, so
	# the settle dropped the column and the two tiles ended up side by side.
	assert_eq(LevelBuilder.to_text(subject), "aa.")
	assert_false(subject.is_stuck())


func test_a_symbol_outside_the_table_renders_as_empty() -> void:
	assert_eq(LevelBuilder.symbol_for(Board.EMPTY), LevelBuilder.EMPTY_SYMBOL)
	assert_eq(LevelBuilder.symbol_for(99), LevelBuilder.EMPTY_SYMBOL)
	assert_eq(LevelBuilder.symbol_for(0), "a")


func test_a_level_typed_with_floating_tiles_is_settled_on_load() -> void:
	# Written as it might be sketched by hand: tiles hanging over a hole, and a
	# column with nothing in it at all.
	var subject := LevelBuilder.from_text("a.b\n...\na.b")
	assert_eq(LevelBuilder.to_text(subject), "...\nab.\nab.")
	assert_eq(subject.settle().size(), 0, "and it is packed once, not every frame")
