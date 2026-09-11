class_name Arena
extends Node2D
## Swarm's root scene: the only place that knows about both the scene tree and
## the [code]Game[/code] session.
##
## Everything interesting is delegated. Rules live in the session, bullet
## lifetime in [ObjectPool], enemy behaviour in [StateMachine] and wave
## composition in [WavePlanner]; the arena wires the four together and does
## nothing a test cannot reach through a public method.
##
## Bullets are released one frame late (see [method _release_bullet]) because a
## node may not leave the tree while the physics server is flushing contacts.

## Waves that must be survived to win the round.
@export_range(1, 50, 1) var waves_to_survive := 5
## Seed handed to [WavePlanner]. The same value replays the same run, which is
## what makes a bug report reproducible and the wave tests deterministic.
@export_range(0, 999999, 1) var wave_seed := 20260909
## Enemies in wave 1.
@export_range(1, 20, 1) var base_enemies := 3
## Extra enemies added per wave.
@export_range(0, 10, 1) var enemies_per_wave := 2
## Ceiling on a wave's size. Keep it under the bullet pool's cap so a full wave
## is always killable without the pool starving.
@export_range(1, 60, 1) var max_enemies_per_wave := 14
## Breathing room in seconds between a cleared wave and the next one.
@export_range(0.1, 10.0, 0.1) var wave_break := 1.6
## Thickness of the arena walls in pixels. The playfield is the viewport inset
## by this much, so bullets expire exactly where the walls are.
@export_range(1.0, 200.0, 1.0) var wall_thickness := 16.0
## Extra inset for spawn points, on top of the walls. Without it a brute could
## be planned flush against a wall and start the wave half inside it.
@export_range(0.0, 120.0, 1.0) var spawn_inset := 20.0
## Scene instanced for every enemy; both kinds share it.
@export var enemy_scene: PackedScene
## Stats for [constant WavePlanner.KIND_DRONE].
@export var drone_stats: EnemyStats
## Stats for [constant WavePlanner.KIND_BRUTE].
@export var brute_stats: EnemyStats

## Rectangle the ship, the enemies and the bullets live inside.
var playfield := Rect2()
## Built in [method _ready] from [member wave_seed] and the wave tunables.
var planner: WavePlanner

@onready var ship: Ship = $Ship
@onready var hud: HUD = $HUD
@onready var bullet_pool: ObjectPool = $BulletPool
@onready var _enemies: Node2D = $Enemies
@onready var _bullets: Node2D = $Bullets
@onready var _wave_timer: Timer = $WaveTimer
@onready var _shoot_sound: AudioStreamPlayer = $ShootSound
@onready var _hit_sound: AudioStreamPlayer = $HitSound
@onready var _wave_sound: AudioStreamPlayer = $WaveSound


func _ready() -> void:
	playfield = viewport_rect().grow(-wall_thickness)
	planner = WavePlanner.new(wave_seed, playfield.grow(-spawn_inset))
	planner.base_count = base_enemies
	planner.growth = enemies_per_wave
	planner.max_count = max_enemies_per_wave

	bullet_pool.acquired.connect(_on_bullet_acquired)
	ship.fired.connect(_on_ship_fired)
	_wave_timer.timeout.connect(_on_wave_timer_timeout)
	Game.wave_cleared.connect(_on_wave_cleared)
	Game.state_changed.connect(_on_state_changed)

	hud.set_title(ProjectSettings.get_setting("application/config/name", "Swarm"))
	Game.start(waves_to_survive, 0.0)
	start_next_wave()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		restart()


## The whole arena including its walls, taken from the project's viewport size
## so the scene and the code cannot disagree about where the edges are.
func viewport_rect() -> Rect2:
	var width := float(ProjectSettings.get_setting("display/window/size/viewport_width", 960))
	var height := float(ProjectSettings.get_setting("display/window/size/viewport_height", 540))
	return Rect2(0.0, 0.0, width, height)


## The stats resource whose [member EnemyStats.kind] is [param kind]. Drones are
## the fallback, so an unknown name still produces something to shoot rather
## than a null dereference mid-wave.
func stats_for(kind: StringName) -> EnemyStats:
	if brute_stats != null and brute_stats.kind == kind:
		return brute_stats
	return drone_stats


## Enemies currently on the field, dying ones included.
func enemies() -> Array[Node]:
	return _enemies.get_children()


## Bullets currently in flight.
func bullets() -> Array[Node]:
	return _bullets.get_children()


