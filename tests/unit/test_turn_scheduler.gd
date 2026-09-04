extends GutTest
## 回合调度：行动结算、怪物 AI、楼层递进、游戏结束。

const TurnScheduler = preload("res://src/core/turn_scheduler.gd")
const DungeonModel = preload("res://src/core/dungeon_model.gd")
const Actor = preload("res://src/core/actor.gd")
const PlayerDef = preload("res://src/core/player_def.gd")
const MonsterDef = preload("res://src/core/monster_def.gd")
const ItemDef = preload("res://src/core/item_def.gd")
const FloorDef = preload("res://src/core/floor_def.gd")
const GameEvents = preload("res://src/core/events.gd")

## 手工布局的可测调度器：绕过生成器，用注入的 model。
class TestScheduler extends TurnScheduler:
	var injected_model: Object = null
	func _build_model(_floor_def: Object, _floor_number: int) -> Object:
		return injected_model

func _player_def() -> Object:
	var d = PlayerDef.new()
	d.max_hp = 20
	d.atk = 5
	d.defense = 1
	d.sight_radius = 6
	d.xp_base = 10
	d.xp_growth = 5
	d.hp_per_level = 5
	d.atk_per_level = 1
	d.defense_per_level = 1
	return d

func _rat(pos: Vector2i, hp := 3, atk := 2) -> Object:
	var d = MonsterDef.new()
	d.id = "rat"
	d.display_name = "窟鼠"
	d.max_hp = hp
	d.atk = atk
	d.defense = 0
	d.sight_radius = 6
	d.xp_reward = 3
	return Actor.from_monster_def(d, pos)

func _flat_model(w := 7, h := 7) -> Object:
	var m = DungeonModel.new(w, h)
	for y in h:
		for x in w:
			m.set_tile(Vector2i(x, y), DungeonModel.Tile.FLOOR)
	return m

func _place_player_and_stairs(m: Object) -> void:
	var player = Actor.from_player_def(_player_def())
	player.pos = Vector2i(3, 3)
	m.add_actor(player)
	m.stairs_pos = Vector2i(6, 6)
	m.set_tile(m.stairs_pos, DungeonModel.Tile.STAIRS)

func _scheduler_with(model: Object) -> Object:
	var s = TestScheduler.new(_player_def(), [FloorDef.new()], 42)
	s.injected_model = model
	s._enter_floor(0)
	return s

func test_move_emits_event_and_updates_fov() -> void:
	var m = _flat_model()
	_place_player_and_stairs(m)
	var s = _scheduler_with(m)
	var events = s.player_action(GameEvents.ACTION_MOVE, Vector2i(1, 0))
	assert_eq(events.size(), 1)
	assert_eq(events[0].type, GameEvents.MOVED)
	assert_eq(s.player.pos, Vector2i(4, 3))
	assert_true(m.visible.has(Vector2i(4, 3)))

func test_move_into_wall_consumes_no_turn() -> void:
	var m = _flat_model()
	_place_player_and_stairs(m)
	m.set_tile(Vector2i(4, 3), DungeonModel.Tile.WALL)
	var s = _scheduler_with(m)
	var events = s.player_action(GameEvents.ACTION_MOVE, Vector2i(1, 0))
	assert_eq(events, [])
	assert_eq(s.player.pos, Vector2i(3, 3))

func test_move_into_monster_attacks_instead() -> void:
	var m = _flat_model()
	_place_player_and_stairs(m)
	var rat = _rat(Vector2i(4, 3))
	m.add_actor(rat)
	var s = _scheduler_with(m)
	var events = s.player_action(GameEvents.ACTION_MOVE, Vector2i(1, 0))
	assert_eq(events[0].type, GameEvents.ATTACKED)
	assert_eq(s.player.pos, Vector2i(3, 3))  # 没有移动
	assert_eq(rat.hp, 0)  # 5 atk - 0 def = 5 >= 3 hp
	assert_eq(events[1].type, GameEvents.DIED)
	# 击杀得经验
	assert_eq(events[2].type, GameEvents.XP_GAINED)
	assert_eq(m.monsters.size(), 0)

