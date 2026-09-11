extends GodotGoTest
## Collectible behaviour, including real Area3D contact with the player body.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _orb: Orb


func before_each() -> void:
	_orb = add_scene(ORB_SCENE) as Orb
	_orb.global_position = Vector3(0, 1.5, 0)


func after_each() -> void:
	await free_node(_orb)


func test_orb_is_in_group_and_on_pickup_layer() -> void:
	assert_true(_orb.is_in_group(&"orbs"))
	assert_eq(_orb.collision_layer, 4, "layer 3 = pickups")
	assert_eq(_orb.collision_mask, 2, "mask 2 = player")
	assert_false(_orb.is_collected())


func test_mesh_bobs_and_spins_while_the_area_stays_put() -> void:
	var mesh := _orb.get_node(^"Mesh") as MeshInstance3D
	var start_mesh_y := mesh.position.y
	var start_yaw := mesh.rotation.y
	await physics_frames(12)
	assert_true(absf(mesh.position.y - start_mesh_y) > 0.001, "mesh should bob")
	assert_true(absf(mesh.rotation.y - start_yaw) > 0.001, "mesh should spin")
	assert_almost_eq(_orb.global_position.y, 1.5, 0.0001, "the Area3D itself never moves")


func test_collect_emits_once_hides_and_frees() -> void:
	var calls := record(_orb.collected)
	var mesh := _orb.get_node(^"Mesh") as MeshInstance3D
	_orb.collect()
	_orb.collect()
	assert_eq(calls.size(), 1, "collected fires exactly once")
	assert_eq(calls[0][0], _orb)
	assert_true(_orb.is_collected())
	assert_false(mesh.visible)
	await tree.create_timer(0.9).timeout
	assert_false(is_instance_valid(_orb), "orb frees itself after its burst")


func test_player_contact_collects_through_physics() -> void:
	var player := add_scene(PLAYER_SCENE) as Player
	player.global_position = _orb.global_position - Vector3(0, 0.8, 0)
	var calls := record(_orb.collected)
	await physics_frames(3)
	assert_eq(calls.size(), 1, "Area3D body_entered must detect the player capsule")
	await free_node(player)


func test_non_player_bodies_are_ignored() -> void:
	var box := RigidBody3D.new()
	box.collision_layer = 2
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	box.add_child(shape)
	add_node(box)
	box.global_position = _orb.global_position
	var calls := record(_orb.collected)
	await physics_frames(3)
	assert_eq(calls.size(), 0)
	await free_node(box)
