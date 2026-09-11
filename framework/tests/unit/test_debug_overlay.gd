extends GodotGoTest
## The drop-in diagnostics panel. It builds its own UI, so the only setup a game
## needs is adding the node.

var _overlay: DebugOverlay


func before_each() -> void:
	_overlay = DebugOverlay.new()
	add_node(_overlay)


func after_each() -> void:
	await free_node(_overlay)


func test_builds_its_own_label_and_starts_hidden() -> void:
	assert_eq(_overlay.get_child_count(), 1)
	assert_is(_overlay.get_child(0), Label)
	assert_false(_overlay.visible, "hidden until F3 is pressed")


func test_reports_frames_per_second_without_a_session() -> void:
	var lines := _overlay.lines()
	assert_true(lines.size() >= 1)
	assert_true(lines[0].ends_with("fps"), "got %s" % lines[0])


func test_reports_session_details_when_a_game_autoload_exists() -> void:
	# The framework project has no Game autoload, so stand one up by hand.
	var session := Session.new()
	session.name = "Game"
	tree.root.add_child(session)
	var overlay := DebugOverlay.new()
	add_node(overlay)
	session.start(3, 30.0)
	session.advance()
	session.add_score(70)

	var text := "\n".join(overlay.lines())
	assert_true(text.contains("state PLAYING"), text)
	assert_true(text.contains("progress 1/3"), text)
	assert_true(text.contains("score 70"), text)
	assert_true(text.contains("time "), text)

	await free_node(overlay)
	await free_node(session)


func test_f3_toggles_visibility() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_F3
	press.pressed = true
	_overlay._input(press)
	assert_true(_overlay.visible)
	_overlay._input(press)
	assert_false(_overlay.visible)


func test_other_keys_are_ignored() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_A
	press.pressed = true
	_overlay._input(press)
	assert_false(_overlay.visible)
