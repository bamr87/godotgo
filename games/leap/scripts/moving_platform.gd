class_name MovingPlatform
extends AnimatableBody2D
## A platform that slides between its start position and an offset, carrying
## anything standing on it.
##
## [member AnimatableBody2D.sync_to_physics] is what makes the hero ride it
## instead of sliding off, so the node is moved in [method _physics_process].
##
## Physics: layer 1 (world).

## Travel from the starting position, in pixels.
@export var travel := Vector2(128, 0)
## Seconds for one leg of the journey.
@export_range(0.1, 20.0, 0.1) var duration := 2.0
## Fraction of the cycle already elapsed at startup, so several platforms can be
## staggered without scripting.
@export_range(0.0, 1.0, 0.05) var phase := 0.0

var _origin := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	_origin = position
	_time = phase * duration * 2.0


func _physics_process(delta: float) -> void:
	_time += delta
	position = position_at(_time)


## The platform's position at [param time] seconds into the cycle. Exposed so
## the motion can be asserted without running the physics server.
func position_at(time: float) -> Vector2:
	var cycle := duration * 2.0
	var t := fmod(time, cycle) / duration
	var eased := t if t <= 1.0 else 2.0 - t
	return _origin + travel * smoothstep(0.0, 1.0, eased)


## Restarts the cycle around a new origin.
##
## With [member AnimatableBody2D.sync_to_physics] on, the physics server owns the
## transform, so the written position only becomes visible on the next physics
## frame. [method position_at] reflects the new origin immediately.
func reset_origin(to: Vector2) -> void:
	_origin = to
	position = to
	_time = phase * duration * 2.0
