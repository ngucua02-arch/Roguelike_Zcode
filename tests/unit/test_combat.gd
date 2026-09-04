extends GutTest
## 战斗：伤害公式、最小 1 边界、死亡事件。

const Combat = preload("res://src/core/combat.gd")
const Actor = preload("res://src/core/actor.gd")

func _actor(id: String, p_hp: int, p_atk: int, p_def: int, is_player := false) -> Object:
	var a = Actor.new()
	a.id = id
	a.max_hp = p_hp
	a.hp = p_hp
	a.atk = p_atk
	a.defense = p_def
	a.is_player = is_player
	a.pos = Vector2i(1, 1)
	return a

func test_damage_is_atk_minus_def() -> void:
	var player = _actor("player", 20, 5, 0, true)
	var rat = _actor("rat", 10, 2, 2)
	var events = Combat.attack(player, rat)
	assert_eq(events.size(), 1)
	assert_eq(events[0].type, "attacked")
	assert_eq(events[0].data.damage, 3)
	assert_eq(rat.hp, 7)
	assert_false(events[0].data.get("died", false))

func test_minimum_damage_is_one() -> void:
	var weak = _actor("weak", 10, 1, 0)
	var tank = _actor("tank", 50, 1, 10)
	var events = Combat.attack(weak, tank)
	assert_eq(events[0].data.damage, 1)
	assert_eq(tank.hp, 49)

func test_death_appends_died_event() -> void:
	var player = _actor("player", 20, 10, 0, true)
	var rat = _actor("rat", 4, 2, 0)
	rat.xp_reward = 3
	var events = Combat.attack(player, rat)
	assert_eq(events.size(), 2)
	assert_eq(events[1].type, "died")
	assert_eq(events[1].data.actor_id, "rat")
	assert_eq(events[1].data.xp_reward, 3)
	assert_eq(rat.hp, 0)

func test_player_death_flags_is_player() -> void:
	var ogre = _actor("ogre", 30, 25, 0)
	var player = _actor("player", 5, 3, 0, true)
	var events = Combat.attack(ogre, player)
	assert_eq(events[1].type, "died")
	assert_true(events[1].data.is_player)
