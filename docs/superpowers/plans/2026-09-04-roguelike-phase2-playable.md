# Roguelike Demo 板块2+3（渲染与 UI 可玩切片）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把规则层接到画面上：F5 进入主菜单 → 开局 → 色块风格地牢渲染 + 走位补间 + 战斗 + 楼层递进 + HUD/日志 + 死亡/通关结算 + 重开，达成 spec 里程碑 M1+M2+M3 的可玩状态。

**Architecture:** 表现层只消费 `TurnManager.events_processed` 事件与 `TurnManager.scheduler.model` 查询，不修改规则层状态（spec §4.1）。地牢用运行时生成的 TileSet（程序化纯色纹理，色块占位，spec §3 素材三步走第一步）；实体用 `Sprite2D` + `ImageTexture` 纯色方形，glyph 无关；镜头跟随玩家，Tween 做走位补间。

**Tech Stack:** Godot 4.7 / GDScript / TileMapLayer（4.3+ API）/ Tween / 规则层（板块 1，接口冻结）。

**Spec:** `docs/superpowers/specs/2026-09-04-roguelike-demo-design.md`（§4.1 数据流、§4.5 像素约定、§5 板块 2/3、§6 里程碑 M1-M3）

## Global Constraints

- 逻辑坐标换算：世界坐标 = 格坐标 * 16（`TILE_SIZE := 16`，常量在 `src/rendering/view_constants.gd`）。
- 表现层禁止修改规则层对象状态；只读查询 + 事件消费。
- 像素约定（spec §4.5）：纹理过滤 Nearest（project.godot 已设）、stretch viewport + integer。
- 四方向输入（project.godot 已映射 move_up/down/left/right、descend）。
- 事件消费表（渲染层）：`moved`→补间位移；`died`→淡出后移除节点；`floor_changed`→全量重建；`attacked`→攻击方小幅冲刺回弹；`picked_up`→日志；`game_over`/`game_won`→结算层显示。
- UI 消费表：`waited/descended/attacked/healed/equipped/leveled_up/xp_gained/picked_up/use_failed`→写日志；`moved` 不写。
- 每个里程碑一次 git 提交；表现层不写自动化测试（spec §7），用 headless 冒烟（场景实例化 + 跑帧无脚本错误）+ 规则层 41 测试回归。

---

### Task 10: 视图常量 + 地牢渲染同步器

**Files:**
- Create: `src/rendering/view_constants.gd`
- Create: `src/rendering/dungeon_renderer.gd`（挂在 TileMapLayer 节点上的脚本）

**Interfaces:**
- Produces:
  - `ViewConstants.TILE_SIZE := 16`；`static func cell_to_world(pos: Vector2i) -> Vector2`（格中心：`pos * 16 + (8, 8)`）；`static func world_to_cell(p: Vector2) -> Vector2i`
  - `DungeonRenderer.rebuild(model) -> void`：全量重建瓦片（`floor_changed` 用），并创建/更新纯色 TileSet：墙=深灰(0.22,0.22,0.26)、地=暖灰(0.45,0.4,0.36)、楼梯=金色(0.9,0.75,0.3)；未探索格（`model.explored` 无）画纯黑、已探索但不可见画暗色（亮度乘 0.45），用两套备用瓦片（暗墙/暗地）实现简易迷雾
  - `DungeonRenderer.refresh_fog(model) -> void`：每回合按 `visible/explored` 重刷迷雾瓦片
- 依赖：`TileMapLayer.tile_set` 运行时构建：`TileSet.new()` + `TileSetAtlasSource`（一张 6x1 的 16px 纹理：墙/地/楼梯/暗墙/暗地/黑），`source.texture_origin` 默认

- [ ] **Step 1: 写 view_constants.gd**

```gdscript
class_name ViewConstants
extends RefCounted
## 表现层视图常量与坐标换算。

const TILE_SIZE := 16

static func cell_to_world(pos: Vector2i) -> Vector2:
	return Vector2(pos) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) / 2.0

static func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i((p / TILE_SIZE).floor())
```

- [ ] **Step 2: 写 dungeon_renderer.gd**

