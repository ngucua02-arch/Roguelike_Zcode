# Roguelike Demo 板块0+1（工程骨架 + 玩法核心）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付可运行空工程 + 不依赖场景树的完整规则层（地牢生成/模型/回合调度/战斗/FOV/背包/楼层递进），全部 GUT 单元测试通过。

**Architecture:** 规则层为纯 GDScript（`extends RefCounted`/`Resource`），通过"事件流（字典数组）+ 模型查询"两个接口与表现层解耦；`TurnManager` autoload 是唯一调度门面。表现层（板块2/3）后续只消费事件，不修改规则层状态。

**Tech Stack:** Godot 4.7 标准版（非 .NET）、GDScript、GUT 9.7.1（已装于 `addons/gut/`）。

**Spec:** `docs/superpowers/specs/2026-09-04-roguelike-demo-design.md`（本计划实现其板块 0 与板块 1；板块 2 渲染、板块 3 UI、板块 4 数值表、板块 5 发布由后续计划承接）

## Global Constraints

- 引擎 Godot 4.7 标准版，GDScript；工程路径 `G:\Zcode\project\Roguelike`（即 git 仓库根）。
- `src/core/` 内所有脚本只允许 `extends RefCounted`（数据定义类 `extends Resource`）；禁止引用任何 Node/场景类型（spec §9 代码评审守门）。
- 事件统一为字典 `{type: String, pos: Vector2i, data: Dictionary}`；事件类型常量集中在 `src/core/events.gd`。
- 网格坐标用 `Vector2i`；16×16 瓦片；四方向移动（上下左右）。
- 战斗公式：伤害 = `max(1, atk - defense)`，无随机浮动；攻击必然命中。
- 撞墙不消耗回合（返回空事件列表，怪物不行动）；移动/攻击/等待/下楼消耗回合并触发怪物回合。
- 玩家每回合结算后自动重算 FOV 并写入 `model.visible` / `model.explored`。
- 楼层递进：站在楼梯格执行 descend；最后一层的楼梯触发通关（`game_won`），否则生成新楼层并追加 `floor_changed` 事件。
- 测试框架 GUT 9.7.1，测试放 `tests/unit/`，命名 `test_<被测类>.gd`；生成器测试用固定随机种子保证确定性。
- 规则层测试不加载 .tres 文件：测试代码直接 `new()` 构造 Def 对象（.tres 数值表属板块 4）。
- 测试中加载被测类用 `const X = preload("res://src/core/x.gd")`，不依赖 class_name 全局注册缓存。
- 每个 Task 结束 git 提交一次；提交信息用 `feat:`/`test:`/`chore:` 前缀。
- 注释与文档用中文。

## 运行测试的命令（每个 Task 复用）

```bash
GODOT="G:/Zcode/tools/godot/Godot_v4.7-stable_win64.exe"
"$GODOT" --headless --path . --import          # 首次或资源变更后导入
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit          # 全量
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_combat.gd -gexit  # 单文件
```

Expected: 输出末尾 `All tests passed`（或总览 `x passed / 0 failed`），退出码 0。

> 若 Godot exe 尚未下载完成：先完成各 Task 的"写文件"步骤，exe 就绪后统一补跑测试步骤；Task 1 的 GUT 冒烟是最早的测试闸口。

---

### Task 1: 工程骨架 + GUT 冒烟

**Files:**
- Create: `project.godot`
- Create: `.gitignore`
- Create: `src/autoload/turn_manager.gd`（占位 autoload，Task 9 填实）
- Create: `src/autoload/main.gd` + `src/autoload/main.tscn`（F5 主场景占位）
- Create: `tests/unit/test_smoke.gd`
- Create: `.gutconfig.json`

**Interfaces:**
- Consumes: 无
- Produces: 可 F5 运行的空工程；autoload 单例名 `TurnManager`（Task 9 起持有 `TurnScheduler`）；输入映射动作名 `move_up` / `move_down` / `move_left` / `move_right` / `descend` / `wait`（后续任务按名引用）。

- [ ] **Step 1: 写 project.godot**

```ini
; Engine configuration file.
config_version=5

[application]

config/name="RoguelikeDemo"
run/main_scene="res://src/autoload/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[autoload]

TurnManager="*res://src/autoload/turn_manager.gd"

[display]

window/size/viewport_width=960
window/size/viewport_height=560
window/stretch/mode="viewport"
window/stretch/scale_mode="integer"

[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")

[input]

move_up={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194320,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_down={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194322,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_left={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_right={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
descend={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194309,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
wait={
"deadzone": 0.2,
"events": []
}

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=0
```

- [ ] **Step 2: 写 .gitignore**

```gitignore
.godot/
*.tmp
```

- [ ] **Step 3: 写占位主场景与 TurnManager 占位**

`src/autoload/main.gd`:

```gdscript
extends Node2D
## 占位主场景：保证工程可 F5。板块 2/3 落地后由真正的主菜单替换。

func _ready() -> void:
	print("RoguelikeDemo 骨架启动成功")
```

`src/autoload/main.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/autoload/main.gd" id="1_main"]

[node name="Main" type="Node2D"]
script = ExtResource("1_main")
```

`src/autoload/turn_manager.gd`（Task 9 填实，先占位保证 autoload 不报错）:

```gdscript
extends Node
## 全局调度单例：接收输入 -> 调规则层 -> 把事件广播给渲染/UI。
## 板块 0 占位；Task 9 接入 TurnScheduler 并定义信号。

signal events_processed(events: Array)
```

- [ ] **Step 4: 写 GUT 冒烟测试与配置**

`tests/unit/test_smoke.gd`:

```gdscript
extends GutTest
## GUT 冒烟：验证 headless 测试链路可用。

func test_engine_boots() -> void:
	assert_true(true)
```

`.gutconfig.json`（工程根）:

```json
{
  "dirs": ["res://tests/unit"],
  "include_subdirs": false,
  "should_exit": true,
  "double_strategy": "script_only"
}
```

- [ ] **Step 5: headless 导入 + 跑冒烟测试**

Run: `"$GODOT" --headless --path . --import`（预期无脚本错误）然后
Run: `"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: `1 passed 0 failed`

- [ ] **Step 6: 提交**

```bash
git add project.godot .gitignore .gutconfig.json src tests addons
git commit -m "chore: 工程骨架（Godot 4.7 + GUT 9.7.1 + 输入映射 + 像素设置）"
```

---

### Task 2: DungeonModel（网格与实体容器）

**Files:**
- Create: `src/core/dungeon_model.gd`
- Test: `tests/unit/test_dungeon_model.gd`

**Interfaces:**
- Consumes: 无
- Produces（后续任务依赖的精确签名）:
  - `DungeonModel.new(width: int, height: int)`
  - 枚举 `DungeonModel.Tile.WALL/FLOOR/DOOR/STAIRS`（int 0..3）
  - `var width/height: int`、`var tiles: PackedInt32Array`、`var player: Actor`（可空）、`var monsters: Array`（Actor 数组）、`var items: Array`（字典 `{item_id: String, pos: Vector2i}`）、`var stairs_pos: Vector2i`、`var floor_number: int`、`var visible: Dictionary`、`var explored: Dictionary`
  - `is_in_bounds(pos: Vector2i) -> bool`
  - `tile_at(pos: Vector2i) -> int`（界外返回 `Tile.WALL`）
  - `set_tile(pos: Vector2i, t: int) -> void`
  - `is_walkable(pos: Vector2i) -> bool`（界内且非 WALL；不含实体判断）
  - `is_occupied(pos: Vector2i) -> bool`（任一 actor 站立）
  - `actor_at(pos: Vector2i) -> Actor`（含玩家，无则 null）
  - `add_actor(a: Actor) -> void`（玩家加入时设置 `player`；怪物加入时设置其 `pos`）
  - `remove_actor(a: Actor) -> void`（死亡移除）
  - `item_at(pos: Vector2i) -> Dictionary`（无则空字典）
  - `add_item(item_id: String, pos: Vector2i) -> void` / `remove_item(pos: Vector2i) -> void`
  - `remember_fov(visible_set: Dictionary) -> void`（写入 visible 并并入 explored）

- [ ] **Step 1: 写失败测试** `tests/unit/test_dungeon_model.gd`

```gdscript
extends GutTest
## DungeonModel：行走判定、实体容器、FOV 记忆。

const DungeonModel = preload("res://src/core/dungeon_model.gd")

func _blank_model() -> Object:
	var m = DungeonModel.new(5, 5)
	for y in 5:
		for x in 5:
			m.set_tile(Vector2i(x, y), DungeonModel.Tile.FLOOR)
	return m

