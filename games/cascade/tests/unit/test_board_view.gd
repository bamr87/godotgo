extends GodotGoTest
## The drawn board: pooled tiles, and the state machine that sequences a pop.
##
## The view is driven straight from a [Board] here rather than through [Level],
## because what is under test is the catching-up: the rules have already moved,
## and these tests are about how faithfully -- and how late -- the pixels follow.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _level: Level
var _view: BoardView


func before_each() -> void:
	Game.reset()
	_level = add_scene(MAIN_SCENE) as Level
	await tree.process_frame
	# The view is the subject, so the level stops driving it: its _process
	# repaints the highlight from the pointer on every frame.
	_level.set_process(false)
	_view = _level.board_view


func after_each() -> void:
	_level.silence()
	await tree.create_timer(0.05).timeout
	await free_node(_level)
	_level = null
	_view = null
	Game.reset()


func test_rendering_draws_one_pooled_tile_per_filled_cell() -> void:
	_view.render(LevelBuilder.from_text("aab\nccb"))
	assert_eq(_view.tile_count(), 6)
	assert_eq(_view.pool.in_use(), 6, "every tile came out of the pool")
	assert_not_null(_view.tile_at(Vector2i(0, 0)))
	assert_null(_view.tile_at(Vector2i(9, 9)), "and nothing is drawn off the board")


func test_a_tile_sits_at_the_centre_of_its_cell() -> void:
	_view.render(LevelBuilder.from_text("ab\nba"))
	var cell := Vector2i(1, 0)
	assert_eq(_view.tile_at(cell).position, _view.cell_to_local(cell))
	assert_eq(_view.local_to_cell(_view.cell_to_local(cell)), cell, "and the map reads back")
	assert_true(_view.tile_pixels() < float(_view.cell_size), "tiles do not touch")


func test_each_colour_draws_its_own_texture() -> void:
	_view.render(LevelBuilder.from_text("ab"))
	assert_eq(_view.tile_at(Vector2i(0, 0)).texture, _view.texture_for(0))
	assert_ne(_view.tile_at(Vector2i(1, 0)).texture, _view.texture_for(0))
	assert_null(_view.texture_for(99), "a colour this scene has no tile for")


func test_the_view_locks_while_a_pop_plays_and_lands_when_it_finishes() -> void:
	var subject := LevelBuilder.from_text("ab\naa")
	_view.render(subject)
	assert_true(_view.is_idle())
	subject.pop(Vector2i(0, 0))
	assert_false(_view.is_idle(), "input stays locked while the board is moving")
	assert_eq(_view.state_machine.current, BoardView.STATE_POPPING)
	var landed := record(_view.animation_finished)
	_view.finish_animation()
	assert_true(_view.is_idle())
	assert_eq(landed.size(), 1)


func test_popped_tiles_go_back_to_the_pool() -> void:
	var subject := LevelBuilder.from_text("ab\naa")
	_view.render(subject)
	assert_eq(_view.pool.in_use(), 4)
	subject.pop(Vector2i(0, 0))
	_view.finish_animation()
	assert_eq(_view.tile_count(), 1)
	assert_eq(_view.pool.in_use(), 1, "the three that went are spare again")


func test_a_survivor_is_the_same_node_moved_to_its_new_cell() -> void:
	var subject := LevelBuilder.from_text("ab\naa")
	_view.render(subject)
	var tile := _view.tile_at(Vector2i(1, 0))
	subject.pop(Vector2i(0, 0))
	_view.finish_animation()
	# Its column emptied under it, so the board slid it left and dropped it.
	assert_eq(_view.tile_at(Vector2i(0, 1)), tile, "moved, not replaced")
	assert_eq(tile.position, _view.cell_to_local(Vector2i(0, 1)))


func test_the_animation_runs_itself_out_without_being_pushed() -> void:
	var subject := LevelBuilder.from_text("ab\naa")
	_view.render(subject)
	subject.pop(Vector2i(0, 0))
	await tree.create_timer((_view.pop_time + _view.fall_time) * 2.0 + 0.1).timeout
	assert_true(_view.is_idle(), "nothing had to call finish_animation")
	assert_eq(_view.tile_count(), 1)
	assert_eq(_view.tile_at(Vector2i(0, 1)).position, _view.cell_to_local(Vector2i(0, 1)))


func test_rendering_a_second_board_replaces_the_first() -> void:
	_view.render(LevelBuilder.from_text("aab\nccb"))
	assert_eq(_view.tile_count(), 6)
	_view.render(LevelBuilder.from_text("aa"))
	assert_eq(_view.tile_count(), 2, "not piled on top of the last board")
	assert_eq(_view.pool.in_use(), 2)


func test_rendering_during_an_animation_abandons_it() -> void:
	var subject := LevelBuilder.from_text("ab\naa")
	_view.render(subject)
	subject.pop(Vector2i(0, 0))
	assert_false(_view.is_idle())
	_view.render(LevelBuilder.from_text("cc"))
	assert_true(_view.is_idle(), "the board just handed over is the truth now")
	assert_eq(_view.tile_count(), 2)
	assert_eq(_view.pool.in_use(), 2, "the tiles caught mid-pop went back too")


func test_every_board_redresses_the_same_pooled_nodes() -> void:
	_view.render(LevelBuilder.load_level(1))
	var created := _view.pool.created()
	assert_true(created > 0)
	for number in range(1, LevelBuilder.level_count() + 1):
		_view.render(LevelBuilder.load_level(number))
	assert_eq(_view.pool.created(), created, "not one extra instance was allocated")


func test_the_highlight_lights_the_group_and_nothing_else() -> void:
	_view.render(LevelBuilder.from_text("aab\naac"))
	_view.highlight_group(Vector2i(0, 0))
	assert_true(_view.tile_at(Vector2i(1, 1)).modulate.r > 1.0, "the whole block is lit")
	assert_eq(_view.tile_at(Vector2i(2, 0)).modulate.r, 1.0, "its neighbour is not")
	_view.clear_highlight()
	assert_eq(_view.tile_at(Vector2i(0, 0)).modulate.r, 1.0)


func test_a_cell_with_no_legal_pop_lights_nothing() -> void:
	_view.render(LevelBuilder.from_text("ab\nba"))
	_view.highlight_group(Vector2i(0, 0))
	assert_eq(_view.tile_at(Vector2i(0, 0)).modulate.r, 1.0, "a lone tile cannot be taken")


func test_the_highlight_is_refused_while_tiles_are_moving() -> void:
	var subject := LevelBuilder.from_text("bbaa\nccaa")
	_view.render(subject)
	_view.highlight_group(Vector2i(0, 0))
	var lit := _view.tile_at(Vector2i(0, 0))
	assert_true(lit.modulate.r > 1.0)
	subject.pop(Vector2i(2, 0))
	_view.highlight_group(Vector2i(0, 0))
	assert_false(_view.is_idle())
	assert_true(lit.modulate.r > 1.0, "nothing was repainted mid-animation")
