extends GodotGoTest
## Best-score persistence through the framework's [SaveSystem].
##
## Everything here runs against a scratch slot that [method after_each] deletes,
## so a test run never touches the progress of whoever is actually playing.

## A slot name no build of the game uses.
const SLOT := "shift-test-progress"

var _store: ProgressStore


func before_each() -> void:
	Game.reset()
	SaveSystem.erase(SLOT)
	_store = ProgressStore.new(SLOT)


func after_each() -> void:
	SaveSystem.erase(SLOT)
	_store = null
	Game.reset()


func test_a_fresh_store_knows_nothing() -> void:
	assert_false(_store.has_record("level_1"))
	assert_false(_store.is_completed("level_1"))
	assert_eq(_store.best_moves("level_1"), 0, "0 means never solved, not solved in zero moves")
	assert_eq(_store.completed_count(), 0)


func test_recording_a_solve_marks_it_complete() -> void:
	assert_true(_store.record_completion("level_1", 12), "the first solve is always a best")
	assert_true(_store.has_record("level_1"))
	assert_true(_store.is_completed("level_1"))
	assert_eq(_store.best_moves("level_1"), 12)
	assert_eq(_store.completed_count(), 1)


func test_a_solve_round_trips_through_the_save_file() -> void:
	_store.record_completion("level_2", 31)
	assert_true(SaveSystem.has_slot(SLOT), "recording writes the slot straight away")
	var reloaded := ProgressStore.new(SLOT)
	assert_true(reloaded.is_completed("level_2"))
	assert_eq(reloaded.best_moves("level_2"), 31, "the count survives JSON as an int, not a float")
	assert_eq(typeof(reloaded.best_moves("level_2")), TYPE_INT)


func test_a_better_score_replaces_a_worse_one() -> void:
	_store.record_completion("level_1", 20)
	assert_true(_store.record_completion("level_1", 14), "14 beats 20")
	assert_eq(_store.best_moves("level_1"), 14)
	assert_eq(ProgressStore.new(SLOT).best_moves("level_1"), 14, "and the file agrees")


func test_a_worse_score_does_not_overwrite_a_better_one() -> void:
	_store.record_completion("level_1", 14)
	assert_false(_store.record_completion("level_1", 20), "20 does not beat 14")
	assert_eq(_store.best_moves("level_1"), 14)
	assert_true(_store.is_completed("level_1"), "but the level is still complete")
	assert_eq(ProgressStore.new(SLOT).best_moves("level_1"), 14)


func test_an_equal_score_is_not_an_improvement() -> void:
	_store.record_completion("level_1", 14)
	assert_false(_store.record_completion("level_1", 14))
	assert_eq(_store.best_moves("level_1"), 14)


func test_a_nonsense_move_count_still_leaves_a_readable_record() -> void:
	# 0 is the "never solved" sentinel that the HUD renders as no record, so a
	# completion must never store it: a level cannot be both done and unplayed.
	assert_true(_store.record_completion("level_1", -5))
	assert_eq(_store.best_moves("level_1"), 1)
	assert_true(_store.is_completed("level_1"), "and the level still counts as done")
	assert_ne(_store.best_moves("level_1"), 0, "a completed level never reads as never solved")


func test_levels_are_tracked_independently() -> void:
	_store.record_completion("level_1", 6)
	_store.record_completion("level_3", 40)
	assert_eq(_store.best_moves("level_1"), 6)
	assert_eq(_store.best_moves("level_3"), 40)
	assert_eq(_store.best_moves("level_2"), 0, "an untouched level stays untouched")
	assert_eq(_store.completed_count(), 2)


func test_erase_forgets_everything() -> void:
	_store.record_completion("level_1", 6)
	assert_eq(_store.erase_progress(), OK)
	assert_false(SaveSystem.has_slot(SLOT))
	assert_eq(_store.best_moves("level_1"), 0)
	assert_eq(ProgressStore.new(SLOT).completed_count(), 0)


func test_load_progress_re_reads_the_slot() -> void:
	var other := ProgressStore.new(SLOT)
	other.record_completion("level_4", 55)
	assert_eq(_store.best_moves("level_4"), 0, "this store has not looked since")
	_store.load_progress()
	assert_eq(_store.best_moves("level_4"), 55)


func test_the_game_and_the_tests_use_different_slots() -> void:
	assert_ne(ProgressStore.SLOT, SLOT, "a test must never write the player's own progress")
	assert_eq(_store.slot, SLOT)
	assert_eq(SaveSystem.path_for(SLOT), "user://saves/%s.json" % SLOT)
