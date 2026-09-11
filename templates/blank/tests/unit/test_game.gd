extends GodotGoTest
## Starting point for __GAME_TITLE__'s tests. Every rule lives in the session,
## so most tests need no scene at all.

const MAIN_SCENE := preload("res://scenes/main.tscn")


func before_each() -> void:
	Game.reset()


func after_each() -> void:
	Game.reset()


func test_a_step_scores_and_advances() -> void:
	Game.start(3, 30.0)
	assert_true(Game.take_step())
	assert_eq(Game.progress, 1)
	assert_eq(Game.score, Game.POINTS_PER_STEP)


func test_reaching_the_goal_announces_the_objective() -> void:
	Game.start(2, 0.0)
	var done := record(Game.objective_reached)
	Game.take_step()
	Game.take_step()
	assert_eq(done.size(), 1)
	assert_true(Game.objective_complete())


func test_main_scene_starts_a_round() -> void:
	var main := add_scene(MAIN_SCENE)
	await tree.process_frame
	assert_true(Game.is_playing())
	assert_eq(Game.goal, main.goal)
	assert_eq(main.hud.progress_text(), "Progress 0 / %d" % main.goal)
	await free_node(main)
