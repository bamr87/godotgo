class_name Enemy
extends CharacterBody2D
## One arena drone, driven by the framework's [StateMachine].
##
## The four states are the enemy's whole contract: it telegraphs, it closes the
## distance, it hits, it dies. Splitting them out means each transition is
## assertable on its own -- a test can park the enemy in [constant STATE_ATTACK]
## and check the damage cadence without ever letting it chase.
##
## What the enemy *is* comes from [EnemyStats], so a drone and a brute are the
## same scene with different data, and [WavePlanner] can compose a wave from
## names alone.
##
## Physics: layer 5 (enemies), mask 1 + 5 (world, other enemies).

## Emitted once, as the enemy enters [constant STATE_DEAD]. The arena turns this
## into score; the corpse fades out on its own afterwards.
signal died(enemy: Enemy)
## Emitted every time an attack lands, so the session can spend hull points.
signal attacked(enemy: Enemy, damage: int)

## Telegraphing: the spawn ring is visible, the body is not yet solid and the
## enemy cannot be shot. Nothing may materialise on top of the ship.
const STATE_SPAWNING := &"spawning"
## Steering towards [member target] at [member EnemyStats.speed].
const STATE_CHASE := &"chase"
## Close enough to hit; damage lands on [member EnemyStats.attack_cooldown].
const STATE_ATTACK := &"attack"
## Out of health: no collision, no steering, fading towards [method queue_free].
const STATE_DEAD := &"dead"

## The kind this enemy is. Applied in [method _ready], or later through
## [method apply_stats].
@export var stats: EnemyStats
## Seconds the corpse takes to fade before it frees itself.
@export_range(0.05, 2.0, 0.05) var death_fade := 0.3
## Multiple of [member EnemyStats.attack_range] the ship must reach before an
## attacker gives up and chases again. Above 1.0 it is hysteresis, which stops
## the enemy flickering between the two states on the range boundary.
@export_range(1.0, 3.0, 0.05) var chase_resume_factor := 1.4

## What the enemy steers towards. Null makes it hold position, which is what a
## unit test wants when it is only exercising the transitions.
var target: Node2D
## Remaining health, seeded from [member EnemyStats.max_health].
var health := 1
## The behaviour machine. Public so tests can watch
## [signal StateMachine.transitioned] rather than poll for a state.
var state_machine := StateMachine.new()

var _attack_timer := 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _ring: Sprite2D = $SpawnRing


func _ready() -> void:
	apply_stats(stats)
	state_machine.add_state(STATE_SPAWNING, _spawning_update, _spawning_enter, _spawning_exit)
	state_machine.add_state(STATE_CHASE, _chase_update)
	state_machine.add_state(STATE_ATTACK, _attack_update, _attack_enter)
	state_machine.add_state(STATE_DEAD, Callable(), _dead_enter)
	state_machine.start(STATE_SPAWNING)


func _physics_process(delta: float) -> void:
	state_machine.update(delta)
	move_and_slide()


## Copies [param new_stats] onto the body: sprite, collision radius and health.
## Needs the node to be ready, because it writes to the child sprite and shape;
## the arena gets that for free by assigning [member stats] before adding the
## enemy to the tree, which makes [method _ready] apply it.
func apply_stats(new_stats: EnemyStats) -> void:
	if new_stats == null:
		return
	stats = new_stats
	health = new_stats.max_health
	_sprite.texture = new_stats.texture
	# A fresh shape per enemy: the two kinds have different radii and a shared
	# CircleShape2D would resize every enemy at once.
	var circle := CircleShape2D.new()
	circle.radius = new_stats.radius
	_shape.shape = circle


## The state machine's current state name.
func state() -> StringName:
	return state_machine.current


func is_alive() -> bool:
	return state_machine.current != STATE_DEAD


## Distance to [member target], or -1.0 when there is nothing to chase.
func distance_to_target() -> float:
	if target == null or not is_instance_valid(target):
		return -1.0
	return global_position.distance_to(target.global_position)


