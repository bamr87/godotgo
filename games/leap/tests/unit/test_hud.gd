extends GodotGoTest
## HUD formatting and its binding to the session's signals.

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var _hud: HUD


func before_each() -> void:
	Game.reset()
	_hud = add_scene(HUD_SCENE) as HUD


func after_each() -> void:
	await free_node(_hud)
	Game.reset()


func test_format_time() -> void:
	assert_eq(HUD.format_time(60.0), "01:00.0")
	assert_eq(HUD.format_time(5.25), "00:05.3")
	assert_eq(HUD.format_time(0.0), "00:00.0")
	assert_eq(HUD.format_time(-3.0), "00:00.0", "negative time clamps to zero")


func test_messages_per_state() -> void:
	assert_eq(HUD.message_for(Session.State.READY), "")
	assert_true(HUD.message_for(Session.State.PLAYING).contains("flag"))
	assert_true(HUD.message_for(Session.State.WON).contains("R"))
	assert_true(HUD.message_for(Session.State.LOST).contains("R"))


func test_labels_follow_the_session() -> void:
	Game.start(3, 45.0)
	assert_eq(_hud.coins_text(), "Coins 0 / 3")
	assert_eq(_hud.time_text(), "Time 00:45.0")
	assert_eq(_hud.score_text(), "Score 0")
	assert_eq(_hud.message_text(), HUD.message_for(Session.State.PLAYING))
	Game.collect_coin()
	assert_eq(_hud.coins_text(), "Coins 1 / 3")
	assert_eq(_hud.score_text(), "Score %d" % Game.POINTS_PER_COIN)


func test_lives_are_drawn_as_pips_and_then_as_none() -> void:
	Game.start(1, 0.0)
	assert_eq(_hud.lives_text(), "Lives " + "*".repeat(Game.MAX_DEATHS))
	Game.lose_life()
	assert_eq(_hud.lives_text(), "Lives " + "*".repeat(Game.MAX_DEATHS - 1))
	for i in Game.MAX_DEATHS:
		Game.lose_life()
	assert_eq(_hud.lives_text(), "Lives none")


func test_the_title_is_settable() -> void:
	_hud.set_title("Test Level")
	assert_eq(_hud.title_text(), "Test Level")
