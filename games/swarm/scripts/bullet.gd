class_name Bullet
extends Area2D
## A pooled player projectile. It never frees itself: it reports that it is
## finished and the arena hands it back to the [ObjectPool] it came from.
##
## Every shot in an arena shooter is a spawn, so allocating one node per bullet
## is the fastest way to make a game stutter. Pooling moves the cost to load
## time, and the pool's [member ObjectPool.max_size] becomes a hard ceiling on
## live bullets that no amount of trigger-holding can exceed.
##
## The bullet only decides *that* it is done ([signal hit], [signal expired]);
## the release itself is deferred by the arena, because a node may not leave the
## tree while the physics server is still flushing contact signals.
##
## Physics: layer 6 (player_bullets), mask 1 + 5 (world, enemies).

## Emitted when the bullet struck [param target] and already applied its damage.
signal hit(bullet: Bullet, target: Node2D)
## Emitted when the bullet ran out of life or left the arena without hitting.
signal expired(bullet: Bullet)

## Travel speed in pixels per second.
@export_range(50.0, 3000.0, 10.0) var speed := 640.0
## Seconds before an unobstructed bullet gives up. A backstop for the bounds
## check: a bullet that somehow escapes the arena still returns to the pool.
@export_range(0.05, 10.0, 0.05) var lifetime := 1.5
## Health removed from the enemy it strikes.
@export_range(1, 20, 1) var damage := 1

## Rectangle the bullet may travel in. Assigned by [method launch]; an empty
## rectangle disables the bounds check.
var bounds := Rect2()

var _direction := Vector2.RIGHT
var _time_left := 0.0
var _spent := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _spent:
		return
	global_position += _direction * speed * delta
	_time_left = maxf(_time_left - delta, 0.0)
	if _time_left <= 0.0 or not _in_bounds():
		_spend()
		expired.emit(self)


## Aims the bullet and starts its life. The caller must have added it to the
## tree first, because the muzzle position is a global one.
func launch(from: Vector2, direction: Vector2, arena: Rect2) -> void:
	bounds = arena
	global_position = from
	if direction.length_squared() > 0.0:
		_direction = direction.normalized()
	rotation = _direction.angle()
	_time_left = lifetime
	_spent = false
	visible = true


## Seconds of travel left before the bullet expires on its own.
func time_left() -> float:
	return _time_left


## The direction [method launch] locked in, as a unit vector.
func direction() -> Vector2:
	return _direction


## True once the bullet has hit or expired and is waiting to be released.
func is_spent() -> bool:
	return _spent


## Called by [ObjectPool] on the way out of the pool.
func pool_acquired() -> void:
	_time_left = lifetime
	_spent = false
	visible = true


## Called by [ObjectPool] on the way back in. Parking the bullet as spent is
## what stops a reused instance from moving for the one frame between being
## released and being launched again.
func pool_released() -> void:
	_spent = true
	visible = false
	_time_left = 0.0


func _in_bounds() -> bool:
	return not bounds.has_area() or bounds.has_point(global_position)


func _spend() -> void:
	_spent = true
	visible = false


func _on_body_entered(body: Node2D) -> void:
	if _spent:
		return
	_spend()
	var enemy := body as Enemy
	if enemy == null:
		# A wall: nothing to damage, but the shot is still over.
		expired.emit(self)
		return
	enemy.take_damage(damage)
	hit.emit(self, enemy)
