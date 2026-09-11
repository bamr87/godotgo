class_name BoardView
extends Node2D
## Draws a [Puzzle] as a flat grid of [Sprite2D]s. No physics bodies, no tilemap,
## no collision: the board's truth is the puzzle object, and this node only ever
## reads it.
##
## The floor, walls and targets never move, so they are built once per level into
## a static layer; only the mover and the crates are touched on every move, which
## keeps a re-render after each keypress to a handful of property writes.

## Pixel size of one cell. The generated textures are 16 x 16 and are scaled to
## fit, so this is a free choice.
@export_range(8, 128, 1) var cell_size := 48

@export_group("Textures")
## Assigned in scenes/main.tscn from the generated 16 x 16 sprites; a missing one
## leaves that cell blank rather than crashing, which is what the null checks buy.
@export var wall_texture: Texture2D
@export var floor_texture: Texture2D
@export var target_texture: Texture2D
@export var crate_texture: Texture2D
## Drawn instead of [member crate_texture] for a crate that is home.
@export var crate_done_texture: Texture2D
@export var mover_texture: Texture2D

var _puzzle: Puzzle
var _static_layer: Node2D
var _actor_layer: Node2D
var _mover: Sprite2D
var _crate_sprites: Array[Sprite2D] = []


## Top-left corner of a cell, in this node's own space.
func cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(cell) * float(cell_size)


## The drawn board's pixel size, for whoever is centring it.
func board_size() -> Vector2:
	if _puzzle == null:
		return Vector2.ZERO
	return Vector2(_puzzle.size) * float(cell_size)


## Draws [param puzzle]. Rebuilds the scenery when handed a different puzzle than
## last time, then repaints the mover and crates; call it after every move, undo
## and reset.
func render(puzzle: Puzzle) -> void:
	if puzzle == null:
		return
	_ensure_layers()
	if puzzle != _puzzle:
		_puzzle = puzzle
		_build_static()
		_build_actors()
	_refresh_actors()


## Sprites currently on the board, scenery included. Tests use it to prove the
## view is rebuilt rather than piled on top of itself.
func sprite_count() -> int:
	if _static_layer == null:
		return 0
	return _static_layer.get_child_count() + _actor_layer.get_child_count()


## World position of the mover sprite, so a test can check the view followed the
## puzzle without reaching into the node tree.
func mover_cell() -> Vector2i:
	if _mover == null:
		return Vector2i(-1, -1)
	return Vector2i((_mover.position / float(cell_size)).floor())


func _ensure_layers() -> void:
	if _static_layer != null:
		return
	_static_layer = Node2D.new()
	_static_layer.name = "Scenery"
	add_child(_static_layer)
	_actor_layer = Node2D.new()
	_actor_layer.name = "Actors"
	add_child(_actor_layer)


func _build_static() -> void:
	for child in _static_layer.get_children():
		_static_layer.remove_child(child)
		child.queue_free()
	for y in _puzzle.size.y:
		for x in _puzzle.size.x:
			var cell := Vector2i(x, y)
			var wall := _puzzle.is_wall(cell)
			_add_sprite(_static_layer, wall_texture if wall else floor_texture, cell)
			if not wall and _puzzle.is_target(cell):
				_add_sprite(_static_layer, target_texture, cell)


func _build_actors() -> void:
	for child in _actor_layer.get_children():
		_actor_layer.remove_child(child)
		child.queue_free()
	_crate_sprites.clear()
	for i in _puzzle.crate_count():
		_crate_sprites.append(_add_sprite(_actor_layer, crate_texture, Vector2i.ZERO))
	_mover = _add_sprite(_actor_layer, mover_texture, _puzzle.player)


func _refresh_actors() -> void:
	var crates := _puzzle.crates()
	for i in _crate_sprites.size():
		var sprite := _crate_sprites[i]
		var cell: Vector2i = crates[i]
		sprite.position = cell_to_local(cell)
		sprite.texture = crate_done_texture if _puzzle.is_target(cell) else crate_texture
	_mover.position = cell_to_local(_puzzle.player)


func _add_sprite(parent: Node2D, texture: Texture2D, cell: Vector2i) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	# The generated art is 16 x 16; scale it to whatever cell_size the level wants
	# instead of shipping one texture per zoom level.
	if texture != null and texture.get_width() > 0:
		sprite.scale = Vector2.ONE * (float(cell_size) / float(texture.get_width()))
	sprite.position = cell_to_local(cell)
	parent.add_child(sprite)
	return sprite