## Applies [param amount] damage. Returns true when the hit landed, i.e. the
## enemy was alive to receive it.
func take_damage(amount: int = 1) -> bool:
	if not is_alive() or amount <= 0:
		return false
	health = maxi(health - amount, 0)
	if health == 0:
		state_machine.transition_to(STATE_DEAD)
	return true


## Kills the enemy outright, whatever its health, taking the normal death path so
## [signal died] fires and the session's wave counter stays in step. Removing an
## enemy without this (a bare [method Node.queue_free]) leaves the wave believing
## it is still out there; [method Arena.clear_field] handles that case instead by
## telling the session to write the whole wave off.
func kill() -> void:
	if is_alive():
		health = 0
		state_machine.transition_to(STATE_DEAD)


func _spawn_time() -> float:
	return stats.spawn_time if stats != null else 0.0


func _steer(wish: Vector2, delta: float) -> void:
	var speed := stats.speed if stats != null else 0.0
	var acceleration := stats.acceleration if stats != null else 1000.0
	velocity = velocity.move_toward(wish * speed, acceleration * delta)


func _direction_to_target() -> Vector2:
	if target == null or not is_instance_valid(target):
		return Vector2.ZERO
	var offset := target.global_position - global_position
	return offset.normalized() if offset.length_squared() > 0.0 else Vector2.ZERO


func _spawning_enter() -> void:
	velocity = Vector2.ZERO
	_ring.visible = true
	_sprite.modulate.a = 0.0
	# Only ever reached from _ready(), so a direct assignment is safe -- and it
	# has to be direct, or the enemy would be shootable for its first frame.
	_shape.disabled = true


func _spawning_update(_delta: float) -> void:
	var duration := _spawn_time()
	if duration <= 0.0 or state_machine.time_in_state >= duration:
		state_machine.transition_to(STATE_CHASE)
		return
	var t := state_machine.time_in_state / duration
	_ring.scale = Vector2.ONE * lerpf(1.7, 0.9, t)
	_sprite.modulate.a = t


func _spawning_exit() -> void:
	_ring.visible = false
	_sprite.modulate.a = 1.0
	# transition_to() runs this from whatever called it, and kill() can be
	# called from Bullet.body_entered while the physics server is flushing
	# queries, so enabling the shape has to be deferred like the one below.
	_shape.set_deferred(&"disabled", false)


func _chase_update(delta: float) -> void:
	var distance := distance_to_target()
	var range_limit := stats.attack_range if stats != null else 0.0
	if distance >= 0.0 and distance <= range_limit:
		state_machine.transition_to(STATE_ATTACK)
		return
	_steer(_direction_to_target(), delta)


func _attack_enter() -> void:
	# Zero, not the cooldown: closing to melee range should hurt immediately,
	# otherwise a fast ship can tap the range boundary for free.
	_attack_timer = 0.0


func _attack_update(delta: float) -> void:
	_steer(Vector2.ZERO, delta)
	var distance := distance_to_target()
	var range_limit := (stats.attack_range if stats != null else 0.0) * chase_resume_factor
	if distance < 0.0 or distance > range_limit:
		state_machine.transition_to(STATE_CHASE)
		return
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = stats.attack_cooldown if stats != null else 1.0
		attacked.emit(self, stats.attack_damage if stats != null else 1)


func _dead_enter() -> void:
	velocity = Vector2.ZERO
	_ring.visible = false
	# Reachable from Bullet.body_entered, where the physics server is still
	# flushing, so this one has to be deferred.
	_shape.set_deferred(&"disabled", true)
	died.emit(self)
	if not is_inside_tree():
		queue_free()
		return
	var tween := create_tween()
	tween.tween_property(_sprite, ^"modulate:a", 0.0, death_fade)
	tween.tween_callback(queue_free)
