class_name FloorDef
extends Resource
## 楼层数值定义：尺寸、房间数、怪物/物品生成表、主题色。

@export var width: int = 40
@export var height: int = 25
@export var room_count_min: int = 6
@export var room_count_max: int = 9
@export var monster_count_min: int = 4
@export var monster_count_max: int = 7
@export var item_count_min: int = 2
@export var item_count_max: int = 4
@export var monster_spawns: Array = []   # [{def: MonsterDef, weight: int}]
@export var item_spawns: Array = []      # [{def: ItemDef, weight: int}]
@export var floor_theme: Color = Color(0.5, 0.5, 0.5)

func _pick_weighted(spawns: Array, rng: RandomNumberGenerator) -> Object:
	var total := 0
	for entry in spawns:
		total += int(entry.weight)
	if total <= 0:
		return null
	var roll := rng.randi_range(1, total)
	for entry in spawns:
		roll -= int(entry.weight)
		if roll <= 0:
			return entry.def
	return spawns.back().def

func pick_monster(rng: RandomNumberGenerator) -> Object:
	return _pick_weighted(monster_spawns, rng)

func pick_item(rng: RandomNumberGenerator) -> Object:
	return _pick_weighted(item_spawns, rng)
