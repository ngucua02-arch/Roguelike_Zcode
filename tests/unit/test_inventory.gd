extends GutTest
## 背包：药水回血（满血不消耗）、武器/护甲装备、越界静默。

const Inventory = preload("res://src/core/inventory.gd")
const ItemDef = preload("res://src/core/item_def.gd")
const Actor = preload("res://src/core/actor.gd")

func _potion(power: int) -> Object:
	var d = ItemDef.new()
	d.id = "potion_minor"
	d.display_name = "小治疗药水"
	d.kind = "potion"
	d.power = power
	return d

func _player(hp: int, max_hp: int) -> Object:
	var a = Actor.new()
	a.id = "player"
	a.hp = hp
	a.max_hp = max_hp
	a.atk = 0
	a.defense = 0
	a.is_player = true
	a.pos = Vector2i(2, 2)
	return a

func test_potion_heals_and_consumes() -> void:
	var inv = Inventory.new()
	inv.add(_potion(8))
	var player = _player(10, 20)
	var events = inv.use(0, player)
	assert_eq(player.hp, 18)
	assert_eq(inv.size(), 0)
	assert_eq(events[0].type, "healed")
	assert_eq(events[0].data.amount, 8)

func test_potion_at_full_hp_not_consumed() -> void:
	var inv = Inventory.new()
	inv.add(_potion(8))
	var player = _player(20, 20)
	var events = inv.use(0, player)
	assert_eq(player.hp, 20)
	assert_eq(inv.size(), 1)
	assert_eq(events[0].type, "use_failed")

func test_potion_overflow_caps_at_max() -> void:
	var inv = Inventory.new()
	inv.add(_potion(99))
	var player = _player(15, 20)
	inv.use(0, player)
	assert_eq(player.hp, 20)

func test_weapon_and_armor_equip() -> void:
	var inv = Inventory.new()
	var sword = ItemDef.new()
	sword.id = "sword"
	sword.kind = "weapon"
	sword.power = 2
	var mail = ItemDef.new()
	mail.id = "mail"
	mail.kind = "armor"
	mail.power = 1
	inv.add(sword)
	inv.add(mail)
	var player = _player(20, 20)
	var events = inv.use(0, player)
	assert_eq(player.atk, 2)
	assert_eq(events[0].type, "equipped")
	assert_eq(events[0].data.stat, "atk")
	var events2 = inv.use(0, player)  # mail 现在是 0 号位
	assert_eq(player.defense, 1)
	assert_eq(events2[0].data.stat, "defense")
	assert_eq(inv.size(), 0)

func test_out_of_range_returns_empty() -> void:
	var inv = Inventory.new()
	assert_eq(inv.use(0, _player(10, 20)), [])
