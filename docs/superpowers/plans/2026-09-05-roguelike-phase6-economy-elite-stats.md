# Roguelike Demo 经济+精英+战绩 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 demo 引入 roguelike 决策深度三件套：金币经济与每层商人、随机精英怪（高价值击杀）、死亡/通关结算战绩。

**Architecture:** 金币走 ItemDef 新 kind="gold"（拾取加钱不进背包）；商人是 ai_type="shopkeeper" 的特殊 actor（不追不攻不被打，撞它=开商店）；商店库存每层从道具表抽 3 件、价格数据驱动（ItemDef.price）；精英在撒怪时 12% 概率出现（属性×1.6、经验×2、必掉道具）；统计在 TurnScheduler 累计并随 game_over/game_won 事件输出。表现层消费新事件：item_dropped / shop_open / bought。

**Tech Stack:** 不变。新增输入映射 `interact`=E。

**Spec:** `docs/superpowers/specs/2026-09-04-roguelike-demo-design.md`（§4.5 怪物约定扩展商人；第二梯队清单第 1/2/3 项为用户指定需求）

## Global Constraints

- 商人不可被攻击、不参与怪物回合（ai_type=="shopkeeper" 全跳过）；开商店/购买不消耗回合。
- 金币 kind="gold"：拾取 `player.gold += power`，不进背包、不计入 items_picked（计入 gold_earned）。
- 精英率 12%；属性 hp/atk 各 ×1.6 取整、xp_reward ×2；死亡必掉一件（从当前层 item_spawns 加权抽取，可以是金币）。
- 事件新增：`item_dropped{pos,data:{item_id,item_name}}`、`shop_open{pos,data:{stock:[{item_id,item_name,price,icon_coords}]}}`、`bought{pos,data:{item_id,item_name,price,gold}}`、`shop_failed{pos,data:{reason}}`；动作常量 `ACTION_SHOP="shop"`。
- 结算事件 game_over/game_won 的 data 增加 `stats`（kills/turns/gold_earned/items_picked/damage_dealt/damage_taken）。
- 全部既有测试 + 新增测试全绿；规则层改动必须有对应 GUT 测试。

---

### Task 25: 金币经济（规则层 + 数据）

**Files:**
- Modify: `src/core/actor.gd`（`var gold: int = 0`）
- Modify: `src/core/item_def.gd`（`@export var price: int = 0`）
- Modify: `src/core/turn_scheduler.gd`（`_try_move` 拾取分支：`def.kind == "gold"` → `player.gold += power`、`stats.gold_earned += power`，PICKED_UP 事件 item_name="N 金币"，不进背包）
- Create: `resources/items/gold.tres`（kind="gold"，power=10 面额，sprite (5,10) 橙蜡烛当金币堆；price=0）
- Modify: `resources/items/*.tres`（填 price：小药水15/大药水30/锈剑20/铁剑35/战斧50/皮甲25）
- Modify: `resources/floors/floor_*.tres`（item_spawns 加 gold：层1 w4 / 层2 w5 / 层3 w5）
- Modify: `src/ui/hud.gd`（stats_label 加"金币"行）
- Test `tests/unit/test_gold.gd`：金币拾取 gold 增加且背包空；背包拾取不受影响；gold_earned 累计

### Task 26: 商人与商店（规则层）

**Files:**
- Create: `resources/monsters/shopkeeper.tres`（ai_type="shopkeeper"，display_name="商人"，sprite (2,8) 棕袍僧侣，hp 999 防误杀兜底）
- Modify: `src/core/events.gd`（常量：ITEM_DROPPED 可留、SHOP_OPEN="shop_open"、BOUGHT="bought"、SHOP_FAILED="shop_failed"、ACTION_SHOP="shop"）
- Modify: `src/core/monster_def.gd`/`actor.gd`（无改动——ai_type 字段已有，from_monster_def 已拷贝）
- Modify: `src/core/dungeon_generator.gd`（`_spawn_shopkeeper(model)`：非玩家出生房随机空位加商人；每层 1 个）
- Modify: `src/core/turn_scheduler.gd`：
  - `var shop_stock: Array`（元素 `{def, price}`）；`_enter_floor` 末尾调 `_roll_shop_stock()`（当前层 item_spawns 排除 gold 后加权抽 3 件不重复）
  - `_monsters_turn`：`ai_type == "shopkeeper"` 跳过
  - `_try_move` blocker 分支：目标是商人 → 返回 `_open_shop()`（不消耗回合、不刷怪）
  - `player_action` 新分支 ACTION_SHOP → `_open_shop()`
  - `_open_shop() -> Array`（SHOP_OPEN 事件，data.stock 为 `{item_id, item_name, price, icon_coords}` 数组）
  - `buy(index: int) -> Array`（越界/金币不足 → SHOP_FAILED；成功：gold -= price、inventory.add(def)、stock 移除、BOUGHT 事件）
