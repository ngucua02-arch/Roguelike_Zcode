class_name GameConfig
extends RefCounted
## demo 内置数值：玩家 + 3 层地牢配置（板块 4 落地后由 .tres 数据表替换）。

static func player_def() -> Object:
	return load("res://src/core/player_def.gd").new()

static func floor_defs() -> Array:
	var rat = _monster("rat", "窟鼠", "r", 4, 2, 0, 5, 3, "chase")
	var bat = _monster("bat", "洞蝠", "b", 3, 3, 0, 7, 4, "wander")
	var skeleton = _monster("skeleton", "骷髅卫兵", "s", 8, 4, 1, 6, 7, "chase")
	var potion = _item("potion_minor", "小治疗药水", "!", "potion", 6)
	var sword = _item("sword_rusty", "锈剑", "/", "weapon", 1)
	var mail = _item("leather_mail", "皮甲", "[", "armor", 1)

	var defs: Array = []
	var sizes := [Vector2i(36, 22), Vector2i(40, 24), Vector2i(44, 26)]
	for i in 3:
		var f = load("res://src/core/floor_def.gd").new()
		f.width = sizes[i].x
		f.height = sizes[i].y
		f.room_count_min = 6
		f.room_count_max = 9
		f.monster_count_min = 3 + i
		f.monster_count_max = 6 + i * 2
		f.item_count_min = 2
		f.item_count_max = 3 + i
		if i == 0:
			f.monster_spawns = [{"def": rat, "weight": 5}, {"def": bat, "weight": 2}]
		elif i == 1:
			f.monster_spawns = [{"def": rat, "weight": 3}, {"def": bat, "weight": 4}, {"def": skeleton, "weight": 2}]
		else:
			f.monster_spawns = [{"def": bat, "weight": 3}, {"def": skeleton, "weight": 5}]
		f.item_spawns = [{"def": potion, "weight": 5}, {"def": sword, "weight": 2}, {"def": mail, "weight": 2}]
		defs.append(f)
	return defs

static func _monster(id: String, display_name: String, glyph: String, max_hp: int, atk: int, defense: int, sight: int, xp: int, ai: String) -> Object:
	var d = load("res://src/core/monster_def.gd").new()
	d.id = id
	d.display_name = display_name
	d.glyph = glyph
	d.max_hp = max_hp
	d.atk = atk
	d.defense = defense
	d.sight_radius = sight
	d.xp_reward = xp
	d.ai_type = ai
	return d

static func _item(id: String, display_name: String, glyph: String, kind: String, power: int) -> Object:
	var d = load("res://src/core/item_def.gd").new()
	d.id = id
	d.display_name = display_name
	d.glyph = glyph
	d.kind = kind
	d.power = power
	return d
