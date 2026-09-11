extends GodotGoTest
## Deterministic wave composition: the same seed must always produce the same
## wave, and a wave must not depend on the ones asked for before it.

const BOUNDS := Rect2(20.0, 20.0, 900.0, 480.0)


func test_wave_size_grows_and_then_caps() -> void:
	var planner := _planner(1)
	planner.base_count = 3
	planner.growth = 2
	planner.max_count = 9
	assert_eq(planner.count_for(1), 3)
	assert_eq(planner.count_for(2), 5)
	assert_eq(planner.count_for(4), 9)
	assert_eq(planner.count_for(20), 9, "capped so the pool always keeps up")
	assert_eq(planner.count_for(0), 0)
	assert_eq(planner.count_for(-3), 0)


func test_the_same_seed_produces_the_same_wave() -> void:
	var first := _planner(4242).plan(3)
	var second := _planner(4242).plan(3)
	assert_eq(first["kinds"], second["kinds"])
	assert_eq(first["positions"], second["positions"])


func test_different_seeds_produce_different_waves() -> void:
	assert_ne(_planner(1).plan(4)["positions"], _planner(2).plan(4)["positions"])


func test_a_plan_does_not_depend_on_the_order_it_was_asked_for() -> void:
	var straight: Dictionary = _planner(77).plan(5)
	var walked := _planner(77)
	for wave in [1, 2, 3, 4]:
		walked.plan(wave)
	var after: Dictionary = walked.plan(5)
	assert_eq(straight["kinds"], after["kinds"], "wave 5 is wave 5 however you get there")
	assert_eq(straight["positions"], after["positions"])


func test_consecutive_waves_differ() -> void:
	var planner := _planner(9)
	assert_ne(planner.plan(3)["positions"], planner.plan(4)["positions"])


func test_kinds_and_positions_are_parallel() -> void:
	var planner := _planner(5)
	var plan := planner.plan(6)
	assert_eq(plan["wave"], 6)
	assert_eq(plan["kinds"].size(), planner.count_for(6))
	assert_eq(plan["positions"].size(), plan["kinds"].size())


func test_wave_zero_is_empty() -> void:
	var plan := _planner(3).plan(0)
	assert_eq(plan["kinds"].size(), 0)
	assert_eq(plan["positions"].size(), 0)


func test_the_brute_weight_ramps_and_is_capped() -> void:
	var planner := _planner(1)
	planner.brute_from_wave = 2
	planner.brute_weight_step = 0.5
	planner.max_brute_weight = 1.5
	assert_almost_eq(planner.brute_weight_for(1), 0.0)
	assert_almost_eq(planner.brute_weight_for(2), 0.5)
	assert_almost_eq(planner.brute_weight_for(3), 1.0)
	assert_almost_eq(planner.brute_weight_for(9), 1.5, 0.0001, "capped, so drones never vanish")


func test_early_waves_are_drones_only() -> void:
	var planner := _planner(31)
	planner.brute_from_wave = 3
	for wave in [1, 2]:
		var kinds: Array[StringName] = planner.plan(wave)["kinds"]
		assert_true(kinds.size() > 0, "wave %d should not be empty" % wave)
		for kind in kinds:
			assert_eq(kind, WavePlanner.KIND_DRONE, "wave %d teaches shooting first" % wave)


func test_later_waves_mix_both_kinds() -> void:
	var planner := _planner(2024)
	planner.base_count = 40
	planner.max_count = 40
	planner.brute_from_wave = 1
	planner.brute_weight_step = 1.0
	var kinds: Array[StringName] = planner.plan(4)["kinds"]
	assert_true(kinds.has(WavePlanner.KIND_BRUTE), "brutes appear once they are unlocked")
	assert_true(kinds.has(WavePlanner.KIND_DRONE), "and drones stay in the mix")


func test_every_spawn_point_lands_inside_the_bounds() -> void:
	var planner := _planner(808)
	planner.base_count = 40
	planner.max_count = 40
	for point in planner.plan(1)["positions"]:
		assert_true(_inside(point, BOUNDS), "%s escaped %s" % [point, BOUNDS])


func test_spawn_points_keep_away_from_the_centre() -> void:
	var planner := _planner(606)
	planner.base_count = 30
	planner.max_count = 30
	planner.spawn_min_radius = 150.0
	planner.spawn_max_radius = 200.0
	var centre := BOUNDS.get_center()
	for point in planner.plan(1)["positions"]:
		assert_true(point.distance_to(centre) >= 100.0, "%s spawned on top of the ship" % point)


func _planner(seed_value: int) -> WavePlanner:
	return WavePlanner.new(seed_value, BOUNDS)


## Rect2.has_point excludes the right and bottom edges, and clamped points land
## exactly on them, so the bounds check is spelled out here.
func _inside(point: Vector2, rect: Rect2) -> bool:
	return (
		point.x >= rect.position.x
		and point.x <= rect.end.x
		and point.y >= rect.position.y
		and point.y <= rect.end.y
	)
