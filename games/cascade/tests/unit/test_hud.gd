extends GodotGoTest
## The heads-up display, driven by the session's signals alone.
##
## The HUD is added on its own rather than through the main scene: it listens to
## [code]Game[/code] and to nothing else, and a test that has to build a board to
## check a label would be testing the wrong thing.

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var _hud: HUD


func before_each() -> void:
	Game.reset()
	_hud = add_scene(HUD_SCENE) as HUD
	await tree.process_frame


func after_each() -> void:
	await free_node(_hud)
	_hud = null
	Game.reset()


func test_the_counters_follow_the_session() -> void:
	Game.start(20, 0.0)
	Game.record_pop(5)
	assert_eq(_hud.score_text(), "Score 20")
	assert_eq(_hud.cleared_text(), "Cleared 5 / 20")
	assert_eq(_hud.pops_text(), "Pops 1 - best group 5")
	Game.record_pop(3)
	assert_eq(_hud.pops_text(), "Pops 2 - best group 5", "the best group is not the last one")


func test_a_hud_built_mid_round_opens_on_the_round_it_found() -> void:
	Game.start(20, 0.0)
	Game.record_pop(4)
	var fresh := add_scene(HUD_SCENE) as HUD
	await tree.process_frame
	assert_eq(fresh.score_text(), "Score %d" % Game.score)
	assert_eq(fresh.cleared_text(), "Cleared 4 / 20")
	assert_eq(fresh.pops_text(), "Pops 1 - best group 4")
	await free_node(fresh)


func test_the_title_and_level_lines_are_set_by_the_level() -> void:
	_hud.set_title("Cascade")
	_hud.set_level(2, 5, "Four Colours")
	assert_eq(_hud.title_text(), "Cascade")
	assert_eq(_hud.level_text(), "Level 2/5 - Four Colours")


func test_the_best_line_says_nothing_until_there_is_a_record() -> void:
	_hud.set_best(0, 0, false, false)
	assert_eq(_hud.best_text(), "Best -")
	_hud.set_best(0, 0, true, false)
	assert_eq(_hud.best_text(), "Best 0, group 0", "a scoreless round is still a record")
	_hud.set_best(900, 11, true, true)
	assert_eq(_hud.best_text(), "Best 900, group 11 (perfect)")


func test_the_message_tracks_the_round() -> void:
	assert_eq(_hud.message_text(), HUD.message_for(Session.State.READY, false))
	Game.start(4, 0.0)
	assert_false(_hud.target_met())
	assert_true(_hud.message_text().contains("two or more"), "how to play")
	Game.record_pop(4)
	assert_true(_hud.target_met())
	assert_true(_hud.message_text().contains("perfect"), "the board is still worth playing")
	Game.finish_board(false)
	assert_eq(_hud.message_text(), HUD.message_for(Session.State.WON, true))


func test_a_jammed_board_says_so() -> void:
	Game.start(20, 0.0)
	Game.record_pop(4)
	Game.finish_board(false)
	assert_eq(Game.state, Session.State.LOST)
	assert_true(_hud.message_text().contains("Stuck"))


func test_restarting_without_leaving_play_still_forgets_the_target() -> void:
	# Level.restart_level() starts a new round from inside PLAYING, where the
	# state never changes and state_changed never fires. The target flag has to
	# clear anyway, or the new board would open telling the player it was met.
	Game.start(4, 0.0)
	Game.record_pop(4)
	assert_true(_hud.target_met())
	Game.start(4, 0.0)
	assert_false(_hud.target_met())
	assert_true(_hud.message_text().contains("two or more"))
