extends GodotGoTest
## Versioned JSON save slots.

const SLOT := "framework_test"


func before_each() -> void:
	SaveSystem.erase(SLOT)


func after_each() -> void:
	SaveSystem.erase(SLOT)


func test_store_then_fetch_round_trips() -> void:
	assert_eq(SaveSystem.store(SLOT, {"level": 3, "best": 1200, "name": "hero"}), OK)
	var data := SaveSystem.fetch(SLOT)
	assert_eq(int(data["level"]), 3)
	assert_eq(int(data["best"]), 1200)
	assert_eq(data["name"], "hero")


func test_missing_slot_returns_the_fallback() -> void:
	assert_false(SaveSystem.has_slot(SLOT))
	var data := SaveSystem.fetch(SLOT, {"level": 1})
	assert_eq(int(data["level"]), 1)


func test_has_slot_and_erase() -> void:
	SaveSystem.store(SLOT, {"a": 1})
	assert_true(SaveSystem.has_slot(SLOT))
	assert_eq(SaveSystem.erase(SLOT), OK)
	assert_false(SaveSystem.has_slot(SLOT))
	assert_eq(SaveSystem.erase(SLOT), OK, "erasing a missing slot is not an error")


func test_store_overwrites() -> void:
	SaveSystem.store(SLOT, {"n": 1})
	SaveSystem.store(SLOT, {"n": 2})
	assert_eq(int(SaveSystem.fetch(SLOT)["n"]), 2)


func test_slot_names_are_sanitised() -> void:
	assert_eq(SaveSystem.sanitize("Level 1/../etc"), "level_1____etc")
	assert_eq(SaveSystem.sanitize(""), "default")
	assert_true(SaveSystem.path_for("A B").ends_with("a_b.json"))


func test_envelope_carries_a_version_and_timestamp() -> void:
	SaveSystem.store(SLOT, {"x": 1})
	var raw := FileAccess.get_file_as_string(SaveSystem.path_for(SLOT))
	var envelope: Variant = JSON.parse_string(raw)
	assert_true(envelope is Dictionary)
	assert_eq(int(envelope["version"]), SaveSystem.VERSION)
	assert_true(int(envelope["saved_at"]) > 0)
	assert_true(envelope["data"] is Dictionary)


func test_a_newer_schema_version_is_refused_rather_than_misread() -> void:
	var file := FileAccess.open(SaveSystem.path_for(SLOT), FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(JSON.stringify({"version": SaveSystem.VERSION + 1, "data": {"x": 9}}))
	file.close()
	var data := SaveSystem.fetch(SLOT, {"x": 0})
	assert_eq(int(data["x"]), 0, "future files fall back instead of loading")


func test_corrupt_json_falls_back() -> void:
	var file := FileAccess.open(SaveSystem.path_for(SLOT), FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	assert_eq(SaveSystem.fetch(SLOT, {"ok": true})["ok"], true)


func test_slots_lists_what_is_on_disk() -> void:
	SaveSystem.store(SLOT, {"a": 1})
	assert_true(SaveSystem.slots().has(SLOT))
