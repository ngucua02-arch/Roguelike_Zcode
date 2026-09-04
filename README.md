# RoguelikeDemo

传统回合制地牢爬行 roguelike 可玩 demo（Godot 4，像素风）。

## 当前状态

- 板块 0（工程骨架）、板块 1（玩法核心规则层）、板块 2+3 可玩切片完成：
  随机地牢生成、回合制战斗、视野迷雾、背包拾取、3 层递进、死亡/通关结算、重开。
- 规则层 41 个 GUT 单元测试全绿；另有 headless 可玩冒烟（模拟 80 回合）。
- 剩余：板块 4 数值 .tres 表、Kenney 素材替换、背包界面、导出发布（板块 4/5）。

## 本地运行测试

1. 安装 Godot 4.7 标准版（官网绿色 exe 即可）。
2. 仓库根目录执行：

```bash
# 单元测试（规则层全量）
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# 可玩冒烟（模拟 80 回合随机移动，真实帧循环）
godot --headless --path . res://tests/smoke/smoke_main.tscn
```

3. 编辑器打开工程后 F5 直接开玩：方向键/WASD 移动，站上金色楼梯按空格下楼，
   死亡或通关后按空格重开。

## 架构速览

规则层 `src/core/`（纯 GDScript，无场景依赖，GUT 全测）：
DungeonModel / DungeonGenerator / TurnScheduler / Combat / FOV / Inventory / Def 数据类。
调度单例 `src/autoload/turn_manager.gd`：输入 -> 规则层 -> 事件流广播。
表现层通过消费事件字典 `{type, pos, data}` 驱动，不修改规则层状态。

设计文档见 `docs/superpowers/specs/2026-09-04-roguelike-demo-design.md`。