func test_out_of_bounds_is_wall_and_not_walkable() -> void:
	var m = DungeonModel.new(3, 3)
	assert_eq(m.tile_at(Vector2i(-1, 0)), DungeonModel.Tile.WALL)
	assert_false(m.is_walkable(Vector2i(3, 0)))
	assert_false(m.is_walkable(Vector2i(0, -1)))

func test_wall_not_walkable_floor_walkable() -> void:
	var m = _blank_model()
	m.set_tile(Vector2i(2, 2), DungeonModel.Tile.WALL)
	assert_false(m.is_walkable(Vector2i(2, 2)))
	assert_true(m.is_walkable(Vector2i(1, 2)))
	assert_true(m.is_walkable(Vector2i(2, 1)))  # 门/楼梯类地面可走由 tile 决定

func test_actor_at_contains_player_and_monsters() -> void:
	var m = _blank_model()
	var player = load("res://src/core/actor.gd").new()
	player.id = "player"
	player.pos = Vector2i(1, 1)
	var rat = load("res://src/core/actor.gd").new()
	rat.id = "rat"
	rat.pos = Vector2i(3, 3)
	m.add_actor(player)
	m.add_actor(rat)
	assert_eq(m.actor_at(Vector2i(1, 1)), player)
	assert_eq(m.actor_at(Vector2i(3, 3)), rat)
	assert_null(m.actor_at(Vector2i(0, 0)))
	assert_eq(m.player, player)
	assert_eq(m.monsters.size(), 1)

func test_remove_actor_clears_position() -> void:
	var m = _blank_model()
	var player = load("res://src/core/actor.gd").new()
	player.id = "player"
	player.pos = Vector2i(1, 1)
	m.add_actor(player)
	var rat = load("res://src/core/actor.gd").new()
	rat.id = "rat"
	rat.pos = Vector2i(3, 3)
	m.add_actor(rat)
	m.remove_actor(rat)
	assert_null(m.actor_at(Vector2i(3, 3)))
	assert_eq(m.monsters.size(), 0)

func test_items_add_remove() -> void:
	var m = _blank_model()
	m.add_item("potion_minor", Vector2i(2, 2))
	var it = m.item_at(Vector2i(2, 2))
	assert_eq(it.get("item_id", ""), "potion_minor")
	m.remove_item(Vector2i(2, 2))
	assert_true(m.item_at(Vector2i(2, 2)).is_empty())

func test_remember_fov_merges_explored() -> void:
	var m = _blank_model()
	var vis = {Vector2i(1, 1): true, Vector2i(2, 1): true}
	m.remember_fov(vis)
	assert_true(m.explored.has(Vector2i(1, 1)))
	m.remember_fov({Vector2i(3, 1): true})
	assert_true(m.explored.has(Vector2i(1, 1)))
	assert_true(m.explored.has(Vector2i(3, 1)))
	assert_false(m.visible.has(Vector2i(1, 1)))  # visible 只保留最近一次
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_dungeon_model.gd -gexit`
Expected: FAIL（脚本无法加载 `actor.gd` 或方法不存在）

- [ ] **Step 3: 写实现** `src/core/dungeon_model.gd`

```gdscript
class_name DungeonModel
extends RefCounted
## 规则层地牢模型：网格 + 实体容器。不持有任何 Node 引用。

enum Tile { WALL, FLOOR, DOOR, STAIRS }

var width: int
var height: int
var tiles: PackedInt32Array = PackedInt32Array()
var player: Object = null          # Actor（用 Object 类型避免 core 依赖顺序问题）
var monsters: Array = []           # Array[Actor]
var items: Array = []              # Array[Dictionary] {item_id, pos}
var stairs_pos: Vector2i = Vector2i(-1, -1)
var floor_number: int = 1
var visible: Dictionary = {}       # Vector2i -> true（本回合可见集）
var explored: Dictionary = {}      # Vector2i -> true（累计已探索）

func _init(p_width: int = 0, p_height: int = 0) -> void:
	width = p_width
	height = p_height
	tiles.resize(width * height)
	tiles.fill(Tile.WALL)

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < width and pos.y < height

func _index(pos: Vector2i) -> int:
	return pos.y * width + pos.x

func tile_at(pos: Vector2i) -> int:
	if not is_in_bounds(pos):
		return Tile.WALL
	return tiles[_index(pos)]

func set_tile(pos: Vector2i, t: int) -> void:
	if is_in_bounds(pos):
		tiles[_index(pos)] = t

func is_walkable(pos: Vector2i) -> bool:
	return is_in_bounds(pos) and tiles[_index(pos)] != Tile.WALL

func is_occupied(pos: Vector2i) -> bool:
	return actor_at(pos) != null

func actor_at(pos: Vector2i) -> Object:
	for a in monsters:
		if a.pos == pos:
			return a
	if player != null and player.pos == pos:
		return player
	return null

func add_actor(a: Object) -> void:
	if a.is_player:
		player = a
	else:
		monsters.append(a)

func remove_actor(a: Object) -> void:
	monsters.erase(a)
	if player == a:
		player = null

func item_at(pos: Vector2i) -> Dictionary:
	for it in items:
		if it.pos == pos:
			return it
	return {}

func add_item(item_id: String, pos: Vector2i) -> void:
	items.append({"item_id": item_id, "pos": pos})

func remove_item(pos: Vector2i) -> void:
	var it := item_at(pos)
	if not it.is_empty():
		items.erase(it)

func remember_fov(visible_set: Dictionary) -> void:
	visible = visible_set
	for key in visible_set.keys():
		explored[key] = true
```

注意：`actor.gd` 属于 Task 3，但本测试已用到——先创建 `src/core/actor.gd` 的最小版本（字段齐全、无逻辑），Task 3 再补行为方法并测行为。最小版本：

```gdscript
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
var ai_type: String = "chase" # "chase" | "wander"
var glyph: String = "?"       # 渲染层占位标识（色块阶段用）
```

- [ ] **Step 4: 跑测试确认通过**

Run: `"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_dungeon_model.gd -gexit`
Expected: `6 passed 0 failed`

- [ ] **Step 5: 提交**

```bash
git add src/core/dungeon_model.gd src/core/actor.gd tests/unit/test_dungeon_model.gd
git commit -m "feat: DungeonModel 网格与实体容器（含 GUT 测试）"
```

---

### Task 3: Actor 成长 + 4 个数据定义类

**Files:**
- Modify: `src/core/actor.gd`（补 `gain_xp` 等行为与静态工厂）
- Create: `src/core/monster_def.gd`、`src/core/item_def.gd`、`src/core/floor_def.gd`、`src/core/player_def.gd`
- Test: `tests/unit/test_actor.gd`

**Interfaces:**
- Consumes: `Actor`（Task 2 最小版）
- Produces:
  - `Actor.from_player_def(def: PlayerDef) -> Actor`（静态；is_player=true，含 xp 曲线字段）
  - `Actor.from_monster_def(def: MonsterDef, pos: Vector2i) -> Actor`（静态）
  - `a.xp_to_next() -> int`（= `xp_base + (level - 1) * xp_growth`）
  - `a.gain_xp(amount: int) -> Array`（返回升级事件数组，元素 `{type:"leveled_up", pos, data:{level}}`；升级：`xp` 扣减、`level+=1`、`max_hp += hp_per_level`、`hp = max_hp`（回满）、`atk += atk_per_level`、`defense += defense_per_level`）
  - `PlayerDef` 字段：`display_name, max_hp, atk, defense, sight_radius, xp_base, xp_growth, hp_per_level, atk_per_level, defense_per_level`（全 @export，int，合理默认值）
  - `MonsterDef` 字段：`id, display_name, glyph, max_hp, atk, defense, sight_radius, xp_reward, ai_type`（`id/display_name/glyph/ai_type` String，余 int）
  - `ItemDef` 字段：`id, display_name, glyph, kind, power`（kind: "potion"/"weapon"/"armor"）
  - `FloorDef` 字段：`width, height, room_count_min, room_count_max, monster_count_min, monster_count_max, item_count_min, item_count_max, monster_spawns: Array`（元素 `{def: MonsterDef, weight: int}`）、`item_spawns: Array`（元素 `{def: ItemDef, weight: int}`）、`floor_theme: Color`
  - `FloorDef.pick_monster(rng: RandomNumberGenerator) -> MonsterDef`（按 weight 加权随机；表空返回 null）
  - `FloorDef.pick_item(rng: RandomNumberGenerator) -> ItemDef`（同上）

- [ ] **Step 1: 写失败测试** `tests/unit/test_actor.gd`

