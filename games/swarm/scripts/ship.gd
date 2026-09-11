class_name Ship
extends CharacterBody2D
## The player's ship: WASD to fly, mouse to aim, hold to fire.
##
## Movement and aim are read through [method move_direction], [method aim_point]
## and [method wants_fire] rather than from [Input] directly, and each one falls
## back to a plain variable when [member use_input_override] is set. That is the
## same trick [Hero] uses in Leap, and it is what lets the whole shooting loop be
## driven from a headless test with no display, no mouse and no input map.
##
## The ship knows nothing about bullets. It emits [signal fired] with a muzzle
## and a direction; the arena owns the pool and decides what comes out.
##
## Physics: layer 2 (player), mask 1 (world).

## Emitted by [method try_fire]. [param from] is the muzzle in world space and
## [param direction] is a unit vector.
signal fired(from: Vector2, direction: Vector2)

const ACTION_UP := &"move_up"
const ACTION_DOWN := &"move_down"
const ACTION_LEFT := &"move_left"
const ACTION_RIGHT := &"move_right"
const ACTION_FIRE := &"fire"

## Top speed in pixels per second.
@export_range(20.0, 1000.0, 5.0) var speed := 250.0
## Acceleration towards the wished-for velocity, in pixels per second squared.
@export_range(10.0, 8000.0, 10.0) var acceleration := 2000.0
## Deceleration when no direction is held. Higher than [member acceleration]
## so the ship stops crisply, which matters when dodging between drones.
@export_range(10.0, 8000.0, 10.0) var friction := 2600.0
## Seconds between shots while the trigger is held.
@export_range(0.02, 2.0, 0.01) var fire_interval := 0.16
## Distance from the ship's centre that bullets appear at, so a shot does not
## start inside the ship's own collision circle.
@export_range(0.0, 64.0, 1.0) var muzzle_offset := 14.0

## Movement wish used instead of the input map while [member use_input_override]
## is true. Longer than one unit is clamped, so it cannot outrun the input map.
var input_override := Vector2.ZERO
## World point aimed at instead of the mouse while [member use_input_override]
## is true.
var aim_override := Vector2.RIGHT
## Trigger-held flag used instead of the fire action while
## [member use_input_override] is true.
var fire_override := false
## Switches the three overrides above on.
var use_input_override := false

var _aim := Vector2.RIGHT
var _cooldown := 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var wish := move_direction()
	if wish.is_zero_approx():
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		velocity = velocity.move_toward(wish * speed, acceleration * delta)
	move_and_slide()
	_sprite.rotation = aim_direction().angle()
	if wants_fire():
		try_fire()


## The movement wish, at most one unit long.
func move_direction() -> Vector2:
	if use_input_override:
		return input_override.limit_length(1.0)
	return Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_UP, ACTION_DOWN)


## The world point the ship is aiming at.
func aim_point() -> Vector2:
	if use_input_override:
		return aim_override
	return get_global_mouse_position()


## A unit vector towards [method aim_point]. When the aim point sits exactly on
## the ship the last good direction is kept, so the ship never snaps to east.
func aim_direction() -> Vector2:
	var offset := aim_point() - global_position
	if offset.length_squared() > 0.0001:
		_aim = offset.normalized()
	return _aim


## True while the trigger is held.
func wants_fire() -> bool:
	if use_input_override:
		return fire_override
	return Input.is_action_pressed(ACTION_FIRE)


## True when [method try_fire] would produce a shot right now.
func can_fire() -> bool:
	return _cooldown <= 0.0


## Fires if the cooldown has elapsed, emitting [signal fired]. Returns whether a
## shot was actually taken.
func try_fire() -> bool:
	if not can_fire():
		return false
	_cooldown = fire_interval
	var direction := aim_direction()
	fired.emit(global_position + direction * muzzle_offset, direction)
	return true


## Places the ship and cancels its momentum and its pending shot.
func teleport_to(point: Vector2) -> void:
	global_position = point
	velocity = Vector2.ZERO
	_cooldown = 0.0
