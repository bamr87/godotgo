class_name GoalFlag
extends LeapTrigger
## The level exit. Always reachable: coins are a bonus, not a gate, which is
## what makes Leap's round shape different from Orb Run's.
##
## Physics: layer 4 (triggers), mask 2 (player).

@onready var _sprite: Sprite2D = $Sprite2D


func _on_fired() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, ^"scale", Vector2(1.4, 1.4), 0.15)
	tween.tween_property(_sprite, ^"scale", Vector2.ONE, 0.15)