- Test `tests/unit/test_shop.gd`：商人存在且不被移动攻击（撞=shop_open）；商人回合不动；stock 3 件无 gold；buy 成功扣钱进背包库存减少；钱不够 SHOP_FAILED；open/buy 不消耗回合（怪物不行动）

### Task 27: 精英怪（规则层 + 渲染）

**Files:**
- Modify: `src/core/actor.gd`（`var is_elite: bool = false`）
- Modify: `src/core/dungeon_generator.gd`（撒怪后 12% 概率精英化：hp/max_hp/atk ×1.6 取整、xp_reward ×2、is_elite=true；精英缩放数据仅此，规则层不做别的事）
- Modify: `src/core/turn_scheduler.gd`（`_after_kill`：is_elite → 从当前层 `pick_item` 掉落 `model.add_item(def.id, victim.pos, def)` + ITEM_DROPPED 事件）
- Modify: `src/rendering/actor_view.gd`（`is_elite` → `scale = Vector2(1.3, 1.3)`）
- Modify: `src/rendering/entity_layer.gd`（consume 加 `item_dropped`：日志由 HUD 处理，渲染层无需动作——掉落物本身已在地上）
- Test `tests/unit/test_elite.gd`：固定种子下精英出现且属性倍率正确；精英死亡掉落事件与地上物品；非精英不掉

### Task 28: 结算战绩（规则层 + UI）

**Files:**
- Modify: `src/core/turn_scheduler.gd`（`var stats: Dictionary`；消耗回合处 turns+1；ATTACKED 时按 attacker 归属累加 dealt/taken；DIED 非玩家 kills+1；拾取 items_picked+1；game_over/game_won data 加 stats）
- Modify: `src/ui/hud.gd`（GAME_OVER/GAME_WON 的 show_end 副标题带战绩行；stats_label 加金币）
- Test `tests/unit/test_stats.gd`：击杀累计 kills；攻击累计 dealt/taken；金币计入 gold_earned；game_over data 含 stats

### Task 29: 商店 UI + 输入 + 收尾

**Files:**
- Modify: `project.godot`（`interact`=E 键 69）
- Modify: `src/autoload/turn_manager.gd`（`func buy(index: int) -> Array` 转发 scheduler.buy 并 emit 事件）
- Modify: `src/autoload/main.gd`（interact：商店开着→关；否则玩家行动 ACTION_SHOP → consume 事件让 HUD 开店；商店开着时拦截移动）
- Modify: `src/ui/hud.gd`（商店面板：标题+金币余额始终可见+3 个商品按钮（icon+名+价，买不起 disabled）+提示；`toggle_shop(stock)`/`refresh_shop()`/购买按钮 → `TurnManager.buy(i)` → `consume(事件)` → 刷新）
- Test：UI 无自动化；回归全量 + 冒烟
- [ ] `--import` → GUT 全绿 → 冒烟通过 → 提交推送 → 重启游戏

## Self-Review

- 用户指定三件套：金币+商店（Task 25/26/29）✓、精英怪（27）✓、结算战绩（28）✓。
- 商店不消耗回合、商人不可杀、金币不进背包——三个易错点均有测试锁定。
- 事件/动作常量集中在 events.gd；表现层只消费；统计只读输出。
- 类型一致性：stock 元素 {def, price}；SHOP_OPEN data.stock 元素 {item_id, item_name, price, icon_coords}；ActorView/EntityLayer 消费的事件字段与 scheduler 产生一致。
