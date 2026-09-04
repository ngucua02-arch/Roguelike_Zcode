extends GutTest
## 集成冒烟：规则层组合跑通"开局 -> 随机移动 -> 下楼到通关/死亡"。
## 直接实例化 TurnManager 脚本（不依赖 autoload 注册）。

const TurnManagerScript = preload("res://src/autoload/turn_manager.gd")
const PlayerDef = preload("res://src/core/player_def.gd")
const MonsterDef = preload("res://src/core/monster_def.gd")
const ItemDef = preload("res://src/core/item_def.gd")
const FloorDef = preload("res://src/core/floor_def.gd")
const GameEvents = preload("res://src/core/events.gd")

func _defs() -> Array:
	var floors: Array = []
	var rat = MonsterDef.new()
	rat.id = "rat"
	rat.max_hp = 2
	var potion = ItemDef.new()
	potion.id = "potion_minor"
	potion.kind = "potion"
	potion.power = 5
	for i in 3:
		var f = FloorDef.new()
		f.width = 30
		f.height = 20
		f.room_count_min = 4
		f.room_count_max = 5
		f.monster_count_min = 1
		f.monster_count_max = 2
		f.item_count_min = 1
		f.item_count_max = 2
		f.monster_spawns = [{"def": rat, "weight": 1}]
		f.item_spawns = [{"def": potion, "weight": 1}]
		floors.append(f)
	return floors

func test_full_game_loop_smoke() -> void:
	var tm = TurnManagerScript.new()
	var start_events = tm.start_new_game(PlayerDef.new(), _defs(), 2026)
	assert_eq(start_events[0].type, GameEvents.FLOOR_CHANGED)
	var s = tm.scheduler
	var total_events := 0
	# 随机走 60 回合（固定种子），规则层不允许崩溃，事件结构完整
	var rng = RandomNumberGenerator.new()
	rng.seed = 99
	var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for i in 60:
		if s.is_game_over or s.is_won:
			break
		var events = tm.player_action(GameEvents.ACTION_MOVE, dirs[rng.randi_range(0, 3)])
		total_events += events.size()
		for e in events:
			assert_true(e.has("type") and e.has("pos") and e.has("data"), "事件结构完整")
	# 楼梯已被生成器保证可达；用瞬移直通车验证 3 层递进到终局
	var guard := 0
	while not s.is_game_over and not s.is_won and guard < 50:
		guard += 1
		s.player.pos = s.model.stairs_pos
		tm.player_action(GameEvents.ACTION_DESCEND, Vector2i.ZERO)
	assert_true(s.is_game_over or s.is_won, "3 层内游戏应结束")
	assert_true(total_events > 0)
	tm.free()
