class_name EnemyStats
extends Resource
## Everything that makes one enemy kind different from another, as data.
##
## Swarm ships two instances ([code]resources/drone.tres[/code] and
## [code]resources/brute.tres[/code]) and a single [code]scenes/enemy.tscn[/code]
## that reads its sprite, body radius and behaviour from whichever one it is
## given. Keeping the difference in a resource rather than in two scenes is what
## lets [WavePlanner] compose a wave without touching the scene tree, so wave
## generation stays a pure, headless, deterministic function.

## Identifier used by [WavePlanner] and by save files. Must match the key the
## arena registers this resource under.
@export var kind: StringName = &"drone"
## Sprite drawn for this kind; also sizes nothing, the radius below does that.
@export var texture: Texture2D
## Body radius in pixels. Drives the collision circle, so bullets hit the shape
## the player actually sees.
@export_range(4.0, 64.0, 1.0) var radius := 9.0
## Hits absorbed before dying. Brutes are slow but soak more.
@export_range(1, 20, 1) var max_health := 1
## Top chase speed in pixels per second.
@export_range(10.0, 800.0, 5.0) var speed := 130.0
## Steering acceleration in pixels per second squared. Low values read as
## momentum, which is how a brute feels heavy without being unfair.
@export_range(10.0, 4000.0, 10.0) var acceleration := 600.0
## Distance to the ship at which the enemy stops chasing and starts hitting.
@export_range(4.0, 200.0, 1.0) var attack_range := 22.0
## Hull points removed per landed hit.
@export_range(1, 5, 1) var attack_damage := 1
## Seconds between landed hits while in range.
@export_range(0.1, 5.0, 0.05) var attack_cooldown := 0.9
## Seconds the spawn ring telegraphs before the enemy becomes solid and
## dangerous. Without it enemies could materialise on top of the ship.
@export_range(0.0, 3.0, 0.05) var spawn_time := 0.6
## Score paid to [code]Game.register_kill[/code] when this enemy dies.
@export_range(1, 1000, 5) var score_value := 25
