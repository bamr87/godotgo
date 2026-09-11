extends GodotGoTest
## HUD presentation driven purely by Game signals.

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var _hud: HUD


func before_each() -> void:
	Game.reset()
	_hud = add_scene(HUD_SCENE) as HUD


func after_each() -> void:
	await free_node(_hud)
	Game.reset()


func test_format_time() -> void:
	assert_eq(HUD.format_time(90.0), "01:30.0")
	assert_eq(HUD.format_time(5.25), "00:05.3")
	assert_eq(HUD.format_time(0.0), "00:00.0")
	assert_eq(HUD.format_time(-3.0), "00:00.0", "negative time clamps to zero")


func test_messages_per_state() -> void:
	assert_eq(HUD.message_for(Session.State.READY), "")
	assert_true(HUD.message_for(Session.State.PLAYING).contains("orb"))
	assert_true(HUD.message_for(Session.State.WON).contains("R"))
	assert_true(HUD.message_for(Session.State.LOST).contains("R"))


func test_labels_follow_game_state() -> void:
	assert_eq(_hud.orbs_text(), "Orbs 0 / 0")
	assert_eq(_hud.message_text(), "")
	Game.start(3, 45.0)
	assert_eq(_hud.orbs_text(), "Orbs 0 / 3")
	assert_eq(_hud.time_text(), "Time 00:45.0")
	assert_eq(_hud.message_text(), HUD.message_for(Session.State.PLAYING))
	Game.collect_orb()
	assert_eq(_hud.orbs_text(), "Orbs 1 / 3")
	Game.win()
	assert_eq(_hud.message_text(), HUD.message_for(Session.State.WON))


func test_title_and_crosshair() -> void:
	_hud.set_title("Test Arena")
	assert_eq(_hud.title_text(), "Test Arena")
	var crosshair := _hud.get_node_or_null(^"Crosshair") as TextureRect
	assert_not_null(crosshair)
	assert_not_null(crosshair.texture, "crosshair.png must be imported and assigned")
