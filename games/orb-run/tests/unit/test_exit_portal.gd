extends GodotGoTest
## Exit trigger: inert until activated, then reacts to the player only.

const EXIT_SCENE := preload("res://scenes/exit_portal.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _exit: ExitPortal


func before_each() -> void:
	_exit = add_scene(EXIT_SCENE) as ExitPortal
	_exit.global_position = Vector3(0, 0, 0)


func after_each() -> void:
	await free_node(_exit)


func _portal_material(portal: ExitPortal) -> StandardMaterial3D:
	var mesh := portal.get_node(^"Mesh") as MeshInstance3D
	return mesh.material_override as StandardMaterial3D


func test_layers_and_initial_visual() -> void:
	assert_eq(_exit.collision_layer, 8, "layer 4 = triggers")
	assert_eq(_exit.collision_mask, 2, "mask 2 = player")
	assert_false(_exit.active)
	assert_false(_portal_material(_exit).emission_enabled)


func test_inactive_portal_ignores_the_player() -> void:
	var player := add_scene(PLAYER_SCENE) as Player
	player.global_position = _exit.global_position
	var calls := record(_exit.player_entered)
	await physics_frames(3)
	assert_eq(calls.size(), 0)
	await free_node(player)


func test_active_portal_emits_on_player_contact() -> void:
	_exit.active = true
	assert_true(_portal_material(_exit).emission_enabled)
	var player := add_scene(PLAYER_SCENE) as Player
	player.global_position = _exit.global_position
	var calls := record(_exit.player_entered)
	await physics_frames(3)
	assert_eq(calls.size(), 1)
	await free_node(player)


func test_activating_with_the_player_already_inside_emits_immediately() -> void:
	var player := add_scene(PLAYER_SCENE) as Player
	player.global_position = _exit.global_position
	await physics_frames(3)
	var calls := record(_exit.player_entered)
	_exit.active = true
	assert_eq(calls.size(), 1, "overlap is checked when the portal opens")
	_exit.active = true
	assert_eq(calls.size(), 1, "re-setting active does not emit again")
	await free_node(player)


func test_material_is_unique_per_instance() -> void:
	var other := add_scene(EXIT_SCENE) as ExitPortal
	_exit.active = true
	assert_true(_portal_material(_exit).emission_enabled)
	assert_false(
		_portal_material(other).emission_enabled, "resource_local_to_scene keeps materials separate"
	)
	await free_node(other)
