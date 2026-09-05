# RoguelikeDemo

传统回合制地牢爬行 roguelike 可玩 demo（Godot 4，像素风）。

## 当前状态

- 板块 0-4 完成：随机地牢、回合制战斗、视野迷雾、背包（B 键开关，点击使用/装备）、
  3 层递进、死亡/通关结算、重开；数值全部抽成 `resources/` 下的 .tres 表（调平衡不碰代码）。
- 规则层 GUT 单元测试全绿（46 个）；另有 headless 可玩冒烟（模拟 80 回合）。
- 剩余：Kenney 像素素材替换色块、音效（可选）、导出实际 exe/网页（预设已就绪）。

## 本地运行测试

1. 安装 Godot 4.7 标准版（官网绿色 exe 即可）。
2. 仓库根目录执行：

```bash
# 单元测试（规则层 + 数值表全量）
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# 可玩冒烟（模拟 80 回合随机移动，真实帧循环）
godot --headless --path . res://tests/smoke/smoke_main.tscn
```

3. 编辑器打开工程后 F5 直接开玩：方向键/WASD 移动，B 开背包（点击使用/装备），
   站上金色楼梯按空格下楼，死亡或通关后按空格重开。

## 调平衡（不碰代码）

直接在 Godot 编辑器里改 `resources/` 下的 .tres：
- `resources/player/player.tres`：玩家初始数值与升级曲线
- `resources/monsters/*.tres`：怪物（hp/攻/防/视野/经验/AI 类型）
- `resources/items/*.tres`：道具（类型 + 效果数值）
- `resources/floors/floor_*.tres`：楼层尺寸、房间数、怪物/物品生成权重表

## 导出 Windows exe 与网页版

1. 编辑器 → Project → Export 之外先安装导出模板：
   Editor → Manage Export Templates → Download and Install（约 1GB，一次性）。
2. Project → Export → 选中预设（Windows Desktop / Web）→ Export Project。
   输出路径见 `export_presets.cfg`：exe 输出到项目外 `../build/`。

命令行方式（装好模板后）：

```bash
godot --headless --path . --export-release "Windows Desktop" ../build/RoguelikeDemo.exe
godot --headless --path . --export-release "Web" ../build/web/index.html
```

## 架构速览

规则层 `src/core/`（纯 GDScript，无场景依赖，GUT 全测）：
DungeonModel / DungeonGenerator / TurnScheduler / Combat / FOV / Inventory / Def 数据类。
调度单例 `src/autoload/turn_manager.gd`：输入 -> 规则层 -> 事件流广播。
表现层通过消费事件字典 `{type, pos, data}` 驱动，不修改规则层状态。

设计文档见 `docs/superpowers/specs/2026-09-04-roguelike-demo-design.md`。
