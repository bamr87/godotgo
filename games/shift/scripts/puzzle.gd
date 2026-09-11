class_name Puzzle
extends RefCounted
## The complete rules of a Shift board: where things are, what a move does, and
## how to take one back. Deliberately free of nodes, scenes and signals from the
## engine's input system.
##
## Every interesting rule in this game lives here, so every interesting rule can
## be asserted in a headless test without instantiating anything. [BoardView]
## draws a puzzle and [LevelBuilder] reads one out of an ASCII file; neither is
## allowed to own a rule.
##
## [codeblock]
## var puzzle := LevelBuilder.load_level(1)
## puzzle.move(Puzzle.RIGHT)   # pushes a crate when one is in the way
## puzzle.undo()               # and takes the push back, crate included
## [/codeblock]

## Emitted after a move that actually happened. [param pushed] is true when the
## move shoved a crate, which is what the view uses to pick a sound.
signal moved(direction: Vector2i, pushed: bool)
## Emitted after [method undo] took a move back, with that move's arguments.
signal undone(direction: Vector2i, pushed: bool)
## Emitted the first time every crate sits on a target. Re-armed by an undo that
## breaks the solution, so a player who undoes past the win can hear it again.
signal solved

## The four moves, as cell offsets. Y grows downwards, the way a text file reads.
const UP := Vector2i(0, -1)
const DOWN := Vector2i(0, 1)
const LEFT := Vector2i(-1, 0)
const RIGHT := Vector2i(1, 0)
## The only vectors [method move] accepts; anything else is refused outright so
## a caller cannot invent a diagonal or a two-cell leap.
const DIRECTIONS: Array[Vector2i] = [UP, DOWN, LEFT, RIGHT]

## Board extent in cells. Everything outside it counts as solid.
var size := Vector2i.ZERO
## The mover's cell.
var player := Vector2i.ZERO

# Cells are stored as Dictionary keys rather than arrays: membership is the only
# question ever asked of them, and a hash lookup keeps move() O(1) on any board.
var _walls := {}
var _targets := {}
var _crates := {}
# One entry per accepted move: {"direction": Vector2i, "pushed": bool}. That is
# all undo needs, because a Sokoban move is exactly reversible from its own
# direction plus whether it carried a crate.
var _history: Array[Dictionary] = []
var _start_player := Vector2i.ZERO
var _start_crates: Array[Vector2i] = []
var _solved_announced := false


## Builds a board. [param walls] is every solid cell, [param crates] the movable
## boxes and [param targets] the cells they must end on.
static func create(
	board_size: Vector2i,
	start_player: Vector2i,
	walls: Array[Vector2i],
	crates: Array[Vector2i],
	targets: Array[Vector2i]
) -> Puzzle:
	var puzzle := Puzzle.new()
	puzzle.size = Vector2i(maxi(board_size.x, 0), maxi(board_size.y, 0))
	puzzle.player = start_player
	puzzle._start_player = start_player
	for cell in walls:
		puzzle._walls[cell] = true
	for cell in targets:
		puzzle._targets[cell] = true
	for cell in crates:
		puzzle._crates[cell] = true
		puzzle._start_crates.append(cell)
	# A board authored with every crate already home starts solved, so the flag
	# is seeded rather than assumed false; otherwise the first unrelated step
	# would announce a solution nobody produced.
	puzzle._solved_announced = puzzle.is_solved()
	return puzzle


