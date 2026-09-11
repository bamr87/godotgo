class_name Rng
extends RefCounted
## Deterministic random numbers. The same seed always produces the same
## sequence, which is what makes spawn patterns and shuffles testable.
##
## [codeblock]
## var rng := Rng.new(1234)
## var wave := rng.pick(["bat", "slime", "ghost"])
## [/codeblock]

## The seed this generator was created or reseeded with.
var seed_value: int = 0

var _rng := RandomNumberGenerator.new()


func _init(initial_seed: int = 0) -> void:
	reseed(initial_seed)


## Restarts the sequence from [param new_seed].
func reseed(new_seed: int) -> void:
	seed_value = new_seed
	_rng.seed = new_seed
	_rng.state = _rng.state  # normalises state after a seed change


## Opaque generator position. Save it and assign it back to resume a sequence.
func get_state() -> int:
	return int(_rng.state)


func set_state(value: int) -> void:
	_rng.state = value


func randi() -> int:
	return int(_rng.randi())


## Inclusive on both ends.
func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


## True with probability [param probability] (0.0 never, 1.0 always).
func chance(probability: float) -> bool:
	return _rng.randf() < probability


## A uniformly chosen element, or null for an empty array.
func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[_rng.randi_range(0, items.size() - 1)]


## A new array with the elements shuffled; the input is left alone.
func shuffled(items: Array) -> Array:
	var out := items.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## Picks an element whose chance is proportional to its weight. Non-positive
## weights are ignored; returns null when nothing is selectable.
func weighted_pick(items: Array, weights: Array) -> Variant:
	var total := 0.0
	for i in mini(items.size(), weights.size()):
		total += maxf(float(weights[i]), 0.0)
	if total <= 0.0:
		return null
	var roll := _rng.randf() * total
	for i in mini(items.size(), weights.size()):
		var weight := maxf(float(weights[i]), 0.0)
		if roll < weight:
			return items[i]
		roll -= weight
	return items[mini(items.size(), weights.size()) - 1]


## A random point inside the given rectangle.
func point_in_rect(rect: Rect2) -> Vector2:
	return Vector2(
		_rng.randf_range(rect.position.x, rect.end.x), _rng.randf_range(rect.position.y, rect.end.y)
	)


## A unit vector with a uniformly random direction.
func direction() -> Vector2:
	return Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
