class_name LeapTrigger
extends Area2D
## Base for Leap's one-shot trigger volumes: coins, spikes and the goal flag.
##
## Each subclass sets its own physics layer in its scene and reacts to the hero
## entering. The shared part is "fire once, then stop caring", which is what
## keeps a coin from paying out twice while its animation plays.

## Emitted when the hero enters, with this node as the argument.
signal triggered(source: LeapTrigger)

## When true the trigger pays out once and then stays spent (coins, the goal).
## When false every entry fires again, which is what a spike needs after the
## hero respawns and walks back into it.
@export var one_shot := true

var _fired := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func is_fired() -> bool:
	return _fired


## Fires the trigger regardless of physics contact. Used by tests and tools.
func fire() -> void:
	if _fired and one_shot:
		return
	_fired = true
	triggered.emit(self)
	_on_fired()


## Makes a spent one-shot trigger usable again.
func rearm() -> void:
	_fired = false


## Overridden by subclasses to play their own reaction.
func _on_fired() -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if body is Hero:
		fire()