```gdscript
extends GutTest
## Actor 经验升级 + Def 静态工厂 + FloorDef 加权抽取。

const Actor = preload("res://src/core/actor.gd")
const PlayerDef = preload("res://src/core/player_def.gd")
const MonsterDef = preload("res://src/core/monster_def.gd")
const ItemDef = preload("res://src/core/item_def.gd")
const FloorDef = preload("res://src/core/floor_def.gd")

func _player_def() -> Object:
	var d = PlayerDef.new()
	d.max_hp = 20
	d.atk = 3
	d.defense = 1
	d.sight_radius = 6
	d.xp_base = 10
	d.xp_growth = 5
	d.hp_per_level = 5
	d.atk_per_level = 1
	d.defense_per_level = 1
	return d

func test_from_player_def_copies_fields() -> void:
	var a = Actor.from_player_def(_player_def())
	assert_true(a.is_player)
	assert_eq(a.max_hp, 20)
	assert_eq(a.hp, 20)
	assert_eq(a.atk, 3)
	assert_eq(a.defense, 1)
	assert_eq(a.xp_to_next(), 10)

func test_gain_xp_levels_up_and_heals_full() -> void:
	var a = Actor.from_player_def(_player_def())
	a.hp = 5  # 先扣血
	var events = a.gain_xp(10)
	assert_eq(events.size(), 1)
	assert_eq(events[0].type, "leveled_up")
	assert_eq(a.level, 2)
	assert_eq(a.max_hp, 25)
	assert_eq(a.hp, 25)  # 升级回满
	assert_eq(a.atk, 4)
	assert_eq(a.defense, 2)
	assert_eq(a.xp, 0)
	assert_eq(a.xp_to_next(), 15)  # 下一级需求按 growth 增长

func test_gain_xp_multi_level_and_carry() -> void:
	var a = Actor.from_player_def(_player_def())
	var events = a.gain_xp(25)  # 10 升 1 级余 15，15 正好升 2 级
	assert_eq(events.size(), 2)
	assert_eq(a.level, 3)
	assert_eq(a.xp, 0)

func test_monster_factory() -> void:
	var d = MonsterDef.new()
	d.id = "rat"
	d.display_name = "窟鼠"
	d.max_hp = 5
	d.atk = 2
	d.defense = 0
	d.sight_radius = 5
	d.xp_reward = 3
	var a = Actor.from_monster_def(d, Vector2i(2, 3))
	assert_false(a.is_player)
	assert_eq(a.pos, Vector2i(2, 3))
	assert_eq(a.hp, 5)
	assert_eq(a.xp_reward, 3)

func test_floor_def_weighted_pick_respects_weights() -> void:
	var f = FloorDef.new()
	var weak = MonsterDef.new()
	weak.id = "rat"
	var strong = MonsterDef.new()
	strong.id = "ogre"
	f.monster_spawns = [{"def": weak, "weight": 0}, {"def": strong, "weight": 1}]
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	for i in 10:
		assert_eq(f.pick_monster(rng).id, "ogre")  # 权重 0 永不选中

func test_floor_def_empty_table_returns_null() -> void:
	var f = FloorDef.new()
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	assert_null(f.pick_monster(rng))
	assert_null(f.pick_item(rng))
```

- [ ] **Step 2: 跑测试确认失败**（同上命令，换文件名）
Expected: FAIL（静态工厂不存在）

- [ ] **Step 3: 写实现**

`src/core/player_def.gd`:

```gdscript
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
```

`src/core/monster_def.gd`:

```gdscript
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
@export var ai_type: String = "chase"  # "chase" | "wander"
```

`src/core/item_def.gd`:

```gdscript
class_name ItemDef
extends Resource
## 物品定义（数据表）。

@export var id: String = ""
@export var display_name: String = ""
@export var glyph: String = "!"
@export_enum("potion", "weapon", "armor") var kind: String = "potion"
@export var power: int = 5           # 药水回血量 / 武器加攻 / 护甲加防
```

`src/core/floor_def.gd`:

```gdscript
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
```

`src/core/actor.gd` 追加（在最小版字段之后）：

```gdscript
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
```

注意：`gain_xp` 的 `while xp >= xp_to_next()` 中，先扣减后升级——循环内 `xp -= xp_to_next()` 用的是**升级前**的 level 需求，注意实现顺序：先 `xp -= xp_to_next()` 再 `level += 1`（测试 `test_gain_xp_multi_level_and_carry` 验证 25 经验升 2 级且余 0）。

- [ ] **Step 4: 跑测试确认通过**
Expected: `6 passed 0 failed`

- [ ] **Step 5: 提交**

```bash
git add src/core tests/unit/test_actor.gd
git commit -m "feat: Actor 成长曲线与 Def 数据定义类（含 GUT 测试）"
```

---

### Task 4: DungeonGenerator（房间 + 走廊 + 撒点）

**Files:**
- Create: `src/core/dungeon_generator.gd`
- Test: `tests/unit/test_dungeon_generator.gd`

**Interfaces:**
- Consumes: `DungeonModel`、`FloorDef`、`Actor.from_monster_def`
- Produces:
  - `DungeonGenerator.new(seed_value: int = -1)`（-1 时随机熵；固定值用于确定性测试）
  - `generate(floor_def: Object, floor_number: int) -> DungeonModel`
  - 生成保证：全部 FLOOR 格从玩家出生点四连通（走廊按房间顺序连接）；楼梯在最后一个房间的中心格（`Tile.STAIRS`，`model.stairs_pos`）；玩家出生在第一个房间中心；怪物/物品数量在 `[min, max]` 内；所有实体互不重叠且都站在 FLOOR 上；楼梯格无实体。

- [ ] **Step 1: 写失败测试** `tests/unit/test_dungeon_generator.gd`

```gdscript
extends GutTest
## 生成器：固定种子做确定性测试。核心断言是"结构性质"而非具体形状。

const DungeonGenerator = preload("res://src/core/dungeon_generator.gd")
const DungeonModel = preload("res://src/core/dungeon_model.gd")
const Actor = preload("res://src/core/actor.gd")
const PlayerDef = preload("res://src/core/player_def.gd")
const MonsterDef = preload("res://src/core/monster_def.gd")
const ItemDef = preload("res://src/core/item_def.gd")
const FloorDef = preload("res://src/core/floor_def.gd")

func _floor_def() -> Object:
	var f = FloorDef.new()
	f.width = 30
	f.height = 20
	f.room_count_min = 5
	f.room_count_max = 7
	f.monster_count_min = 3
	f.monster_count_max = 6
	f.item_count_min = 2
	f.item_count_max = 3
	var rat = MonsterDef.new()
	rat.id = "rat"
	var potion = ItemDef.new()
	potion.id = "potion_minor"
	f.monster_spawns = [{"def": rat, "weight": 1}]
	f.item_spawns = [{"def": potion, "weight": 1}]
	return f

func _generate(seed_value: int) -> Object:
	var gen = DungeonGenerator.new(seed_value)
	return gen.generate(_floor_def(), 1)

func _flood_reachable(m: Object) -> Dictionary:
	# 从玩家位置 BFS，只走 walkable
	var seen := {m.player.pos: true}
	var queue: Array = [m.player.pos]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var nxt: Vector2i = cur + dir
			if m.is_walkable(nxt) and not seen.has(nxt):
				seen[nxt] = true
				queue.append(nxt)
	return seen

func test_same_seed_same_layout() -> void:
	var a = _generate(1234)
	var b = _generate(1234)
	assert_eq(a.tiles, b.tiles)
	assert_eq(a.player.pos, b.player.pos)
	assert_eq(a.stairs_pos, b.stairs_pos)

func test_stairs_reachable_from_player() -> void:
	for s in [1, 2, 3]:
		var m = _generate(100 + s)
		assert_true(_flood_reachable(m).has(m.stairs_pos), "seed %d 楼梯可达" % s)

func test_all_floor_tiles_connected() -> void:
	var m = _generate(7)
	var reachable = _flood_reachable(m)
	for y in m.height:
		for x in m.width:
			var pos := Vector2i(x, y)
			if m.tile_at(pos) != DungeonModel.Tile.WALL:
				assert_true(reachable.has(pos), "地板格 %s 应连通" % str(pos))

func test_rooms_do_not_overlap() -> void:
	# 房间区域 = 每个房间矩形；通过生成器内部记录验证
	var gen = DungeonGenerator.new(99)
	var m = gen.generate(_floor_def(), 1)
	var rooms: Array = gen.rooms
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			var a: Rect2i = rooms[i]
			var b: Rect2i = rooms[j]
			var expanded_a := a.grow(1)  # 允许墙间隔，膨胀 1 格后仍不得相交
			assert_false(expanded_a.intersects(b), "房间 %s 与 %s 重叠" % [str(a), str(b)])

func test_entity_counts_and_no_overlap() -> void:
	var m = _generate(5)
	assert_true(m.monsters.size() >= 3 and m.monsters.size() <= 6)
	assert_true(m.items.size() >= 2 and m.items.size() <= 3)
	var occupied := {m.player.pos: true, m.stairs_pos: true}
	for mon in m.monsters:
		assert_false(occupied.has(mon.pos), "怪物与已有实体重叠")
		assert_eq(m.tile_at(mon.pos), DungeonModel.Tile.FLOOR)
		occupied[mon.pos] = true
	for it in m.items:
		assert_false(occupied.has(it.pos), "物品与已有实体重叠")
		assert_eq(m.tile_at(it.pos), DungeonModel.Tile.FLOOR)
		occupied[it.pos] = true
	assert_eq(m.tile_at(m.stairs_pos), DungeonModel.Tile.STAIRS)
	assert_eq(m.tile_at(m.player.pos), DungeonModel.Tile.FLOOR)
```

