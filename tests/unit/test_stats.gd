extends GutTest
## 战绩统计：击杀/回合/伤害/金币 累计，终局事件携带 stats。

const TurnScheduler = preload("res://src/core/turn_scheduler.gd")
const DungeonModel = preload("res://src/core/dungeon_model.gd")
const Actor = preload("res://src/core/actor.gd")
const PlayerDef = preload("res://src/core/player_def.gd")
const MonsterDef = preload("res://src/core/monster_def.gd")
const ItemDef = preload("res://src/core/item_def.gd")
const FloorDef = preload("res://src/core/floor_def.gd")
const GameEvents = preload("res://src/core/events.gd")

func _scheduler() -> Object:
	var m = DungeonModel.new(7, 7)
	for y in 7:
		for x in 7:
			m.set_tile(Vector2i(x, y), DungeonModel.Tile.FLOOR)
	m.stairs_pos = Vector2i(6, 6)
	m.set_tile(m.stairs_pos, DungeonModel.Tile.STAIRS)
	var player = Actor.from_player_def(PlayerDef.new())
	player.pos = Vector2i(3, 3)
	m.add_actor(player)
	var s = TurnScheduler.new(PlayerDef.new(), [FloorDef.new()], 42)
	s.model = m
	s.player = m.player
	return s

func _rat(pos: Vector2i, hp: int, atk: int) -> Object:
	var d = MonsterDef.new()
	d.id = "rat"
	d.max_hp = hp
	d.atk = atk
	return Actor.from_monster_def(d, pos)

func test_kill_counts_and_damage_dealt() -> void:
	var s = _scheduler()
	var rat = _rat(Vector2i(4, 3), 1, 0)
	s.model.add_actor(rat)
	s.player_action(GameEvents.ACTION_MOVE, Vector2i(1, 0))
	assert_eq(s.stats.kills, 1)
	assert_eq(s.stats.damage_dealt, 3)  # 默认 PlayerDef atk=3，rat 0 防
	assert_eq(s.stats.turns, 1)

func test_damage_taken_recorded() -> void:
	var s = _scheduler()
	var rat = _rat(Vector2i(4, 3), 20, 3)
	s.model.add_actor(rat)
	s.player_action(GameEvents.ACTION_WAIT)
	assert_true(s.stats.damage_taken > 0)
	assert_eq(s.stats.kills, 0)

func test_gold_counted_in_earned() -> void:
	var s = _scheduler()
	var d = ItemDef.new()
	d.id = "gold"
	d.kind = "gold"
	d.power = 7
	s.model.add_item("gold", Vector2i(4, 3), d)
	s.player_action(GameEvents.ACTION_MOVE, Vector2i(1, 0))
	assert_eq(s.stats.gold_earned, 7)

func test_game_over_carries_stats() -> void:
	var s = _scheduler()
	var ogre = _rat(Vector2i(4, 3), 50, 99)
	ogre.id = "ogre"
	s.model.add_actor(ogre)
	s.player.hp = 1
	var events = s.player_action(GameEvents.ACTION_WAIT)
	var over: Array = events.filter(func(e): return e.type == GameEvents.GAME_OVER)
	assert_eq(over.size(), 1)
	assert_true(over[0].data.has("stats"))
	assert_true(over[0].data.stats.has("turns"))
