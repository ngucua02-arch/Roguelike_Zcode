class_name Combat
extends RefCounted
## 战斗结算：伤害 = max(1, atk - defense)，无随机、必然命中。

static func attack(attacker: Object, defender: Object) -> Array:
	var damage: int = maxi(1, attacker.atk - defender.defense)
	defender.hp -= damage
	if defender.hp < 0:
		defender.hp = 0  # 死亡时钳到 0，渲染/UI 不出现负血
	var events: Array = []
	events.append({
		"type": GameEvents.ATTACKED,
		"pos": defender.pos,
		"data": {
			"attacker_id": attacker.id,
			"defender_id": defender.id,
			"damage": damage,
			"defender_hp": defender.hp,
			"died": defender.hp <= 0,
		},
	})
	if defender.hp <= 0:
		events.append({
			"type": GameEvents.DIED,
			"pos": defender.pos,
			"data": {
				"actor_id": defender.id,
				"is_player": defender.is_player,
				"xp_reward": defender.xp_reward,
			},
		})
	return events
