extends GodotGoTest
## HUD presentation. The counters must come from [code]Game[/code] signals alone;
## only the level name and the best score are pushed in from outside.

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var _hud: HUD


func before_each() -> void:
	Game.reset()
	_hud = add_scene(HUD_SCENE) as HUD


func after_each() -> void:
	await free_node(_hud)
	Game.reset()


func test_messages_per_state() -> void:
	assert_eq(HUD.message_for(Session.State.READY), "", "nothing to say before a round")
	assert_true(HUD.message_for(Session.State.PLAYING).contains("U"), "tells the player about undo")
	assert_true(HUD.message_for(Session.State.WON).contains("N"), "and about the next level")
	assert_true(HUD.message_for(Session.State.LOST).contains("R"))


func test_counters_follow_the_session() -> void:
	assert_eq(_hud.crates_text(), "Crates 0 / 0")
	assert_eq(_hud.moves_text(), "Moves 0")
	assert_eq(_hud.message_text(), "")
	Game.start(3, 0.0)
	assert_eq(_hud.crates_text(), "Crates 0 / 3")
	assert_eq(_hud.message_text(), HUD.message_for(Session.State.PLAYING))
	Game.record_move()
	Game.record_move()
	assert_eq(_hud.moves_text(), "Moves 2")
	Game.set_crates_placed(1)
	assert_eq(_hud.crates_text(), "Crates 1 / 3")


func test_undo_shows_the_move_coming_back_off() -> void:
	Game.start(1, 0.0)
	Game.record_move()
	Game.take_back_move()
	assert_eq(_hud.moves_text(), "Moves 0")


func test_winning_changes_the_message() -> void:
	Game.start(1, 0.0)
	Game.set_crates_placed(1)
	assert_eq(_hud.message_text(), HUD.message_for(Session.State.WON))
	assert_eq(_hud.crates_text(), "Crates 1 / 1")


func test_the_level_line_names_the_puzzle() -> void:
	_hud.set_level(2, 4, "Twin Crates")
	assert_eq(_hud.level_text(), "Level 2/4 - Twin Crates")


func test_an_unsolved_level_has_no_best() -> void:
	_hud.set_best(0)
	assert_eq(_hud.best_text(), "Best -", "0 is 'never solved', not 'solved in no moves'")
	_hud.set_best(17)
	assert_eq(_hud.best_text(), "Best 17 moves")


func test_the_title_is_set_from_outside() -> void:
	_hud.set_title("Test Board")
	assert_eq(_hud.title_text(), "Test Board")
