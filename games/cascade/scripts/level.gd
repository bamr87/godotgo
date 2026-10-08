class_name Level
extends Node2D
## Cascade's main scene: the only place where a [Board], the [code]Game[/code]
## session, the [BoardView] and the pointer meet.
##
## Everything here is wiring. The rules are in the board, the round is in the
## session, the pixels are in the view and the records are in the store; a change
## that belongs to one of those does not belong in this file. Restarting reloads
## the level rather than the scene, because a level is data both of its sources
## can produce again on demand -- a seeded board rebuilds identically, so a
## restart is a genuine retry of the same puzzle rather than a new one.
##
## Mouse and keyboard drive the same [member cursor] rather than two parallel
## notions of what is selected: moving the pointer puts the cursor under it, the
## arrow keys step it, and a pop always takes the group the cursor is in. That is
## what lets the game be played, driven by a script and photographed without a
## pointer, and it is why the highlight has exactly one thing to follow.

## Which action steps the cursor which way.
const CURSOR_ACTIONS: Dictionary[StringName, Vector2i] = {
	&"move_up": Vector2i.UP,
	&"move_down": Vector2i.DOWN,
	&"move_left": Vector2i.LEFT,
	&"move_right": Vector2i.RIGHT,
}

## Level to open on boot, 1-based. The range matches [constant
## LevelBuilder.LEVELS]; raise it when more are added.
@export_range(1, 5, 1) var starting_level := 1
## Share of the board that has to be cleared to win. Below 1.0 on purpose: a
## board almost never comes apart completely, and a target nobody can reach is
## not a target.
@export_range(0.1, 1.0, 0.05) var target_ratio := 0.7
## Pixels reserved down the left edge for the HUD, so the board is centred in
## what is left rather than under the text.
@export_range(0.0, 480.0, 1.0) var board_margin_left := 250.0

## The board being played.
var board: Board
## Which level is open, 1-based.
var level_number := 1
## The cell a pop would take, kept inside the board at all times.
var cursor := Vector2i.ZERO
## Best-run storage. Replaceable so a test can point it at a scratch slot.
var score_store: ScoreStore

@onready var board_view: BoardView = $Board
@onready var hud: HUD = $HUD
@onready var _pop_sound: AudioStreamPlayer = $PopSound
@onready var _fall_sound: AudioStreamPlayer = $FallSound
@onready var _clear_sound: AudioStreamPlayer = $ClearSound


func _ready() -> void:
	score_store = ScoreStore.new()
	Game.won.connect(_on_won)
	Game.lost.connect(_on_lost)
	hud.set_title(ProjectSettings.get_setting("application/config/name", "Cascade"))
	load_level(starting_level)


func _process(_delta: float) -> void:
	if Game.is_playing():
		board_view.highlight_group(cursor)
	else:
		board_view.clear_highlight()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		move_cursor_to(cell_under_pointer())
		return
	# allow_echo is on for the cursor: a held arrow key should keep stepping,
	# which across a twelve-column board is the difference between playable and
	# tedious.
	for action: StringName in CURSOR_ACTIONS:
		if event.is_action_pressed(action, true):
			move_cursor_to(cursor + CURSOR_ACTIONS[action])
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"pop"):
		# A click says where as well as when; a key means the cursor as it is.
		if event is InputEventMouseButton:
			move_cursor_to(cell_under_pointer())
		try_pop(cursor)
	elif event.is_action_pressed(&"restart"):
		restart_level()
	elif event.is_action_pressed(&"next_level"):
		next_level()
	else:
		return
	get_viewport().set_input_as_handled()


## How many tiles must go before the board counts as beaten: [param ratio] of the
## [param total] it started with, rounded up, and never less than one so that
## [method Session.objective_complete] always has something to compare against.
static func goal_for(total: int, ratio: float) -> int:
	return maxi(ceili(float(total) * clampf(ratio, 0.0, 1.0)), 1)


## Opens a level by its 1-based number and starts a fresh round on it.
func load_level(number: int) -> void:
	level_number = clampi(number, 1, LevelBuilder.level_count())
	board = LevelBuilder.load_level(level_number)
	board.settled.connect(_on_board_settled)
	board_view.render(board)
	board_view.position = _centred_board_origin()
	move_cursor_to(cursor)
	hud.set_level(level_number, LevelBuilder.level_count(), LevelBuilder.level_name(level_number))
	_refresh_best()
	Game.start(goal_for(board.remaining(), target_ratio), 0.0)


## The save key for the open level.
func level_id() -> String:
	return LevelBuilder.level_id(level_number)


## The cell the mouse is over, in board coordinates. Cells off the board come
## back out of range, which every [Board] query already tolerates.
func cell_under_pointer() -> Vector2i:
	return board_view.local_to_cell(board_view.to_local(get_global_mouse_position()))


## Puts the cursor on [param cell], clamped onto the board. Clamping rather than
## refusing means an arrow key at the edge holds position instead of doing
## nothing visible, and a click off the board picks the nearest cell on it.
func move_cursor_to(cell: Vector2i) -> Vector2i:
	if board == null:
		return cursor
	cursor = Vector2i(
		clampi(cell.x, 0, maxi(board.size.x - 1, 0)), clampi(cell.y, 0, maxi(board.size.y - 1, 0))
	)
	return cursor


## Pops the group under [param cell] and folds the result into the round.
## Returns the tiles taken, or 0 for a refusal -- the round is over, the view is
## still playing the last pop, or the group was under [constant Board.MIN_GROUP].
## A refusal changes nothing at all.
func try_pop(cell: Vector2i) -> int:
	if not Game.is_playing() or not board_view.is_idle():
		return 0
	var count := board.pop(cell)
	if count == 0:
		return 0
	Game.record_pop(count)
	_pop_sound.play()
	# No legal pop left ends the round whichever way it goes; the session reads
	# the target to say which.
	if board.is_stuck():
		Game.finish_board(board.is_empty())
	return count


## Rebuilds the open level and starts over on it.
func restart_level() -> void:
	load_level(level_number)


## Moves on to the next level, wrapping past the last one. Refused until the
## board has been beaten, so N cannot be used to skip a level.
func next_level() -> bool:
	if Game.state != Session.State.WON:
		return false
	load_level(level_number % LevelBuilder.level_count() + 1)
	return true


## Stops every sound this level owns. An [AudioStreamPlayer] freed while its
## sample is still mixing leaves the playback registered with the audio server,
## so anything tearing a level down early should silence it first.
func silence() -> void:
	for player: AudioStreamPlayer in [_pop_sound, _fall_sound, _clear_sound]:
		player.stop()


func _centred_board_origin() -> Vector2:
	var view := get_viewport_rect().size
	var extent := board_view.board_size()
	var left := board_margin_left + (view.x - board_margin_left - extent.x) * 0.5
	return Vector2(left, (view.y - extent.y) * 0.5).round()


func _refresh_best() -> void:
	var id := level_id()
	hud.set_best(
		score_store.best_score(id),
		score_store.best_pop(id),
		score_store.has_record(id),
		score_store.is_perfect(id)
	)


func _on_board_settled(moves: Dictionary) -> void:
	if not moves.is_empty():
		_fall_sound.play()


func _on_won(_result: Dictionary) -> void:
	_clear_sound.play()
	_record_result()


func _on_lost(_reason: String) -> void:
	_record_result()


func _record_result() -> void:
	score_store.record_result(level_id(), Game.score, Game.best_pop, board.is_empty())
	_refresh_best()
