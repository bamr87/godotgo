class_name LevelBuilder
extends RefCounted
## Builds Cascade's boards, whether they were typed into a text file or grown
## from a seed, and renders one back into the same characters.
##
## Both kinds of level end up as the same [Board], which is the point: an
## authored board is a picture a person shaped, a generated one is five numbers,
## and nothing downstream can tell the difference. Authored levels teach the
## rules; generated ones supply boards nobody has memorised.
##
## Map symbols: [code].[/code] is an empty cell and [code]a[/code] to
## [code]e[/code] are the five tile colours. Anything else reads as empty, so a
## ragged file is padded rather than rejected.

## One character per colour; a colour's index is its position in this string.
const COLOUR_SYMBOLS := "abcde"
## The character for a cell with nothing in it.
const EMPTY_SYMBOL := "."
## Where the authored level files live.
const LEVEL_DIR := "res://levels"
## Every shipped level in play order. A level either names a [code]file[/code]
## under [constant LEVEL_DIR] or carries the [code]width[/code],
## [code]height[/code], [code]colours[/code] and [code]seed[/code] that
## [method Board.generate] needs. Adding a level means adding an entry here, and
## the tests immediately hold it to the same standard as the rest.
const LEVELS: Array[Dictionary] = [
	{"id": "level_1", "name": "First Drop", "file": "level_1"},
	{"id": "level_2", "name": "Four Colours", "file": "level_2"},
	{"id": "level_3", "name": "Tall Order", "file": "level_3"},
	{"id": "level_4", "name": "Scatter", "width": 10, "height": 8, "colours": 4, "seed": 20260911},
	{"id": "level_5", "name": "Prism", "width": 12, "height": 9, "colours": 5, "seed": 20260912},
]


## How many levels ship with the game.
static func level_count() -> int:
	return LEVELS.size()


## The record for a 1-based level number. Out-of-range numbers clamp, so a
## corrupt save can never ask for a level that is not there.
static func level_at(number: int) -> Dictionary:
	return LEVELS[clampi(number - 1, 0, LEVELS.size() - 1)]


## The save-file key for a level.
static func level_id(number: int) -> String:
	return str(level_at(number)["id"])


static func level_name(number: int) -> String:
	return str(level_at(number)["name"])


## True when the level is grown from a seed rather than read from a file.
static func is_generated(number: int) -> bool:
	return not level_at(number).has("file")


## The file a level is read from, or an empty string for a generated one.
static func level_path(number: int) -> String:
	var level := level_at(number)
	if not level.has("file"):
		return ""
	return "%s/%s.txt" % [LEVEL_DIR, level["file"]]


## The board for a 1-based level number, from whichever source it declares.
static func load_level(number: int) -> Board:
	if not is_generated(number):
		return from_file(level_path(number))
	var level := level_at(number)
	var extent := Vector2i(int(level["width"]), int(level["height"]))
	return Board.generate(extent, int(level["colours"]), Rng.new(int(level["seed"])))


static func from_file(path: String) -> Board:
	return parse(TextGrid.from_file(path))


## Parses a board out of inline text. The shortest way to write a board in a
## test, and the same code path the shipped files take.
static func from_text(text: String) -> Board:
	return parse(TextGrid.parse(text))


## Turns a parsed [TextGrid] into a [Board], then settles it.
##
## The settle is not cosmetic. A file may be typed with tiles floating over gaps,
## and the rules only ever describe a packed board; settling on load means the
## first frame already shows where everything rests, and a hand-written level
## cannot smuggle in a state [method Board.pop] would never produce.
static func parse(grid: TextGrid) -> Board:
	var cells := PackedInt32Array()
	for y in grid.height:
		for x in grid.width:
			cells.append(colour_for(grid.cell(x, y)))
	var board := Board.create(Vector2i(grid.width, grid.height), cells)
	board.settle()
	return board


## The colour index a map character means, or [constant Board.EMPTY].
static func colour_for(symbol: String) -> int:
	var index := COLOUR_SYMBOLS.find(symbol)
	return index if index >= 0 else Board.EMPTY


## The map character for a colour index, or [constant EMPTY_SYMBOL] for an empty
## cell and for any colour this game has no tile for.
static func symbol_for(colour: int) -> String:
	if colour < 0 or colour >= COLOUR_SYMBOLS.length():
		return EMPTY_SYMBOL
	return COLOUR_SYMBOLS[colour]


## Renders a board back into the same characters it was read from. Round-tripping
## a level file through [method parse] and this is the cheapest proof that the
## symbol table is complete, and it lets a test assert a whole board as a picture
## rather than as a list of cells.
static func to_text(board: Board) -> String:
	var rows: PackedStringArray = []
	for y in board.size.y:
		var row := ""
		for x in board.size.x:
			row += symbol_for(board.colour_at(Vector2i(x, y)))
		rows.append(row)
	return "\n".join(rows)
