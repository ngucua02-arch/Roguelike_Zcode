extends GutTest
## FOV：半径限制 + 墙挡视线 + 墙面本身可见。

const FOV = preload("res://src/core/fov.gd")
const DungeonModel = preload("res://src/core/dungeon_model.gd")

func _room(w: int, h: int) -> Object:
	var m = DungeonModel.new(w, h)
	for y in h:
		for x in w:
			m.set_tile(Vector2i(x, y), DungeonModel.Tile.FLOOR)
	return m

func test_radius_limits_visibility() -> void:
	var m = _room(11, 11)
	var vis = FOV.compute(m, Vector2i(5, 5), 2)
	assert_true(vis.has(Vector2i(7, 5)))    # 切比雪夫距离 2
	assert_false(vis.has(Vector2i(8, 5)))   # 距离 3，超半径
	assert_true(vis.has(Vector2i(6, 6)))

func test_wall_blocks_line_of_sight() -> void:
	var m = _room(5, 5)
	m.set_tile(Vector2i(2, 1), DungeonModel.Tile.WALL)  # 玩家正北方向隔一堵墙
	var vis = FOV.compute(m, Vector2i(2, 3), 4)
	assert_true(vis.has(Vector2i(2, 1)), "墙面本身可见")
	assert_false(vis.has(Vector2i(2, 0)), "墙后格子不可见")

func test_origin_always_visible() -> void:
	var m = _room(3, 3)
	var vis = FOV.compute(m, Vector2i(1, 1), 1)
	assert_true(vis.has(Vector2i(1, 1)))

func test_diagonal_around_corner_blocked() -> void:
	# L 形墙角：对角线穿角不可见
	var m = _room(5, 5)
	m.set_tile(Vector2i(1, 1), DungeonModel.Tile.WALL)
	m.set_tile(Vector2i(1, 2), DungeonModel.Tile.WALL)
	m.set_tile(Vector2i(2, 1), DungeonModel.Tile.WALL)
	var vis = FOV.compute(m, Vector2i(0, 0), 4)
	assert_false(vis.has(Vector2i(2, 2)), "墙角对角不可见")
