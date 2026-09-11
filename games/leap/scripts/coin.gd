class_name Coin
extends LeapTrigger
## A collectible coin. Pays out once, pops, then removes itself.
##
## Physics: layer 3 (pickups), mask 2 (player).

## Seconds the pop animation runs before the coin frees itself.
@export_range(0.05, 1.0, 0.05) var pop_time := 0.25

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _on_fired() -> void:
	_shape.set_deferred(&"disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sprite, ^"position:y", _sprite.position.y - 24.0, pop_time)
	tween.tween_property(_sprite, ^"modulate:a", 0.0, pop_time)
	tween.chain().tween_callback(queue_free)
