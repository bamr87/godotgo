class_name WavePlanner
extends RefCounted
## Turns a wave number into the enemies that wave contains and where they come
## in, using the framework's [Rng] so a seed replays a run exactly.
##
## [method plan] reseeds before every wave with a value derived from
## [member seed_value] and the wave number, which is what makes a plan depend
## only on those two things. Planning wave 7 straight away therefore gives the
## same answer as planning waves 1 to 7 in order -- a test can check one wave
## without simulating the ones before it, and a bug report can be reproduced
## from a seed alone.
##
## [codeblock]
## var planner := WavePlanner.new(1234, Rect2(16, 16, 928, 508))
## var wave := planner.plan(3)
## for i in wave["kinds"].size():
##     spawn(wave["kinds"][i], wave["positions"][i])
## [/codeblock]

## Kind name of the fast, fragile enemy. Matches [member EnemyStats.kind] in
## [code]resources/drone.tres[/code].
const KIND_DRONE := &"drone"
## Kind name of the slow, tough enemy. Matches [code]resources/brute.tres[/code].
const KIND_BRUTE := &"brute"
## Odd 32-bit multiplier (the golden-ratio hash constant) that spreads adjacent
## wave numbers across the seed space, so wave 2 is not a near-copy of wave 1.
const WAVE_SALT := 0x9E3779B9

## Base seed for the whole run. Two planners with the same value are
## interchangeable.
var seed_value := 0
## Rectangle spawn points are clamped into. The arena passes its playfield
## already inset by the wall thickness and the enemy radius.
var bounds := Rect2(0.0, 0.0, 960.0, 540.0)
## Enemies in wave 1.
var base_count := 3
## Extra enemies added per wave after the first.
var growth := 2
## Ceiling on a wave's size, so a long run stays playable and the bullet pool
## keeps up.
var max_count := 18
## First wave that may contain brutes. Earlier waves teach the player to shoot.
var brute_from_wave := 2
## Brute weight added per wave once brutes are unlocked, against a drone weight
## fixed at 1.0.
var brute_weight_step := 0.3
## Ceiling on the brute weight, so drones never disappear entirely.
var max_brute_weight := 2.0
## Closest a spawn point may be to the arena centre, where the ship starts.
var spawn_min_radius := 180.0
## Furthest a spawn point may be from the arena centre before clamping.
var spawn_max_radius := 460.0

var _rng := Rng.new(0)


func _init(initial_seed: int = 0, arena_bounds: Rect2 = Rect2(0.0, 0.0, 960.0, 540.0)) -> void:
	seed_value = initial_seed
	bounds = arena_bounds


## Enemies in [param wave]. Waves below 1 are empty.
func count_for(wave: int) -> int:
	if wave < 1:
		return 0
	return mini(base_count + growth * (wave - 1), max_count)


## Relative chance of a brute in [param wave], against a drone weight of 1.0.
func brute_weight_for(wave: int) -> float:
	if wave < brute_from_wave:
		return 0.0
	return minf(brute_weight_step * float(wave - brute_from_wave + 1), max_brute_weight)


## The composition of [param wave] as
## [code]{"wave": int, "kinds": Array[StringName], "positions": PackedVector2Array}[/code].
## The two arrays are parallel and always the same length.
func plan(wave: int) -> Dictionary:
	var kinds: Array[StringName] = []
	var positions := PackedVector2Array()
	var count := count_for(wave)
	if count > 0:
		# Reseeding per wave, not per run, is what decouples a plan from the
		# order the caller asks for it in.
		_rng.reseed(seed_value ^ (wave * WAVE_SALT))
		var choices: Array = [KIND_DRONE, KIND_BRUTE]
		var weights: Array = [1.0, brute_weight_for(wave)]
		var centre := bounds.get_center()
		for i in count:
			kinds.append(_rng.weighted_pick(choices, weights))
			positions.append(_spawn_point(centre))
	return {"wave": wave, "kinds": kinds, "positions": positions}


func _spawn_point(centre: Vector2) -> Vector2:
	var offset := _rng.direction() * _rng.randf_range(spawn_min_radius, spawn_max_radius)
	var point := centre + offset
	return Vector2(
		clampf(point.x, bounds.position.x, bounds.end.x),
		clampf(point.y, bounds.position.y, bounds.end.y)
	)