```gdscript
class_name DungeonRenderer
extends TileMapLayer
## 规则层 DungeonModel -> 瓦片渲染同步器（含简易迷雾）。只读模型。

# atlas 瓦片索引
const T_WALL := 0
const T_FLOOR := 1
const T_STAIRS := 2
const T_WALL_DIM := 3
const T_FLOOR_DIM := 4
const T_BLACK := 5

const COLORS := [
	Color(0.22, 0.22, 0.26),  # 墙
	Color(0.45, 0.40, 0.36),  # 地
	Color(0.90, 0.75, 0.30),  # 楼梯
	Color(0.22, 0.22, 0.26) * 0.45,  # 暗墙
	Color(0.45, 0.40, 0.36) * 0.45,  # 暗地
	Color(0.05, 0.05, 0.06),  # 未探索
]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tile_set = _build_tile_set()

func _build_tile_set() -> TileSet:
	var img := Image.create(COLORS.size() * ViewConstants.TILE_SIZE, ViewConstants.TILE_SIZE, false, Image.FORMAT_RGB8)
	for i in COLORS.size():
		img.fill_rect(Rect2i(i * ViewConstants.TILE_SIZE, 0, ViewConstants.TILE_SIZE, ViewConstants.TILE_SIZE), COLORS[i])
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(ViewConstants.TILE_SIZE, ViewConstants.TILE_SIZE)
	for i in COLORS.size():
		src.create_tile(Vector2i(i, 0))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(ViewConstants.TILE_SIZE, ViewConstants.TILE_SIZE)
	ts.add_source(src, 0)
	return ts

func rebuild(model: Object) -> void:
	clear()
	for y in model.height:
		for x in model.width:
			_paint_cell(model, Vector2i(x, y))

func refresh_fog(model: Object) -> void:
	for y in model.height:
		for x in model.width:
			_paint_cell(model, Vector2i(x, y))

func _paint_cell(model: Object, pos: Vector2i) -> void:
	var t: int = model.tile_at(pos)
	var idx := T_BLACK
	if model.explored.has(pos):
		if model.visible.has(pos):
			match t:
				DungeonModel.Tile.WALL: idx = T_WALL
				DungeonModel.Tile.STAIRS: idx = T_STAIRS
				_: idx = T_FLOOR
		else:
			match t:
				DungeonModel.Tile.WALL: idx = T_WALL_DIM
				_: idx = T_FLOOR_DIM
	set_cell(pos, 0, Vector2i(idx, 0))
```

- [ ] **Step 3: headless 冒烟**（Task 14 统一跑）

---

### Task 11: 实体视图与走位补间

**Files:**
- Create: `src/rendering/actor_view.gd`（单实体节点）
- Create: `src/rendering/entity_layer.gd`（实体容器：按事件增删移实体节点）

**Interfaces:**
- Consumes: `ViewConstants.cell_to_world`、事件字典（板块 1）
- Produces:
  - `ActorView.setup(actor: Object, color: Color) -> void`（玩家 `@` 色 (0.9,0.9,0.95)、怪物红系 (0.85,0.3,0.25)）；`ActorView.slide_to(cell: Vector2i) -> void`（0.08s Tween 位移）；`ActorView.die() -> Tween`（0.2s 淡出，结束后 queue_free 由 EntityLayer 处理）
  - `EntityLayer.spawn_from_model(model) -> void`（floor_changed 全量：玩家 + 怪物各建 ActorView，`meta("actor_ref")` 存规则层对象）
  - `EntityLayer.consume(events: Array) -> void`：消费 `moved`（找对应节点 slide_to）、`died`（淡出移除）
  - `EntityLayer.player_view(model) -> ActorView`（镜头跟随用）

实现要点（actor_view.gd）：

```gdscript
class_name ActorView
extends Sprite2D

func setup(actor: Object, color: Color) -> void:
	var img := Image.create(12, 12, false, Image.FORMAT_RGB8)
	img.fill(color)
	texture = ImageTexture.create_from_image(img)
	position = ViewConstants.cell_to_world(actor.pos)
	set_meta("actor_ref", actor)

func slide_to(cell: Vector2i) -> void:
	var tw := create_tween()
	tw.tween_property(self, "position", ViewConstants.cell_to_world(cell), 0.08)

func play_attack(target_cell: Vector2i) -> void:
	var origin := position
	var tw := create_tween()
	tw.tween_property(self, "position", ViewConstants.cell_to_world(target_cell), 0.05)
	tw.tween_property(self, "position", origin, 0.05)

func die() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)
```

