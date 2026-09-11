class_name ScoreStore
extends RefCounted
## The best run on record for each level, persisted through the framework's
## [SaveSystem].
##
## Kept behind a small object rather than called statically so a test can point
## it at a throwaway slot and delete that slot afterwards, instead of trampling
## the progress of whoever is actually playing.
##
## A score of zero is a legitimate result here -- a board can jam before the
## first legal pop -- so unlike a puzzle's move count there is no value that can
## stand in for "never played". Whether a level has a record is the presence of
## its entry, which is what [method has_record] asks and why the HUD cannot
## confuse an unplayed level with a bad round.
##
## [codeblock]
## var store := ScoreStore.new()
## store.record_result("level_1", 240, 9, false)   # true, the first is a best
## store.record_result("level_1", 180, 4, false)   # false, 240 still stands
## [/codeblock]

## The slot the game itself uses.
const SLOT := "cascade-scores"
## Key holding the per-level records inside the saved data.
const KEY_LEVELS := "levels"
## Keys inside one level's record.
const KEY_BEST_SCORE := "best_score"
const KEY_BEST_POP := "best_pop"
const KEY_PERFECT := "perfect"

## The [SaveSystem] slot this store reads and writes. Set once in [method _init]:
## changing it afterwards would leave the previous slot's records in memory and
## write them into the new one, so construct another store instead.
var slot := SLOT

# level id -> {best_score: int, best_pop: int, perfect: bool}. Held in memory so
# the HUD can ask for a best score without touching the disk.
var _levels := {}


func _init(save_slot: String = SLOT) -> void:
	slot = save_slot
	load_scores()


## Re-reads the slot, discarding anything held in memory. A missing or unreadable
## slot leaves an empty store rather than an error: a first run is not a failure.
func load_scores() -> void:
	_levels.clear()
	var data := SaveSystem.fetch(slot, {})
	var saved: Variant = data.get(KEY_LEVELS, {})
	if not saved is Dictionary:
		return
	var levels: Dictionary = saved
	for key: Variant in levels:
		var entry: Variant = levels[key]
		if not entry is Dictionary:
			continue
		var record: Dictionary = entry
		_levels[str(key)] = {
			# JSON has a single number type, so both counts come back as floats.
			KEY_BEST_SCORE: maxi(int(record.get(KEY_BEST_SCORE, 0)), 0),
			KEY_BEST_POP: maxi(int(record.get(KEY_BEST_POP, 0)), 0),
			KEY_PERFECT: bool(record.get(KEY_PERFECT, false)),
		}


func save_scores() -> Error:
	return SaveSystem.store(slot, {KEY_LEVELS: _levels})


## True once this level has been played to an ending at least once.
func has_record(level_id: String) -> bool:
	return _levels.has(level_id)


## Highest score ever taken from this level, or 0 when it has never been played.
## Ask [method has_record] to tell those two apart.
func best_score(level_id: String) -> int:
	return maxi(int(_record(level_id).get(KEY_BEST_SCORE, 0)), 0)


## Largest group ever popped on this level, in tiles.
func best_pop(level_id: String) -> int:
	return maxi(int(_record(level_id).get(KEY_BEST_POP, 0)), 0)


## True when this level has been cleared down to an empty board at least once.
func is_perfect(level_id: String) -> bool:
	return bool(_record(level_id).get(KEY_PERFECT, false))


## Files the result of a finished round. Each figure is kept at its own best, so
## a run with a huge group but a poor score still improves the group record.
## Returns true when [param score] beat the stored best, which is what the HUD
## uses to say "new best".
func record_result(level_id: String, score: int, biggest_pop: int, cleared_all: bool) -> bool:
	# Read every stored figure before writing any of them: _record() hands back
	# the live dictionary for a level that already has one, so an interleaved
	# read would see this round's value instead of the record it is beating.
	var previous_score := best_score(level_id)
	var previous_pop := best_pop(level_id)
	var previous_perfect := is_perfect(level_id)
	var improved := not has_record(level_id) or score > previous_score
	_levels[level_id] = {
		KEY_BEST_SCORE: maxi(score, previous_score),
		KEY_BEST_POP: maxi(biggest_pop, previous_pop),
		KEY_PERFECT: cleared_all or previous_perfect,
	}
	var err := save_scores()
	if err != OK:
		push_warning("ScoreStore: could not write slot '%s' (%s)" % [slot, error_string(err)])
	return improved


## How many levels have been played to an ending.
func played_count() -> int:
	return _levels.size()


## Forgets everything, on disk and in memory.
func erase_scores() -> Error:
	_levels.clear()
	return SaveSystem.erase(slot)


func _record(level_id: String) -> Dictionary:
	return _levels.get(level_id, {})
