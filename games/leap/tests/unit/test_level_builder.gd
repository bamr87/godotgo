extends GodotGoTest
## The ASCII-to-nodes step. Everything here is pure geometry, so it is asserted
## directly rather than through a running level.

const COIN_SCENE := preload("res://scenes/coin.tscn")
const HAZARD_SCENE := preload("res://scenes/hazard.tscn")
const GOAL_SCENE := preload("res://scenes/goal.tscn")

var _root: Node2D


func before_each() -> void:
	_root = Node2D.new()
	add_node(_root)


func after_each() -> void:
	await free_node(_root)


func _scenes() -> Dictionary:
	return {
		LevelBuilder.COIN: COIN_SCENE,
		LevelBuilder.SPIKE: HAZARD_SCENE,
		LevelBuilder.GOAL: GOAL_SCENE,
	}


func test_cell_to_world_centres_the_tile() -> void:
	assert_eq(LevelBuilder.cell_to_world(Vector2i(0, 0), 32), Vector2(16, 16))
	assert_eq(LevelBuilder.cell_to_world(Vector2i(2, 3), 32), Vector2(80, 112))


func test_solid_runs_merges_a_row_into_one_rectangle() -> void:
	var runs := LevelBuilder.solid_runs(TextGrid.parse("#####"))
	assert_eq(runs.size(), 1)
	assert_eq(runs[0], Rect2i(0, 0, 5, 1))


func test_solid_runs_splits_on_gaps() -> void:
	var runs := LevelBuilder.solid_runs(TextGrid.parse("##..###"))
	assert_eq(runs.size(), 2)
	assert_eq(runs[0], Rect2i(0, 0, 2, 1))
	assert_eq(runs[1], Rect2i(4, 0, 3, 1))


func test_solid_runs_closes_a_run_at_the_right_edge() -> void:
	var runs := LevelBuilder.solid_runs(TextGrid.parse("..###"))
	assert_eq(runs.size(), 1)
	assert_eq(runs[0], Rect2i(2, 0, 3, 1), "a run touching the edge is still closed")


func test_solid_runs_keeps_rows_separate() -> void:
	var runs := LevelBuilder.solid_runs(TextGrid.parse("###\n###"))
	assert_eq(runs.size(), 2, "rows are not merged vertically")
	assert_eq(runs[0].position.y, 0)
	assert_eq(runs[1].position.y, 1)


func test_an_empty_map_yields_no_runs() -> void:
	assert_eq(LevelBuilder.solid_runs(TextGrid.parse("...\n...")).size(), 0)


func test_build_creates_one_static_body_per_run_with_merged_collision() -> void:
	var grid := TextGrid.parse("####\n....")
	var built := LevelBuilder.build(_root, grid, 32, _scenes())
	var solids: Array = built["solids"]
	assert_eq(solids.size(), 1)
	var body: StaticBody2D = solids[0]
	assert_eq(body.collision_layer, 1, "solids are world geometry")
	var shape := body.get_child(0) as CollisionShape2D
	assert_eq((shape.shape as RectangleShape2D).size, Vector2(128, 32))


func test_build_places_the_spawn_point() -> void:
	var built := LevelBuilder.build(_root, TextGrid.parse("..@."), 32, _scenes())
	assert_eq(built["spawn"], Vector2(80, 16))


func test_build_instantiates_one_node_per_symbol() -> void:
	var grid := TextGrid.parse("o.o.^\n....F")
	var built := LevelBuilder.build(_root, grid, 32, _scenes())
	assert_eq(built["coins"].size(), 2)
	assert_eq(built["hazards"].size(), 1)
	assert_not_null(built["goal"])
	assert_is(built["goal"], GoalFlag)


func test_build_positions_nodes_at_their_cell_centres() -> void:
	var built := LevelBuilder.build(_root, TextGrid.parse(".o"), 32, _scenes())
	var coin: Node2D = built["coins"][0]
	assert_eq(coin.position, Vector2(48, 16))


func test_build_tolerates_a_map_with_no_spawn_or_goal() -> void:
	var built := LevelBuilder.build(_root, TextGrid.parse("####"), 32, _scenes())
	assert_eq(built["spawn"], Vector2.ZERO)
	assert_null(built["goal"])


func test_build_without_scenes_still_creates_geometry() -> void:
	var built := LevelBuilder.build(_root, TextGrid.parse("##\n.o"), 32, {})
	assert_eq(built["solids"].size(), 1)
	assert_eq(built["coins"].size(), 0, "a symbol with no scene is skipped, not an error")


func test_the_shipped_level_is_winnable() -> void:
	var grid := TextGrid.from_file("res://levels/level_1.txt")
	assert_true(grid.width > 0, "level_1.txt must parse")
	assert_ne(grid.find_first(LevelBuilder.SPAWN), Vector2i(-1, -1), "needs a spawn point")
	assert_ne(
		grid.find_first(LevelBuilder.GOAL), Vector2i(-1, -1), "needs a goal flag to be winnable"
	)
	assert_true(grid.count(LevelBuilder.COIN) > 0, "needs coins to score")
	assert_true(LevelBuilder.solid_runs(grid).size() > 0, "needs ground to stand on")
