class_name Level
extends Node2D
## Builds a Leap level from its ASCII map and wires it to the [code]Game[/code]
## session: coins score, spikes and pits cost a life, the flag wins the round.

@export_group("Level")
## ASCII map parsed by [LevelBuilder]. See that class for the symbol table.
@export_file("*.txt") var level_file := "res://levels/level_1.txt"
@export_range(8, 128, 1) var tile_size := 32
## Seconds allowed. 0 disables the countdown.
@export_range(0.0, 600.0, 1.0) var time_limit := 60.0
## Falling past this world Y costs a life.
@export var kill_y := 700.0

@export_group("Scenes")
@export var coin_scene: PackedScene
@export var hazard_scene: PackedScene
@export var goal_scene: PackedScene
@export var tile_texture: Texture2D

## World-space spawn point taken from the map's "@" cell.
var spawn_point := Vector2.ZERO
## The parsed level map.
var grid: TextGrid

@onready var hero: Hero = $Hero
@onready var hud: HUD = $HUD
@onready var _world: Node2D = $World
@onready var _coin_sound: AudioStreamPlayer = $CoinSound
@onready var _jump_sound: AudioStreamPlayer = $JumpSound
@onready var _hurt_sound: AudioStreamPlayer = $HurtSound


func _ready() -> void:
	grid = TextGrid.from_file(level_file)
	var scenes := {
		LevelBuilder.COIN: coin_scene,
		LevelBuilder.SPIKE: hazard_scene,
		LevelBuilder.GOAL: goal_scene,
	}
	var built := LevelBuilder.build(_world, grid, tile_size, scenes, tile_texture)
	spawn_point = built["spawn"]

	for coin: Coin in built["coins"]:
		coin.triggered.connect(_on_coin_taken)
	for hazard: Hazard in built["hazards"]:
		hazard.triggered.connect(_on_hazard_touched)
	var goal := built["goal"] as GoalFlag
	if goal != null:
		goal.triggered.connect(_on_goal_reached)

	hero.teleport_to(spawn_point)
	hero.jumped.connect(_on_hero_jumped)
	hero.landed.connect(_on_hero_landed)
	hud.set_title(ProjectSettings.get_setting("application/config/name", "Leap"))
	Game.start(built["coins"].size(), time_limit)


func _physics_process(_delta: float) -> void:
	if Game.is_playing() and hero.global_position.y > kill_y:
		_lose_life()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		restart()


## Coins still in the level, spent or not.
func coins() -> Array[Node]:
	return _world.get_children().filter(func(n: Node) -> bool: return n is Coin)


func respawn_hero() -> void:
	hero.teleport_to(spawn_point)


## Resets the round and reloads the scene. Outside the tree's current scene
## (tests, tools) only the reset happens.
func restart() -> void:
	Game.reset()
	if get_tree().current_scene == null:
		push_warning("Level.restart: no current scene to reload")
		return
	var err := get_tree().reload_current_scene()
	if err != OK:
		push_warning("Level.restart: reload_current_scene failed (%s)" % error_string(err))


func _lose_life() -> void:
	var alive := Game.lose_life()
	_hurt_sound.play()
	if alive:
		respawn_hero()


func _on_coin_taken(_coin: LeapTrigger) -> void:
	if not Game.collect_coin():
		return
	_coin_sound.play()


func _on_hazard_touched(_hazard: LeapTrigger) -> void:
	if Game.is_playing():
		_lose_life()


func _on_goal_reached(_goal: LeapTrigger) -> void:
	Game.reach_goal()


func _on_hero_jumped() -> void:
	_jump_sound.play()


func _on_hero_landed(fall_speed: float) -> void:
	if fall_speed >= hero.hard_landing_speed:
		_hurt_sound.play()