entity_layer.gd 消费 `moved`：按 `data.actor_id` 与 `meta("actor_ref").id` 匹配；玩家 id 恒为 `"player"`。

- [ ] **Step 1: 写 actor_view.gd / entity_layer.gd**（结构如上，entity_layer 完整实现）

```gdscript
class_name EntityLayer
extends Node2D
## 实体精灵容器：按事件同步显示，不触碰规则层状态。

func spawn_from_model(model: Object) -> void:
	for child in get_children():
		child.queue_free()
	if model.player != null:
		var pv := ActorView.new()
		pv.setup(model.player, Color(0.9, 0.9, 0.95))
		add_child(pv)
	for mon in model.monsters:
		var mv := ActorView.new()
		mv.setup(mon, Color(0.85, 0.3, 0.25))
		add_child(mv)

func consume(events: Array) -> void:
	for e in events:
		match e.type:
			"moved":
				var v := _find_view(e.data.actor_id)
				if v != null:
					v.slide_to(e.pos)
			"attacked":
				var av := _find_view(e.data.attacker_id)
				if av != null:
					av.play_attack(e.pos)
			"died":
				var dv := _find_view(e.data.actor_id)
				if dv != null:
					dv.die()

func player_view() -> ActorView:
	return _find_view("player")

func _find_view(actor_id: String) -> ActorView:
	for child in get_children():
		if child.get_meta("actor_ref", null) != null and child.get_meta("actor_ref").id == actor_id:
			return child
	return null
```

注意：`died` 事件里怪物节点淡出后 queue_free，下一层 `spawn_from_model` 前需 `get_children()` 清理（queue_free 延迟一帧，用 `remove_child` + `queue_free` 双保险或直接在 spawn 时 `child.queue_free()` 后仍 add 新的——旧节点当帧仍在，短暂重叠可接受；更稳：spawn 前 `_clear_now()`：遍历 `remove_child(c)` + `c.free()`）。**决定用 `_clear_now()` 立即释放**，避免帧间残留。

---

### Task 12: 游戏主场景（输入 + 镜头 + 事件接线）

**Files:**
- Modify: `src/autoload/main.gd`（从占位改为游戏主控）
- Modify: `src/autoload/main.tscn`（节点树：Main(Node2D) → Dungeon(TileMapLayer+script) / Entities(Node2D+script) / Camera2D）
- Create: `src/autoload/game_config.gd`（默认 PlayerDef + 3 层 FloorDef 的代码构造，板块 4 会替换为 .tres 加载）

**Interfaces:**
- Consumes: `TurnManager` autoload（板块 1 门面）、DungeonRenderer、EntityLayer
- Produces: 完整游戏循环

game_config.gd（demo 内置数值，spec §4.3 玩家初始与 3 层配置的代码版）：

```gdscript
class_name GameConfig
extends RefCounted
## demo 内置数值：玩家 + 3 层地牢（板块 4 落地后由 .tres 表替换）。

static func player_def() -> Object:
	var d = load("res://src/core/player_def.gd").new()
	return d

static func floor_defs() -> Array:
	var rat = load("res://src/core/monster_def.gd").new()
	rat.id = "rat"
	rat.display_name = "窟鼠"
	rat.glyph = "r"
	rat.max_hp = 4
	rat.atk = 2
	rat.defense = 0
	rat.sight_radius = 5
	rat.xp_reward = 3
	var bat = load("res://src/core/monster_def.gd").new()
	bat.id = "bat"
	bat.display_name = "洞蝠"
	bat.glyph = "b"
	bat.max_hp = 3
	bat.atk = 3
	bat.defense = 0
	bat.sight_radius = 7
	bat.xp_reward = 4
	bat.ai_type = "wander"
	var skeleton = load("res://src/core/monster_def.gd").new()
	skeleton.id = "skeleton"
	skeleton.display_name = "骷髅卫兵"
	skeleton.glyph = "s"
	skeleton.max_hp = 8
	skeleton.atk = 4
	skeleton.defense = 1
	skeleton.sight_radius = 6
	skeleton.xp_reward = 7
	var potion = load("res://src/core/item_def.gd").new()
	potion.id = "potion_minor"
	potion.display_name = "小治疗药水"
	potion.kind = "potion"
	potion.power = 6
	var sword = load("res://src/core/item_def.gd").new()
	sword.id = "sword_rusty"
	sword.display_name = "锈剑"
	sword.kind = "weapon"
	sword.power = 1
	var mail = load("res://src/core/item_def.gd").new()
	mail.id = "leather_mail"
	mail.display_name = "皮甲"
	mail.kind = "armor"
	mail.power = 1

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
```

