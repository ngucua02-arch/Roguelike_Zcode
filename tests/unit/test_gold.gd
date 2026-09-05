extends GutTest
## 金币经济：金币拾取加钱不进背包、战绩累计。

const TurnScheduler = preload("res://src/core/turn_scheduler.gd")
const DungeonModel = preload("res://src/core/dungeon_model.gd")
const Actor = preload("res://src/core/actor.gd")
const PlayerDef = preload("res://src/core/player_def.gd")
const ItemDef = preload("res://src/core/item_def.gd")
const FloorDef = preload("res://src/core/floor_def.gd")
const GameEvents = preload("res://src/core/events.gd")

func _flat_model() -> Object:
	var m = DungeonModel.new(7, 7)
	for y in 7:
		for x in 7:
			m.set_tile(Vector2i(x, y), DungeonModel.Tile.FLOOR)
	m.stairs_pos = Vector2i(6, 6)
	m.set_tile(m.stairs_pos, DungeonModel.Tile.STAIRS)
	var player = Actor.from_player_def(PlayerDef.new())
	player.pos = Vector2i(3, 3)
	m.add_actor(player)
	return m

func _gold_def(face: int) -> Object:
	var d = ItemDef.new()
	d.id = "gold"
	d.kind = "gold"
	d.power = face
	return d

func _scheduler_with(model: Object) -> Object:
	var s = TurnScheduler.new(PlayerDef.new(), [FloorDef.new()], 42)
	s.model = model
	s.player = model.player
	return s

func test_gold_pickup_adds_coins_not_inventory() -> void:
	var m = _flat_model()
	m.add_item("gold", Vector2i(4, 3), _gold_def(10))
	var s = _scheduler_with(m)
	var events = s.player_action(GameEvents.ACTION_MOVE, Vector2i(1, 0))
	var picked: Array = events.filter(func(e): return e.type == GameEvents.PICKED_UP)
	assert_eq(picked.size(), 1)
	assert_eq(picked[0].data.item_name, "10 金币")
	assert_eq(s.player.gold, 10)
	assert_eq(s.inventory.size(), 0)
	assert_eq(s.stats.gold_earned, 10)

func test_regular_item_still_goes_to_inventory() -> void:
	var m = _flat_model()
	var potion = ItemDef.new()
	potion.id = "potion_minor"
	potion.kind = "potion"
	m.add_item("potion_minor", Vector2i(4, 3), potion)
	var s = _scheduler_with(m)
	s.player_action(GameEvents.ACTION_MOVE, Vector2i(1, 0))
	assert_eq(s.player.gold, 0)
	assert_eq(s.inventory.size(), 1)
	assert_eq(s.stats.items_picked, 1)
