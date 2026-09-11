extends GodotGoTest
## Coins, spikes and the goal flag, including real contact with the hero body.

const COIN_SCENE := preload("res://scenes/coin.tscn")
const HAZARD_SCENE := preload("res://scenes/hazard.tscn")
const GOAL_SCENE := preload("res://scenes/goal.tscn")
const HERO_SCENE := preload("res://scenes/hero.tscn")


func test_layers_match_the_documented_convention() -> void:
	var coin := add_scene(COIN_SCENE) as Coin
	var hazard := add_scene(HAZARD_SCENE) as Hazard
	var goal := add_scene(GOAL_SCENE) as GoalFlag
	assert_eq(coin.collision_layer, 4, "layer 3 = pickups")
	assert_eq(hazard.collision_layer, 16, "layer 5 = hazards")
	assert_eq(goal.collision_layer, 8, "layer 4 = triggers")
	for area in [coin, hazard, goal]:
		assert_eq(area.collision_mask, 2, "every trigger watches the player layer")
	await free_node(coin)
	await free_node(hazard)
	await free_node(goal)


func test_a_coin_pays_out_once_then_removes_itself() -> void:
	var coin := add_scene(COIN_SCENE) as Coin
	var hits := record(coin.triggered)
	coin.fire()
	coin.fire()
	assert_eq(hits.size(), 1, "a coin is one-shot")
	assert_true(coin.is_fired())
	await tree.create_timer(coin.pop_time + 0.2).timeout
	assert_false(is_instance_valid(coin), "the coin frees itself after the pop")


func test_a_spike_re_arms_so_a_respawned_hero_can_die_again() -> void:
	var hazard := add_scene(HAZARD_SCENE) as Hazard
	assert_false(hazard.one_shot, "set in hazard.tscn, visible to a designer")
	var hits := record(hazard.triggered)
	hazard.fire()
	hazard.fire()
	assert_eq(hits.size(), 2)
	await free_node(hazard)


func test_rearm_makes_a_spent_one_shot_usable_again() -> void:
	var goal := add_scene(GOAL_SCENE) as GoalFlag
	var hits := record(goal.triggered)
	goal.fire()
	goal.fire()
	assert_eq(hits.size(), 1)
	goal.rearm()
	goal.fire()
	assert_eq(hits.size(), 2)
	await free_node(goal)


func test_the_hero_body_fires_a_coin_through_physics() -> void:
	var coin := add_scene(COIN_SCENE) as Coin
	coin.global_position = Vector2(200, 200)
	var hero := add_scene(HERO_SCENE) as Hero
	hero.use_input_override = true
	hero.teleport_to(coin.global_position)
	var hits := record(coin.triggered)
	await physics_frames(3)
	assert_eq(hits.size(), 1, "Area2D body_entered must see the hero capsule")
	await free_node(hero)


func test_other_bodies_are_ignored() -> void:
	var coin := add_scene(COIN_SCENE) as Coin
	coin.global_position = Vector2(400, 400)
	var box := CharacterBody2D.new()
	box.collision_layer = 2
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	box.add_child(shape)
	add_node(box)
	box.global_position = coin.global_position
	var hits := record(coin.triggered)
	await physics_frames(3)
	assert_eq(hits.size(), 0, "only a Hero counts")
	await free_node(box)
	await free_node(coin)
