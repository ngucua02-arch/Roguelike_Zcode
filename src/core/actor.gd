class_name Actor
extends RefCounted
## 战斗实体（玩家与怪物共用）的规则层数据对象。

var id: String = ""
var display_name: String = ""
var pos: Vector2i = Vector2i.ZERO
var hp: int = 1
var max_hp: int = 1
var atk: int = 1
var defense: int = 0
var sight_radius: int = 6
var xp_reward: int = 0        # 被击杀时奖励给击杀者的经验（怪物用）
var level: int = 1
var xp: int = 0
var is_player: bool = false
var gold: int = 0              # 玩家金币（商人/怪物不用）
var ai_type: String = "chase" # "chase" | "wander" | "shopkeeper"
var glyph: String = "?"       # 渲染层占位标识（色块阶段用）
var sprite_coords: Vector2i = Vector2i(-1, -1)  # 图集坐标（渲染层取精灵用）
var is_elite: bool = false     # 精英怪：属性强化、必掉战利品

# 升级曲线参数（玩家从 PlayerDef 拷入；怪物不升级则无副作用）
var xp_base: int = 10
var xp_growth: int = 5
var hp_per_level: int = 5
var atk_per_level: int = 1
var defense_per_level: int = 1

static func from_player_def(def: Object) -> Object:
	var a := Actor.new()
	a.id = "player"
	a.display_name = def.display_name
	a.max_hp = def.max_hp
	a.hp = def.max_hp
	a.atk = def.atk
	a.defense = def.defense
	a.sight_radius = def.sight_radius
	a.is_player = true
	a.xp_base = def.xp_base
	a.xp_growth = def.xp_growth
	a.hp_per_level = def.hp_per_level
	a.atk_per_level = def.atk_per_level
	a.defense_per_level = def.defense_per_level
	a.sprite_coords = def.sprite_coords
	a.glyph = "@"
	return a

static func from_monster_def(def: Object, pos: Vector2i) -> Object:
	var a := Actor.new()
	a.id = def.id
	a.display_name = def.display_name
	a.max_hp = def.max_hp
	a.hp = def.max_hp
	a.atk = def.atk
	a.defense = def.defense
	a.sight_radius = def.sight_radius
	a.xp_reward = def.xp_reward
	a.ai_type = def.ai_type
	a.sprite_coords = def.sprite_coords
	a.pos = pos
	a.glyph = def.glyph
	return a

func xp_to_next() -> int:
	return xp_base + (level - 1) * xp_growth

func gain_xp(amount: int) -> Array:
	var events: Array = []
	if amount <= 0:
		return events
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		max_hp += hp_per_level
		hp = max_hp  # 升级回满
		atk += atk_per_level
		defense += defense_per_level
		events.append({"type": "leveled_up", "pos": pos, "data": {"level": level}})
	return events
