class_name Inventory
extends RefCounted
## 背包：道具使用即生效（药水回血 / 武器加攻 / 护甲加防），使用后移除。

var items: Array = []  # [{def: ItemDef, item_id: String}]

func add(def: Object) -> void:
	items.append({"def": def, "item_id": def.id})

func size() -> int:
	return items.size()

func use(index: int, player: Object) -> Array:
	if index < 0 or index >= items.size():
		return []
	var entry: Dictionary = items[index]
	var def: Object = entry.def
	var events: Array = []
	match def.kind:
		"potion":
			if player.hp >= player.max_hp:
				events.append({"type": GameEvents.USE_FAILED, "pos": player.pos,
					"data": {"item_id": def.id, "reason": "full_hp"}})
				return events
			var amount: int = mini(def.power, player.max_hp - player.hp)
			player.hp += amount
			items.remove_at(index)
			events.append({"type": "healed", "pos": player.pos,
				"data": {"item_id": def.id, "amount": amount, "hp": player.hp}})
		"weapon":
			player.atk += def.power
			items.remove_at(index)
			events.append({"type": "equipped", "pos": player.pos,
				"data": {"item_id": def.id, "stat": "atk", "gain": def.power}})
		"armor":
			player.defense += def.power
			items.remove_at(index)
			events.append({"type": "equipped", "pos": player.pos,
				"data": {"item_id": def.id, "stat": "defense", "gain": def.power}})
	return events
