extends GodotGoTest
## Import pipeline and project wiring: generated assets, Material Maker
## exports, the orb shader, autoload, input map, physics layers and main scene.


func test_generated_audio_imports_as_wav_streams() -> void:
	for name in ["pickup", "land"]:
		var stream := load("res://assets/audio/%s.wav" % name)
		assert_is(stream, AudioStreamWAV, name)
		assert_true(stream.get_length() > 0.1, "%s has audible length" % name)


func test_generated_obj_imports_as_mesh() -> void:
	var mesh := load("res://assets/models/orb.obj") as Mesh
	assert_not_null(mesh)
	assert_eq(mesh.get_surface_count(), 1)
	var size := mesh.get_aabb().size
	assert_almost_eq(size.x, 0.8, 0.01)
	assert_almost_eq(size.y, 0.8, 0.01)


func test_generated_texture_imports() -> void:
	var texture := load("res://assets/textures/crosshair.png") as Texture2D
	assert_not_null(texture)
	assert_eq(texture.get_size(), Vector2(32, 32))


func test_material_maker_exports_load_with_maps() -> void:
	for stem in ["starter/starter_pbr", "metal/metal"]:
		var material := load("res://materials/%s.tres" % stem) as StandardMaterial3D
		assert_not_null(material, stem)
		assert_not_null(material.albedo_texture, "%s albedo" % stem)
		assert_not_null(material.roughness_texture, "%s orm" % stem)
		assert_true(material.normal_enabled, "%s normal" % stem)


func test_orb_shader_material() -> void:
	var material := load("res://materials/orb/orb_material.tres") as ShaderMaterial
	assert_not_null(material)
	assert_not_null(material.shader)
	assert_true(material.shader.code.contains("EMISSION"))
	assert_eq(typeof(material.get_shader_parameter("base_color")), TYPE_COLOR)
	assert_almost_eq(material.get_shader_parameter("pulse_speed"), 3.0)


func test_project_settings_declare_game_wiring() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/main.tscn")
	assert_eq(ProjectSettings.get_setting("autoload/Game"), "*res://scripts/game.gd")
	assert_is(Game, Session, "the game's autoload extends the framework session")
	assert_true(is_instance_valid(Game), "autoload is instantiated")
	for action in [
		"move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "restart"
	]:
		assert_true(InputMap.has_action(action), action)
	assert_eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_1"), "world")
	assert_eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_2"), "player")
	assert_eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_3"), "pickups")
	assert_eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_4"), "triggers")


func test_scenes_carry_uids() -> void:
	for path in [
		"res://scenes/main.tscn",
		"res://scenes/player.tscn",
		"res://scenes/orb.tscn",
		"res://scenes/exit_portal.tscn",
		"res://scenes/ui/hud.tscn",
		"res://resources/arena_config.tres"
	]:
		var id := ResourceLoader.get_resource_uid(path)
		assert_ne(id, ResourceUID.INVALID_ID, "%s has a registered uid" % path)
		assert_eq(ResourceUID.get_id_path(id), path)
