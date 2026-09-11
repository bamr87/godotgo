class_name Player
extends CharacterBody3D
## First-person character controller.
##
## Movement is integrated in [method _physics_process]; mouse look is applied
## from raw deltas in [method _unhandled_input]. All tunables are exported so
## designers can adjust them per scene without touching code.

## Emitted when the player leaves the floor because of a jump.
signal jumped
## Emitted when the player touches the floor after being airborne.
## [param fall_speed] is the downward speed (m/s, positive) at the moment of contact.
signal landed(fall_speed: float)

const ACTION_FORWARD := &"move_forward"
const ACTION_BACK := &"move_back"
const ACTION_LEFT := &"move_left"
const ACTION_RIGHT := &"move_right"
const ACTION_JUMP := &"jump"
const ACTION_SPRINT := &"sprint"
const ACTION_CANCEL := &"ui_cancel"

@export_group("Movement")
## Ground speed in m/s.
@export_range(0.0, 50.0, 0.1) var speed := 6.0
## Speed multiplier while [constant ACTION_SPRINT] is held.
@export_range(1.0, 5.0, 0.05) var sprint_multiplier := 1.6
## Horizontal acceleration on the ground in m/s^2.
@export_range(1.0, 200.0, 1.0) var acceleration := 40.0
## Fraction of [member acceleration] available while airborne.
@export_range(0.0, 1.0, 0.05) var air_control := 0.3
## Upward velocity applied when jumping, in m/s.
@export_range(0.0, 30.0, 0.1) var jump_velocity := 5.5
## Seconds after walking off a ledge during which a jump is still accepted.
@export_range(0.0, 0.5, 0.01) var coyote_time := 0.1
## Seconds before landing during which a jump press is remembered.
@export_range(0.0, 0.5, 0.01) var jump_buffer := 0.1

@export_group("Look")
## Radians of rotation per pixel of mouse movement.
@export_range(0.0005, 0.02, 0.0001) var mouse_sensitivity := 0.002
## Maximum pitch (up or down) in radians.
@export_range(0.0, 1.57, 0.01) var pitch_limit := 1.4
## Node rotated for pitch. Defaults to the child named [code]CameraPivot[/code].
@export var camera_pivot: Node3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0


func _ready() -> void:
	if camera_pivot == null:
		camera_pivot = get_node_or_null(^"CameraPivot")
	assert(camera_pivot != null, "Player needs a camera_pivot Node3D")
	set_mouse_captured(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and is_mouse_captured():
		_apply_look(event.relative)
	elif event.is_action_pressed(ACTION_CANCEL):
		set_mouse_captured(not is_mouse_captured())


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	_update_timers(delta, on_floor)

	if not on_floor:
		velocity.y -= _gravity * delta

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_jump()

	_apply_movement(delta, on_floor)
	# move_and_slide() cancels the vertical velocity on contact, so sample it first.
	var vertical_speed := velocity.y
	move_and_slide()
	if is_on_floor() and not on_floor:
		landed.emit(maxf(-vertical_speed, 0.0))


## Captures or releases the mouse cursor.
func set_mouse_captured(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func is_mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


## Desired horizontal movement direction in world space, or [constant Vector3.ZERO].
func get_wish_direction() -> Vector3:
	var input_dir := Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_FORWARD, ACTION_BACK)
	return (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()


func _apply_look(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	camera_pivot.rotate_x(-relative.y * mouse_sensitivity)
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -pitch_limit, pitch_limit)


func _update_timers(delta: float, on_floor: bool) -> void:
	_coyote_timer = coyote_time if on_floor else maxf(_coyote_timer - delta, 0.0)
	if Input.is_action_just_pressed(ACTION_JUMP):
		_jump_buffer_timer = jump_buffer
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func _jump() -> void:
	velocity.y = jump_velocity
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	jumped.emit()


func _apply_movement(delta: float, on_floor: bool) -> void:
	var target_speed := speed
	if Input.is_action_pressed(ACTION_SPRINT):
		target_speed *= sprint_multiplier
	var target := get_wish_direction() * target_speed
	var accel := acceleration if on_floor else acceleration * air_control
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
