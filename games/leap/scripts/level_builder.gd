class_name LevelBuilder
extends RefCounted
## Turns an ASCII [TextGrid] into the nodes that make up a Leap level.
##
## Keeping level geometry in a text file means levels are diffable, editable in
## any editor, and assertable in tests without opening a scene. Solid tiles are
## merged into horizontal runs so a wide floor costs one collision shape instead
## of one per tile.
##
## Map symbols:
## [codeblock]
## #  solid ground     @  hero spawn
## o  coin             ^  spike
## F  goal flag        .  empty (any unlisted character)
## [/codeblock]

const SOLID := "#"
const SPAWN := "@"
const COIN := "o"
const SPIKE := "^"
const GOAL := "F"


## Centre of a cell in world space.
static func cell_to_world(cell: Vector2i, tile_size: int) -> Vector2:
	return Vector2(cell.x * tile_size, cell.y * tile_size) + Vector2.ONE * (tile_size / 2.0)


## Merges runs of solid cells in each row into cell-space rectangles.
## A 10-wide floor becomes one Rect2i(x, y, 10, 1) instead of ten cells.
static func solid_runs(grid: TextGrid, symbols: String = SOLID) -> Array[Rect2i]:
	var runs: Array[Rect2i] = []
	for y in grid.height:
		var start := -1
		for x in grid.width + 1:
			var solid := x < grid.width and symbols.contains(grid.cell(x, y))
			if solid and start < 0:
				start = x
			elif not solid and start >= 0:
				runs.append(Rect2i(start, y, x - start, 1))
				start = -1
	return runs


## Builds every node described by [param grid] under [param parent].
##
## [param scenes] maps the symbols [constant COIN], [constant SPIKE] and
## [constant GOAL] to PackedScenes. Returns the spawn point and the nodes
## created, keyed "spawn", "solids", "coins", "hazards" and "goal".
static func build(
	parent: Node2D,
	grid: TextGrid,
	tile_size: int,
	scenes: Dictionary,
	tile_texture: Texture2D = null
) -> Dictionary:
	var result := {
		"spawn": Vector2.ZERO,
		"solids": [] as Array[StaticBody2D],
		"coins": [] as Array[Node2D],
		"hazards": [] as Array[Node2D],
		"goal": null,
	}

	for run in solid_runs(grid):
		var body := _make_solid(run, tile_size, tile_texture)
		parent.add_child(body)
		result["solids"].append(body)

	var spawn_cell := grid.find_first(SPAWN)
	if spawn_cell.x >= 0:
		result["spawn"] = cell_to_world(spawn_cell, tile_size)

	for symbol in [COIN, SPIKE, GOAL]:
		var scene: PackedScene = scenes.get(symbol)
		if scene == null:
			continue
		for cell in grid.find_all(symbol):
			var node: Node2D = scene.instantiate()
			node.position = cell_to_world(cell, tile_size)
			parent.add_child(node)
			match symbol:
				COIN:
					result["coins"].append(node)
				SPIKE:
					result["hazards"].append(node)
				GOAL:
					result["goal"] = node
	return result


static func _make_solid(run: Rect2i, tile_size: int, texture: Texture2D) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "Solid_%d_%d" % [run.position.x, run.position.y]
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector2(run.position.x * tile_size, run.position.y * tile_size)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(run.size.x * tile_size, tile_size)
	shape.shape = rect
	shape.position = rect.size / 2.0
	body.add_child(shape)

	if texture != null:
		for i in run.size.x:
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.position = Vector2(i * tile_size, 0) + Vector2.ONE * (tile_size / 2.0)
			sprite.scale = Vector2.ONE * (float(tile_size) / maxf(texture.get_width(), 1.0))
			body.add_child(sprite)
	return body
