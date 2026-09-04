class_name ViewConstants
extends RefCounted
## 表现层视图常量与坐标换算。

const TILE_SIZE := 16

static func cell_to_world(pos: Vector2i) -> Vector2:
	return Vector2(pos) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) / 2.0

static func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i((p / TILE_SIZE).floor())
