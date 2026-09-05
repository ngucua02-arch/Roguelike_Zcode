extends CanvasLayer
## HUD：右侧状态面板 + 底部消息日志 + 结算层。只读规则层，消费事件写文案。

const GameEvents = preload("res://src/core/events.gd")

const NAME_MAP := {
	"player": "你",
	"rat": "窟鼠",
	"bat": "洞蝠",
	"skeleton": "骷髅卫兵",
}
const MAX_LOG_LINES := 8

var main: Object = null
var hp_bar: ProgressBar
var stats_label: Label
var log_label: Label
var end_layer: Control
var end_title: Label
var end_detail: Label
var _log_lines: Array = []

# 背包面板
var inventory_open := false
var _inv_panel: PanelContainer
var _inv_grid: GridContainer
var _inv_hint: Label

func _ready() -> void:
	_build_stats_panel()
	_build_log()
	_build_end_layer()
	_build_inventory_panel()

func bind_game(game_main: Object) -> void:
	main = game_main

## 追加一条日志（超出上限丢弃最旧行）。
func push_msg(msg: String) -> void:
	_log_lines.append(msg)
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	log_label.text = "\n".join(_log_lines)

## 消费事件流：翻译成玩家可读文案 + 刷新状态面板 + 终局结算。
func consume(events: Array) -> void:
	for e in events:
		match e.type:
			GameEvents.ATTACKED:
				_log("%s 对 %s 造成 %d 伤害" % [_name(e.data.attacker_id), _name(e.data.defender_id), e.data.damage])
			GameEvents.DIED:
				if e.data.is_player:
					_log("你倒下了……")
				else:
					_log("%s 倒下了" % _name(e.data.actor_id))
			GameEvents.XP_GAINED:
				_log("获得 %d 经验" % e.data.amount)
			GameEvents.LEVELED_UP:
				_log("升级！Lv.%d（回满血）" % e.data.level)
			GameEvents.PICKED_UP:
				_log("拾取 %s" % e.data.item_name)
				if inventory_open:
					refresh_inventory()
			"healed":
				_log("恢复 %d HP" % e.data.amount)
			"equipped":
				_log("装备 %s（%s +%d）" % [e.data.item_id, e.data.stat, e.data.gain])
			GameEvents.USE_FAILED:
				_log("使用失败（满血）")
			GameEvents.DESCENDED:
				_log("沿楼梯下行……")
			GameEvents.FLOOR_CHANGED:
				_log("来到第 %d 层" % e.data.floor_number)
			GameEvents.GAME_OVER:
				show_end("你死了", "到达第 %d 层\n\n按 空格 重新开始" % e.data.floor_number)
			GameEvents.GAME_WON:
				show_end("地牢征服者！", "3 层全部通过，通关！\n\n按 空格 再来一局")
	_refresh_stats()

func show_end(title: String, detail: String) -> void:
	end_title.text = title
	end_detail.text = detail
	end_layer.visible = true

func hide_end() -> void:
	end_layer.visible = false

## 重开时清空日志与结算层。
func reset() -> void:
	_log_lines.clear()
	log_label.text = ""
	hide_end()
	inventory_open = false
	_inv_panel.visible = false
	_refresh_stats()

## B 键开关背包；打开时按当前背包内容重建格子。
func toggle_inventory() -> void:
	inventory_open = not inventory_open
	_inv_panel.visible = inventory_open
	if inventory_open:
		refresh_inventory()

## 按规则层 Inventory 当前内容重建物品按钮格子。
func refresh_inventory() -> void:
	for child in _inv_grid.get_children():
		child.queue_free()
	var s = TurnManager.scheduler
	if s == null:
		return
	var items: Array = s.inventory.items
	if items.is_empty():
		_inv_hint.visible = true
		return
	_inv_hint.visible = false
	for i in items.size():
		var def: Object = items[i].def
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(66, 56)
		btn.text = def.display_name
		if def.sprite_coords.x >= 0:
			btn.icon = SpriteCatalog.tile_texture(def.sprite_coords)
		btn.tooltip_text = _item_tooltip(def)
		btn.pressed.connect(_use_item.bind(i))
		_inv_grid.add_child(btn)

