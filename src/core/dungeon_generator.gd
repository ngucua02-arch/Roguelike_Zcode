class_name DungeonGenerator
extends RefCounted
## 随机房间 + 走廊地牢生成器。固定种子 -> 确定性布局。

var rng: RandomNumberGenerator
var rooms: Array = []   # Array[Rect2i]（最近一次 generate 的房间矩形，测试与调试用）

func _init(seed_value: int = -1) -> void:
	rng = RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

func generate(floor_def: Object, floor_number: int) -> Object:
	var model := DungeonModel.new(floor_def.width, floor_def.height)
	model.floor_number = floor_number
	rooms.clear()

	var room_count := rng.randi_range(floor_def.room_count_min, floor_def.room_count_max)
	var attempts := 0
	while rooms.size() < room_count and attempts < 200:
		attempts += 1
		var w := rng.randi_range(4, 8)
		var h := rng.randi_range(3, 6)
		var x := rng.randi_range(1, floor_def.width - w - 2)
		var y := rng.randi_range(1, floor_def.height - h - 2)
		var rect := Rect2i(x, y, w, h)
		var ok := true
		for other in rooms:
			if rect.grow(1).intersects(other):  # 至少 1 格墙间隔
				ok = false
				break
		if ok:
			rooms.append(rect)
			_carve_room(model, rect)

	# 按房间顺序 L 形走廊两两相连 -> 天然全连通
	for i in range(1, rooms.size()):
		_carve_corridor(model, _center(rooms[i - 1]), _center(rooms[i]))

	var first: Rect2i = rooms[0]
	var last: Rect2i = rooms[rooms.size() - 1]
	var player_pos := _center(first)
	model.set_tile(player_pos, DungeonModel.Tile.FLOOR)
	model.stairs_pos = _center(last)
	model.set_tile(model.stairs_pos, DungeonModel.Tile.STAIRS)

	# 生成器建一个默认玩家占出生点；TurnScheduler._enter_floor 会替换为正式玩家
	var player = load("res://src/core/actor.gd").from_player_def(load("res://src/core/player_def.gd").new())
	player.pos = player_pos
	model.add_actor(player)

	_spawn_entities(model, floor_def)
	return model

func _carve_room(model: Object, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			model.set_tile(Vector2i(x, y), DungeonModel.Tile.FLOOR)

func _carve_corridor(model: Object, from: Vector2i, to: Vector2i) -> void:
	var cur := from
	# 先横后纵的 L 形
	while cur.x != to.x:
		model.set_tile(cur, DungeonModel.Tile.FLOOR)
		cur.x += signi(to.x - cur.x)
	while cur.y != to.y:
		model.set_tile(cur, DungeonModel.Tile.FLOOR)
		cur.y += signi(to.y - cur.y)
	model.set_tile(to, DungeonModel.Tile.FLOOR)

func _center(rect: Rect2i) -> Vector2i:
	return rect.position + rect.size / 2

func _random_floor_in(rect: Rect2i) -> Vector2i:
	return Vector2i(
		rng.randi_range(rect.position.x, rect.position.x + rect.size.x - 1),
		rng.randi_range(rect.position.y, rect.position.y + rect.size.y - 1))

func _spawn_entities(model: Object, floor_def: Object) -> void:
	var actor = load("res://src/core/actor.gd")
	var monster_count := rng.randi_range(floor_def.monster_count_min, floor_def.monster_count_max)
	for i in monster_count:
		var def = floor_def.pick_monster(rng)
		if def == null:
			break
		var pos := _find_free_spot(model)
		if pos == Vector2i(-1, -1):
			break
		model.add_actor(actor.from_monster_def(def, pos))

	var item_count := rng.randi_range(floor_def.item_count_min, floor_def.item_count_max)
	for i in item_count:
		var def = floor_def.pick_item(rng)
		if def == null:
			break
		var pos := _find_free_spot(model)
		if pos == Vector2i(-1, -1):
			break
		model.add_item(def.id, pos, def)

func _find_free_spot(model: Object) -> Vector2i:
	# 随机房间内找空位：非玩家位、非楼梯、无实体、无物品
	for attempt in 100:
		var pos := _random_floor_in(rooms[rng.randi_range(0, rooms.size() - 1)])
		if pos == model.player.pos or pos == model.stairs_pos:
			continue
		if model.is_occupied(pos) or not model.item_at(pos).is_empty():
			continue
		if model.tile_at(pos) != DungeonModel.Tile.FLOOR:
			continue
		return pos
	return Vector2i(-1, -1)
