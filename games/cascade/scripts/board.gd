class_name Board
extends RefCounted
## The complete rules of a Cascade board: which colour sits in each cell, what a
## pop takes with it, and where the survivors land afterwards.
##
## Nodes, scenes and input are deliberately absent. [BoardView] draws a board and
## [LevelBuilder] builds one from a text file or from a seed; neither is allowed
## to own a rule, so every rule in this game can be asserted headlessly against a
## few lines of ASCII.
##
## [codeblock]
## var board := LevelBuilder.load_level(1)
## board.pop(Vector2i(0, 0))   # clears the group, drops the rest, closes the gap
## [/codeblock]

## Emitted for a pop that happened, before the survivors move. [param cells] is
## the whole group in reading order, which is what the view needs to fade out
## exactly the tiles that went.
signal cleared(cells: Array[Vector2i], colour: int)
## Emitted straight after [signal cleared], carrying every cell that changed
## place as [code]from -> to[/code]. Empty when the pop moved nothing.
signal settled(moves: Dictionary)

## The colour of a cell with nothing in it, and what [method colour_at] reports
## for anything off the board.
const EMPTY := -1
## Tiles that must share a colour and touch before the group may be popped. Two
## is the classic rule, and [method is_stuck] leans on it; see the note there.
const MIN_GROUP := 2
## How many times [method generate] re-rolls a board that opens with no legal pop
## before it seats a pair by hand.
const MAX_FILL_ATTEMPTS := 8
## The four cells a group may grow through. Diagonals never join a group.
const NEIGHBOURS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

## Board extent in cells. Y grows downwards, the way a text file reads, so tiles
## fall towards increasing Y.
var size := Vector2i.ZERO

# One colour per cell, indexed y * size.x + x. A flat array rather than a
# dictionary of occupied cells: every cell always has an answer, and settling
# rewrites all of them at once.
var _cells := PackedInt32Array()


## Builds a board from [param cells] in reading order. Missing entries and any
## negative value are left [constant EMPTY], so a short array is a partial board
## rather than an error.
static func create(board_size: Vector2i, cells: PackedInt32Array) -> Board:
	var board := Board.new()
	board.size = Vector2i(maxi(board_size.x, 0), maxi(board_size.y, 0))
	var count := board.size.x * board.size.y
	board._cells.resize(count)
	board._cells.fill(EMPTY)
	for i in mini(count, cells.size()):
		board._cells[i] = cells[i] if cells[i] >= 0 else EMPTY
	return board