- [ ] **Step 2: 跑测试确认失败**
Expected: FAIL（脚本无法加载）

- [ ] **Step 3: 写实现** `src/core/dungeon_generator.gd`

```gdscript
class_name DungeonGenerator
extends RefCounted
## 随机房间 + 走廊地牢生成器。固定种子 -> 确定性布局。

var rng: RandomNumberGenerator
var rooms: Array = []   # Array[Rect2i]（最近一次 generate 的房间矩形，测试用）

func _init(seed_value: int = -1) -> void:
	rng = RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

func generate(floor_def: Object, floor_number: int) -> Object:
	var model := DungeonModel.new(floor_def.width, floor_def.height)
	model.floor_number = floor_number
	rooms.clear()

	var room_count := rng.randi_range(floor_def.room_count_min, floor_def.room_count_max)
	var attempts := 0
	while rooms.size() < room_count and attempts < 200:
		attempts += 1
		var w := rng.randi_range(4, 8)
		var h := rng.randi_range(3, 6)
		var x := rng.randi_range(1, floor_def.width - w - 2)
		var y := rng.randi_range(1, floor_def.height - h - 2)
		var rect := Rect2i(x, y, w, h)
		var ok := true
		for other in rooms:
			if rect.grow(1).intersects(other):  # 至少 1 格墙间隔
				ok = false
				break
		if ok:
			rooms.append(rect)
			_carve_room(model, rect)

	# 按房间顺序 L 形走廊两两相连 -> 天然全连通
	for i in range(1, rooms.size()):
		_carve_corridor(model, _center(rooms[i - 1]), _center(rooms[i]))

	var first: Rect2i = rooms[0]
	var last: Rect2i = rooms[rooms.size() - 1]
	var player_pos := _center(first)
	model.set_tile(player_pos, DungeonModel.Tile.FLOOR)
	model.stairs_pos = _center(last)
	model.set_tile(model.stairs_pos, DungeonModel.Tile.STAIRS)

	var player = load("res://src/core/actor.gd").from_player_def(load("res://src/core/player_def.gd").new())
	player.pos = player_pos
	model.add_actor(player)

	_spawn_entities(model, floor_def)
	return model

func _carve_room(model: Object, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			model.set_tile(Vector2i(x, y), DungeonModel.Tile.FLOOR)

func _carve_corridor(model: Object, from: Vector2i, to: Vector2i) -> void:
	var cur := from
	# 先横后纵
	while cur.x != to.x:
		model.set_tile(cur, DungeonModel.Tile.FLOOR)
		cur.x += signi(to.x - cur.x)
	while cur.y != to.y:
		model.set_tile(cur, DungeonModel.Tile.FLOOR)
		cur.y += signi(to.y - cur.y)
	model.set_tile(to, DungeonModel.Tile.FLOOR)

func _center(rect: Rect2i) -> Vector2i:
	return rect.position + rect.size / 2

func _random_floor_in(rect: Rect2i) -> Vector2i:
	return Vector2i(
		rng.randi_range(rect.position.x, rect.position.x + rect.size.x - 1),
		rng.randi_range(rect.position.y, rect.position.y + rect.size.y - 1))

func _spawn_entities(model: Object, floor_def: Object) -> void:
	var actor = load("res://src/core/actor.gd")
	var monster_count := rng.randi_range(floor_def.monster_count_min, floor_def.monster_count_max)
	for i in monster_count:
		var def = floor_def.pick_monster(rng)
		if def == null:
			break
		var pos := _find_free_spot(model)
		if pos == Vector2i(-1, -1):
			break
		model.add_actor(actor.from_monster_def(def, pos))

	var item_count := rng.randi_range(floor_def.item_count_min, floor_def.item_count_max)
	for i in item_count:
		var def = floor_def.pick_item(rng)
		if def == null:
			break
		var pos := _find_free_spot(model)
		if pos == Vector2i(-1, -1):
			break
		model.add_item(def.id, pos)

func _find_free_spot(model: Object) -> Vector2i:
	# 随机房间内找空位：非玩家位、非楼梯、无实体、无物品
	for attempt in 100:
		var pos := _random_floor_in(rooms[rng.randi_range(0, rooms.size() - 1)])
		if pos == model.player.pos or pos == model.stairs_pos:
			continue
		if model.is_occupied(pos) or not model.item_at(pos).is_empty():
			continue
		if model.tile_at(pos) != DungeonModel.Tile.FLOOR:
			continue
		return pos
	return Vector2i(-1, -1)
```

注意 `player_def` 在生成器里暂时 `new()` 默认值（板块 4 接 .tres / Task 9 由 TurnManager 注入真实 PlayerDef——`generate` 不接收 PlayerDef，玩家出生格 FLOOR 已手动 carve，防止走廊端点覆盖成别的）。

- [ ] **Step 4: 跑测试确认通过**
Expected: `5 passed 0 failed`

- [ ] **Step 5: 提交**

```bash
git add src/core/dungeon_generator.gd tests/unit/test_dungeon_generator.gd
git commit -m "feat: 地牢生成器（房间+走廊+加权撒点，固定种子确定性测试）"
```

---

### Task 5: FOV（Bresenham 视线）

**Files:**
- Create: `src/core/fov.gd`
- Test: `tests/unit/test_fov.gd`

**Interfaces:**
- Consumes: `DungeonModel`
- Produces: `FOV.compute(model: Object, origin: Vector2i, radius: int) -> Dictionary`（静态；键 `Vector2i`。可见规则：目标格沿线路径（不含起终点）遇墙则不可见；目标格自身可为墙（看见墙面）。半径为切比雪夫距离 `max(|dx|,|dy|) <= radius`。）

- [ ] **Step 1: 写失败测试** `tests/unit/test_fov.gd`

```gdscript
extends GutTest
## FOV：半径限制 + 墙挡视线 + 墙面本身可见。

const FOV = preload("res://src/core/fov.gd")
const DungeonModel = preload("res://src/core/dungeon_model.gd")

func _room(w: int, h: int) -> Object:
	var m = DungeonModel.new(w, h)
	for y in h:
		for x in w:
			m.set_tile(Vector2i(x, y), DungeonModel.Tile.FLOOR)
	return m

func test_radius_limits_visibility() -> void:
	var m = _room(11, 11)
	var vis = FOV.compute(m, Vector2i(5, 5), 2)
	assert_true(vis.has(Vector2i(7, 5)))    # 切比雪夫距离 2
	assert_false(vis.has(Vector2i(8, 5)))   # 距离 3，超半径
	assert_true(vis.has(Vector2i(6, 6)))

func test_wall_blocks_line_of_sight() -> void:
	var m = _room(5, 5)
	m.set_tile(Vector2i(2, 1), DungeonModel.Tile.WALL)  # 玩家正北方向隔一堵墙
	var vis = FOV.compute(m, Vector2i(2, 3), 4)
	assert_true(vis.has(Vector2i(2, 1)), "墙面本身可见")
	assert_false(vis.has(Vector2i(2, 0)), "墙后格子不可见")

func test_origin_always_visible() -> void:
	var m = _room(3, 3)
	var vis = FOV.compute(m, Vector2i(1, 1), 1)
	assert_true(vis.has(Vector2i(1, 1)))

func test_diagonal_around_corner_blocked() -> void:
	# L 形墙角：对角线穿角不可见
	var m = _room(5, 5)
	m.set_tile(Vector2i(1, 1), DungeonModel.Tile.WALL)
	m.set_tile(Vector2i(1, 2), DungeonModel.Tile.WALL)
	m.set_tile(Vector2i(2, 1), DungeonModel.Tile.WALL)
	var vis = FOV.compute(m, Vector2i(0, 0), 4)
	assert_false(vis.has(Vector2i(2, 2)), "墙角对角不可见")
```

