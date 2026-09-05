class_name TurnScheduler
extends RefCounted
## 一局游戏的规则层门面：玩家行动 -> 怪物回合 -> 事件流。
## 楼层递进、金币经济、商店、精英掉落与战绩统计都在这里完成。不持有任何 Node 引用。

const ELITE_CHANCE := 0.12      # 撒怪时精英化概率
const ELITE_MULT := 1.6         # 精英 hp/atk 倍率
const SHOP_STOCK_SIZE := 3      # 每层商店商品数

const _ActorScript = preload("res://src/core/actor.gd")
const _DungeonGenerator = preload("res://src/core/dungeon_generator.gd")
const _FOV = preload("res://src/core/fov.gd")
const _Combat = preload("res://src/core/combat.gd")
const _Inventory = preload("res://src/core/inventory.gd")
const _ItemDef = preload("res://src/core/item_def.gd")
const _GameEvents = preload("res://src/core/events.gd")

var model: Object = null
var player: Object = null
var inventory: Object = null
var rng: RandomNumberGenerator
var is_game_over := false
var is_won := false
var floor_index := 0
var floor_defs: Array = []
var shop_stock: Array = []      # [{def: ItemDef, price: int}]
var stats: Dictionary = {"kills": 0, "turns": 0, "gold_earned": 0,
	"items_picked": 0, "damage_dealt": 0, "damage_taken": 0}
var _player_def: Object

func _init(p_player_def: Object, p_floor_defs: Array, seed_value: int = -1) -> void:
	_player_def = p_player_def
	floor_defs = p_floor_defs
	rng = RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	inventory = _Inventory.new()

## 可测试点：生成一层的模型。测试子类可覆写注入手工布局。
func _build_model(floor_def: Object, floor_number: int) -> Object:
	var gen := _DungeonGenerator.new(rng.randi())
	return gen.generate(floor_def, floor_number)

func start() -> Array:
	return _enter_floor(0)

func _enter_floor(index: int) -> Array:
	floor_index = index
	model = _build_model(floor_defs[index], index + 1)
	var new_player = _ActorScript.from_player_def(_player_def)
	new_player.pos = model.player.pos  # 保留生成器的出生点，替换为带成长曲线的正式玩家
	new_player.gold = player.gold if player != null else 0  # 金币跨楼层保留
	model.player = new_player
	player = new_player
	_roll_shop_stock()
	return [{"type": _GameEvents.FLOOR_CHANGED, "pos": player.pos,
		"data": {"floor_number": model.floor_number}}]

func player_action(action: String, dir: Vector2i = Vector2i.ZERO) -> Array:
	if is_game_over or is_won:
		return []
	var events: Array = []
	match action:
		_GameEvents.ACTION_WAIT:
			events.append({"type": _GameEvents.WAITED, "pos": player.pos, "data": {}})
		_GameEvents.ACTION_MOVE:
			events = _try_move(dir)
			if events.is_empty():
				return []  # 撞墙不消耗回合，怪物不行动
			for e in events:
				if e.type == _GameEvents.SHOP_OPEN:
					return events  # 与商人交易不消耗回合
		_GameEvents.ACTION_DESCEND:
			return _try_descend()
		_GameEvents.ACTION_SHOP:
			return _open_shop()
		_:
			return []
	stats.turns += 1
	events.append_array(_monsters_turn())
	_check_player_death(events)
	if not is_game_over:
		_update_fov()
	return events

func _try_move(dir: Vector2i) -> Array:
	var target: Vector2i = player.pos + dir
	if not model.is_walkable(target):
		return []
	var blocker: Object = model.actor_at(target)
	if blocker != null:
		if blocker.ai_type == "shopkeeper":
			return _open_shop()  # 走向商人 = 交易，不攻击
		var attack_events: Array = _Combat.attack(player, blocker)
		stats.damage_dealt += attack_events[0].data.damage
		_after_kill(attack_events, blocker)
		return attack_events
	var from: Vector2i = player.pos
	player.pos = target
	var events: Array = [{"type": _GameEvents.MOVED, "pos": target,
		"data": {"actor_id": player.id, "from": from}}]
	var ground: Dictionary = model.item_at(target)
	if not ground.is_empty():
		var def: Object = ground.get("def", null)
		if def == null:
			def = _ItemDef.new()
			def.id = ground.item_id
		if def.kind == "gold":
			player.gold += def.power
			stats.gold_earned += def.power
			events.append({"type": _GameEvents.PICKED_UP, "pos": target,
				"data": {"item_id": def.id, "item_name": "%d 金币" % def.power}})
		else:
			inventory.add(def)
			stats.items_picked += 1
			events.append({"type": _GameEvents.PICKED_UP, "pos": target,
				"data": {"item_id": ground.item_id, "item_name": def.display_name}})
		model.remove_item(target)
	return events

