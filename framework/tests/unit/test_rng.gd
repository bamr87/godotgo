extends GodotGoTest
## Deterministic random numbers: the property the sample games rely on for
## reproducible spawn patterns and testable shuffles.


func test_same_seed_gives_the_same_sequence() -> void:
	var a := Rng.new(1234)
	var b := Rng.new(1234)
	for i in 20:
		assert_eq(a.randi_range(0, 1000), b.randi_range(0, 1000))


func test_different_seeds_diverge() -> void:
	var a := Rng.new(1)
	var b := Rng.new(2)
	var same := 0
	for i in 20:
		if a.randi_range(0, 1000) == b.randi_range(0, 1000):
			same += 1
	assert_true(same < 5, "sequences should not track each other, matched %d of 20" % same)


func test_reseed_restarts_the_sequence() -> void:
	var rng := Rng.new(99)
	var first := rng.randi_range(0, 10000)
	rng.randi_range(0, 10000)
	rng.reseed(99)
	assert_eq(rng.randi_range(0, 10000), first)
	assert_eq(rng.seed_value, 99)


func test_state_can_be_saved_and_restored() -> void:
	var rng := Rng.new(7)
	rng.randi()
	var state := rng.get_state()
	var expected := rng.randi()
	rng.randi()
	rng.set_state(state)
	assert_eq(rng.randi(), expected)


func test_ranges_are_respected() -> void:
	var rng := Rng.new(42)
	for i in 200:
		var v := rng.randi_range(3, 7)
		assert_true(v >= 3 and v <= 7, "randi_range out of bounds: %d" % v)
	for i in 200:
		var f := rng.randf_range(-1.0, 1.0)
		assert_true(f >= -1.0 and f <= 1.0, "randf_range out of bounds: %f" % f)


func test_chance_bounds() -> void:
	var rng := Rng.new(5)
	for i in 50:
		assert_false(rng.chance(0.0), "probability 0 never fires")
		assert_true(rng.chance(1.0), "probability 1 always fires")


func test_pick_returns_a_member_and_handles_empty() -> void:
	var rng := Rng.new(3)
	var items := ["a", "b", "c"]
	for i in 30:
		assert_true(items.has(rng.pick(items)))
	assert_null(rng.pick([]))


func test_shuffled_is_a_permutation_and_leaves_the_input_alone() -> void:
	var rng := Rng.new(11)
	var source := [1, 2, 3, 4, 5, 6, 7, 8]
	var shuffled := rng.shuffled(source)
	assert_eq(source, [1, 2, 3, 4, 5, 6, 7, 8], "input untouched")
	assert_eq(shuffled.size(), source.size())
	var sorted_copy := shuffled.duplicate()
	sorted_copy.sort()
	assert_eq(sorted_copy, source, "same elements")


func test_weighted_pick_honours_weights() -> void:
	var rng := Rng.new(2024)
	var counts := {"common": 0, "rare": 0}
	for i in 400:
		var choice: String = rng.weighted_pick(["common", "rare"], [9.0, 1.0])
		counts[choice] += 1
	assert_true(counts["common"] > counts["rare"] * 3, "9:1 weights, got %s" % str(counts))
	assert_eq(counts["common"] + counts["rare"], 400)


func test_weighted_pick_with_no_usable_weights() -> void:
	var rng := Rng.new(1)
	assert_null(rng.weighted_pick(["a", "b"], [0.0, 0.0]))
	assert_null(rng.weighted_pick([], []))


func test_direction_is_a_unit_vector() -> void:
	var rng := Rng.new(8)
	for i in 20:
		assert_almost_eq(rng.direction().length(), 1.0, 0.0001)


func test_point_in_rect_stays_inside() -> void:
	var rng := Rng.new(6)
	var rect := Rect2(-10, -5, 20, 10)
	for i in 50:
		assert_true(rect.has_point(rng.point_in_rect(rect)))
