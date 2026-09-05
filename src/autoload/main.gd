extends Node2D
## 游戏主控：装配渲染层、转发输入到规则层、把事件分发给渲染与 UI。
## 表现层只消费事件与只读查询，不修改规则层状态（spec §4.1）。

const GameEvents = preload("res://src/core/events.gd")
const GameConfig = preload("res://src/autoload/game_config.gd")

var game_running := false
var _move_cooldown := 0.0

const MOVE_INTERVAL := 0.12  # 按住方向键的连走间隔（秒）

func _ready() -> void:
	randomize()
	_start_game()

## 长按连走：轮询按住状态，冷却到点即走一步（补间 0.08s 能跟上）。
func _process(delta: float) -> void:
	_move_cooldown = maxf(0.0, _move_cooldown - delta)
	if not game_running or %Hud.inventory_open or _move_cooldown > 0.0:
		return
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("move_up"):
		dir = Vector2i.UP
	elif Input.is_action_pressed("move_down"):
		dir = Vector2i.DOWN
	elif Input.is_action_pressed("move_left"):
		dir = Vector2i.LEFT
	elif Input.is_action_pressed("move_right"):
		dir = Vector2i.RIGHT
	if dir != Vector2i.ZERO:
		_act(GameEvents.ACTION_MOVE, dir)
		_move_cooldown = MOVE_INTERVAL

func _start_game() -> void:
	TurnManager.start_new_game(GameConfig.player_def(), GameConfig.floor_defs())
	var model = TurnManager.scheduler.model
	_apply_floor_theme(model.floor_number)
	%Dungeon.rebuild(model)
	%Entities.spawn_from_model(model)
	%Camera.position = ViewConstants.cell_to_world(model.player.pos)
	%Hud.bind_game(self)
	%Hud.reset()
	%Hud.push_msg("你醒在地牢第 1 层。按住 方向键/WASD 移动，B 开背包，站上洞口按空格下楼。")
	game_running = true

## 楼层主题色：用 FloorDef.floor_theme 给整张地图着色（每层氛围不同）。
func _apply_floor_theme(floor_number: int) -> void:
	var defs: Array = GameConfig.floor_defs()
	var idx: int = clampi(floor_number - 1, 0, defs.size() - 1)
	%Dungeon.modulate = defs[idx].floor_theme

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("bag"):
		%Hud.toggle_inventory()
		return
	if not game_running:
		if event.is_action_pressed("descend"):
			_start_game()  # 结算画面按空格重开
		return
	if %Hud.inventory_open:
		return  # 背包打开时拦截游戏输入（回合制无需暂停世界）
	if event.is_action_pressed("descend"):
		_act(GameEvents.ACTION_DESCEND)
	elif event.is_action_pressed("wait"):
		_act(GameEvents.ACTION_WAIT)

func _act(action: String, dir := Vector2i.ZERO) -> void:
	var events: Array = TurnManager.player_action(action, dir)
	if events.is_empty():
		return
	%Dungeon.refresh_fog(TurnManager.scheduler.model)
	%Entities.consume(events)
	%Hud.consume(events)
	for e in events:
		if e.type == GameEvents.FLOOR_CHANGED:
			_apply_floor_theme(e.data.floor_number)
	var pv = %Entities.player_view()
	if pv != null:
		%Camera.position = pv.global_position  # 平滑跟随玩家精灵
	for e in events:
		if e.type == GameEvents.GAME_OVER or e.type == GameEvents.GAME_WON:
			game_running = false