func _try_descend() -> Array:
	if player.pos != model.stairs_pos:
		return []
	if floor_index >= floor_defs.size() - 1:
		is_won = true
		return [{"type": _GameEvents.GAME_WON, "pos": player.pos,
			"data": {"floor_number": model.floor_number, "stats": stats.duplicate()}}]
	var events: Array = [{"type": _GameEvents.DESCENDED, "pos": player.pos, "data": {}}]
	events.append_array(_enter_floor(floor_index + 1))
	_update_fov()
	return events

## 打开商店（不消耗回合）。
func _open_shop() -> Array:
	var stock: Array = []
	for entry in shop_stock:
		stock.append({"item_id": entry.def.id, "item_name": entry.def.display_name,
			"price": entry.price, "icon_coords": entry.def.sprite_coords})
	return [{"type": _GameEvents.SHOP_OPEN, "pos": player.pos,
		"data": {"stock": stock, "gold": player.gold}}]

## 购买商品（不消耗回合）。
func buy(index: int) -> Array:
	if index < 0 or index >= shop_stock.size():
		return []
	var entry: Dictionary = shop_stock[index]
	if player.gold < entry.price:
		return [{"type": _GameEvents.SHOP_FAILED, "pos": player.pos,
			"data": {"reason": "poor", "item_id": entry.def.id}}]
	player.gold -= entry.price
	inventory.add(entry.def)
	shop_stock.remove_at(index)
	return [{"type": _GameEvents.BOUGHT, "pos": player.pos,
		"data": {"item_id": entry.def.id, "item_name": entry.def.display_name,
			"price": entry.price, "gold": player.gold}}]

## 每层商店库存：从道具表（排除金币）抽 3 件不重复。
func _roll_shop_stock() -> void:
	shop_stock.clear()
	var pool: Array = []
	for entry in floor_defs[floor_index].item_spawns:
		if entry.def.kind != "gold" and int(entry.def.price) > 0:
			pool.append(entry.def)
	var picks: Array = []
	while picks.size() < SHOP_STOCK_SIZE and not pool.is_empty():
		var i := rng.randi_range(0, pool.size() - 1)
		picks.append(pool[i])
		pool.remove_at(i)
	for def in picks:
		shop_stock.append({"def": def, "price": def.price})

func _monsters_turn() -> Array:
	var events: Array = []
	for mon in model.monsters.duplicate():
		if is_game_over or player == null:
			break
		if mon.hp <= 0 or mon.ai_type == "shopkeeper":
			continue  # 商人不行动也不攻击
		if absi(mon.pos.x - player.pos.x) + absi(mon.pos.y - player.pos.y) == 1:
			var attack_events: Array = _Combat.attack(mon, player)
			stats.damage_taken += attack_events[0].data.damage
			events.append_array(attack_events)
			continue
		var can_see: bool = _FOV.compute(model, mon.pos, mon.sight_radius).has(player.pos)
		if can_see:
			_monster_step_toward(mon)
		elif rng.randf() < 0.25:
			var dirs: Array = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
			_try_monster_move(mon, mon.pos + dirs[rng.randi_range(0, 3)])
	return events

## 贪心逼近：主轴优先，被堵试副轴，都堵则原地不动。
func _monster_step_toward(mon: Object) -> void:
	var dx: int = signi(player.pos.x - mon.pos.x)
	var dy: int = signi(player.pos.y - mon.pos.y)
	var candidates: Array = []
	if absi(player.pos.x - mon.pos.x) >= absi(player.pos.y - mon.pos.y):
		candidates = [Vector2i(dx, 0), Vector2i(0, dy)]
	else:
		candidates = [Vector2i(0, dy), Vector2i(dx, 0)]
	for c in candidates:
		if c == Vector2i.ZERO:
			continue
		if _try_monster_move(mon, mon.pos + c):
			return

func _try_monster_move(mon: Object, target: Vector2i) -> bool:
	if not model.is_walkable(target):
		return false
	if model.is_occupied(target):
		return false
	mon.pos = target
	return true

## 玩家击杀结算：移除尸体、发经验、处理升级、精英掉落。
func _after_kill(events: Array, victim: Object) -> void:
	if victim.hp > 0:
		return
	model.remove_actor(victim)
	if victim.is_player:
		return
	stats.kills += 1
	var xp: int = victim.xp_reward
	if xp > 0:
		events.append({"type": _GameEvents.XP_GAINED, "pos": player.pos,
			"data": {"amount": xp}})
	events.append_array(player.gain_xp(xp))
	if victim.is_elite:
		var def = floor_defs[floor_index].pick_item(rng)
		if def != null:
			model.add_item(def.id, victim.pos, def)
			events.append({"type": _GameEvents.ITEM_DROPPED, "pos": victim.pos,
				"data": {"item_id": def.id, "item_name": def.display_name}})

func _check_player_death(events: Array) -> void:
	if player.hp <= 0:
		is_game_over = true
		events.append({"type": _GameEvents.GAME_OVER, "pos": player.pos,
			"data": {"floor_number": model.floor_number, "stats": stats.duplicate()}})

func _update_fov() -> void:
	model.remember_fov(_FOV.compute(model, player.pos, player.sight_radius))