func _use_item(index: int) -> void:
	var s = TurnManager.scheduler
	if s == null or not inventory_open:
		return
	var events: Array = s.inventory.use(index, s.player)
	if not events.is_empty():
		consume(events)
	refresh_inventory()

func _item_tooltip(def: Object) -> String:
	match def.kind:
		"potion":
			return "点击使用：恢复 %d 点 HP" % def.power
		"weapon":
			return "点击装备：攻击 +%d" % def.power
		"armor":
			return "点击装备：防御 +%d" % def.power
	return def.display_name

func _build_inventory_panel() -> void:
	_inv_panel = PanelContainer.new()
	_inv_panel.visible = false
	add_child(_inv_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_inv_panel.add_child(vbox)
	var title := Label.new()
	title.text = "背包（B 关闭，点击物品使用/装备）"
	vbox.add_child(title)
	_inv_grid = GridContainer.new()
	_inv_grid.columns = 4
	_inv_grid.add_theme_constant_override("h_separation", 6)
	_inv_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(_inv_grid)
	_inv_hint = Label.new()
	_inv_hint.text = "空空如也——去地牢里翻找吧"
	_inv_hint.modulate = Color(1, 1, 1, 0.5)
	vbox.add_child(_inv_hint)
	# 面板固定在屏幕中央
	_inv_panel.anchor_left = 0.5
	_inv_panel.anchor_right = 0.5
	_inv_panel.anchor_top = 0.5
	_inv_panel.anchor_bottom = 0.5
	_inv_panel.offset_left = -160.0
	_inv_panel.offset_right = 160.0
	_inv_panel.offset_top = -150.0
	_inv_panel.offset_bottom = 150.0

func _refresh_stats() -> void:
	var s = TurnManager.scheduler
	if s == null or s.player == null:
		return
	var p = s.player
	hp_bar.max_value = p.max_hp
	hp_bar.value = p.hp
	stats_label.text = "HP %d/%d\nLv.%d  经验 %d/%d\n攻击 %d  防御 %d\n楼层 %d  背包 %d 件" % [
		p.hp, p.max_hp, p.level, p.xp, p.xp_to_next(), p.atk, p.defense,
		s.model.floor_number, s.inventory.size()]

func _name(id: String) -> String:
	return NAME_MAP.get(id, id)

func _log(msg: String) -> void:
	push_msg(msg)

func _build_stats_panel() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -200.0
	panel.offset_top = 8.0
	panel.offset_bottom = -8.0
	panel.offset_right = -8.0
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "冒险者"
	vbox.add_child(title)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 18)
	hp_bar.show_percentage = false
	vbox.add_child(hp_bar)
	stats_label = Label.new()
	vbox.add_child(stats_label)
	var hint := Label.new()
	hint.text = "按住 方向键/WASD 移动\n空格 下楼\nB 背包（点击使用）"
	hint.modulate = Color(1, 1, 1, 0.55)
	vbox.add_child(hint)

func _build_log() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.anchor_top = 1.0
	bg.anchor_bottom = 1.0
	bg.anchor_right = 0.0
	bg.offset_left = 8.0
	bg.offset_right = 560.0
	bg.offset_top = -148.0
	bg.offset_bottom = -8.0
	add_child(bg)
	log_label = Label.new()
	log_label.position = Vector2(8, 8)
	log_label.size = Vector2(544, 132)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bg.add_child(log_label)

func _build_end_layer() -> void:
	end_layer = Control.new()
	end_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_layer.visible = false
	add_child(end_layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_layer.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_layer.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)
	end_title = Label.new()
	end_title.text = ""
	end_title.add_theme_font_size_override("font_size", 40)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(end_title)
	end_detail = Label.new()
	end_detail.text = ""
	end_detail.add_theme_font_size_override("font_size", 18)
	end_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(end_detail)
