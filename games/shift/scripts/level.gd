class_name Level
extends Node2D
## Shift's main scene: the only place where a [Puzzle], the [code]Game[/code]
## session, the [BoardView] and the keyboard meet.
##
## Everything here is wiring. The rules are in the puzzle, the round is in the
## session, the pixels are in the view, and the best scores are in the store; if
## a change belongs to one of those, it does not belong in this file. Restarting
## does not reload the scene the way Leap's does, because a puzzle's start state
## is data the puzzle already keeps.

## Which action pushes the mover which way.
const MOVE_ACTIONS: Dictionary[StringName, Vector2i] = {
	&"move_up": Puzzle.UP,
	&"move_down": Puzzle.DOWN,
	&"move_left": Puzzle.LEFT,
	&"move_right": Puzzle.RIGHT,
}

## Level to open on boot, 1-based. The range matches the number of level files
## in levels/; raise it when more are added.
@export_range(1, 4, 1) var starting_level := 1
## Seconds allowed. Zero, and meant to stay zero: a puzzle is judged on moves,
## and this is the game that proves [Session] is happy with no countdown at all.
@export_range(0.0, 600.0, 1.0) var time_limit := 0.0
## Pixels reserved down the left edge for the HUD, so the board is centred in
## what is left rather than under the text.
@export_range(0.0, 480.0, 1.0) var board_margin_left := 250.0

## The board being played.
var puzzle: Puzzle
## Which level is open, 1-based.
var level_number := 1
## Best-score storage. Replaceable so a test can point it at a scratch slot.
var progress_store: ProgressStore

@onready var board: BoardView = $Board
@onready var hud: HUD = $HUD
@onready var _step_sound: AudioStreamPlayer = $StepSound
@onready var _push_sound: AudioStreamPlayer = $PushSound
@onready var _solved_sound: AudioStreamPlayer = $SolvedSound


func _ready() -> void:
	progress_store = ProgressStore.new()
	Game.won.connect(_on_won)
	hud.set_title(ProjectSettings.get_setting("application/config/name", "Shift"))
	load_level(starting_level)


func _unhandled_input(event: InputEvent) -> void:
	# allow_echo is on for movement: a held arrow key should keep walking, which
	# on a nine-cell board is the difference between playable and tedious.
	for action: StringName in MOVE_ACTIONS:
		if event.is_action_pressed(action, true):
			try_move(MOVE_ACTIONS[action])
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"undo", true):
		undo_move()
	elif event.is_action_pressed(&"restart"):
		restart_level()
	elif event.is_action_pressed(&"next_level"):
		next_level()
	else:
		return
	get_viewport().set_input_as_handled()


## Opens a level by its 1-based number and starts a fresh round on it.
func load_level(number: int) -> void:
	level_number = clampi(number, 1, LevelBuilder.level_count())
	puzzle = LevelBuilder.load_level(level_number)
	puzzle.moved.connect(_on_puzzle_moved)
	puzzle.undone.connect(_on_puzzle_undone)
	puzzle.solved.connect(_on_puzzle_solved)
	board.render(puzzle)
	board.position = _centred_board_origin()
	hud.set_level(level_number, LevelBuilder.level_count(), LevelBuilder.level_name(level_number))
	hud.set_best(progress_store.best_moves(level_id()))
	Game.start(puzzle.crate_count(), time_limit)
	Game.seed_crates_placed(puzzle.crates_on_targets())


## The save key for the open level.
func level_id() -> String:
	return LevelBuilder.level_id(level_number)


## Walks the mover one cell. Returns false when the round is over or the puzzle
## refused the move, and in neither case does the move counter change.
func try_move(direction: Vector2i) -> bool:
	if not Game.is_playing() or not puzzle.move(direction):
		return false
	Game.record_move()
	Game.set_crates_placed(puzzle.crates_on_targets())
	# A crate wedged into a corner it can never leave ends the round: without
	# this the player is left pressing keys against a board that cannot be won.
	if Game.is_playing() and puzzle.is_deadlocked():
		Game.lose(Game.REASON_STUCK)
	return true


## Takes the last move back, giving its move back too.
func undo_move() -> bool:
	if not Game.is_playing() or not puzzle.undo():
		return false
	Game.take_back_move()
	Game.set_crates_placed(puzzle.crates_on_targets())
	return true


## Puts the open level back to its starting layout with a fresh round.
func restart_level() -> void:
	puzzle.reset()
	board.render(puzzle)
	Game.start(puzzle.crate_count(), time_limit)
	Game.seed_crates_placed(puzzle.crates_on_targets())


## Moves on to the next level, wrapping past the last one. Refused while the
## board is unsolved, so N cannot be used to skip a puzzle.
func next_level() -> bool:
	if Game.state != Session.State.WON:
		return false
	load_level(level_number % LevelBuilder.level_count() + 1)
	return true


## Stops every sound this level owns. An [AudioStreamPlayer] freed while its
## sample is still mixing leaves the playback registered with the audio server,
## so anything tearing a level down early should silence it first.
func silence() -> void:
	for player: AudioStreamPlayer in [_step_sound, _push_sound, _solved_sound]:
		player.stop()


func _centred_board_origin() -> Vector2:
	var view := get_viewport_rect().size
	var extent := board.board_size()
	var left := board_margin_left + (view.x - board_margin_left - extent.x) * 0.5
	return Vector2(left, (view.y - extent.y) * 0.5).round()


func _on_puzzle_moved(_direction: Vector2i, pushed: bool) -> void:
	board.render(puzzle)
	if pushed:
		_push_sound.play()
	else:
		_step_sound.play()


func _on_puzzle_undone(_direction: Vector2i, _pushed: bool) -> void:
	board.render(puzzle)
	_step_sound.play()


func _on_puzzle_solved() -> void:
	_solved_sound.play()


func _on_won(_result: Dictionary) -> void:
	progress_store.record_completion(level_id(), Game.moves)
	hud.set_best(progress_store.best_moves(level_id()))