- [ ] **Step 2: 跑测试确认失败**
Expected: FAIL

- [ ] **Step 3: 写实现** `src/core/fov.gd`

```gdscript
class_name FOV
extends RefCounted
## 简易视野：以 origin 为中心向半径内所有格做 Bresenham 射线。

static func compute(model: Object, origin: Vector2i, radius: int) -> Dictionary:
	var result := {}
	assert(radius >= 0)
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var target: Vector2i = origin + Vector2i(dx, dy)
			if _line_clear(model, origin, target):
				result[target] = true
	return result

## 直线路径（不含起点；含终点格本身）是否通畅：中途遇墙=false；终点是墙=true（看见墙面）。
static func _line_clear(model: Object, from: Vector2i, to: Vector2i) -> bool:
	if not model.is_in_bounds(to):
		return false
	var cur := from
	var dx: int = absi(to.x - from.x)
	var dy: int = absi(to.y - from.y)
	var sx: int = signi(to.x - from.x)
	var sy: int = signi(to.y - from.y)
	var err := dx - dy
	while cur != to:
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			cur.x += sx
		if e2 < dx:
			err += dx
			cur.y += sy
		if cur == to:
			break
		if not model.is_in_bounds(cur) or model.tile_at(cur) == DungeonModel.Tile.WALL:
			return false
	return true
```

- [ ] **Step 4: 跑测试确认通过**
Expected: `4 passed 0 failed`

- [ ] **Step 5: 提交**

```bash
git add src/core/fov.gd tests/unit/test_fov.gd
git commit -m "feat: Bresenham 视线 FOV（含 GUT 测试）"
```

---

### Task 6: Combat（伤害结算与死亡事件）

**Files:**
- Create: `src/core/combat.gd`
- Create: `src/core/events.gd`（事件类型常量）
- Test: `tests/unit/test_combat.gd`

**Interfaces:**
- Consumes: `Actor`；事件常量 `GameEvents`（`MOVED/ATTACKED/DIED/XP_GAINED/LEVELED_UP/PICKED_UP/DESCENDED/FLOOR_CHANGED/GAME_OVER/GAME_WON/WAITED/USE_FAILED`）
- Produces:
  - `Combat.attack(attacker: Object, defender: Object) -> Array`
    - 事件 1：`{type:"attacked", pos:defender.pos, data:{attacker_id, defender_id, damage, defender_hp}}`
    - 若 `defender.hp <= 0`：追加 `{type:"died", pos:defender.pos, data:{actor_id, is_player, xp_reward}}`（xp_reward 仅怪物有意义）
  - 无随机数、必然命中；伤害 `max(1, attacker.atk - defender.defense)`。

- [ ] **Step 1: 写失败测试** `tests/unit/test_combat.gd`

```gdscript
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
```

- [ ] **Step 2: 跑测试确认失败**
Expected: FAIL

- [ ] **Step 3: 写实现**

`src/core/events.gd`:

```gdscript
class_name GameEvents
extends RefCounted
## 事件流类型常量与玩家动作常量。事件字典统一 {type, pos, data}。

const MOVED := "moved"
const ATTACKED := "attacked"
const DIED := "died"
const XP_GAINED := "xp_gained"
const LEVELED_UP := "leveled_up"
const PICKED_UP := "picked_up"
const WAITED := "waited"
const USE_FAILED := "use_failed"
const DESCENDED := "descended"
const FLOOR_CHANGED := "floor_changed"
const GAME_OVER := "game_over"
const GAME_WON := "game_won"

const ACTION_MOVE := "move"
const ACTION_WAIT := "wait"
const ACTION_DESCEND := "descend"
```

`src/core/combat.gd`:

```gdscript
class_name Combat
extends RefCounted
## 战斗结算：伤害 = max(1, atk - defense)，无随机、必然命中。

static func attack(attacker: Object, defender: Object) -> Array:
	var damage: int = maxi(1, attacker.atk - defender.defense)
	defender.hp -= damage
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
```

- [ ] **Step 4: 跑测试确认通过**
Expected: `4 passed 0 failed`

- [ ] **Step 5: 提交**

```bash
git add src/core/combat.gd src/core/events.gd tests/unit/test_combat.gd
git commit -m "feat: 战斗结算与事件常量（含 GUT 测试）"
```

---

### Task 7: Inventory（背包与道具使用）

**Files:**
- Create: `src/core/inventory.gd`
- Test: `tests/unit/test_inventory.gd`

**Interfaces:**
- Consumes: `ItemDef`（测试代码构造）、`Actor`、`GameEvents`
- Produces:
  - `Inventory.new()`；`var items: Array`（元素 `{def: ItemDef 对象, item_id: String}`）
  - `add(def: Object) -> void`
  - `size() -> int`
  - `use(index: int, player: Object) -> Array`
    - 越界 → `[{type:"use_failed", pos, data:{reason:"empty_slot"}}]`？越界返回 `[]`（UI 不应发出无效 index；规则层静默）
    - potion：`hp` 已满 → `[{type:"use_failed", ...}]` 且**不消耗**；否则 `hp = min(max_hp, hp + power)` → `{type:"healed", pos, data:{amount, hp}}` 并移除该格
    - weapon：`player.atk += power` → `{type:"equipped", pos, data:{item_id, stat:"atk", gain}}` 并移除
    - armor：`player.defense += power` → `{type:"equipped", ... stat:"defense"}` 并移除

- [ ] **Step 1: 写失败测试** `tests/unit/test_inventory.gd`

```gdscript
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
```

- [ ] **Step 2: 跑测试确认失败**
Expected: FAIL

- [ ] **Step 3: 写实现** `src/core/inventory.gd`

```gdscript
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
```

- [ ] **Step 4: 跑测试确认通过**
Expected: `5 passed 0 failed`

- [ ] **Step 5: 提交**

```bash
git add src/core/inventory.gd tests/unit/test_inventory.gd
git commit -m "feat: 背包与道具使用（含 GUT 测试）"
```

---

### Task 8: TurnScheduler（回合调度、怪物 AI、楼层递进）

**Files:**
- Create: `src/core/turn_scheduler.gd`
- Test: `tests/unit/test_turn_scheduler.gd`

**Interfaces:**
- Consumes: 全部前序类
- Produces:
  - `TurnScheduler.new(player_def: Object, floor_defs: Array, seed_value: int = -1)`
  - `var model: Object`（当前层 DungeonModel）、`var player: Object`、`var inventory: Object`、`var rng: RandomNumberGenerator`、`var is_game_over: bool`、`var is_won: bool`、`var floor_index: int`（0 起）
  - `start() -> Array`：生成第 1 层，返回 `[{type:"floor_changed", ...}]`
  - `player_action(action: String, dir: Vector2i = Vector2i.ZERO) -> Array`
    - `game_over` 后恒返回 `[]`
    - `ACTION_WAIT` → `[{type:"waited", ...}]` + 怪物回合
    - `ACTION_MOVE`：目标 `pos + dir`；不可走或有墙 → `[]`（不消耗回合）；目标有怪 → 玩家攻击 + 怪物回合；否则移动（`moved` 事件）+ 踩到物品自动拾取（`picked_up`）+ 怪物回合
    - `ACTION_DESCEND`：不在楼梯 → `[]`（不消耗回合）；在楼梯：末层 → `game_won`；否则 `descended` + 内部生成下一层 + `floor_changed`
    - 玩家死亡：事件流追加 `game_over`，置 `is_game_over`
    - 每次消耗回合后：`model.remember_fov(FOV.compute(model, player.pos, player.sight_radius))`
  - 怪物 AI：与玩家曼哈顿距离 1 → 攻击；玩家在其 sight_radius 内且 FOV 可见（`model.visible` 有玩家格？不行——怪物判定用 `FOV.compute(model, m.pos, m.sight_radius)` 是否含 player.pos）→ 贪心逼近；否则 25% 概率随机走（rng）；死亡的怪跳过；玩家死后停止
  - 贪心逼近顺序：`|dx| >= |dy|` 先试主轴 `(sign(dx), 0)` 再试 `(0, sign(dy))`，反之先纵后横；候选格需 `is_walkable` 且无 actor

- [ ] **Step 1: 写失败测试** `tests/unit/test_turn_scheduler.gd`

测试用手工构造 model 的场景来精确控制布局。为可测，提供注入点：允许测试先 `new()` 再替换 `model`（提供 `func _set_model_for_test(m: Object)`?——更干净：scheduler 提供 `_install_model(m: Object) -> void` 公开方法仅测试使用？不。用受保护约定的做法：测试通过子类？GUT 里常用做法是直接给 `var model` 赋值 + 提供工厂方法 `_build_floor()` 可覆写。定：`func _build_model(floor_def: Object, floor_number: int) -> Object` 调 generator，测试子类覆写它注入手工 model。）

