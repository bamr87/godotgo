extends GodotGoTest
## HUD presentation, driven purely by Game signals.

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var _hud: HUD


func before_each() -> void:
	Game.reset()
	_hud = add_scene(HUD_SCENE) as HUD


func after_each() -> void:
	await free_node(_hud)
	Game.reset()


func test_hull_is_drawn_as_pips() -> void:
	assert_eq(HUD.format_hull(3, 3), "Hull |||")
	assert_eq(HUD.format_hull(1, 3), "Hull |..")
	assert_eq(HUD.format_hull(0, 3), "Hull ...")
	assert_eq(HUD.format_hull(-2, 3), "Hull ...", "a negative hull clamps")
	assert_eq(HUD.format_hull(9, 3), "Hull |||", "and so does an overfull one")


func test_a_message_for_every_state() -> void:
	assert_eq(HUD.message_for(Session.State.READY), "")
	assert_true(HUD.message_for(Session.State.PLAYING).contains("WASD"))
	assert_true(HUD.message_for(Session.State.WON).contains("R"))
	assert_true(HUD.message_for(Session.State.LOST).contains("R"))


func test_labels_render_a_reset_session() -> void:
	assert_eq(_hud.wave_text(), "Wave 0 / 0")
	assert_eq(_hud.kills_text(), "Kills 0")
	assert_eq(_hud.score_text(), "Score 0")
	assert_eq(_hud.hull_text(), HUD.format_hull(Game.MAX_HULL, Game.MAX_HULL))
	assert_eq(_hud.message_text(), "")


func test_labels_follow_a_round() -> void:
	Game.start(4, 0.0)
	assert_eq(_hud.wave_text(), "Wave 0 / 4")
	assert_eq(_hud.message_text(), HUD.message_for(Session.State.PLAYING))
	Game.start_wave(2)
	assert_eq(_hud.wave_text(), "Wave 1 / 4")
	Game.register_kill(25)
	assert_eq(_hud.kills_text(), "Kills 1")
	assert_eq(_hud.score_text(), "Score 25")
	Game.take_damage()
	assert_eq(_hud.hull_text(), HUD.format_hull(Game.MAX_HULL - 1, Game.MAX_HULL))
	Game.register_kill(25)
	assert_eq(_hud.kills_text(), "Kills 2")
	assert_eq(_hud.score_text(), "Score %d" % Game.score)


func test_the_status_line_reports_how_the_round_ended() -> void:
	Game.start(1, 0.0)
	Game.take_damage(Game.MAX_HULL)
	assert_eq(_hud.message_text(), HUD.message_for(Session.State.LOST))
	Game.start(1, 0.0)
	Game.start_wave(1)
	Game.register_kill(10)
	assert_eq(_hud.message_text(), HUD.message_for(Session.State.WON))


func test_the_title_comes_from_the_arena() -> void:
	_hud.set_title("Test Arena")
	assert_eq(_hud.title_text(), "Test Arena")