main.gd（游戏主控）：

```gdscript
extends Node2D
## 游戏主控：装配渲染层、转发输入到规则层、把事件分发给渲染与 UI。

const GameEvents = preload("res://src/core/events.gd")
const GameConfig = preload("res://src/autoload/game_config.gd")

var game_running := false

func _ready() -> void:
	randomize()
	%Entities.spawn_from_model_typed = false  # no-op 防误用；真实装配见 _start_game
	_start_game()

func _start_game() -> void:
	TurnManager.start_new_game(GameConfig.player_def(), GameConfig.floor_defs())
	var model = TurnManager.scheduler.model
	%Dungeon.rebuild(model)
	%Entities.spawn_from_model(model)
	%Camera.position = ViewConstants.cell_to_world(model.player.pos)
	%Hud.bind_game(self)
	%Hud.log("你醒在地牢第 1 层。方向键/WASD 移动，空格下楼。")
	game_running = true

func _unhandled_input(event: InputEvent) -> void:
	if not game_running:
		if event.is_action_pressed("descend"):
			_start_game()  # 结算画面按空格重开
		return
	var dir := Vector2i.ZERO
	if event.is_action_pressed("move_up"): dir = Vector2i.UP
	elif event.is_action_pressed("move_down"): dir = Vector2i.DOWN
	elif event.is_action_pressed("move_left"): dir = Vector2i.LEFT
	elif event.is_action_pressed("move_right"): dir = Vector2i.RIGHT
	elif event.is_action_pressed("descend"):
		_act(GameEvents.ACTION_DESCEND)
		return
	elif event.is_action_pressed("wait"):
		_act(GameEvents.ACTION_WAIT)
		return
	if dir != Vector2i.ZERO:
		_act(GameEvents.ACTION_MOVE, dir)

func _act(action: String, dir := Vector2i.ZERO) -> void:
	var events: Array = TurnManager.player_action(action, dir)
	if events.is_empty():
		return
	%Dungeon.refresh_fog(TurnManager.scheduler.model)
	%Entities.consume(events)
	%Hud.consume(events)
	var pv = %Entities.player_view()
	if pv != null:
		%Camera.position = ViewConstants.cell_to_world(pv.position_to_cell())
```

说明与修正点（执行时落实）：
- `%` 唯一名引用需要在场景里设置 unique_name_in_owner；执行时给 Dungeon/Entities/Camera/Hud 节点勾选（.tscn 里 `unique_name_in_owner = true`）。
- `pv.position_to_cell()` 不存在——直接用 `ViewConstants.world_to_cell(pv.global_position)`。
- `_ready` 里那行 `%Entities.spawn_from_model_typed = false` 是废话，执行时删除；游戏循环就是 `_ready → _start_game`。
- Camera2D：`position_smoothing_enabled = true, position_smoothing_speed = 8`；limit 不设（跟随即可）。
- main.tscn 文本结构：

```
[gd_scene load_steps=5 format=3]
[ext_resource type="Script" path="res://src/autoload/main.gd" id="1"]
[ext_resource type="Script" path="res://src/rendering/dungeon_renderer.gd" id="2"]
[ext_resource type="Script" path="res://src/rendering/entity_layer.gd" id="3"]
[ext_resource type="Script" path="res://src/ui/hud.gd" id="4"]

[node name="Main" type="Node2D"]
script = ExtResource("1")

[node name="Dungeon" type="TileMapLayer" parent="."]
unique_name_in_owner = true
script = ExtResource("2")

[node name="Entities" type="Node2D" parent="."]
unique_name_in_owner = true
script = ExtResource("3")

[node name="Camera" type="Camera2D" parent="."]
unique_name_in_owner = true
position_smoothing_enabled = true
position_smoothing_speed = 8.0

[node name="Hud" type="CanvasLayer" parent="."]
unique_name_in_owner = true
script = ExtResource("4")
```

