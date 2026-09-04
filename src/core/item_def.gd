class_name ItemDef
extends Resource
## 物品定义（数据表）。使用即生效：药水回血 / 武器加攻 / 护甲加防。

@export var id: String = ""
@export var display_name: String = ""
@export var glyph: String = "!"
@export_enum("potion", "weapon", "armor") var kind: String = "potion"
@export var power: int = 5           # 药水回血量 / 武器加攻 / 护甲加防