```gdscript
extends GutTest
## 回合调度：行动结算、怪物 AI、楼层递进、游戏结束。

const TurnScheduler = preload("res://src/core/turn_scheduler.gd")
const DungeonModel = preload("res://src/core/dungeon_model.gd")
const DungeonGenerator = preload("res://src/core/dungeon_generator.gd")
const Actor = preload("res://src/core/actor.gd")
const PlayerDef = preload("res://src/core/player_def.gd")
const MonsterDef = preload("res://src/core/monster_def.gd")
const ItemDef = preload("res://src/core/item_def.gd")
const FloorDef = preload("res://src/core/floor_def.gd")
const GameEvents = preload("res://src/core/events.gd")

## 手工布局的可测调度器：绕过生成器，用给定 model。
class TestScheduler:
	extends TurnScheduler
	var injected_model: Object = null
	func _build_model(_floor_def: Object, _floor_number: int) -> Object:
		return injected_model

func _player_def() -> Object:
	var d = PlayerDef.new()
	d.max_hp = 20
	d.atk = 5
	d.defense = 1
	d.sight_radius = 6
	d.xp_base = 10
	d.xp_growth = 5
	d.hp_per_level = 5
	d.atk_per_level = 1
	d.defense_per_level = 1
	return d

func _rat(pos: Vector2i, hp := 3, atk := 2) -> Object:
	var d = MonsterDef.new()
	d.id = "rat"
	d.display_name = "窟鼠"
	d.max_hp = hp
	d.atk = atk
	d.defense = 0
	d.sight_radius = 6
	d.xp_reward = 3
	return Actor.from_monster_def(d, pos)

func _flat_model(w := 7, h := 7) -> Object:
	var m = DungeonModel.new(w, h)
	for y in h:
		for x in w:
			m.set_tile(Vector2i(x, y), DungeonModel.Tile.FLOOR)
	return m

func _scheduler_with(model: Object, floor_count := 2) -> Object:
	var s = TestScheduler.new(_player_def(), [], 42)
	s.injected_model = model
	s.model = model
	s.player = model.player
	s.floor_defs = []
	for i in floor_count:
		s.floor_defs.append(FloorDef.new())  # 占位层定义（注入模式不真正生成）
	return s

func _place_player_and_stairs(m: Object) -> void:
	var player = Actor.from_player_def(_player_def())
	player.pos = Vector2i(3, 3)
	m.add_actor(player)
	m.stairs_pos = Vector2i(6, 6)
	m.set_tile(m.stairs_pos, DungeonModel.Tile.STAIRS)

func test_move_emits_event_and_updates_fov() -> void:
	var m = _flat_model()
	_place_player_and_stairs(m)
	var s = _scheduler_with(m)
	var events = s.player_action(GameEvents.ACTION_MOVE, Vector2i(1, 0))
	assert_eq(events.size(), 1)
	assert_eq(events[0].type, GameEvents.MOVED)
	assert_eq(s.player.pos, Vector2i(4, 3))
	assert_true(m.visible.has(Vector2i(4, 3)))

func test_move_into_wall_consumes_no_turn() -> void:
	var m = _flat_model()
	_place_player_and_stairs(m)
	m.set_tile(Vector2i(4, 3), DungeonModel.Tile.WALL)
	var s = _scheduler_with(m)
	var events = s.player_action(GameEvents.ACTION_MOVE, Vector2i(1, 0))
	assert_eq(events, [])
	assert_eq(s.player.pos, Vector2i(3, 3))

func test_move_into_monster_attacks_instead() -> void:
	var m = _flat_model()
	_place_player_and_stairs(m)
	var rat = _rat(Vector2i(4, 3))
	m.add_actor(rat)
	var s = _scheduler_with(m)
	var events = s.player_action(GameEvents.ACTION_MOVE, Vector2i(1, 0))
	assert_eq(events[0].type, GameEvents.ATTACKED)
	assert_eq(s.player.pos, Vector2i(3, 3))  # 没有移动
	assert_eq(rat.hp, 0)  # 5 atk - 0 def = 5 >= 3 hp
	assert_eq(events[1].type, GameEvents.DIED)
	# 击杀得经验
	assert_eq(events[2].type, GameEvents.XP_GAINED)
	assert_eq(m.monsters.size(), 0)

func test_monster_chases_and_attacks_when_adjacent() -> void:
	var m = _flat_model()
	_place_player_and_stairs(m)
	var rat = _rat(Vector2i(5, 3))
	m.add_actor(rat)
	var s = _scheduler_with(m)
	# 玩家在 (3,3)，鼠在 (5,3)，距离 2。玩家原地等待 -> 鼠逼近到 (4,3)
	s.player_action(GameEvents.ACTION_WAIT)
	assert_eq(rat.pos, Vector2i(4, 3))
	# 再等待 -> 鼠相邻 -> 攻击玩家
	var events = s.player_action(GameEvents.ACTION_WAIT)
	var attacked := events.filter(func(e): return e.type == GameEvents.ATTACKED)
	assert_eq(attacked.size(), 1)
	assert_eq(attacked[0].data.attacker_id, "rat")

func test_dead_monster_does_not_act() -> void:
	var m = _flat_model()
	_place_player_and_stairs(m)
	var rat = _rat(Vector2i(4, 3), 1)  # 1 hp
	m.add_actor(rat)
	var s = _scheduler_with(m)
	# 玩家攻击杀死鼠；之后无任何怪物事件
	var events = s.player_action(GameEvents.ACTION_MOVE, Vector2i(1, 0))
	for e in events:
		assert_ne(e.get("data", {}).get("attacker_id", ""), "rat")

func test_player_death_emits_game_over_and_blocks_input() -> void:
	var m = _flat_model()
	_place_player_and_stairs(m)
	m.player.hp = 1
	var ogre = _rat(Vector2i(4, 3), 20, 10)
	ogre.id = "ogre"
	m.add_actor(ogre)
	var s = _scheduler_with(m)
	var events = s.player_action(GameEvents.ACTION_WAIT)  # 鼠相邻攻击
	assert_eq(events.back().type, GameEvents.GAME_OVER)
	assert_true(s.is_game_over)
	var again = s.player_action(GameEvents.ACTION_WAIT)
	assert_eq(again, [])

func test_pickup_on_move() -> void:
	var m = _flat_model()
	_place_player_and_stairs(m)
	var potion = ItemDef.new()
	potion.id = "potion_minor"
	potion.kind = "potion"
	potion.power = 5
	m.add_item("potion_minor", Vector2i(4, 3))
	var s = _scheduler_with(m)
	var events = s.player_action(GameEvents.ACTION_MOVE, Vector2i(1, 0))
	var picked := events.filter(func(e): return e.type == GameEvents.PICKED_UP)
	assert_eq(picked.size(), 1)
	assert_eq(picked[0].data.item_id, "potion_minor")
	assert_true(m.item_at(Vector2i(4, 3)).is_empty())
	assert_eq(s.inventory.size(), 1)

func test_descend_generates_new_floor_and_wins_on_last() -> void:
	# 真生成器版：2 层配置
	var gen_defs: Array = []
	for i in 2:
		var f = FloorDef.new()
		f.width = 25
		f.height = 15
		f.room_count_min = 3
		f.room_count_max = 4
		f.monster_count_min = 0
		f.monster_count_max = 0
		f.item_count_min = 0
		f.item_count_max = 0
		gen_defs.append(f)
	var s = TurnScheduler.new(_player_def(), gen_defs, 7)
	var start_events = s.start()
	assert_eq(start_events[0].type, GameEvents.FLOOR_CHANGED)
	assert_eq(s.model.floor_number, 1)
	# 传送到楼梯（测试便利：直接改坐标）
	s.player.pos = s.model.stairs_pos
	var desc = s.player_action(GameEvents.ACTION_DESCEND)
	var types := {}
	for e in desc:
		types[e.type] = true
	assert_true(types.has(GameEvents.DESCENDED))
	assert_true(types.has(GameEvents.FLOOR_CHANGED))
	assert_eq(s.model.floor_number, 2)
	# 第 2 层是末层 -> 下楼 = 通关
	s.player.pos = s.model.stairs_pos
	var won = s.player_action(GameEvents.ACTION_DESCEND)
	assert_eq(won.back().type, GameEvents.GAME_WON)
	assert_true(s.is_won)

func test_descend_off_stairs_consumes_no_turn() -> void:
	var m = _flat_model()
	_place_player_and_stairs(m)
	var s = _scheduler_with(m)
	assert_eq(s.player_action(GameEvents.ACTION_DESCEND), [])
```

