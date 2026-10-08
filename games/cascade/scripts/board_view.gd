class_name BoardView
extends Node2D
## Draws a [Board] with pooled tiles and sequences the aftermath of a pop with a
## framework [StateMachine].
##
## The board mutates the instant a pop is accepted: the rules never wait for an
## animation. This node is therefore always catching up with a truth that has
## already moved on. [signal Board.cleared] says which tiles went and
## [signal Board.settled] says where the survivors ended up, and the state
## machine turns that pair into a fade followed by a fall.
##
## Unlike Swarm's per-enemy machine this one runs the board rather than an
## entity, and its states are as much a lock as an animation: [method is_idle] is
## false while tiles are still moving, and [Level] refuses input until it is true
## again. Without that, a second pop would be accepted against cells the player
## can see but the board has already vacated. [method finish_animation] skips
## straight to the end, which is how a test asserts the settled board without
## waiting out real seconds.
##
## The tile pool deliberately has no [member ObjectPool.max_size]. In Swarm the
## cap is the point -- it is the ceiling on bullets in flight -- but a board's
## tile count is dictated by the rules, so a cap here would silently leave tiles
## the player is supposed to be able to click undrawn.

## Emitted once the fade and the fall have both finished and input is live again.
signal animation_finished

## Waiting for input; the board on screen matches the board in memory.
const STATE_IDLE := &"idle"
## Popped tiles are shrinking and fading; the survivors have not moved yet.
const STATE_POPPING := &"popping"
## Survivors are sliding to the cells they already occupy in the rules.
const STATE_FALLING := &"falling"

## Pixel pitch of the grid. The tile itself is drawn smaller by
## [member tile_inset], and the difference is the gap between tiles.
@export_range(8, 128, 1) var cell_size := 44
## Pixels trimmed off a tile so neighbours do not touch.
@export_range(0, 32, 1) var tile_inset := 5
## Seconds a popped group takes to fade out.
@export_range(0.0, 1.0, 0.01) var pop_time := 0.14
## Seconds the survivors take to reach their new cells.
@export_range(0.0, 1.0, 0.01) var fall_time := 0.16

@export_group("Textures")
## One texture per colour index, assigned in scenes/main.tscn from the generated
## sprites. A colour with no entry draws blank rather than crashing.
@export var colour_textures: Array[Texture2D] = []

## The board's phase machine. Public so a test can watch
## [signal StateMachine.transitioned] rather than poll for a state.
var state_machine := StateMachine.new()

var _board: Board
var _tiles: Dictionary[Vector2i, Tile] = {}
var _popping: Array[Tile] = []
var _pending_moves: Dictionary = {}
var _falling: Array[Tile] = []
var _fall_from := PackedVector2Array()
var _fall_to := PackedVector2Array()

@onready var pool: ObjectPool = $TilePool
@onready var _tile_layer: Node2D = $Tiles


## The machine is built here rather than in [method Node._ready] so that it is
## usable the moment the node exists. [method render] resets it, and a caller
## that renders before the node is in the tree would otherwise be transitioning
## into states that had not been registered yet.
func _init() -> void:
	state_machine.add_state(STATE_IDLE)
	state_machine.add_state(STATE_POPPING, _popping_update)
	state_machine.add_state(STATE_FALLING, _falling_update)
	state_machine.start(STATE_IDLE)


func _process(delta: float) -> void:
	state_machine.update(delta)


## Draws [param board] from scratch and listens to it from then on. Safe to call
## mid-animation: whatever was moving is abandoned, because the board being drawn
## is the board as it is now.
func render(board: Board) -> void:
	if board == null:
		return
	_abandon_animation()
	if board != _board:
		_listen_to(board)
	_release_all()
	for y in _board.size.y:
		for x in _board.size.x:
			var cell := Vector2i(x, y)
			var colour := _board.colour_at(cell)
			if colour == Board.EMPTY:
				continue
			var tile := _spawn_tile(colour, cell)
			if tile != null:
				_tiles[cell] = tile


