class_name LevelBuilder
extends RefCounted
## Reads Shift's levels out of plain ASCII text files and hands back a [Puzzle].
##
## Levels are text, not scenes, because that makes them diffable in a review,
## editable in any editor, and assertable in a test without opening Godot. The
## framework's [TextGrid] does the padding and lookup; this class only knows what
## the characters mean, and it is the single place that knowledge lives.
##
## Map symbols:
## [codeblock]
## #  wall                     .  floor
## @  mover                    &  mover standing on a target
## $  crate                    +  crate already sitting on a target
## *  target
## [/codeblock]
## Any other character (a space, most usefully) is treated as solid, so a level
## may be an irregular room padded out to a rectangle with blanks.

## The map characters, one per meaning. The table in the class docs above is the
## reference; these are what the code compares against.
const WALL := "#"
const FLOOR := "."
const PLAYER := "@"
const CRATE := "$"
const TARGET := "*"
const CRATE_ON_TARGET := "+"
const PLAYER_ON_TARGET := "&"

## Every character a mover may stand on. Derived from the symbols above so that
## adding one cannot leave it accidentally solid.
const WALKABLE := FLOOR + PLAYER + CRATE + TARGET + CRATE_ON_TARGET + PLAYER_ON_TARGET

## Where the shipped level files live.
const LEVEL_DIR := "res://levels"
## Level file stems in play order. Adding a level means adding a file and a name
## here, and the tests will immediately hold the new file to the same standard.
const LEVEL_IDS: PackedStringArray = ["level_1", "level_2", "level_3", "level_4"]
## Display names, parallel to [constant LEVEL_IDS].
const LEVEL_NAMES: PackedStringArray = [
	"First Push", "Twin Crates", "Three in a Row", "Around the Wall"
]


## How many levels ship with the game.
static func level_count() -> int:
	return LEVEL_IDS.size()


## The save-file key for a level, from its 1-based number. Out-of-range numbers
## clamp so a corrupt save can never ask for a level that is not there.
static func level_id(number: int) -> String:
	return LEVEL_IDS[_clamped_index(number)]


static func level_name(number: int) -> String:
	return LEVEL_NAMES[_clamped_index(number)]


static func level_path(number: int) -> String:
	return "%s/%s.txt" % [LEVEL_DIR, level_id(number)]


## Parses the shipped level with the given 1-based number.
static func load_level(number: int) -> Puzzle:
	return from_file(level_path(number))


static func from_file(path: String) -> Puzzle:
	return parse(TextGrid.from_file(path))


## Turns a parsed [TextGrid] into a [Puzzle]. Only the first mover symbol counts;
## later ones are ignored rather than fought over.
static func parse(grid: TextGrid) -> Puzzle:
	var walls: Array[Vector2i] = []
	var crates: Array[Vector2i] = []
	var targets: Array[Vector2i] = []
	var start := Vector2i.ZERO
	var found_player := false
	for y in grid.height:
		for x in grid.width:
			var pos := Vector2i(x, y)
			var symbol := grid.at(pos)
			if not WALKABLE.contains(symbol):
				walls.append(pos)
				continue
			if symbol == CRATE or symbol == CRATE_ON_TARGET:
				crates.append(pos)
			if symbol == TARGET or symbol == CRATE_ON_TARGET or symbol == PLAYER_ON_TARGET:
				targets.append(pos)
			if not found_player and (symbol == PLAYER or symbol == PLAYER_ON_TARGET):
				start = pos
				found_player = true
	return Puzzle.create(Vector2i(grid.width, grid.height), start, walls, crates, targets)


## Renders a puzzle back into the same character set. Round-tripping a level file
## through [method parse] and this is the cheapest possible proof that the symbol
## table is complete, and it makes board assertions in tests read like a picture.
static func to_text(puzzle: Puzzle) -> String:
	var rows: PackedStringArray = []
	for y in puzzle.size.y:
		var row := ""
		for x in puzzle.size.x:
			row += _symbol_at(puzzle, Vector2i(x, y))
		rows.append(row)
	return "\n".join(rows)


static func _symbol_at(puzzle: Puzzle, pos: Vector2i) -> String:
	if puzzle.is_wall(pos):
		return WALL
	var on_target := puzzle.is_target(pos)
	if puzzle.player == pos:
		return PLAYER_ON_TARGET if on_target else PLAYER
	if puzzle.has_crate(pos):
		return CRATE_ON_TARGET if on_target else CRATE
	return TARGET if on_target else FLOOR


static func _clamped_index(number: int) -> int:
	return clampi(number - 1, 0, LEVEL_IDS.size() - 1)
