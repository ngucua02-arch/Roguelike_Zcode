class_name TurnScheduler
extends RefCounted
## 一局游戏的规则层门面：玩家行动 -> 怪物回合 -> 事件流。
## 楼层递进也在这里完成（descend 时生成新 model）。不持有任何 Node 引用。

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
	model.player = new_player
	player = new_player
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
		_GameEvents.ACTION_DESCEND:
			return _try_descend()
		_:
			return []
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
		var attack_events: Array = _Combat.attack(player, blocker)
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
		inventory.add(def)
		model.remove_item(target)
		events.append({"type": _GameEvents.PICKED_UP, "pos": target,
			"data": {"item_id": ground.item_id, "item_name": def.display_name}})
	return events

func _try_descend() -> Array:
	if player.pos != model.stairs_pos:
		return []
	if floor_index >= floor_defs.size() - 1:
		is_won = true
		return [{"type": _GameEvents.GAME_WON, "pos": player.pos,
			"data": {"floor_number": model.floor_number}}]
	var events: Array = [{"type": _GameEvents.DESCENDED, "pos": player.pos, "data": {}}]
	events.append_array(_enter_floor(floor_index + 1))
	_update_fov()
	return events

func _monsters_turn() -> Array:
	var events: Array = []
	for mon in model.monsters.duplicate():
		if is_game_over or player == null:
			break
		if mon.hp <= 0:
			continue
		if absi(mon.pos.x - player.pos.x) + absi(mon.pos.y - player.pos.y) == 1:
			events.append_array(_Combat.attack(mon, player))
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

## 玩家击杀结算：移除尸体、发经验、处理升级。怪物攻击致死不经过这里。
func _after_kill(events: Array, victim: Object) -> void:
	if victim.hp > 0:
		return
	model.remove_actor(victim)
	if victim.is_player:
		return
	var xp: int = victim.xp_reward
	if xp > 0:
		events.append({"type": _GameEvents.XP_GAINED, "pos": player.pos,
			"data": {"amount": xp}})
	events.append_array(player.gain_xp(xp))

func _check_player_death(events: Array) -> void:
	if player.hp <= 0:
		is_game_over = true
		events.append({"type": _GameEvents.GAME_OVER, "pos": player.pos,
			"data": {"floor_number": model.floor_number}})

func _update_fov() -> void:
	model.remember_fov(_FOV.compute(model, player.pos, player.sight_radius))
