extends GutTest
## 精英怪：生成器概率精英化；精英死亡必掉战利品。

const TurnScheduler = preload("res://src/core/turn_scheduler.gd")
const DungeonGenerator = preload("res://src/core/dungeon_generator.gd")
const DungeonModel = preload("res://src/core/dungeon_model.gd")
const Actor = preload("res://src/core/actor.gd")
const PlayerDef = preload("res://src/core/player_def.gd")
const MonsterDef = preload("res://src/core/monster_def.gd")
const ItemDef = preload("res://src/core/item_def.gd")
const FloorDef = preload("res://src/core/floor_def.gd")
const GameEvents = preload("res://src/core/events.gd")

func _floor_def() -> Object:
	var f = FloorDef.new()
	f.width = 30
	f.height = 20
	f.room_count_min = 5
	f.room_count_max = 7
	f.monster_count_min = 5
	f.monster_count_max = 7
	f.item_count_min = 0
	f.item_count_max = 0
	var rat = MonsterDef.new()
	rat.id = "rat"
	rat.max_hp = 4
	rat.atk = 2
	rat.xp_reward = 3
	f.monster_spawns = [{"def": rat, "weight": 1}]
	var potion = ItemDef.new()
	potion.id = "potion_minor"
	f.item_spawns = [{"def": potion, "weight": 1}]
	return f

func test_generator_elites_have_boosted_stats() -> void:
	var found := false
	for seed_value in range(1, 40):
		var gen = DungeonGenerator.new(seed_value)
		var m = gen.generate(_floor_def(), 1)
		for mon in m.monsters:
			if mon.is_elite:
				found = true
				# 基础 rat: hp4/atk2/xp3 -> 精英 ceil(x1.6): hp>=7/atk>=4/xp6
				assert_true(mon.max_hp >= 7, "精英 hp 强化")
				assert_true(mon.atk >= 4, "精英 atk 强化")
				assert_eq(mon.xp_reward, 6, "精英经验 x2")
				break
		if found:
			break
	assert_true(found, "40 个种子中应至少出现一只精英")

func test_elite_kill_drops_loot() -> void:
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
	d.id = "rat"
	d.max_hp = 1
	var elite = Actor.from_monster_def(d, Vector2i(4, 3))
	elite.is_elite = true
	m.add_actor(elite)

	var s = TurnScheduler.new(PlayerDef.new(), [_floor_def()], 42)
	s.model = m
	s.player = m.player
	var events = s.player_action(GameEvents.ACTION_MOVE, Vector2i(1, 0))
	var dropped: Array = events.filter(func(e): return e.type == GameEvents.ITEM_DROPPED)
	assert_eq(dropped.size(), 1)
	assert_eq(events[0].data.attacker_id, "player")
	assert_false(m.item_at(Vector2i(4, 3)).is_empty(), "掉落物在地上")

func test_normal_kill_drops_nothing() -> void:
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
	d.id = "rat"
	d.max_hp = 1
	m.add_actor(Actor.from_monster_def(d, Vector2i(4, 3)))

	var s = TurnScheduler.new(PlayerDef.new(), [_floor_def()], 42)
	s.model = m
	s.player = m.player
	var events = s.player_action(GameEvents.ACTION_MOVE, Vector2i(1, 0))
	var dropped: Array = events.filter(func(e): return e.type == GameEvents.ITEM_DROPPED)
	assert_eq(dropped.size(), 0)
	assert_true(m.item_at(Vector2i(4, 3)).is_empty())
