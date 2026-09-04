extends GutTest
## DungeonModel：行走判定、实体容器、FOV 记忆。

const DungeonModel = preload("res://src/core/dungeon_model.gd")
const Actor = preload("res://src/core/actor.gd")

func _blank_model() -> Object:
	var m = DungeonModel.new(5, 5)
	for y in 5:
		for x in 5:
			m.set_tile(Vector2i(x, y), DungeonModel.Tile.FLOOR)
	return m

func test_out_of_bounds_is_wall_and_not_walkable() -> void:
	var m = DungeonModel.new(3, 3)
	assert_eq(m.tile_at(Vector2i(-1, 0)), DungeonModel.Tile.WALL)
	assert_false(m.is_walkable(Vector2i(3, 0)))
	assert_false(m.is_walkable(Vector2i(0, -1)))

func test_wall_not_walkable_floor_walkable() -> void:
	var m = _blank_model()
	m.set_tile(Vector2i(2, 2), DungeonModel.Tile.WALL)
	assert_false(m.is_walkable(Vector2i(2, 2)))
	assert_true(m.is_walkable(Vector2i(1, 2)))
	assert_true(m.is_walkable(Vector2i(2, 1)))

func test_actor_at_contains_player_and_monsters() -> void:
	var m = _blank_model()
	var player = Actor.new()
	player.id = "player"
	player.is_player = true
	player.pos = Vector2i(1, 1)
	var rat = Actor.new()
	rat.id = "rat"
	rat.pos = Vector2i(3, 3)
	m.add_actor(player)
	m.add_actor(rat)
	assert_eq(m.actor_at(Vector2i(1, 1)), player)
	assert_eq(m.actor_at(Vector2i(3, 3)), rat)
	assert_null(m.actor_at(Vector2i(0, 0)))
	assert_eq(m.player, player)
	assert_eq(m.monsters.size(), 1)

func test_remove_actor_clears_position() -> void:
	var m = _blank_model()
	var player = Actor.new()
	player.id = "player"
	player.is_player = true
	player.pos = Vector2i(1, 1)
	m.add_actor(player)
	var rat = Actor.new()
	rat.id = "rat"
	rat.pos = Vector2i(3, 3)
	m.add_actor(rat)
	m.remove_actor(rat)
	assert_null(m.actor_at(Vector2i(3, 3)))
	assert_eq(m.monsters.size(), 0)

func test_items_add_remove() -> void:
	var m = _blank_model()
	m.add_item("potion_minor", Vector2i(2, 2))
	var it = m.item_at(Vector2i(2, 2))
	assert_eq(it.get("item_id", ""), "potion_minor")
	m.remove_item(Vector2i(2, 2))
	assert_true(m.item_at(Vector2i(2, 2)).is_empty())

func test_remember_fov_merges_explored() -> void:
	var m = _blank_model()
	var vis = {Vector2i(1, 1): true, Vector2i(2, 1): true}
	m.remember_fov(vis)
	assert_true(m.explored.has(Vector2i(1, 1)))
	m.remember_fov({Vector2i(3, 1): true})
	assert_true(m.explored.has(Vector2i(1, 1)))
	assert_true(m.explored.has(Vector2i(3, 1)))
	assert_false(m.visible.has(Vector2i(1, 1)))  # visible 只保留最近一次