## Composes and spawns the wave after the one the session is on. Public so a
## test or a tool can step the ladder without sitting out [member wave_break].
## Returns false when the round is not running or the plan came back empty.
func start_next_wave() -> bool:
	if not Game.is_playing() or Game.wave_in_progress():
		return false
	if enemy_scene == null:
		push_error("Arena: no enemy_scene assigned on %s" % get_path())
		return false
	if drone_stats == null:
		# stats_for() falls back to the drone, so a missing drone resource would
		# spawn enemies with no speed, no reach and no score value.
		push_error("Arena: no drone_stats assigned on %s" % get_path())
		return false
	# Cancel any pending automatic wave, so calling this by hand cannot end up
	# spawning two waves on top of each other.
	_wave_timer.stop()
	var plan := planner.plan(Game.wave + 1)
	var kinds: Array[StringName] = plan["kinds"]
	var positions: PackedVector2Array = plan["positions"]
	if not Game.start_wave(kinds.size()):
		return false
	for i in kinds.size():
		# _spawn, not spawn_enemy: start_wave already declared this wave's size,
		# so counting each one again would double it.
		_spawn(kinds[i], positions[i])
	_wave_sound.play()
	return true


## Puts one enemy of [param kind] on the field at [param at] and adds it to the
## wave in progress, so the wave still clears when everything on the field is
## dead. Public so tests and tools can build an exact situation instead of
## waiting for the right wave to come round.
func spawn_enemy(kind: StringName, at: Vector2) -> Enemy:
	var enemy := _spawn(kind, at)
	Game.reinforce_wave(1)
	return enemy


func _spawn(kind: StringName, at: Vector2) -> Enemy:
	var enemy := enemy_scene.instantiate() as Enemy
	enemy.stats = stats_for(kind)
	enemy.target = ship
	enemy.position = at
	enemy.died.connect(_on_enemy_died)
	enemy.attacked.connect(_on_enemy_attacked)
	_enemies.add_child(enemy)
	return enemy


## Empties the arena: every enemy freed, every bullet back in the pool.
##
## These enemies are removed rather than killed, so they never report a death
## and the session has to be told the wave is gone. Skipping that would leave a
## wave that can never reach zero and a round that can never end.
func clear_field() -> void:
	for child in _enemies.get_children():
		child.queue_free()
	Game.forget_wave()
	bullet_pool.release_all()


## Resets the round and reloads the scene. Outside the tree's current scene
## (tests, tools) only the reset happens.
func restart() -> void:
	Game.reset()
	if get_tree().current_scene == null:
		push_warning("Arena.restart: no current scene to reload")
		return
	var err := get_tree().reload_current_scene()
	if err != OK:
		push_warning("Arena.restart: reload_current_scene failed (%s)" % error_string(err))


func _release_bullet(bullet: Bullet) -> void:
	# Deferred, so a bullet already taken back by clear_field() -- or already
	# re-acquired and re-launched by the time this runs -- is not released
	# twice. Being spent and still parented here is the proof that this exact
	# shot is the one that finished.
	if not is_instance_valid(bullet) or not bullet.is_spent():
		return
	if bullet.get_parent() == _bullets:
		bullet_pool.release(bullet)


func _on_bullet_acquired(node: Node) -> void:
	var bullet := node as Bullet
	# Pooled instances outlive a single shot, so connect the first time only.
	if bullet == null or bullet.hit.is_connected(_on_bullet_hit):
		return
	bullet.hit.connect(_on_bullet_hit)
	bullet.expired.connect(_on_bullet_expired)


func _on_bullet_hit(bullet: Bullet, _target: Node2D) -> void:
	_release_bullet.call_deferred(bullet)


func _on_bullet_expired(bullet: Bullet) -> void:
	_release_bullet.call_deferred(bullet)


func _on_ship_fired(from: Vector2, direction: Vector2) -> void:
	if not Game.is_playing():
		return
	var bullet := bullet_pool.acquire() as Bullet
	if bullet == null:
		# The pool is at its cap. Dropping the shot is deliberate: the ceiling
		# on live bullets is the point of pooling them.
		return
	_bullets.add_child(bullet)
	bullet.launch(from, direction, playfield)
	_shoot_sound.play()


func _on_enemy_died(enemy: Enemy) -> void:
	Game.register_kill(enemy.stats.score_value if enemy.stats != null else 0)
	_hit_sound.play()


func _on_enemy_attacked(_enemy: Enemy, damage: int) -> void:
	Game.take_damage(damage)
	_hit_sound.play()


func _on_wave_cleared(_wave: int) -> void:
	# Not playing means that was the final wave and the round is already won.
	if Game.is_playing():
		_wave_timer.start(wave_break)


func _on_wave_timer_timeout() -> void:
	start_next_wave()


func _on_state_changed(_state: Session.State) -> void:
	if not Game.is_over():
		return
	_wave_timer.stop()
	# The ship would otherwise keep cycling its trigger against a finished
	# round; freezing it also reads as "the round is over" on screen.
	ship.set_physics_process(false)
	# The winning kill arrives from inside Bullet.body_entered, and a
	# CollisionObject may not leave the tree while the physics server is
	# flushing queries, so the sweep waits for the end of the frame.
	clear_field.call_deferred()
