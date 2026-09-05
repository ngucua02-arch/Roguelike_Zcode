# Roguelike Demo 手感优化 + 内容量补足 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按住 WASD 连续移动（手感）；补足 spec §2 承诺的内容量（怪物 4-5 种→做 6 种、道具 5-6 种→做 7 种）；战斗伤害飘字反馈；启用楼层主题色（FloorDef.floor_theme 已有字段但未使用）。

**Architecture:** 长按移动从事件驱动改为 `_process` 轮询 + 移动冷却（0.12s/步，补间 0.08s 能跟上）；新内容纯数据（.tres 表 + 图集坐标），规则层零改动；飘字是渲染层表现；主题色用 TileMapLayer.modulate 乘法着色。

**Tech Stack:** 不变（Godot 4.7 / GDScript / Kenney 图集）。

**Spec:** `docs/superpowers/specs/2026-09-04-roguelike-demo-design.md`（§2 范围"4-5 种怪物、5-6 种道具"、§4.5 移动约定、floor_theme 字段）

## Global Constraints

- 规则层 `src/core/` 零改动；新怪物/道具只动 .tres 与渲染/UI 表现层。
- 移动冷却 0.12s；背包打开时轮询不生效；结算画面（game_running=false）不生效。
- 每层生成表权重和 > 0；所有新 def 带有效 sprite_coords。
- 全部既有测试 + 新增内容量断言全绿。

---

### Task 22: 长按连走

**Files:**
- Modify: `src/autoload/main.gd`
- 方案：`_unhandled_input` 只保留 bag/descend/wait/重开；新增 `_process(delta)` 轮询 `Input.is_action_pressed` 四方向，`_move_cooldown` 计时（`MOVE_INTERVAL := 0.12`），触发 `_act(ACTION_MOVE, dir)`。

### Task 23: 内容量补足（纯数据）

**Files:**
- Create: `resources/monsters/slime.tres`（(0,9) 绿史莱姆：hp6/atk2/def1/视野4/xp4/wander）、`goblin.tres`（(4,9) 绿帽哥布林：hp7/atk5/def1/视野7/xp8/chase）、`hellhound.tres`（(2,9) 红甲虫：hp10/atk6/def2/视野8/xp12/chase）
- Create: `resources/items/potion_greater.tres`（(7,9) 红药水 +12）、`sword_iron.tres`（(9,8) 直剑 +2）、`battle_axe.tres`（(9,9) 斧 +3）
- Modify: `resources/floors/floor_*.tres`（生成表扩充）：
  - 层1 怪：rat5/bat2/slime2；物：potion_minor5/sword_rusty2/leather_mail2
  - 层2 怪：rat2/bat3/slime3/skeleton2/goblin2；物：potion_minor4/potion_greater2/sword_iron2/leather_mail2
  - 层3 怪：bat2/skeleton4/goblin4/hellhound3；物：potion_greater4/sword_iron2/battle_axe2/leather_mail1
  - 层主题色 floor_theme：层1 Color(1,0.96,0.88) / 层2 Color(0.82,0.88,1) / 层3 Color(1,0.82,0.8)
- Modify: `src/rendering/entity_layer.gd`（attacked 分支加伤害飘字：Label "-N" 金黄色，上飘+淡出 0.45s）
- Modify: `src/autoload/main.gd`（floor_changed / _start_game 时 `%Dungeon.modulate = floor_theme`，从 GameConfig.floor_defs()[floor_index] 取）
- Modify: `src/ui/hud.gd`（提示文本改"按住 方向键/WASD 移动"）
- Modify: `tests/unit/test_game_config.gd`（新增：全局怪物 id 种类 ≥5、道具种类 ≥6（spec §2 规格断言）；每层怪物表 ≤ 6 种）

### Task 24: 验证 + 提交推送 + 重启游戏

- [ ] `--import` → GUT 全量全绿 → 可玩冒烟通过
- [ ] 提交推送；重启游戏窗口

## Self-Review

- 用户反馈 1（长按移动）→ Task 22 ✓；反馈 2（内容缺）→ Task 23 补足 spec 规格并超额（怪 6 种/物 7 种）+ 手感反馈（飘字）+ 楼层差异化（主题色）✓
- 类型一致性：事件字段不变；sprite_coords 全部有效；floor_theme 为已有字段。
- 规则层零改动声明：Task 22/23 均不触及 src/core。
