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
