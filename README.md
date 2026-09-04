# RoguelikeDemo

传统回合制地牢爬行 roguelike 可玩 demo（Godot 4，像素风）。

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

设计文档见 `docs/superpowers/specs/2026-09-04-roguelike-demo-design.md`。
