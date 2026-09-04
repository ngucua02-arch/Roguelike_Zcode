extends GutTest
## Actor 经验升级 + Def 静态工厂 + FloorDef 加权抽取。

const Actor = preload("res://src/core/actor.gd")
const PlayerDef = preload("res://src/core/player_def.gd")
const MonsterDef = preload("res://src/core/monster_def.gd")
const ItemDef = preload("res://src/core/item_def.gd")
const FloorDef = preload("res://src/core/floor_def.gd")

func _player_def() -> Object:
	var d = PlayerDef.new()
	d.max_hp = 20
	d.atk = 3
	d.defense = 1
	d.sight_radius = 6
	d.xp_base = 10
	d.xp_growth = 5
	d.hp_per_level = 5
	d.atk_per_level = 1
	d.defense_per_level = 1
	return d

func test_from_player_def_copies_fields() -> void:
	var a = Actor.from_player_def(_player_def())
	assert_true(a.is_player)
	assert_eq(a.max_hp, 20)
	assert_eq(a.hp, 20)
	assert_eq(a.atk, 3)
	assert_eq(a.defense, 1)
	assert_eq(a.xp_to_next(), 10)

func test_gain_xp_levels_up_and_heals_full() -> void:
	var a = Actor.from_player_def(_player_def())
	a.hp = 5  # 先扣血
	var events = a.gain_xp(10)
	assert_eq(events.size(), 1)
	assert_eq(events[0].type, "leveled_up")
	assert_eq(a.level, 2)
	assert_eq(a.max_hp, 25)
	assert_eq(a.hp, 25)  # 升级回满
	assert_eq(a.atk, 4)
	assert_eq(a.defense, 2)
	assert_eq(a.xp, 0)
	assert_eq(a.xp_to_next(), 15)  # 下一级需求按 growth 增长

func test_gain_xp_multi_level_and_carry() -> void:
	var a = Actor.from_player_def(_player_def())
	var events = a.gain_xp(25)  # 10 升 1 级余 15，15 正好升 2 级
	assert_eq(events.size(), 2)
	assert_eq(a.level, 3)
	assert_eq(a.xp, 0)

func test_monster_factory() -> void:
	var d = MonsterDef.new()
	d.id = "rat"
	d.display_name = "窟鼠"
	d.max_hp = 5
	d.atk = 2
	d.defense = 0
	d.sight_radius = 5
	d.xp_reward = 3
	var a = Actor.from_monster_def(d, Vector2i(2, 3))
	assert_false(a.is_player)
	assert_eq(a.pos, Vector2i(2, 3))
	assert_eq(a.hp, 5)
	assert_eq(a.xp_reward, 3)

func test_floor_def_weighted_pick_respects_weights() -> void:
	var f = FloorDef.new()
	var weak = MonsterDef.new()
	weak.id = "rat"
	var strong = MonsterDef.new()
	strong.id = "ogre"
	f.monster_spawns = [{"def": weak, "weight": 0}, {"def": strong, "weight": 1}]
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	for i in 10:
		assert_eq(f.pick_monster(rng).id, "ogre")  # 权重 0 永不选中

func test_floor_def_empty_table_returns_null() -> void:
	var f = FloorDef.new()
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	assert_null(f.pick_monster(rng))
	assert_null(f.pick_item(rng))