## Fills a board with [param colour_count] colours drawn from [param rng], so the
## same seed always produces the same board and a level can ship as five numbers
## instead of a file.
##
## A uniform fill can in principle come out with no two like tiles touching, and
## that board would be lost before the first click. Rather than hand one back,
## the fill is re-rolled from the generator's next values and, if even that keeps
## failing, a pair is seated outright: a level is always playable.
static func generate(board_size: Vector2i, colour_count: int, rng: Rng) -> Board:
	var colours := maxi(colour_count, 1)
	var board := create(board_size, PackedInt32Array())
	var count := board.size.x * board.size.y
	for attempt in MAX_FILL_ATTEMPTS:
		for i in count:
			board._cells[i] = rng.randi_range(0, colours - 1)
		if not board.is_stuck():
			return board
	board._seat_a_pair()
	return board


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## The colour in [param cell]. Blank cells and everything outside the board read
## as [constant EMPTY], so no caller needs a bounds check of its own.
func colour_at(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return EMPTY
	return _cells[cell.y * size.x + cell.x]


func is_filled(cell: Vector2i) -> bool:
	return colour_at(cell) != EMPTY


## Every cell reachable from [param cell] through orthogonal neighbours of the
## same colour, in reading order. Empty for a blank or off-board cell, and a
## lone tile comes back as a group of one rather than as nothing.
func group_at(cell: Vector2i) -> Array[Vector2i]:
	var group: Array[Vector2i] = []
	var colour := colour_at(cell)
	if colour == EMPTY:
		return group
	var seen := {cell: true}
	var pending: Array[Vector2i] = [cell]
	while not pending.is_empty():
		var current: Vector2i = pending.pop_back()
		group.append(current)
		for step: Vector2i in NEIGHBOURS:
			var next := current + step
			if seen.has(next) or colour_at(next) != colour:
				continue
			seen[next] = true
			pending.append(next)
	group.sort_custom(_before)
	return group


## Whether [method pop] would do anything, without changing the board.
func can_pop(cell: Vector2i) -> bool:
	return group_at(cell).size() >= MIN_GROUP


## Clears the group containing [param cell] and repacks the board. Returns how
## many tiles went, or 0 when the group was under [constant MIN_GROUP], in which
## case nothing moved and no signal fired.
func pop(cell: Vector2i) -> int:
	var group := group_at(cell)
	if group.size() < MIN_GROUP:
		return 0
	var colour := colour_at(cell)
	for target: Vector2i in group:
		_write(target, EMPTY)
	cleared.emit(group, colour)
	settled.emit(settle())
	return group.size()


## Drops every tile to the bottom of its column and slides the surviving columns
## left over any that emptied, returning the cells that moved as
## [code]from -> to[/code]. On an already-packed board it returns nothing and
## changes nothing, which is what makes it safe to call when loading a level.
##
## The fall and the column slide are one pass, not two. A tile only ever needs to
## be told its final cell; an intermediate one would be a frame of animation
## nobody asked for, and would put the same tile in the map twice.
func settle() -> Dictionary[Vector2i, Vector2i]:
	var columns: Array[PackedInt32Array] = []
	var sources: Array[Array] = []
	for x in size.x:
		var stack := PackedInt32Array()
		var from: Array[Vector2i] = []
		for y in range(size.y - 1, -1, -1):
			var cell := Vector2i(x, y)
			var colour := colour_at(cell)
			if colour == EMPTY:
				continue
			stack.append(colour)
			from.append(cell)
		# An emptied column is dropped rather than kept, and that is the whole
		# of the slide: the ones that follow simply take the next index.
		if stack.is_empty():
			continue
		columns.append(stack)
		sources.append(from)
	var moves: Dictionary[Vector2i, Vector2i] = {}
	_cells.fill(EMPTY)
	for new_x in columns.size():
		var column: PackedInt32Array = columns[new_x]
		var origins: Array = sources[new_x]
		for i in column.size():
			var target := Vector2i(new_x, size.y - 1 - i)
			_write(target, column[i])
			var origin: Vector2i = origins[i]
			if origin != target:
				moves[origin] = target
	return moves


## Tiles still on the board.
func remaining() -> int:
	var count := 0
	for colour: int in _cells:
		if colour != EMPTY:
			count += 1
	return count


## True once every tile has been popped, which is the perfect finish.
func is_empty() -> bool:
	return remaining() == 0


## True when no pop is legal any more, an emptied board included. This is what
## ends a round, so it has to be exact rather than merely cheap.
##
## With [constant MIN_GROUP] at 2 a legal pop exists precisely when some two
## orthogonally adjacent cells share a colour, so one sweep over the board
## answers it; a flood fill per cell would give the same answer for more work.
## Raising [constant MIN_GROUP] would invalidate that shortcut.
func is_stuck() -> bool:
	for y in size.y:
		for x in size.x:
			var colour := colour_at(Vector2i(x, y))
			if colour == EMPTY:
				continue
			# Only right and down: every adjacency is reached once that way.
			if colour == colour_at(Vector2i(x + 1, y)):
				return false
			if colour == colour_at(Vector2i(x, y + 1)):
				return false
	return true


## Every cell's colour in reading order, as a copy, so callers can compare a
## whole board in one assertion without being able to write to it.
func cells() -> PackedInt32Array:
	return _cells.duplicate()


func _write(cell: Vector2i, colour: int) -> void:
	if in_bounds(cell):
		_cells[cell.y * size.x + cell.x] = colour


## Copies one tile's colour onto a neighbour so at least one pop is legal.
## Only reached from [method generate] when every re-roll came back stuck, which
## needs a board too small or too thinly spread to hold a pair by chance.
func _seat_a_pair() -> void:
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			var colour := colour_at(cell)
			if colour == EMPTY:
				continue
			var candidates: Array[Vector2i] = [cell + Vector2i.RIGHT, cell + Vector2i.DOWN]
			for neighbour: Vector2i in candidates:
				if is_filled(neighbour):
					_write(neighbour, colour)
					return


func _before(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x