- [ ] **Step 2: 跑测试确认失败**
Expected: FAIL

- [ ] **Step 3: 写实现** `src/core/turn_scheduler.gd`

```gdscript
class_name TurnScheduler
extends RefCounted
## 一局游戏的规则层门面：玩家行动 -> 怪物回合 -> 事件流。
## 楼层递进也在这里完成（descend 时生成新 model）。

var model: Object = null
var player: Object = null
var inventory: Object
var rng: RandomNumberGenerator
var is_game_over := false
var is_won := false
var floor_index := 0
var floor_defs: Array = []
var _player_def: Object

const _DungeonGenerator = preload("res://src/core/dungeon_generator.gd")
const _FOV = preload("res://src/core/fov.gd")
const _Combat = preload("res://src/core/combat.gd")
const _Inventory = preload("res://src/core/inventory.gd")
const _GameEvents = preload("res://src/core/events.gd")

func _init(p_player_def: Object, p_floor_defs: Array, seed_value: int = -1) -> void:
	_player_def = p_player_def
	floor_defs = p_floor_defs
	rng = RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	inventory = _Inventory.new()

## 可测试点：生成一层的模型。测试子类可覆写注入手工布局。
func _build_model(floor_def: Object, floor_number: int) -> Object:
	var gen := _DungeonGenerator.new(rng.randi())
	return gen.generate(floor_def, floor_number)

func start() -> Array:
	return _enter_floor(0)

func _enter_floor(index: int) -> Array:
	floor_index = index
	var floor_def: Object = floor_defs[index]
	if model == null:
		model = _build_model(floor_def, index + 1)
		player = model.player
		# 生成器默认建玩家，替换为带成长曲线的正式玩家
		model.monsters = model.monsters  # no-op，保持结构清晰
	else:
		model = _build_model(floor_def, index + 1)
		player = model.player
	return [{"type": _GameEvents.FLOOR_CHANGED, "pos": player.pos,
		"data": {"floor_number": model.floor_number}}]
```

等等——注入测试模式下 `model.player` 是测试放置的玩家（`_place_player_and_stairs` 已放入）。`_scheduler_with` 里直接赋值 `s.model/s.player`，不走 `_enter_floor`。真流程（`test_descend_generates_new_floor_and_wins_on_last`）走 `start()`。两个路径都要成立。上面 `_enter_floor` 里 `player = model.player`——生成器建的是默认 PlayerDef 玩家，而 scheduler 需要 `_player_def` 的玩家。修正：`_build_model` 后强制重建玩家：

```gdscript
func _enter_floor(index: int) -> Array:
	floor_index = index
	model = _build_model(floor_defs[index], index + 1)
	player = load("res://src/core/actor.gd").from_player_def(_player_def())
	player.pos = model.player.pos
	model.player = player  # 替换生成器的默认玩家
	return [{"type": _GameEvents.FLOOR_CHANGED, "pos": player.pos,
		"data": {"floor_number": model.floor_number}}]
```

（生成器创建的默认玩家被替换掉，保留其出生坐标。inventory 跨楼层保留。）继续主实现：

```gdscript
func player_action(action: String, dir: Vector2i = Vector2i.ZERO) -> Array:
	if is_game_over or is_won:
		return []
	var events: Array = []
	match action:
		_GameEvents.ACTION_WAIT:
			events.append({"type": _GameEvents.WAITED, "pos": player.pos, "data": {}})
		_GameEvents.ACTION_MOVE:
			events = _try_move(dir)
			if events.is_empty():
				return []  # 撞墙不消耗回合
		_GameEvents.ACTION_DESCEND:
			return _try_descend()
		_:
			return []
	events.append_array(_monsters_turn())
	_check_player_death(events)
	if not is_game_over:
		_update_fov()
	return events

func _try_move(dir: Vector2i) -> Array:
	var target: Vector2i = player.pos + dir
	if not model.is_walkable(target):
		return []
	var blocker: Object = model.actor_at(target)
	if blocker != null:
		var events := _Combat.attack(player, blocker)
		_grant_kill_xp(events, blocker)
		return events
	var from: Vector2i = player.pos
	player.pos = target
	var events: Array = [{"type": _GameEvents.MOVED, "pos": target,
		"data": {"actor_id": player.id, "from": from}}]
	var ground: Dictionary = model.item_at(target)
	if not ground.is_empty():
		inventory.add(load("res://src/core/item_def.gd").new())  # 占位行，下一行替换：
	return events
```

上面最后两行是错的——拾取要拿到**真正的 ItemDef**。问题：`model.items` 只存 item_id 字符串，没有 def。拾取事件要带 item_name、背包要存 def。修正：`DungeonGenerator` 撒点时存 def 引用：`model.add_item` 的字典扩展为 `{item_id, pos, def}`（def 可空——测试 `_flat_model` 里 `add_item("potion_minor", pos)` 没给 def，拾取事件 data 用 id 兜底）。Inventory.add 签名是 `add(def)`——无 def 时构造空 ItemDef？不好。

最终定案：`model.items` 元素 `{item_id: String, pos: Vector2i, def: Object 可空}`。scheduler 拾取：

```gdscript
	var ground: Dictionary = model.item_at(target)
	if not ground.is_empty():
		var def: Object = ground.get("def", null)
		if def == null:
			def = load("res://src/core/item_def.gd").new()
			def.id = ground.item_id
		inventory.add(def)
		model.remove_item(target)
		events.append({"type": _GameEvents.PICKED_UP, "pos": target,
			"data": {"item_id": ground.item_id, "item_name": def.display_name}})
```

继续：

```gdscript
func _try_descend() -> Array:
	if player.pos != model.stairs_pos:
		return []
	if floor_index >= floor_defs.size() - 1:
		is_won = true
		return [{"type": _GameEvents.GAME_WON, "pos": player.pos,
			"data": {"floor_number": model.floor_number}}]
	var events: Array = [{"type": _GameEvents.DESCENDED, "pos": player.pos, "data": {}}]
	events.append_array(_enter_floor(floor_index + 1))
	_update_fov()
	return events

func _monsters_turn() -> Array:
	var events: Array = []
	for mon in model.monsters.duplicate():
		if is_game_over:
			break
		if mon.hp <= 0:
			continue
		if absi(mon.pos.x - player.pos.x) + absi(mon.pos.y - player.pos.y) == 1:
			events.append_array(_Combat.attack(mon, player))
			continue
		var can_see: bool = _FOV.compute(model, mon.pos, mon.sight_radius).has(player.pos)
		if can_see:
			events.append_array(_monster_step_toward(mon))
		elif rng.randf() < 0.25:
			var dir: Vector2i = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT][rng.randi_range(0, 3)]
			_try_monster_move(mon, mon.pos + dir)
	return events

func _monster_step_toward(mon: Object) -> void:
	var dx: int = signi(player.pos.x - mon.pos.x)
	var dy: int = signi(player.pos.y - mon.pos.y)
	var candidates: Array = []
	if absi(player.pos.x - mon.pos.x) >= absi(player.pos.y - mon.pos.y):
		candidates = [Vector2i(dx, 0), Vector2i(0, dy)]
	else:
		candidates = [Vector2i(0, dy), Vector2i(dx, 0)]
	for c in candidates:
		if c == Vector2i.ZERO:
			continue
		if _try_monster_move(mon, mon.pos + c):
			break

func _try_monster_move(mon: Object, target: Vector2i) -> bool:
	if not model.is_walkable(target):
		return false
	if model.is_occupied(target):
		return false
	mon.pos = target
	return true

func _grant_kill_xp(events: Array, victim: Object) -> void:
	if victim.hp > 0 or victim.is_player:
		return
	var xp: int = victim.xp_reward
	if xp > 0:
		events.append({"type": _GameEvents.XP_GAINED, "pos": player.pos,
			"data": {"amount": xp}})
	events.append_array(player.gain_xp(xp))

func _check_player_death(events: Array) -> void:
	if player.hp <= 0:
		is_game_over = true
		events.append({"type": _GameEvents.GAME_OVER, "pos": player.pos,
			"data": {"floor_number": model.floor_number}})

func _update_fov() -> void:
	model.remember_fov(_FOV.compute(model, player.pos, player.sight_radius))
```

注意 1：`_monsters_turn` 里 `model.monsters.duplicate()`——死亡移除时安全遍历（`remove_actor` 由谁调？战斗死亡后需要 `model.remove_actor(victim)`。加在 `_grant_kill_xp` 里：`model.remove_actor(victim)`。哦但 `_grant_kill_xp` 名字不贴切了。改名 `_after_kill(events, victim)`：移除尸体 + 发经验 + 升级事件。）