---

### Task 13: HUD、消息日志与结算

**Files:**
- Create: `src/ui/hud.gd`（CanvasLayer 脚本，运行时构建子控件）

**Interfaces:**
- Consumes: `TurnManager.scheduler`（只读：player hp/max_hp/level/xp/xp_to_next、floor_number、inventory）、事件数组
- Produces:
  - `bind_game(main: Object) -> void`；`log(msg: String) -> void`（最多保留 8 行）；`consume(events: Array) -> void`；`show_end(title: String, detail: String) -> void`；`hide_end() -> void`
  - 布局：右侧 320px 面板（HP 条 + 等级/经验/楼层/攻击/防御），底部左侧消息日志区（半透明黑底白字），事件→文案映射：
    - `attacked`→"{攻击方} 对 {防御方} 造成 {damage} 伤害"（名称查规则层？事件只有 id——demo 简化：id 直接显示，或 id→中文映射表写在 hud 里：player→你, rat→窟鼠, bat→洞蝠, skeleton→骷髅卫兵。**用映射表**）
    - `died`→"{名字} 倒下了"；is_player→"你死了……"
    - `xp_gained`→"获得 {amount} 经验"；`leveled_up`→"升级！Lv.{level}（回满血）"
    - `picked_up`→"拾取 {item_name}"；`healed`→"恢复 {amount} HP"；`equipped`→"装备 {item_id}（{stat}+{gain}）"
    - `descended`→"沿楼梯下行……"；`floor_changed`→"来到第 {floor_number} 层"
    - `game_over`→结算"你死了"，`game_won`→结算"通关！"
  - 结算层：全屏半透明黑 + 居中标题（你死了 / 地牢征服者！）+ 副标题（到达楼层 / 统计）+ "按空格重新开始"；主控 `game_running=false` 后 descend 重开（Task 12 已接）
  - HP 条：`ProgressBar`（max=max_hp），每回合 `consume` 末尾 `_refresh_stats()` 从 scheduler 拉取

hud.gd 全部控件 `_ready()` 里代码创建（避免 .tscn 里铺 UI 节点），锚点用 `set_anchors_preset`。

- [ ] **Step 1: 写 hud.gd**（按上述接口完整实现，事件文案映射表内置）

---

### Task 14: 集成验证 + 提交推送

- [ ] **Step 1: 规则层回归**：`"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` → 41/41 通过（表现层改动不得影响规则层）
- [ ] **Step 2: headless 冒烟**：`"$GODOT" --headless --path . --quit-after 60` → 无 SCRIPT ERROR（主场景装配 + 首层渲染 + HUD 构建在 headless 下执行；输入事件 headless 不模拟，规则层交互已由 41 测试覆盖）
- [ ] **Step 3: 提交推送**

```bash
git add src docs
git commit -m "feat: 板块2+3 可玩切片——渲染同步器/实体补间/镜头/HUD/日志/结算重开（M1-M3）"
git push origin main
```

## Self-Review 记录

- Spec 覆盖：§4.1 数据流（渲染/UI 只消费事件）✓；§4.5 像素约定（Nearest/viewport/整数缩放已由板块 0 设定）✓；§5 板块 2（同步器/镜头/补间）✓；板块 3（HUD/日志/结算；背包界面**明确延后**——道具"使用即生效"且拾取自动，背包 UI 属 M4 完整 HUD 范畴，spec M3 只要求"药水/武器/护甲生效"，生效路径已由规则层测试覆盖）✓；M1 能走动（渲染/镜头/撞墙）✓；M2 能打架（追击互攻死亡）✓；M3 有内容（三层道具结算重开）✓。
- 占位扫描：无 TBD；Task 12 修正点已内联标注（world_to_cell、删除废话行、unique_name_in_owner）。
- 类型一致性：事件字段与板块 1 `GameEvents` 常量一致；`ViewConstants.cell_to_world` 返回格中心，与 ActorView.setup 一致；`spawn_from_model(model)` 与 `_enter_floor` 后的 model 一致。
