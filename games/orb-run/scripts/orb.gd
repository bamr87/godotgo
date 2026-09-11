class_name Orb
extends Area3D
## A collectible. Its mesh bobs and spins until the player's body enters the
## area, then the orb hides, plays its burst particles, emits
## [signal collected] and frees itself.
##
## Physics: layer 3 (pickups), mask 2 (player). Group "orbs" lets tools and
## editor scripts find every orb with [method SceneTree.get_nodes_in_group].
## Only the Mesh child is animated, so the Area3D transform stays wherever the
## scene (or a spawner) put it.

## Emitted once, when this orb is collected.
signal collected(orb: Orb)

## Bob amplitude of the mesh, in metres.
@export_range(0.0, 2.0, 0.05) var bob_height := 0.25
## Bob frequency in radians per second.
@export_range(0.0, 10.0, 0.1) var bob_speed := 2.0
## Spin in radians per second.
@export_range(0.0, 10.0, 0.1) var spin_speed := 1.5

var _elapsed := 0.0
var _collected := false

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _particles: GPUParticles3D = $Particles


func _ready() -> void:
	add_to_group(&"orbs")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _collected:
		return
	_elapsed += delta
	_mesh.position.y = sin(_elapsed * bob_speed) * bob_height
	_mesh.rotate_y(spin_speed * delta)


## True once [method collect] has run; the node frees itself shortly after.
func is_collected() -> bool:
	return _collected


## Collects the orb regardless of physics contact (also used by tests and tools).
func collect() -> void:
	if _collected:
		return
	_collected = true
	_shape.set_deferred(&"disabled", true)
	_mesh.visible = false
	_particles.restart()
	collected.emit(self)
	await get_tree().create_timer(_particles.lifetime).timeout
	queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		collect()
