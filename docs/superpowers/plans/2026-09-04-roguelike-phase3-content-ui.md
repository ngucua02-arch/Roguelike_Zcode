# Roguelike Demo 板块4+M4收尾（数值表 + 背包 + 导出预设）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 数值全部抽成编辑器可改的 .tres 数据表（spec 板块4："改数值不碰代码"）；补上背包界面（捡到的道具可点击使用，修复"药水无使用入口"的可玩性缺口）；写好 Windows/Web 导出预设。

**Architecture:** .tres 资源表替换 `game_config.gd` 内的代码构造数值，GameConfig 变成纯加载器；背包是 HUD 的一个覆盖面板，鼠标点击调用规则层 `Inventory.use(index, player)`，产生的事件照常走 `hud.consume` 文案流。回合制无需暂停世界，背包打开时只拦截键盘移动输入。

**Tech Stack:** Godot 4.7 / GDScript Resource(.tres) / 规则层接口（冻结不变）。

**Spec:** `docs/superpowers/specs/2026-09-04-roguelike-demo-design.md`（§4.3 数据资源、§4.5 背包操作约定"鼠标点击使用/装备"、§5 板块4/5）

## Global Constraints

- 数值以当前 `game_config.gd` 为准原样固化（用户试玩反馈"还行"），不调平衡。
- `src/core/` 规则层零改动；本计划只动 autoload/渲染/UI/资源/测试。
- .tres 引用脚本类（MonsterDef 等）依赖 class_name 全局注册，提交后需跑一次 `--import` 再测试。
- 背包键位：`bag` 输入映射 = B 键；背包打开时移动/下楼/等待输入全部忽略，B 关闭。
- 导出预设 `export_path` 指到项目外 `../build/`（不进 git）；导出模板（约 1GB）当前网络无法下载，预设文件先行，实际导出待模板就绪。
- 测试新增 `test_game_config.gd`（资源表完整性），与既有 41 测试一起全绿；可玩冒烟重跑。

---

### Task 15: 背包界面

**Files:**
- Modify: `project.godot`（加 `bag` 输入映射，B 键）
- Modify: `src/ui/hud.gd`（背包面板 + 刷新逻辑）
- Modify: `src/autoload/main.gd`（B 切换背包、打开时拦截移动输入、拾取时刷新）

**Interfaces:**
- Consumes: `TurnManager.scheduler.inventory.items`（元素 `{def, item_id}`）、`Inventory.use(index, player) -> Array`
- Produces:
  - `Hud.toggle_inventory() -> void`（开关面板，开时刷新格子）
  - `Hud.inventory_open: bool`
  - `Hud.refresh_inventory() -> void`（从 scheduler.inventory 重建按钮格子；拾取事件后若面板开着自动刷新）
  - 物品格子 = Button，文本 `"{glyph}\n{名称}"`，tooltip 按类型显示（药水：恢复 N 点 HP / 武器：攻击 +N / 护甲：防御 +N）；点击 → `Inventory.use` → `consume(事件)` → 刷新格子
- [ ] 实现 hud.gd 的 `_build_inventory_panel()`（PanelContainer 居中偏右，含标题"背包 (B 关闭)" + GridContainer 4 列）与上述接口；格子数量 = inventory.items.size()，空背包显示提示"空空如也"。
- [ ] main.gd `_unhandled_input`：`event.is_action_pressed("bag")` → `%Hud.toggle_inventory()` 并 return；`if %Hud.inventory_open: return`（拦截移动/下楼/等待）；拾取事件（picked_up）后调用 `%Hud.refresh_inventory()`。

### Task 16: .tres 数值表

**Files:**
- Create: `resources/player/player.tres`
- Create: `resources/monsters/rat.tres`、`bat.tres`、`skeleton.tres`
- Create: `resources/items/potion_minor.tres`、`sword_rusty.tres`、`leather_mail.tres`
- Create: `resources/floors/floor_1.tres`、`floor_2.tres`、`floor_3.tres`
- Modify: `src/autoload/game_config.gd`（改为 load .tres）
- Test: `tests/unit/test_game_config.gd`

**Interfaces:**
- Produces: `GameConfig.player_def()` 返回 `resources/player/player.tres`；`GameConfig.floor_defs()` 返回 3 个楼层 .tres 数组。字段值与现行 game_config 完全一致。
- [ ] 写 .tres 文件（`[gd_resource type="MonsterDef" format=3]` + `[resource]` 字段；FloorDef 的 `monster_spawns/item_spawns` 用 Dictionary 数组 + ExtResource 引用怪物/物品 .tres）
- [ ] GameConfig 改加载器；写 test_game_config.gd：玩家字段为正、3 层表齐全、每层 spawn 表权重和 > 0、`pick_monster/pick_item` 固定种子返回非 null、沿用现行数值断言（rat max_hp=4 / skeleton defense=1 等）

### Task 17: 导出预设 + README

**Files:**
- Create: `export_presets.cfg`（Windows Desktop → `../build/RoguelikeDemo.exe`，embed_pck 单文件；Web → `../build/web/index.html`）
- Modify: `README.md`（补"如何导出"一节：编辑器下载模板 → Project > Export 一键导出；或 CLI `godot --headless --export-release`）

### Task 18: 回归 + 提交推送

- [ ] `--import` 后 GUT 全量（41 + test_game_config 全绿）
- [ ] 可玩冒烟 `tests/smoke/smoke_main.tscn` 通过
- [ ] 提交推送（素材替换 Kenney 包下载受限，留待后续；色块版保持）

## Self-Review

- Spec 覆盖：§4.3 数据表 .tres ✓；§4.5 背包鼠标使用 ✓（B 开关 + 点击使用）；§5 板块4 产出资源文件 ✓；板块5 预设就绪、导出受模板下载限制已注明 ✓。
- 占位扫描：无 TBD。
- 类型一致性：Inventory.use/事件字段不变；.tres 字段名 = Def 类 @export 名（defense 非 def）；GameConfig 签名不变。