注意 2：测试 `test_monster_chases_and_attacks_when_adjacent` 中 `_scheduler_with` 构造的 TestScheduler 用 `TestScheduler.new(_player_def(), [], 42)`——`floor_defs` 空数组在 `_try_descend` 时 `floor_index >= -1` 恒真 → 楼梯上 descend 直接 game_won。测试里不测这个路径（注入模式测试不 descend）。OK。

注意 3：`_scheduler_with` 直接赋值 `s.model/s.player/s.floor_defs`——TestScheduler 不调 start()。`player_action` 用 `model`/`player` 都已就位。可行。

注意 4：GDScript 中同一函数内 `var events` 不能重复声明——`_try_move` 里 blocker 分支声明 `var events := ...`，后面又 `var events: Array = [...]`。合并写法避免重复声明（用 if/else 单一声明）。执行时注意。

- [ ] **Step 4: 跑测试确认通过**
Expected: `9 passed 0 failed`

- [ ] **Step 5: 提交**

```bash
git add src/core/turn_scheduler.gd tests/unit/test_turn_scheduler.gd
git commit -m "feat: 回合调度 + 怪物 AI + 楼层递进（含 GUT 测试）"
```

---

### Task 9: TurnManager 接线 + 全局集成冒烟 + README

**Files:**
- Modify: `src/autoload/turn_manager.gd`
- Test: `tests/unit/test_integration_smoke.gd`
- Create: `README.md`

**Interfaces:**
- Consumes: `TurnScheduler` 全部接口
- Produces（板块 2/3 渲染与 UI 依赖的最终门面）:
  - `TurnManager.start_new_game(player_def: Object, floor_defs: Array, seed_value: int = -1) -> Array`（内部建 TurnScheduler 并调 start，广播事件）
  - `TurnManager.player_action(action: String, dir: Vector2i = Vector2i.ZERO) -> Array`（转发 scheduler；每次 `events_processed.emit(events)`）
  - `TurnManager.scheduler: Object`（渲染/UI 查询 model/ player/inventory 用）
  - 信号 `events_processed(events: Array)`

- [ ] **Step 1: 写集成冒烟测试** `tests/unit/test_integration_smoke.gd`

```gdscript
extends GutTest
## 集成冒烟：规则层组合跑通"开局 -> 移动 -> 捡道具 -> 用药水 -> 下楼"。

const TurnManagerScript = preload("res://src/autoload/turn_manager.gd")
const PlayerDef = preload("res://src/core/player_def.gd")
const MonsterDef = preload("res://src/core/monster_def.gd")
const ItemDef = preload("res://src/core/item_def.gd")
const FloorDef = preload("res://src/core/floor_def.gd")
const GameEvents = preload("res://src/core/events.gd")

func _defs() -> Array:
	var floors: Array = []
	var rat = MonsterDef.new()
	rat.id = "rat"
	rat.max_hp = 2
	var potion = ItemDef.new()
	potion.id = "potion_minor"
	potion.kind = "potion"
	potion.power = 5
	for i in 3:
		var f = FloorDef.new()
		f.width = 30
		f.height = 20
		f.room_count_min = 4
		f.room_count_max = 5
		f.monster_count_min = 1
		f.monster_count_max = 2
		f.item_count_min = 1
		f.item_count_max = 2
		f.monster_spawns = [{"def": rat, "weight": 1}]
		f.item_spawns = [{"def": potion, "weight": 1}]
		floors.append(f)
	return floors

func test_full_game_loop_smoke() -> void:
	var tm = TurnManagerScript.new()
	var start_events = tm.start_new_game(PlayerDef.new(), _defs(), 2026)
	assert_eq(start_events[0].type, GameEvents.FLOOR_CHANGED)
	var s = tm.scheduler
	var total_events := 0
	# 随机走 60 回合（固定种子），规则层不允许崩溃
	var rng = RandomNumberGenerator.new()
	rng.seed = 99
	var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for i in 60:
		if s.is_game_over or s.is_won:
			break
		var events = tm.player_action(GameEvents.ACTION_MOVE, dirs[rng.randi_range(0, 3)])
		total_events += events.size()
		for e in events:
			assert_true(e.has("type") and e.has("pos") and e.has("data"), "事件结构完整")
	# 楼梯可达性（生成器已保证），下楼到通关或死亡为止
	var guard := 0
	while not s.is_game_over and not s.is_won and guard < 50:
		guard += 1
		s.player.pos = s.model.stairs_pos  # 测试直通车：瞬移下楼
		tm.player_action(GameEvents.ACTION_DESCEND, Vector2i.ZERO)
	assert_true(s.is_game_over or s.is_won, "3 层内游戏应结束")
	assert_true(total_events > 0)
	tm.free()
```

- [ ] **Step 2: 跑测试确认失败**（TurnManager 尚无实现）
Expected: FAIL

- [ ] **Step 3: 填实 TurnManager** `src/autoload/turn_manager.gd`

```gdscript
extends Node
## 全局调度单例：接收输入 -> 调规则层（TurnScheduler）-> 把事件广播给渲染/UI。

signal events_processed(events: Array)

var scheduler: Object = null

func start_new_game(player_def: Object, floor_defs: Array, seed_value: int = -1) -> Array:
	scheduler = load("res://src/core/turn_scheduler.gd").new(player_def, floor_defs, seed_value)
	var events: Array = scheduler.start()
	events_processed.emit(events)
	return events

func player_action(action: String, dir: Vector2i = Vector2i.ZERO) -> Array:
	if scheduler == null:
		return []
	var events: Array = scheduler.player_action(action, dir)
	if not events.is_empty():
		events_processed.emit(events)
	return events
```

注意：GUT 集成测试里 `TurnManagerScript.new()` 创建的是裸 Node（未注册为 autoload），`free()` 清理；autoload 场景运行时用 `TurnManager` 全局名访问同一 API。

- [ ] **Step 4: 全量回归**

Run: `"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: 全部通过（约 40 个测试，0 failed）

- [ ] **Step 5: 写 README** `README.md`

```markdown
# RoguelikeDemo

传统回合制地牢爬行 roguelike 可玩 demo（Godot 4 回合制地牢，像素风）。

## 当前状态

- 板块 0（工程骨架）与板块 1（玩法核心规则层）完成：随机地牢生成、回合制战斗、
  视野、背包、3 层递进、死亡/通关结算，全部规则层有 GUT 单元测试。
- 表现层（渲染/UI）与数值表见后续计划（docs/superpowers/plans/）。

## 本地运行测试

1. 安装 Godot 4.7 标准版（官网绿色 exe 即可）。
2. 仓库根目录执行：

```bash
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

3. 编辑器打开工程后 F5 可运行占位主场景（表现层接入前）。

## 架构速览

规则层 `src/core/`（纯 GDScript，无场景依赖，GUT 全测）：
DungeonModel / DungeonGenerator / TurnScheduler / Combat / FOV / Inventory / Def 数据类。
调度单例 `src/autoload/turn_manager.gd`：输入 -> 规则层 -> 事件流广播。
表现层通过消费事件字典 `{type, pos, data}` 驱动，不修改规则层状态。
```

- [ ] **Step 6: 提交**

```bash
git add src/autoload/turn_manager.gd tests/unit/test_integration_smoke.gd README.md
git commit -m "feat: TurnManager 门面接线 + 集成冒烟 + README（板块0+1 完成）"
```

---

## Self-Review 记录

- Spec 覆盖：spec §4.1 规则层六要素（DungeonModel✓DungeonGenerator✓TurnScheduler✓Combat✓FOV✓事件流✓）、§4.2 接口要点（伤害公式✓最小1✓经验升级✓贪心逼近✓随机游走✓）、§4.3 数据类（4 个 Def✓，.tres 表归板块4）、§4.4 工程结构（目录✓）、§4.5 操作约定（输入映射✓四方向✓自动拾取✓空格/回车下楼✓）、§5 板块0（输入映射/TurnManager/GUT 空测试✓）、§7 测试策略（固定种子✓连通性✓最小1边界✓死亡不行动✓墙挡视线✓）。M0"粉色方块走格"被 M1 真地牢直接覆盖（板块0产出=可运行空工程，以板块表为准）。
- 占位扫描：无 TBD/TODO；Task 8 的 GDScript 变量重复声明风险已标注执行注意。
- 类型一致性：事件字段（type/pos/data）跨任务一致；`defense`（非 def）跨 Actor/Def/Combat 一致；`GameEvents` 常量名被 Task 7/8/9 一致引用；`Inventory.add(def)` 与拾取处传 ItemDef 一致；`model.items` 元素含可选 `def` 字段已在 Task 8 定案。
