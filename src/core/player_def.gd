class_name PlayerDef
extends Resource
## 玩家初始数值与升级曲线（数据表，编辑器可调）。

@export var display_name: String = "冒险者"
@export var max_hp: int = 20
@export var atk: int = 3
@export var defense: int = 1
@export var sight_radius: int = 6
@export var xp_base: int = 10        # 升到 2 级所需经验
@export var xp_growth: int = 5       # 每级递增量
@export var hp_per_level: int = 5
@export var atk_per_level: int = 1
@export var defense_per_level: int = 1
