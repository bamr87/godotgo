class_name Hero
extends CharacterBody2D
## Side-on platformer controller: run, jump, coyote time and jump buffering.
##
## The same feel rules as Orb Run's first-person controller, in two dimensions:
## acceleration rather than instant velocity, a short grace window after walking
## off a ledge, and a remembered jump press just before landing.
##
## Physics: layer 2 (player), mask 1 (world).

## Emitted when a jump actually leaves the ground.
signal jumped
## Emitted on touchdown. [param fall_speed] is downward speed in px/s, positive.
signal landed(fall_speed: float)

const ACTION_LEFT := &"move_left"
const ACTION_RIGHT := &"move_right"
const ACTION_JUMP := &"jump"

@export_group("Movement")
## Top running speed in pixels per second.
@export_range(0.0, 800.0, 5.0) var speed := 220.0
## Ground acceleration in pixels per second squared.
@export_range(10.0, 8000.0, 10.0) var acceleration := 1800.0
## Ground deceleration when no direction is held.
@export_range(10.0, 8000.0, 10.0) var friction := 2200.0
## Fraction of [member acceleration] available in the air.
@export_range(0.0, 1.0, 0.05) var air_control := 0.55
## Upward speed applied on jump (positive; Y is inverted internally).
@export_range(0.0, 2000.0, 10.0) var jump_speed := 520.0
## Extra gravity multiplier while falling, for a less floaty arc.
@export_range(1.0, 4.0, 0.1) var fall_gravity_scale := 1.6
## Seconds after leaving a ledge during which a jump is still accepted.
@export_range(0.0, 0.5, 0.01) var coyote_time := 0.1
## Seconds before landing during which a jump press is remembered.
@export_range(0.0, 0.5, 0.01) var jump_buffer := 0.12
## Downward speed treated as a hard landing, for sound and effects.
@export_range(0.0, 2000.0, 10.0) var hard_landing_speed := 500.0

## Horizontal input to use instead of the input map, when
## [member use_input_override] is set. Lets tests and cutscenes drive the hero.
var input_override := 0.0
var use_input_override := false

var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	_update_timers(delta, on_floor)

	if not on_floor:
		var scale_factor := fall_gravity_scale if velocity.y > 0.0 else 1.0
		velocity.y += _gravity * scale_factor * delta

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_jump()

	_apply_horizontal(delta, on_floor)

	# move_and_slide() zeroes the vertical speed on contact, so sample it first.
	var fall_speed := velocity.y
	move_and_slide()
	if is_on_floor() and not on_floor:
		landed.emit(maxf(fall_speed, 0.0))


## -1, 0 or 1 from the input map, or the override when one is set.
func direction() -> float:
	if use_input_override:
		return input_override
	return Input.get_axis(ACTION_LEFT, ACTION_RIGHT)


## Places the hero and cancels all momentum.
func teleport_to(position_2d: Vector2) -> void:
	global_position = position_2d
	velocity = Vector2.ZERO
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0


## Remembers a jump press, as if the player had hit the button this frame. The
## jump still happens only when the hero is on the ground or inside the coyote
## window, exactly as a real press would.
func request_jump() -> void:
	_jump_buffer_timer = jump_buffer


func _update_timers(delta: float, on_floor: bool) -> void:
	_coyote_timer = coyote_time if on_floor else maxf(_coyote_timer - delta, 0.0)
	if not use_input_override and Input.is_action_just_pressed(ACTION_JUMP):
		_jump_buffer_timer = jump_buffer
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func _jump() -> void:
	velocity.y = -jump_speed
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	jumped.emit()


func _apply_horizontal(delta: float, on_floor: bool) -> void:
	var wish := direction()
	var rate := acceleration if on_floor else acceleration * air_control
	if is_zero_approx(wish):
		rate = friction if on_floor else friction * air_control
		velocity.x = move_toward(velocity.x, 0.0, rate * delta)
	else:
		velocity.x = move_toward(velocity.x, wish * speed, rate * delta)