## Centre of [param cell] in this node's own space. Tiles are centred rather than
## corner-aligned so the pop shrinks towards the middle of the cell.
func cell_to_local(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * float(cell_size)


## The cell a point in this node's space falls in. Points outside the board come
## back as out-of-range cells, which every [Board] query already tolerates.
func local_to_cell(point: Vector2) -> Vector2i:
	return Vector2i((point / float(cell_size)).floor())


## The drawn board's pixel size, for whoever is centring it.
func board_size() -> Vector2:
	if _board == null:
		return Vector2.ZERO
	return Vector2(_board.size) * float(cell_size)


## How wide a tile's texture is drawn, once the gap is taken off the cell.
func tile_pixels() -> float:
	return float(maxi(cell_size - tile_inset, 1))


## The texture for a colour index, or null when the scene has none for it.
func texture_for(colour: int) -> Texture2D:
	if colour < 0 or colour >= colour_textures.size():
		return null
	return colour_textures[colour]


## True when nothing is moving and a pop may be accepted.
func is_idle() -> bool:
	return state_machine.current == STATE_IDLE


## Tiles currently drawn, popping ones excluded. Tests use it to prove the view
## is rebuilt rather than piled on top of itself.
func tile_count() -> int:
	return _tiles.size()


## The tile drawn in [param cell], or null when that cell is empty.
func tile_at(cell: Vector2i) -> Tile:
	return _tiles.get(cell)


## Brightens the group under [param cell] and nothing else. Ignored unless the
## view is idle, so a moving pointer cannot repaint tiles that are mid-animation.
## A cell with no legal pop in it simply clears the highlight, which is the
## honest answer: that group cannot be taken.
func highlight_group(cell: Vector2i) -> void:
	if not is_idle():
		return
	var group: Array[Vector2i] = []
	if _board != null and _board.can_pop(cell):
		group = _board.group_at(cell)
	for key: Vector2i in _tiles:
		_tiles[key].set_highlighted(group.has(key))


func clear_highlight() -> void:
	highlight_group(Vector2i(-1, -1))


## Runs the fade and the fall out to their end immediately and returns to
## [constant STATE_IDLE], emitting [signal animation_finished] as usual. Tests
## use it instead of waiting out real seconds.
func finish_animation() -> void:
	if state_machine.current == STATE_POPPING:
		_finish_pop()
	if state_machine.current == STATE_FALLING:
		_finish_fall()


func _listen_to(board: Board) -> void:
	if _board != null:
		_board.cleared.disconnect(_on_board_cleared)
		_board.settled.disconnect(_on_board_settled)
	_board = board
	_board.cleared.connect(_on_board_cleared)
	_board.settled.connect(_on_board_settled)


func _spawn_tile(colour: int, cell: Vector2i) -> Tile:
	var tile := pool.acquire() as Tile
	if tile == null:
		push_error("BoardView: the tile pool handed back nothing on %s" % get_path())
		return null
	_tile_layer.add_child(tile)
	tile.apply(colour, texture_for(colour), tile_pixels())
	tile.position = cell_to_local(cell)
	return tile


func _release_all() -> void:
	for cell: Vector2i in _tiles:
		pool.release(_tiles[cell])
	_tiles.clear()


func _on_board_cleared(cells: Array[Vector2i], _colour: int) -> void:
	# A pop arriving while the last one is still playing means something drove
	# the board past the input lock -- a test, or a tool. Land the previous
	# animation rather than dropping its tiles on the floor.
	finish_animation()
	for cell: Vector2i in cells:
		var tile: Tile = _tiles.get(cell)
		if tile == null:
			continue
		_tiles.erase(cell)
		tile.set_highlighted(false)
		_popping.append(tile)
	state_machine.transition_to(STATE_POPPING)


func _on_board_settled(moves: Dictionary) -> void:
	_pending_moves = moves


func _popping_update(_delta: float) -> void:
	var progress := _phase_progress(pop_time)
	for tile: Tile in _popping:
		tile.set_pop_progress(progress)
	if progress >= 1.0:
		_finish_pop()


func _finish_pop() -> void:
	for tile: Tile in _popping:
		pool.release(tile)
	_popping.clear()
	_take_up_moves()
	if _falling.is_empty():
		_land()
		return
	state_machine.transition_to(STATE_FALLING)


func _falling_update(_delta: float) -> void:
	var progress := _phase_progress(fall_time)
	# Squared, so tiles start slowly and gather speed the way falling looks.
	var eased := progress * progress
	for i in _falling.size():
		_falling[i].position = _fall_from[i].lerp(_fall_to[i], eased)
	if progress >= 1.0:
		_finish_fall()


func _finish_fall() -> void:
	for i in _falling.size():
		_falling[i].position = _fall_to[i]
	_land()


## Re-keys the drawn tiles onto the cells the board has already put them in, and
## notes which ones have somewhere to travel.
##
## The whole dictionary is rebuilt rather than edited in place because one pop's
## moves routinely use a cell as both a source and a destination; editing would
## overwrite a tile that had not been read yet.
func _take_up_moves() -> void:
	var next: Dictionary[Vector2i, Tile] = {}
	_falling.clear()
	_fall_from.clear()
	_fall_to.clear()
	for cell: Vector2i in _tiles:
		var tile: Tile = _tiles[cell]
		var target: Vector2i = _pending_moves.get(cell, cell)
		next[target] = tile
		if target == cell:
			continue
		_falling.append(tile)
		_fall_from.append(tile.position)
		_fall_to.append(cell_to_local(target))
	_tiles = next
	_pending_moves = {}


func _land() -> void:
	_falling.clear()
	_fall_from.clear()
	_fall_to.clear()
	state_machine.transition_to(STATE_IDLE)
	animation_finished.emit()


## Drops whatever was moving without finishing it, for a view that is about to
## draw a different board. No [signal animation_finished]: nothing arrived.
func _abandon_animation() -> void:
	for tile: Tile in _popping:
		pool.release(tile)
	_popping.clear()
	_falling.clear()
	_fall_from.clear()
	_fall_to.clear()
	_pending_moves = {}
	state_machine.transition_to(STATE_IDLE)


## How far the current phase has run, 0 to 1. A duration of zero is complete
## immediately, which is what makes the animations switchable off.
func _phase_progress(duration: float) -> float:
	if duration <= 0.0:
		return 1.0
	return minf(state_machine.time_in_state / duration, 1.0)
