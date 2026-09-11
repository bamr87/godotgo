extends SceneTree
## Boots a GodotGo game for real, drives it with scripted input, captures PNG
## screenshots and reports the session state as JSON.
##
## This is the piece `tools/smoke.sh` cannot be: smoke boots with `--headless`,
## which selects the dummy renderer, so it proves a scene loads but produces no
## pixels and reads no gameplay. This one runs a real rendering backend, so it
## can answer "what does the game look like after the player does X".
##
## Launched with `--script`, never `--headless`. Arguments come after `--`:
##
##   --scene=res://path.tscn   scene to run (default: the project's main scene)
##   --out=/abs/dir            where screenshots land (default: /tmp/godotgo-shots)
##   --steps=a,b,c             the script to perform (default: wait:90,shot:boot)
##   --settle=N                frames to wait before the first step (default: 30)
##
## Steps, comma separated, performed in order:
##
##   wait:N            advance N frames
##   press:ACTION:N    hold an input action for N frames, then release it
##   tap:ACTION        press and release across a single frame
##   shot:NAME         write NAME.png
##   state             print one JSON line of the session state
##
## Normally you do not invoke this directly: drive.sh next to it wraps the
## container, Xvfb and the software-Vulkan environment. Directly, from the
## workspace root, it looks like this - note the ABSOLUTE script path, because
## this file lives outside every Godot project and res:// cannot address it:
##
##   godot --path games/leap --audio-driver Dummy \
##     --script "$PWD/.claude/skills/run-godotgo/driver.gd" \
##     -- --out=/tmp/shots --steps=wait:60,shot:spawn,press:move_right:45,state
##
## Exit code is 0 when every step ran, 1 if a step was malformed or a screenshot
## could not be written, so a caller can trust the run rather than grep for it.

const DEFAULT_STEPS := "wait:90,shot:boot,state"
const DEFAULT_OUT := "/tmp/godotgo-shots"

var _out_dir := DEFAULT_OUT
var _steps: PackedStringArray = []
var _settle := 30
var _status := 0
var _shots := 0


func _initialize() -> void:
	var scene_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--steps="):
			_steps = arg.trim_prefix("--steps=").split(",", false)
		elif arg.begins_with("--settle="):
			_settle = maxi(0, int(arg.trim_prefix("--settle=")))
		else:
			_fail("unknown argument %s" % arg)
			return
	if _steps.is_empty():
		_steps = DEFAULT_STEPS.split(",", false)
	if scene_path.is_empty():
		scene_path = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if scene_path.is_empty():
		_fail("no --scene given and this project has no main scene")
		return
	if DirAccess.make_dir_recursive_absolute(_out_dir) != OK:
		_fail("cannot create output directory %s" % _out_dir)
		return

	var packed := load(scene_path) as PackedScene
	if packed == null:
		_fail("cannot load scene %s" % scene_path)
		return
	root.add_child(packed.instantiate())
	print("[driver] scene=%s out=%s steps=%d" % [scene_path, _out_dir, _steps.size()])
	_drive()


## The step machine. Runs as a coroutine so a screenshot can wait for the frame
## it is meant to photograph to actually be drawn.
func _drive() -> void:
	# Nothing is on screen for the first few frames: the window is still being
	# sized and the game's own _ready work has not run. Photographing before
	# this settles gives a black rectangle that looks like a crash.
	await _frames(_settle)

	for step in _steps:
		var parts := step.split(":", false)
		if parts.is_empty():
			continue
		match parts[0]:
			"wait":
				if parts.size() != 2:
					_fail("wait needs a frame count: %s" % step)
					break
				await _frames(int(parts[1]))
			"press":
				if parts.size() != 3:
					_fail("press needs an action and a frame count: %s" % step)
					break
				if not InputMap.has_action(parts[1]):
					_fail("no such input action: %s" % parts[1])
					break
				_send(parts[1], true)
				await _frames(int(parts[2]))
				_send(parts[1], false)
				await _frames(1)
			"tap":
				if parts.size() != 2:
					_fail("tap needs an action: %s" % step)
					break
				if not InputMap.has_action(parts[1]):
					_fail("no such input action: %s" % parts[1])
					break
				_send(parts[1], true)
				await _frames(1)
				_send(parts[1], false)
				await _frames(1)
			"shot":
				if parts.size() != 2:
					_fail("shot needs a name: %s" % step)
					break
				await _capture(parts[1])
			"state":
				_report_state()
			_:
				_fail("unknown step %s" % step)
				break

	print("[driver] done: %d screenshot(s) in %s" % [_shots, _out_dir])
	# Let the last frame finish before tearing the tree down, so a screenshot
	# written on the final step is flushed.
	await _frames(2)
	quit(_status)


## Drives an action two ways at once, because the games read input two ways.
##
## Input.action_press() only moves the polled state that is_action_pressed()
## reads, which is what the character controllers use. It dispatches no event at
## all, so a game reading _unhandled_input() never hears it - Shift takes every
## move that way and sat at "Moves 0" through a whole run of taps. Feeding an
## InputEventAction through parse_input_event() covers that half, and also
## updates the polled state, so sending both is safe rather than doubled: the
## two land in the same frame and a just_pressed edge still fires once.
func _send(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


## Counts PHYSICS frames, not rendered ones. Gameplay lives in _physics_process,
## which Godot ticks at a fixed 60 Hz, so 60 here is one second of game time no
## matter how fast the renderer is going. Counting rendered frames instead makes
## every step's duration depend on the GPU: under Xvfb with software rendering
## and no vsync the engine free-runs at around 150 fps, so `press:move_right:90`
## moved the hero for 0.6 s rather than the 1.5 s it reads as.
func _frames(count: int) -> void:
	for _i in maxi(count, 0):
		await physics_frame


## Writes the root viewport to a PNG. The await is the whole trick: the viewport
## texture only holds the finished frame after the server has drawn it, so
## capturing from inside a process frame photographs the frame before.
func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("viewport gave no image for %s; is this running with --headless?" % name)
		return
	var path := _out_dir.path_join("%s.png" % name)
	if image.save_png(path) != OK:
		_fail("cannot write %s" % path)
		return
	_shots += 1
	print("[driver] shot %s %dx%d" % [path, image.get_width(), image.get_height()])


## One JSON line, so a caller can parse the run instead of reading prose.
func _report_state() -> void:
	var game := root.get_node_or_null(^"Game")
	if game == null:
		print('[driver] state {"game":null}')
		return
	var state := {
		"state": game.state,
		"state_name": ["READY", "PLAYING", "PAUSED", "WON", "LOST"][game.state],
		"score": game.score,
		"progress": game.progress,
		"goal": game.goal,
		"time_left": snappedf(game.time_left, 0.1),
		"elapsed": snappedf(game.elapsed, 0.1),
	}
	print("[driver] state %s" % JSON.stringify(state))


func _fail(message: String) -> void:
	printerr("[driver] %s" % message)
	_status = 1
