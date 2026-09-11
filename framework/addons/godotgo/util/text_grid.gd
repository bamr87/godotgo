class_name TextGrid
extends RefCounted
## An ASCII level map parsed into single-character cells.
##
## Levels are plain text files, which makes them diffable, hand-editable and
## trivial to assert on in tests. Rows are padded with spaces to a common width.
##
## [codeblock]
## var grid := TextGrid.parse("###\n#@#\n###")
## grid.find_first("@")  # -> Vector2i(1, 1)
## [/codeblock]

const EMPTY := " "

var width := 0
var height := 0

var _rows: PackedStringArray = []


## Parses text into a grid. Blank leading and trailing lines are dropped.
static func parse(text: String) -> TextGrid:
	var grid := TextGrid.new()
	var lines := text.replace("\r\n", "\n").split("\n")
	var rows: PackedStringArray = []
	for line in lines:
		rows.append(line)
	while not rows.is_empty() and rows[0].strip_edges().is_empty():
		rows.remove_at(0)
	while not rows.is_empty() and rows[rows.size() - 1].strip_edges().is_empty():
		rows.remove_at(rows.size() - 1)
	var widest := 0
	for row in rows:
		widest = maxi(widest, row.length())
	for i in rows.size():
		rows[i] = rows[i].rpad(widest, EMPTY)
	grid._rows = rows
	grid.width = widest
	grid.height = rows.size()
	return grid


## Parses a [code]res://[/code] or [code]user://[/code] text file. Returns an
## empty grid when the file cannot be read.
static func from_file(path: String) -> TextGrid:
	if not FileAccess.file_exists(path):
		push_warning("TextGrid: no such file %s" % path)
		return TextGrid.parse("")
	return TextGrid.parse(FileAccess.get_file_as_string(path))


func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < width and pos.y < height


## The character at [param pos], or [constant EMPTY] when out of bounds.
func at(pos: Vector2i) -> String:
	if not in_bounds(pos):
		return EMPTY
	return _rows[pos.y][pos.x]


func cell(x: int, y: int) -> String:
	return at(Vector2i(x, y))


## Overwrites one cell. Out-of-bounds writes are ignored.
func set_at(pos: Vector2i, symbol: String) -> void:
	if not in_bounds(pos) or symbol.length() != 1:
		return
	var row := _rows[pos.y]
	_rows[pos.y] = row.substr(0, pos.x) + symbol + row.substr(pos.x + 1)


## Every position holding [param symbol], in reading order.
func find_all(symbol: String) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for y in height:
		for x in width:
			if _rows[y][x] == symbol:
				found.append(Vector2i(x, y))
	return found


## The first position holding [param symbol], or (-1, -1) when absent.
func find_first(symbol: String) -> Vector2i:
	for y in height:
		for x in width:
			if _rows[y][x] == symbol:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Every position whose character appears in [param symbols].
func find_any(symbols: String) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for y in height:
		for x in width:
			if symbols.contains(_rows[y][x]):
				found.append(Vector2i(x, y))
	return found


func count(symbol: String) -> int:
	return find_all(symbol).size()


## An independent copy, safe to mutate.
func clone() -> TextGrid:
	return TextGrid.parse(to_text())


func to_text() -> String:
	return "\n".join(_rows)
