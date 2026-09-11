class_name Tile
extends Sprite2D
## One tile on the board: a sprite that knows its colour and how to bow out.
##
## Tiles are handed out by an [ObjectPool], so the same node is a red disc on one
## board and a purple brick on the next. Everything that makes an instance
## specific is therefore set in [method apply] and undone in
## [method pool_released]; nothing may be assumed to survive a trip through the
## pool.
##
## The fade and the highlight are kept apart on purpose: the highlight owns the
## colour channels of [member CanvasItem.modulate] and the pop owns the alpha, so
## a tile can be lit and leaving at the same time without either one erasing the
## other.

## What a highlighted tile is multiplied by. Above one, so the group under the
## pointer is brighter than its neighbours rather than the neighbours being
## dimmer -- the board should not change mood as the mouse moves.
const HIGHLIGHT_TINT := Color(1.4, 1.4, 1.4, 1.0)

## The colour index this tile is showing, or [constant Board.EMPTY] while it is
## in the pool.
var colour := Board.EMPTY
## The scale that makes the texture fill its cell. The pop animation works in
## multiples of this, so cell size and animation never fight over [member scale].
var base_scale := Vector2.ONE


## Dresses a pooled tile as [param colour_index], sized so [param texture] covers
## [param pixels] across. A null texture leaves the tile blank rather than
## crashing, which is what keeps a half-wired scene debuggable.
func apply(colour_index: int, texture_2d: Texture2D, pixels: float) -> void:
	colour = colour_index
	texture = texture_2d
	base_scale = Vector2.ONE
	if texture_2d != null and texture_2d.get_width() > 0:
		base_scale = Vector2.ONE * (pixels / float(texture_2d.get_width()))
	scale = base_scale


## Plays the pop, with [param progress] running 0 (untouched) to 1 (gone). The
## tile shrinks towards its own centre and fades; the pool takes it back once the
## view has run this out.
func set_pop_progress(progress: float) -> void:
	var left := 1.0 - clampf(progress, 0.0, 1.0)
	scale = base_scale * left
	modulate.a = left


## Lights this tile as part of the group under the pointer.
func set_highlighted(on: bool) -> void:
	var tint := HIGHLIGHT_TINT if on else Color.WHITE
	modulate = Color(tint.r, tint.g, tint.b, modulate.a)


## Called by [ObjectPool] as the tile is handed out.
func pool_acquired() -> void:
	visible = true
	modulate = Color.WHITE
	base_scale = Vector2.ONE
	scale = Vector2.ONE


## Called by [ObjectPool] as the tile is taken back. A released tile keeps no
## trace of the board it came from: it is about to be dressed as something else.
func pool_released() -> void:
	visible = false
	colour = Board.EMPTY
	texture = null
	modulate = Color.WHITE
	scale = Vector2.ONE