func test_monster_chases_and_attacks_when_adjacent() -> void:
	var m = _flat_model()
	_place_player_and_stairs(m)
	var rat = _rat(Vector2i(5, 3))
	m.add_actor(rat)
	var s = _scheduler_with(m)
	# 玩家在 (3,3)，鼠在 (5,3)，距离 2。等待 -> 鼠逼近到 (4,3)
	s.player_action(GameEvents.ACTION_WAIT)
	assert_eq(rat.pos, Vector2i(4, 3))
	# 再等待 -> 鼠相邻 -> 攻击玩家
	var events = s.player_action(GameEvents.ACTION_WAIT)
	var attacked: Array = events.filter(func(e): return e.type == GameEvents.ATTACKED)
	assert_eq(attacked.size(), 1)
	assert_eq(attacked[0].data.attacker_id, "rat")

func test_dead_monster_does_not_act() -> void:
	var m = _flat_model()
	_place_player_and_stairs(m)
	var rat = _rat(Vector2i(4, 3), 1)  # 1 hp
	m.add_actor(rat)
	var s = _scheduler_with(m)
	# 玩家攻击杀死鼠；之后无任何鼠的事件
	var events = s.player_action(GameEvents.ACTION_MOVE, Vector2i(1, 0))
	for e in events:
		assert_ne(e.get("data", {}).get("attacker_id", ""), "rat")

func test_player_death_emits_game_over_and_blocks_input() -> void:
	var m = _flat_model()
	_place_player_and_stairs(m)
	var ogre = _rat(Vector2i(4, 3), 20, 10)
	ogre.id = "ogre"
	m.add_actor(ogre)
	var s = _scheduler_with(m)
	s.player.hp = 1  # 在 scheduler 建立后改血（_enter_floor 会替换玩家实例）
	var events = s.player_action(GameEvents.ACTION_WAIT)  # 鼠相邻攻击
	assert_eq(events.back().type, GameEvents.GAME_OVER)
	assert_true(s.is_game_over)
	var again = s.player_action(GameEvents.ACTION_WAIT)
	assert_eq(again, [])

func test_pickup_on_move() -> void:
	var m = _flat_model()
	_place_player_and_stairs(m)
	var potion = ItemDef.new()
	potion.id = "potion_minor"
	potion.kind = "potion"
	potion.power = 5
	m.add_item("potion_minor", Vector2i(4, 3), potion)
	var s = _scheduler_with(m)
	var events = s.player_action(GameEvents.ACTION_MOVE, Vector2i(1, 0))
	var picked: Array = events.filter(func(e): return e.type == GameEvents.PICKED_UP)
	assert_eq(picked.size(), 1)
	assert_eq(picked[0].data.item_id, "potion_minor")
	assert_true(m.item_at(Vector2i(4, 3)).is_empty())
	assert_eq(s.inventory.size(), 1)

func test_descend_generates_new_floor_and_wins_on_last() -> void:
	# 真生成器版：2 层配置
	var gen_defs: Array = []
	for i in 2:
		var f = FloorDef.new()
		f.width = 25
		f.height = 15
		f.room_count_min = 3
		f.room_count_max = 4
		f.monster_count_min = 0
		f.monster_count_max = 0
		f.item_count_min = 0
		f.item_count_max = 0
		gen_defs.append(f)
	var s = TurnScheduler.new(_player_def(), gen_defs, 7)
	var start_events = s.start()
	assert_eq(start_events[0].type, GameEvents.FLOOR_CHANGED)
	assert_eq(s.model.floor_number, 1)
	# 测试便利：直接瞬移到楼梯
	s.player.pos = s.model.stairs_pos
	var desc = s.player_action(GameEvents.ACTION_DESCEND, Vector2i.ZERO)
	var types := {}
	for e in desc:
		types[e.type] = true
	assert_true(types.has(GameEvents.DESCENDED))
	assert_true(types.has(GameEvents.FLOOR_CHANGED))
	assert_eq(s.model.floor_number, 2)
	# 第 2 层是末层 -> 下楼 = 通关
	s.player.pos = s.model.stairs_pos
	var won = s.player_action(GameEvents.ACTION_DESCEND, Vector2i.ZERO)
	assert_eq(won.back().type, GameEvents.GAME_WON)
	assert_true(s.is_won)

func test_descend_off_stairs_consumes_no_turn() -> void:
	var m = _flat_model()
	_place_player_and_stairs(m)
	var s = _scheduler_with(m)
	assert_eq(s.player_action(GameEvents.ACTION_DESCEND), [])
