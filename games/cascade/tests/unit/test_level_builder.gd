extends GodotGoTest
## The two ways a level reaches the game: typed into a file, or grown from a
## seed. Both arrive as a [Board], and these tests hold the shipped levels of
## either kind to the same standard.

const MAIN_SCENE := preload("res://scenes/main.tscn")
## The ways [method play_line] may choose its next pop. Each is deterministic
## and none looks ahead, so a level one of them beats is beatable by a player
## who is not even trying to think.
const POLICIES: Array[StringName] = [&"reading_order", &"smallest_first", &"largest_first"]


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


func test_every_shipped_level_can_be_beaten() -> void:
	# Opening with a legal pop is not the same as being winnable: a board can
	# jam with more than its target's worth of tiles stranded whatever you do.
	# Each level is played to the end through the real session, at the target
	# the real scene sets, and has to be won by at least one simple line.
	var ratio := shipped_target_ratio()
	for number in range(1, LevelBuilder.level_count() + 1):
		var outcomes: PackedStringArray = []
		var won := false
		for policy: StringName in POLICIES:
			var level_board := LevelBuilder.load_level(number)
			Game.start(Level.goal_for(level_board.remaining(), ratio), 0.0)
			play_line(level_board, policy)
			won = won or Game.state == Session.State.WON
			outcomes.append("%s left %d" % [policy, level_board.remaining()])
		assert_true(
			won,
			(
				"%s cannot be beaten at %d%% (%s)"
				% [LevelBuilder.level_id(number), roundi(ratio * 100.0), ", ".join(outcomes)]
			)
		)


func test_a_policy_line_ends_the_round_it_plays() -> void:
	# The helper above is only evidence if it really finishes boards through the
	# session rather than stopping early: every line leaves a jammed board and a
	# closed round.
	for policy: StringName in POLICIES:
		var level_board := LevelBuilder.load_level(1)
		Game.start(Level.goal_for(level_board.remaining(), shipped_target_ratio()), 0.0)
		play_line(level_board, policy)
		assert_true(level_board.is_stuck(), String(policy))
		assert_true(Game.is_over(), String(policy))
		assert_eq(Game.progress, level_board.size.x * level_board.size.y - level_board.remaining())


## The win threshold the main scene ships with, read from the scene itself so a
## retuned [member Level.target_ratio] is tested at the value players get.
func shipped_target_ratio() -> float:
	var scene := MAIN_SCENE.instantiate() as Level
	var ratio := scene.target_ratio
	scene.free()
	return ratio


## Pops [param level_board] until it jams, choosing each group by [param policy]
## and folding every pop into the session exactly as [method Level.try_pop] does.
func play_line(level_board: Board, policy: StringName) -> void:
	while Game.is_playing() and not level_board.is_stuck():
		var count := level_board.pop(choose_pop(level_board, policy))
		Game.record_pop(count)
	if Game.is_playing():
		Game.finish_board(level_board.is_empty(), level_board.remaining())


## One cell from every poppable group, chosen by [param policy]. Ties go to the
## group met first in reading order.
func choose_pop(level_board: Board, policy: StringName) -> Vector2i:
	var chosen := Vector2i(-1, -1)
	var chosen_size := 0
	var seen := {}
	for y in level_board.size.y:
		for x in level_board.size.x:
			var cell := Vector2i(x, y)
			if seen.has(cell):
				continue
			var group := level_board.group_at(cell)
			for member: Vector2i in group:
				seen[member] = true
			if group.size() < Board.MIN_GROUP:
				continue
			if policy == &"reading_order":
				return cell
			var better := (
				chosen_size == 0
				or (policy == &"smallest_first" and group.size() < chosen_size)
				or (policy == &"largest_first" and group.size() > chosen_size)
			)
			if better:
				chosen = cell
				chosen_size = group.size()
	return chosen


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
