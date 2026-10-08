extends GodotGoTest
## Best-run persistence through the framework's [SaveSystem].
##
## Everything here runs against a scratch slot that [method after_each] deletes,
## so a test run never touches the records of whoever is actually playing.

## A slot name no build of the game uses.
const SLOT := "cascade-test-scores"

var _store: ScoreStore


func before_each() -> void:
	Game.reset()
	SaveSystem.erase(SLOT)
	_store = ScoreStore.new(SLOT)


func after_each() -> void:
	SaveSystem.erase(SLOT)
	_store = null
	Game.reset()


func test_a_fresh_store_knows_nothing() -> void:
	assert_false(_store.has_record("level_1"))
	assert_eq(_store.best_score("level_1"), 0)
	assert_eq(_store.best_pop("level_1"), 0)
	assert_false(_store.is_perfect("level_1"))
	assert_eq(_store.played_count(), 0)


func test_a_scoreless_round_still_counts_as_played() -> void:
	# A board can jam before a single legal pop, so zero is a real result and
	# cannot double as "never played".
	assert_true(_store.record_result("level_1", 0, 0, false))
	assert_true(_store.has_record("level_1"), "zero is a score, not a blank")
	assert_eq(_store.best_score("level_1"), 0)


func test_the_higher_score_is_the_one_kept() -> void:
	assert_true(_store.record_result("level_1", 240, 6, false), "the first is always a best")
	assert_false(_store.record_result("level_1", 180, 4, false))
	assert_eq(_store.best_score("level_1"), 240)
	assert_true(_store.record_result("level_1", 900, 5, false))
	assert_eq(_store.best_score("level_1"), 900)


func test_the_biggest_group_is_kept_apart_from_the_score() -> void:
	_store.record_result("level_1", 900, 4, false)
	_store.record_result("level_1", 100, 11, false)
	assert_eq(_store.best_score("level_1"), 900, "the poor round did not lower the score")
	assert_eq(_store.best_pop("level_1"), 11, "but its group is still a record")


func test_a_perfect_clear_is_remembered_even_after_a_worse_round() -> void:
	_store.record_result("level_1", 900, 9, true)
	assert_true(_store.is_perfect("level_1"))
	_store.record_result("level_1", 120, 3, false)
	assert_true(_store.is_perfect("level_1"), "it happened, and that does not un-happen")


func test_levels_are_recorded_apart_from_each_other() -> void:
	_store.record_result("level_1", 300, 5, false)
	_store.record_result("level_2", 700, 8, true)
	assert_eq(_store.best_score("level_1"), 300)
	assert_eq(_store.best_score("level_2"), 700)
	assert_false(_store.is_perfect("level_1"))
	assert_eq(_store.played_count(), 2)


func test_a_result_round_trips_through_the_save_file() -> void:
	_store.record_result("level_3", 512, 7, true)
	assert_true(SaveSystem.has_slot(SLOT), "it is on disk, not just in memory")
	var reopened := ScoreStore.new(SLOT)
	assert_eq(reopened.best_score("level_3"), 512)
	assert_eq(reopened.best_pop("level_3"), 7)
	assert_true(reopened.is_perfect("level_3"))


func test_erasing_forgets_everything_on_disk_and_in_memory() -> void:
	_store.record_result("level_1", 300, 5, false)
	assert_eq(_store.erase_scores(), OK)
	assert_false(_store.has_record("level_1"))
	assert_false(SaveSystem.has_slot(SLOT))
	assert_eq(ScoreStore.new(SLOT).played_count(), 0)
