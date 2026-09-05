extends GutTest
## 数值表完整性：.tres 装配 + 字段正确性 + 每层生成表可抽取。

const GameConfig = preload("res://src/autoload/game_config.gd")

func test_player_def_from_tres() -> void:
	var d = GameConfig.player_def()
	assert_not_null(d)
	assert_eq(d.display_name, "冒险者")
	assert_eq(d.max_hp, 20)
	assert_eq(d.atk, 3)
	assert_eq(d.defense, 1)
	assert_eq(d.xp_base, 10)

func test_floor_defs_three_floors() -> void:
	var defs: Array = GameConfig.floor_defs()
	assert_eq(defs.size(), 3)
	assert_eq(defs[0].width, 36)
	assert_eq(defs[1].width, 40)
	assert_eq(defs[2].width, 44)
	for f in defs:
		assert_true(f.monster_spawns.size() > 0, "怪物表非空")
		assert_true(f.item_spawns.size() > 0, "物品表非空")

func test_spawn_tables_have_positive_weights_and_pickable() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	for f in GameConfig.floor_defs():
		var total_m := 0
		for entry in f.monster_spawns:
			total_m += int(entry.weight)
			assert_not_null(entry.def, "怪物 def 引用有效")
		var total_i := 0
		for entry in f.item_spawns:
			total_i += int(entry.weight)
			assert_not_null(entry.def, "物品 def 引用有效")
		assert_true(total_m > 0 and total_i > 0, "权重和为正")
		assert_not_null(f.pick_monster(rng))
		assert_not_null(f.pick_item(rng))

func test_known_monster_values() -> void:
	var f = GameConfig.floor_defs()[0]
	var rat_found := false
	for entry in f.monster_spawns:
		if entry.def.id == "rat":
			rat_found = true
			assert_eq(entry.def.max_hp, 4)
			assert_eq(entry.def.atk, 2)
			assert_eq(entry.def.xp_reward, 3)
	assert_true(rat_found, "第 1 层含窟鼠")

func test_item_kinds_valid() -> void:
	var valid := ["potion", "weapon", "armor"]
	var f = GameConfig.floor_defs()[1]
	for entry in f.item_spawns:
		assert_true(valid.has(entry.def.kind), "物品类型合法: %s" % entry.def.kind)
		assert_true(entry.def.power > 0)

func test_all_defs_have_sprites() -> void:
	# 素材数据驱动：每个 def 必须带有效图集坐标（Kenney Tiny Dungeon 12x11）
	var p = GameConfig.player_def()
	assert_true(p.sprite_coords.x >= 0 and p.sprite_coords.y >= 0, "玩家精灵坐标有效")
	for f in GameConfig.floor_defs():
		for entry in f.monster_spawns:
			assert_true(entry.def.sprite_coords.x >= 0 and entry.def.sprite_coords.y >= 0,
				"怪物 %s 精灵坐标有效" % entry.def.id)
		for entry in f.item_spawns:
			assert_true(entry.def.sprite_coords.x >= 0 and entry.def.sprite_coords.y >= 0,
				"物品 %s 精灵坐标有效" % entry.def.id)

func test_content_volume_matches_spec() -> void:
	# spec §2：4-5 种怪物、5-6 种道具（当前承诺超额：怪 6 / 物 7）
	var monster_ids := {}
	var item_ids := {}
	for f in GameConfig.floor_defs():
		for entry in f.monster_spawns:
			monster_ids[entry.def.id] = true
		for entry in f.item_spawns:
			item_ids[entry.def.id] = true
	assert_true(monster_ids.size() >= 5, "怪物种类 >= 5（实际 %d）" % monster_ids.size())
	assert_true(item_ids.size() >= 6, "道具种类 >= 6（实际 %d）" % item_ids.size())

func test_floor_themes_differ() -> void:
	# 楼层主题色互不相同（每层氛围差异）
	var themes: Array = []
	for f in GameConfig.floor_defs():
		assert_false(themes.has(f.floor_theme), "楼层主题色重复")
		themes.append(f.floor_theme)
