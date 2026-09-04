class_name MonsterDef
extends Resource
## 怪物数值定义（数据表）。

@export var id: String = ""
@export var display_name: String = ""
@export var glyph: String = "?"      # 渲染层占位标识
@export var max_hp: int = 5
@export var atk: int = 2
@export var defense: int = 0
@export var sight_radius: int = 5
@export var xp_reward: int = 3
@export_enum("chase", "wander") var ai_type: String = "chase"
