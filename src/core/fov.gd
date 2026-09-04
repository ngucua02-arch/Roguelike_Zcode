class_name FOV
extends RefCounted
## 简易视野：以 origin 为中心向半径内所有格做 Bresenham 射线。

static func compute(model: Object, origin: Vector2i, radius: int) -> Dictionary:
	var result := {}
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var target: Vector2i = origin + Vector2i(dx, dy)
			if _line_clear(model, origin, target):
				result[target] = true
	return result

## 直线路径（不含起点；含终点格本身）是否通畅：中途遇墙=false；终点是墙=true（看见墙面）。
static func _line_clear(model: Object, from: Vector2i, to: Vector2i) -> bool:
	if not model.is_in_bounds(to):
		return false
	var cur := from
	var dx: int = absi(to.x - from.x)
	var dy: int = absi(to.y - from.y)
	var sx: int = signi(to.x - from.x)
	var sy: int = signi(to.y - from.y)
	var err := dx - dy
	while cur != to:
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			cur.x += sx
		if e2 < dx:
			err += dx
			cur.y += sy
		if cur == to:
			break
		if not model.is_in_bounds(cur) or model.tile_at(cur) == DungeonModel.Tile.WALL:
			return false
	return true
