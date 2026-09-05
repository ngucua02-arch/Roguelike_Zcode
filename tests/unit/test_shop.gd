extends GutTest
## 商店：商人不可被攻击、不参与回合；开店/购买不消耗回合。

const TurnScheduler = preload("res://src/core/turn_scheduler.gd")
const DungeonModel = preload("res://src/core/dungeon_model.gd")
const Actor = preload("res://src/core/actor.gd")
const PlayerDef = preload("res://src/core/player_def.gd")
const MonsterDef = preload("res://src/core/monster_def.gd")
const ItemDef = preload("res://src/core/item_def.gd")
const FloorDef = preload("res://src/core/floor_def.gd")
const GameEvents = preload("res://src/core/events.gd")

func _model_with_shopkeeper() -> Object:
	var m = DungeonModel.new(7, 7)
	for y in 7:
		for x in 7:
			m.set_tile(Vector2i(x, y), DungeonModel.Tile.FLOOR)
	m.stairs_pos = Vector2i(6, 6)
	m.set_tile(m.stairs_pos, DungeonModel.Tile.STAIRS)
	var player = Actor.from_player_def(PlayerDef.new())
	player.pos = Vector2i(3, 3)
	m.add_actor(player)
	var d = MonsterDef.new()
	d.id = "shopkeeper"
	d.display_name = "商人"
	d.ai_type = "shopkeeper"
	d.max_hp = 999
	m.add_actor(Actor.from_monster_def(d, Vector2i(4, 3)))
	return m

func _scheduler_with(model: Object) -> Object:
	var s = TurnScheduler.new(PlayerDef.new(), [FloorDef.new()], 42)
	s.model = model
	s.player = model.player
	return s

func test_walking_into_shopkeeper_opens_shop_not_attack() -> void:
	var m = _model_with_shopkeeper()
	var s = _scheduler_with(m)
	var turns_before: int = s.stats.turns
	var events = s.player_action(GameEvents.ACTION_MOVE, Vector2i(1, 0))
	assert_eq(events[0].type, GameEvents.SHOP_OPEN)
	assert_eq(s.player.pos, Vector2i(3, 3))  # 玩家没动
	assert_eq(s.stats.turns, turns_before)   # 不消耗回合
	assert_eq(m.actor_at(Vector2i(4, 3)).hp, 999)  # 商人没掉血

func test_shopkeeper_never_acts() -> void:
	var m = _model_with_shopkeeper()
	var s = _scheduler_with(m)
	var events = s.player_action(GameEvents.ACTION_WAIT)
	# 商人相邻但不攻击、不移动
	var attacked: Array = events.filter(func(e): return e.type == GameEvents.ATTACKED)
	assert_eq(attacked.size(), 0)
	assert_eq(m.actor_at(Vector2i(4, 3)).pos, Vector2i(4, 3))

func test_action_shop_opens_shop() -> void:
	var m = _model_with_shopkeeper()
	var s = _scheduler_with(m)
	var events = s.player_action(GameEvents.ACTION_SHOP)
	assert_eq(events[0].type, GameEvents.SHOP_OPEN)

func test_roll_shop_stock_excludes_gold() -> void:
	var s = TurnScheduler.new(PlayerDef.new(), [FloorDef.new()], 42)
	assert_eq(s.shop_stock.size(), 0)  # 空表 -> 空库存

func test_buy_success_deducts_gold_and_fills_inventory() -> void:
	var m = _model_with_shopkeeper()
	var s = _scheduler_with(m)
	var sword = ItemDef.new()
	sword.id = "sword_iron"
	sword.kind = "weapon"
	sword.price = 35
	s.shop_stock = [{"def": sword, "price": 35}]
	s.player.gold = 40
	var events = s.buy(0)
	assert_eq(events[0].type, GameEvents.BOUGHT)
	assert_eq(s.player.gold, 5)
	assert_eq(s.inventory.size(), 1)
	assert_eq(s.shop_stock.size(), 0)

func test_buy_too_poor_fails() -> void:
	var m = _model_with_shopkeeper()
	var s = _scheduler_with(m)
	var axe = ItemDef.new()
	axe.id = "battle_axe"
	axe.price = 50
	s.shop_stock = [{"def": axe, "price": 50}]
	s.player.gold = 10
	var events = s.buy(0)
	assert_eq(events[0].type, GameEvents.SHOP_FAILED)
	assert_eq(s.player.gold, 10)
	assert_eq(s.inventory.size(), 0)
	assert_eq(s.shop_stock.size(), 1)

func test_buy_out_of_range_returns_empty() -> void:
	var m = _model_with_shopkeeper()
	var s = _scheduler_with(m)
	assert_eq(s.buy(0), [])
