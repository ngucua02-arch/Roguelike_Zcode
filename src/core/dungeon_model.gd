class_name DungeonModel
extends RefCounted
## 规则层地牢模型：网格 + 实体容器。不持有任何 Node 引用。

enum Tile { WALL, FLOOR, DOOR, STAIRS }

var width: int
var height: int
var tiles: PackedInt32Array = PackedInt32Array()
var player: Object = null          # Actor（用 Object 类型避免 core 内循环依赖）
var monsters: Array = []           # Array[Actor]
var items: Array = []              # Array[Dictionary] {item_id, pos, def 可空}
var stairs_pos: Vector2i = Vector2i(-1, -1)
var floor_number: int = 1
var visible: Dictionary = {}       # Vector2i -> true（本回合可见集）
var explored: Dictionary = {}      # Vector2i -> true（累计已探索）

func _init(p_width: int = 0, p_height: int = 0) -> void:
	width = p_width
	height = p_height
	tiles.resize(width * height)
	tiles.fill(Tile.WALL)

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < width and pos.y < height

func _index(pos: Vector2i) -> int:
	return pos.y * width + pos.x

func tile_at(pos: Vector2i) -> int:
	if not is_in_bounds(pos):
		return Tile.WALL
	return tiles[_index(pos)]

func set_tile(pos: Vector2i, t: int) -> void:
	if is_in_bounds(pos):
		tiles[_index(pos)] = t

func is_walkable(pos: Vector2i) -> bool:
	return is_in_bounds(pos) and tiles[_index(pos)] != Tile.WALL

func is_occupied(pos: Vector2i) -> bool:
	return actor_at(pos) != null

func actor_at(pos: Vector2i) -> Object:
	for a in monsters:
		if a.pos == pos:
			return a
	if player != null and player.pos == pos:
		return player
	return null

func add_actor(a: Object) -> void:
	if a.is_player:
		player = a
	else:
		monsters.append(a)

func remove_actor(a: Object) -> void:
	monsters.erase(a)
	if player == a:
		player = null

func item_at(pos: Vector2i) -> Dictionary:
	for it in items:
		if it.pos == pos:
			return it
	return {}

func add_item(item_id: String, pos: Vector2i, def: Object = null) -> void:
	items.append({"item_id": item_id, "pos": pos, "def": def})

func remove_item(pos: Vector2i) -> void:
	var it := item_at(pos)
	if not it.is_empty():
		items.erase(it)

func remember_fov(visible_set: Dictionary) -> void:
	visible = visible_set
	for key in visible_set.keys():
		explored[key] = true
