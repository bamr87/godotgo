class_name Level
extends Node3D
## Orchestrates one round of Orb Run. Wires the orbs, exit portal, player and
## HUD to the [code]Game[/code] session, respawns the player below
## [member LevelConfig.kill_y], and restarts the scene on the "restart" action.
##
## Gameplay rules live in the session (framework [Session] plus the game's thin
## subclass); this node only connects scene objects to them.

## Tuning for this level. A default LevelConfig is used when unset.
@export var config: LevelConfig

@onready var player: Player = $Player
@onready var spawn_point: Marker3D = $SpawnPoint
@onready var exit_portal: ExitPortal = $ExitPortal
@onready var hud: HUD = $HUD
@onready var _orbs_root: Node3D = $Orbs
@onready var _pickup_sound: AudioStreamPlayer = $PickupSound
@onready var _land_sound: AudioStreamPlayer = $LandSound


func _ready() -> void:
	if config == null:
		config = LevelConfig.new()
	var orbs := get_orbs()
	for orb in orbs:
		orb.collected.connect(_on_orb_collected)
	Game.objective_reached.connect(_on_all_orbs_collected)
	exit_portal.player_entered.connect(_on_exit_entered)
	player.landed.connect(_on_player_landed)
	hud.set_title(config.title)
	Game.start(orbs.size(), config.time_limit)


func _physics_process(_delta: float) -> void:
	if player.global_position.y < config.kill_y:
		respawn_player()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		restart()


## Every Orb placed under the Orbs node, collected or not (freed ones are gone).
func get_orbs() -> Array[Orb]:
	var orbs: Array[Orb] = []
	for child in _orbs_root.get_children():
		if child is Orb:
			orbs.append(child)
	return orbs


## Moves the player back to the spawn point and cancels their velocity.
func respawn_player() -> void:
	player.global_position = spawn_point.global_position
	player.velocity = Vector3.ZERO
	print("[Level] respawned player")


## Resets the round and reloads the current scene. When this level is not the
## tree's current scene (tests, tools) only the reset happens.
func restart() -> void:
	Game.reset()
	if get_tree().current_scene == null:
		push_warning("Level.restart: no current scene to reload")
		return
	var err := get_tree().reload_current_scene()
	if err != OK:
		push_warning("Level.restart: reload_current_scene failed (%s)" % error_string(err))


func _on_orb_collected(_orb: Orb) -> void:
	Game.collect_orb()
	_pickup_sound.play()


func _on_all_orbs_collected() -> void:
	exit_portal.active = true
	print("[Level] all orbs collected, exit open")


func _on_exit_entered() -> void:
	Game.reach_exit()


func _on_player_landed(fall_speed: float) -> void:
	if fall_speed >= config.land_sound_min_fall_speed:
		_land_sound.play()
