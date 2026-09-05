# Roguelike Demo M4 收尾（Kenney 素材替换）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 Kenney Tiny Dungeon（CC0，16×16，与工程瓦片同尺寸）替换色块占位：瓦片/角色/物品图标全部换真像素素材；顺带补上"地面物品可见"缺口（当前物品在地图上隐形）。

**Architecture:** 素材数据驱动——`MonsterDef/ItemDef` 增加 `sprite_coords`（图集坐标）字段并由 .tres 提供（spec §4.3 "MonsterDef 含精灵帧"）；渲染层 `SpriteCatalog` 只负责加载图集与裁切 AtlasTexture。TileSet 用两份 source：原版 + 运行时乘 0.45 的暗版（迷雾），未探索纯黑用程序生成单格 source。

**Tech Stack:** Kenney Tiny Dungeon v1.0（已下载 `G:\Zcode\assets\kenney\Tilemap\tilemap_packed.png`，12×11 格，CC0）/ Godot 4.7 TileSetAtlasSource + AtlasTexture。

**Spec:** `docs/superpowers/specs/2026-09-04-roguelike-demo-design.md`（§3 素材三步走第二步、§4.3 数据字段）

## 素材映射（tilemap_packed 图集坐标，0 起）

| 用途 | 坐标 | 内容 |
|------|------|------|
| 地板 FLOOR | (2,0) | 棕泥地 |
| 墙 WALL | (9,3) | 灰石砖 |
| 楼梯 STAIRS | (8,4) | 石环洞口 |
| 玩家 | (1,8) | 金甲战士 |
| 窟鼠 rat | (0,10) | 蜘蛛 |
| 洞蝠 bat | (1,10) | 白幽灵 |
| 骷髅卫兵 skeleton | (2,7) | 骷髅战士 |
| 小治疗药水 | (6,9) | 红药水 |
| 锈剑 | (7,8) | 剑 |
| 皮甲 | (6,8) | 盾徽 |

## Global Constraints

- 规则层 `src/core/` 不改逻辑，只允许 Def 类加 `sprite_coords` 字段与 Actor 拷贝一行。
- 图集坐标以 .tres 数据为准；渲染层不做 id→贴图硬编码映射（SpriteCatalog 仅玩家常量 + 工具函数）。
- 物品拾取后地上图标消失（消费 `picked_up` 的 pos）；换层重建。
- 迷雾三态保持：未探索=纯黑、已探索不可见=暗版瓦片、可见=原版。
- 全部既有测试（46）+ 新增 sprite_coords 断言保持全绿。

---

### Task 19: 素材入库 + Def 字段

**Files:**
- Create: `assets/sprites/tiny_dungeon.png`（拷贝 packed 版）、`assets/sprites/LICENSE-kenney.txt`（CC0 说明）
- Modify: `src/core/monster_def.gd`、`src/core/item_def.gd`、`src/core/player_def.gd`（加 `@export var sprite_coords: Vector2i = Vector2i(-1, -1)`）
- Modify: `src/core/actor.gd`（`from_monster_def`/`from_player_def` 拷贝 `sprite_coords`）
- Modify: `resources/**/*.tres`（各加 sprite_coords 行，按映射表；player.tres = Vector2i(1, 8)）
- Modify: `tests/unit/test_game_config.gd`（断言所有 def 的 sprite_coords != (-1,-1)）

### Task 20: 渲染层替换

**Files:**
- Create: `src/rendering/sprite_catalog.gd`（SHEET 常量、PLAYER 坐标、`static func tile_texture(coords) -> AtlasTexture` 带缓存）
- Modify: `src/rendering/dungeon_renderer.gd`（TileSet：source 0=原版图集（create_tile 三个用到的坐标）、source 1=暗版图集（同坐标，像素乘 0.45）、source 2=纯黑单格；_paint_cell 改用 source+坐标常量）
- Modify: `src/rendering/actor_view.gd`（setup 改为读 `actor.sprite_coords` 生成 AtlasTexture 贴图；12×12 色块逻辑删除）
- Modify: `src/rendering/entity_layer.gd`（spawn_from_model 增加地上物品 Sprite2D（item coords，微缩放 0.75 叠在地板上）；consume 处理 `picked_up`：移除该 pos 的物品视图）
- Modify: `src/ui/hud.gd`（背包按钮 `btn.icon = SpriteCatalog.tile_texture(def.sprite_coords)`，`expand_icon = true`）

**Interfaces:**
- `SpriteCatalog.tile_texture(coords: Vector2i) -> AtlasTexture`（region = coords*16, 16×16；静态缓存 sheet ImageTexture）
- `ActorView.setup(actor: Object) -> void`（签名变化：不再传颜色）
- `EntityLayer` 消费事件不变，仅增加 picked_up 分支

### Task 21: 验证 + 提交推送 + 重启游戏

- [ ] `--import`（为 png 生成 .import）→ GUT 全量全绿
- [ ] 可玩冒烟通过
- [ ] 提交推送；重启游戏窗口给用户看效果

## Self-Review

- Spec：素材三步走第二步 ✓；§4.3 精灵字段数据驱动 ✓；迷雾三态保持 ✓；物品可见性缺口补上 ✓。
- 类型一致性：`sprite_coords: Vector2i` 在 Def/Actor/渲染层一致；AtlasTexture region 尺寸 16 与 TILE_SIZE 一致。
- 无占位符；坐标映射表为本计划唯一事实来源。