## True for solid cells and for everything off the board, so callers never need
## a separate bounds check before asking.
func is_wall(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.y < 0 or pos.x >= size.x or pos.y >= size.y:
		return true
	return _walls.has(pos)


## True for a cell a crate has to end on. Targets are floor: the mover walks over
## them, and a crate only counts once it stops on one.
func is_target(pos: Vector2i) -> bool:
	return _targets.has(pos)


func has_crate(pos: Vector2i) -> bool:
	return _crates.has(pos)


## Whether [method move] would succeed, without changing anything. [method move]
## asks this first, so a refusal is decided before a single cell is touched and
## there is no half-applied move to unwind.
func can_move(direction: Vector2i) -> bool:
	if not DIRECTIONS.has(direction):
		return false
	var step := player + direction
	if is_wall(step):
		return false
	if not has_crate(step):
		return true
	var landing := step + direction
	return not is_wall(landing) and not has_crate(landing)


## Walks one cell, pushing a single crate ahead of the mover. Returns false and
## leaves the board untouched when the way is blocked: a wall, the board edge, or
## a crate that has a wall or a second crate behind it.
func move(direction: Vector2i) -> bool:
	if not can_move(direction):
		return false
	var step := player + direction
	var pushed := has_crate(step)
	if pushed:
		_crates.erase(step)
		_crates[step + direction] = true
	player = step
	_history.append({"direction": direction, "pushed": pushed})
	moved.emit(direction, pushed)
	_announce_if_newly_solved()
	return true


## Takes the last move back, crate and all. Returns false when the history is
## empty, which is also what makes "undo at the start of a level" harmless.
func undo() -> bool:
	if _history.is_empty():
		return false
	var step: Dictionary = _history.pop_back()
	var direction: Vector2i = step["direction"]
	var pushed: bool = step["pushed"]
	if pushed:
		# The crate this move shoved is one cell ahead of the mover; pull it back
		# into the cell the mover is about to leave.
		_crates.erase(player + direction)
		_crates[player] = true
	player -= direction
	undone.emit(direction, pushed)
	_announce_if_newly_solved()
	return true


## Puts every crate and the mover back where the level file had them and forgets
## the history. This is the "R" key, and it is why the start state is kept.
func reset() -> void:
	player = _start_player
	_crates.clear()
	for cell in _start_crates:
		_crates[cell] = true
	_history.clear()
	# Seeded from the board rather than set to false: a level authored with every
	# crate already home is solved before anyone moves, and must not announce
	# itself on the first unrelated step.
	_solved_announced = is_solved()


## True when every crate sits on a target. An empty board is never solved, so a
## malformed level cannot be won by accident.
func is_solved() -> bool:
	return not _crates.is_empty() and crates_on_targets() == _crates.size()


## True when the level is playable: at least one crate, exactly as many targets
## as crates, and a mover standing somewhere legal. Tests run this over every
## shipped level so a typo in a .txt file fails loudly.
func is_valid() -> bool:
	for pos: Vector2i in _crates:
		# is_wall() reports out-of-bounds cells as solid, so this covers a crate
		# placed off the board as well as one buried in a wall. Either way it can
		# never be pushed, so the level can never be solved.
		if is_wall(pos):
			return false
	return (
		crate_count() > 0
		and crate_count() == target_count()
		and not is_wall(player)
		and not has_crate(player)
	)


## True when no sequence of moves can finish the level any more, because some
## crate is wedged in a corner it can never leave.
##
## This is the cheap, certain half of Sokoban deadlock detection: a crate that is
## not on a target and has solid cells on two perpendicular sides cannot be moved
## along either axis, ever. It never reports a solvable board as stuck; it simply
## does not catch every stuck board, which is the right trade for a rule that
## runs after every keypress.
func is_deadlocked() -> bool:
	for pos: Vector2i in _crates:
		if _targets.has(pos):
			continue
		var blocked_x := is_wall(pos + LEFT) or is_wall(pos + RIGHT)
		var blocked_y := is_wall(pos + UP) or is_wall(pos + DOWN)
		if blocked_x and blocked_y:
			return true
	return false


func _announce_if_newly_solved() -> void:
	var was_announced := _solved_announced
	_solved_announced = is_solved()
	if _solved_announced and not was_announced:
		solved.emit()


## How many crates are home. Objective progress is exactly this number, and it
## goes down again as readily as up.
func crates_on_targets() -> int:
	var placed := 0
	for pos: Vector2i in _crates:
		if _targets.has(pos):
			placed += 1
	return placed


func crate_count() -> int:
	return _crates.size()


func target_count() -> int:
	return _targets.size()


## Moves made since the level started, minus the ones undone. This is the number
## the save file compares, so undo genuinely costs nothing but the move it erases.
func move_count() -> int:
	return _history.size()


## Crate cells in reading order, so a test can compare the whole set at once.
func crates() -> Array[Vector2i]:
	return _sorted(_crates.keys())


func targets() -> Array[Vector2i]:
	return _sorted(_targets.keys())


func walls() -> Array[Vector2i]:
	return _sorted(_walls.keys())


func _sorted(cells: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in cells:
		out.append(cell)
	out.sort_custom(_before)
	return out


func _before(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x
