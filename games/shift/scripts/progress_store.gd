class_name ProgressStore
extends RefCounted
## Which levels the player has solved and the fewest moves each took, persisted
## through the framework's [SaveSystem].
##
## Kept behind a small object rather than called statically so a test can point
## it at a throwaway slot and delete that slot afterwards, instead of trampling
## the player's real progress. The whole file is rewritten on every solve, not
## only on an improvement: it is a handful of integers, and one whole write is
## far easier to reason about than a partial update.
##
## [codeblock]
## var store := ProgressStore.new()
## store.record_completion("level_1", 12)   # true, that is a new best
## store.record_completion("level_1", 20)   # false, 12 still stands
## [/codeblock]

## The slot the game itself uses.
const SLOT := "shift-progress"
## Key holding the per-level record dictionaries inside the saved data.
const KEY_LEVELS := "levels"
## Keys inside one level's record.
const KEY_BEST_MOVES := "best_moves"
const KEY_COMPLETED := "completed"

## The [SaveSystem] slot this store reads and writes. Set once in [method _init]:
## changing it afterwards would leave the previous slot's records in memory and
## write them into the new one, so construct another store instead.
var slot := SLOT

# level id -> {best_moves: int, completed: bool}. Held in memory so the HUD can
# ask for a best score every frame without touching the disk.
var _levels := {}


func _init(save_slot: String = SLOT) -> void:
	slot = save_slot
	load_progress()


## Re-reads the slot, discarding anything held in memory. A missing or unreadable
## slot leaves an empty store rather than an error: a first run is not a failure.
func load_progress() -> void:
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
			# JSON has a single number type, so a move count comes back as a float.
			KEY_BEST_MOVES: maxi(int(record.get(KEY_BEST_MOVES, 0)), 0),
			KEY_COMPLETED: bool(record.get(KEY_COMPLETED, false)),
		}


func save_progress() -> Error:
	return SaveSystem.store(slot, {KEY_LEVELS: _levels})


## Fewest moves this level was ever solved in, or 0 when it never has been.
## A completed level always records at least one move, so 0 keeps exactly one
## meaning and the HUD can render it as "no record" without ambiguity.
func best_moves(level_id: String) -> int:
	var record: Dictionary = _levels.get(level_id, {})
	return maxi(int(record.get(KEY_BEST_MOVES, 0)), 0)


func has_record(level_id: String) -> bool:
	return _levels.has(level_id)


func is_completed(level_id: String) -> bool:
	var record: Dictionary = _levels.get(level_id, {})
	return bool(record.get(KEY_COMPLETED, false))


## Marks a level solved and keeps the better of the new and stored move counts.
## Returns true only when [param move_count] beat the stored best (or was the
## first ever), which is what the HUD uses to say "new best".
func record_completion(level_id: String, move_count: int) -> bool:
	# At least one: a stored 0 is the "never solved" sentinel, so a completion
	# must never produce a record that reads as no record.
	var moves := maxi(move_count, 1)
	var previous := best_moves(level_id)
	var improved := not is_completed(level_id) or moves < previous
	var record: Dictionary = _levels.get(level_id, {})
	record[KEY_COMPLETED] = true
	if improved:
		record[KEY_BEST_MOVES] = moves
	_levels[level_id] = record
	var err := save_progress()
	if err != OK:
		push_warning("ProgressStore: could not write slot '%s' (%s)" % [slot, error_string(err)])
	return improved


func completed_count() -> int:
	var done := 0
	for level_id: String in _levels:
		if is_completed(level_id):
			done += 1
	return done


## Forgets everything, on disk and in memory.
func erase_progress() -> Error:
	_levels.clear()
	return SaveSystem.erase(slot)
