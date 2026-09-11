class_name ExitPortal
extends Area3D
## The level exit. Inert until [member active] is set (the level does that once
## every orb is collected); then player contact emits [signal player_entered],
## including a player who is already standing inside when it activates.
##
## Physics: layer 4 (triggers), mask 2 (player).

## Emitted when the active portal is touched by the player.
signal player_entered

const INACTIVE_COLOR := Color(0.35, 0.35, 0.4)
const ACTIVE_COLOR := Color(0.3, 1.0, 0.5)

## Whether the portal accepts the player. Setting it repaints the ring and,
## if the player is already overlapping, emits [signal player_entered] at once.
@export var active := false:
	set(value):
		var was_active := active
		active = value
		_apply_visual()
		if active and not was_active and is_inside_tree():
			for body in get_overlapping_bodies():
				if body is Player:
					player_entered.emit()
					break

@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_visual()


func _apply_visual() -> void:
	if _mesh == null:
		return
	var material := _mesh.material_override as StandardMaterial3D
	if material == null:
		return
	material.albedo_color = ACTIVE_COLOR if active else INACTIVE_COLOR
	material.emission_enabled = active
	material.emission = ACTIVE_COLOR


func _on_body_entered(body: Node3D) -> void:
	if active and body is Player:
		player_entered.emit()
