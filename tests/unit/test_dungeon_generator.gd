extends GutTest
## 生成器：固定种子做确定性测试。核心断言是"结构性质"而非具体形状。

const DungeonGenerator = preload("res://src/core/dungeon_generator.gd")
const DungeonModel = preload("res://src/core/dungeon_model.gd")
const PlayerDef = preload("res://src/core/player_def.gd")
const MonsterDef = preload("res://src/core/monster_def.gd")
const ItemDef = preload("res://src/core/item_def.gd")
const FloorDef = preload("res://src/core/floor_def.gd")

func _floor_def() -> Object:
	var f = FloorDef.new()
	f.width = 30
	f.height = 20
	f.room_count_min = 5
	f.room_count_max = 7
	f.monster_count_min = 3
	f.monster_count_max = 6
	f.item_count_min = 2
	f.item_count_max = 3
	var rat = MonsterDef.new()
	rat.id = "rat"
	var potion = ItemDef.new()
	potion.id = "potion_minor"
	f.monster_spawns = [{"def": rat, "weight": 1}]
	f.item_spawns = [{"def": potion, "weight": 1}]
	return f

func _generate(seed_value: int) -> Object:
	var gen = DungeonGenerator.new(seed_value)
	return gen.generate(_floor_def(), 1)

func _flood_reachable(m: Object) -> Dictionary:
	# 从玩家位置 BFS，只走 walkable
	var seen := {m.player.pos: true}
	var queue: Array = [m.player.pos]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var nxt: Vector2i = cur + dir
			if m.is_walkable(nxt) and not seen.has(nxt):
				seen[nxt] = true
				queue.append(nxt)
	return seen

func test_same_seed_same_layout() -> void:
	var a = _generate(1234)
	var b = _generate(1234)
	assert_eq(a.tiles, b.tiles)
	assert_eq(a.player.pos, b.player.pos)
	assert_eq(a.stairs_pos, b.stairs_pos)

func test_stairs_reachable_from_player() -> void:
	for s in [1, 2, 3]:
		var m = _generate(100 + s)
		assert_true(_flood_reachable(m).has(m.stairs_pos), "seed %d 楼梯可达" % s)

func test_all_floor_tiles_connected() -> void:
	var m = _generate(7)
	var reachable = _flood_reachable(m)
	for y in m.height:
		for x in m.width:
			var pos := Vector2i(x, y)
			if m.tile_at(pos) != DungeonModel.Tile.WALL:
				assert_true(reachable.has(pos), "地板格 %s 应连通" % str(pos))

func test_rooms_do_not_overlap() -> void:
	var gen = DungeonGenerator.new(99)
	gen.generate(_floor_def(), 1)
	var rooms: Array = gen.rooms
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			var a: Rect2i = rooms[i]
			var b: Rect2i = rooms[j]
			var expanded_a := a.grow(1)  # 允许墙间隔，膨胀 1 格后仍不得相交
			assert_false(expanded_a.intersects(b), "房间 %s 与 %s 重叠" % [str(a), str(b)])

func test_entity_counts_and_no_overlap() -> void:
	var m = _generate(5)
	assert_true(m.monsters.size() >= 3 and m.monsters.size() <= 6)
	assert_true(m.items.size() >= 2 and m.items.size() <= 3)
	var occupied := {m.player.pos: true, m.stairs_pos: true}
	for mon in m.monsters:
		assert_false(occupied.has(mon.pos), "怪物与已有实体重叠")
		assert_eq(m.tile_at(mon.pos), DungeonModel.Tile.FLOOR)
		occupied[mon.pos] = true
	for it in m.items:
		assert_false(occupied.has(it.pos), "物品与已有实体重叠")
		assert_eq(m.tile_at(it.pos), DungeonModel.Tile.FLOOR)
		occupied[it.pos] = true
	assert_eq(m.tile_at(m.stairs_pos), DungeonModel.Tile.STAIRS)
	assert_eq(m.tile_at(m.player.pos), DungeonModel.Tile.FLOOR)
