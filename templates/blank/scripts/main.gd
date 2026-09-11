class_name Main
extends Node2D
## __GAME_TITLE__'s root scene: starts a round and connects input to the session.
##
## Replace this with real gameplay. The parts worth keeping are the shape: rules
## live in the [code]Game[/code] session, this node only wires scene objects to
## it, and everything it does is reachable from a test.

## Objective steps needed to win.
@export_range(1, 100, 1) var goal := 3
## Seconds allowed. 0 disables the countdown.
@export_range(0.0, 600.0, 1.0) var time_limit := 30.0

@onready var hud: HUD = $HUD


func _ready() -> void:
	Game.objective_reached.connect(_on_objective_reached)
	hud.set_title(ProjectSettings.get_setting("application/config/name", "__GAME_TITLE__"))
	Game.start(goal, time_limit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"advance"):
		Game.take_step()
	elif event.is_action_pressed(&"restart"):
		restart()


## Resets the round and reloads the scene. Outside the tree's current scene
## (tests, tools) only the reset happens.
func restart() -> void:
	Game.reset()
	if get_tree().current_scene == null:
		push_warning("Main.restart: no current scene to reload")
		return
	var err := get_tree().reload_current_scene()
	if err != OK:
		push_warning("Main.restart: reload_current_scene failed (%s)" % error_string(err))


func _on_objective_reached() -> void:
	Game.win()
