extends Node
## headless 可玩冒烟驱动器：挂在实际游戏场景旁，逐帧模拟玩家随机移动 80 回合，
## 验证渲染消费/Tween/迷雾/HUD 在真实帧循环下不崩。用 `godot --headless res://tests/smoke/smoke_main.tscn` 运行。

const GameEvents = preload("res://src/core/events.gd")

var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
var rng := RandomNumberGenerator.new()
var turns := 0
var max_turns := 80
var main: Object = null

func _ready() -> void:
	rng.seed = 7
	main = get_node("../Game")

func _process(_delta: float) -> void:
	if main == null:
		return
	if turns >= max_turns or not main.game_running:
		var s = TurnManager.scheduler
		print("SMOKE_OK turns=%d running=%s floor=%d hp=%d/%d" % [
			turns, main.game_running, s.model.floor_number, s.player.hp, s.player.max_hp])
		get_tree().quit(0)
		return
	main._act(GameEvents.ACTION_MOVE, dirs[rng.randi_range(0, 3)])
	turns += 1
