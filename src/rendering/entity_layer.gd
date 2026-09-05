class_name EntityLayer
extends Node2D
## 实体与地面物品的精灵容器：按事件同步显示，不触碰规则层状态。

func spawn_from_model(model: Object) -> void:
	_clear_now()
	if model.player != null:
		var pv := ActorView.new()
		pv.setup(model.player)
		add_child(pv)
	for mon in model.monsters:
		var mv := ActorView.new()
		mv.setup(mon)
		add_child(mv)
	for it in model.items:
		var def: Object = it.get("def")
		if def == null or def.sprite_coords.x < 0:
			continue
		var iv := Sprite2D.new()
		iv.texture = SpriteCatalog.tile_texture(def.sprite_coords)
		iv.scale = Vector2(0.75, 0.75)  # 物品略小于整格，与角色区分
		iv.position = ViewConstants.cell_to_world(it.pos)
		iv.set_meta("item_pos", it.pos)
		add_child(iv)

## 消费事件流：moved->补间位移、attacked->冲刺回弹、died->淡出移除、
## picked_up->移除地面物品图标。
func consume(events: Array) -> void:
	for e in events:
		match e.type:
			"moved":
				var v := _find_view(e.data.actor_id)
				if v != null:
					v.slide_to(e.pos)
			"attacked":
				var av := _find_view(e.data.attacker_id)
				if av != null:
					av.play_attack(e.pos)
				_spawn_damage_number(e.pos, e.data.damage)
			"died":
				var dv := _find_view(e.data.actor_id)
				if dv != null:
					dv.die()
			"picked_up":
				var iv := _find_item_view(e.pos)
				if iv != null:
					iv.queue_free()

func player_view() -> ActorView:
	return _find_view("player")

## 伤害飘字：向上飘并淡出，纯表现不参与结算。
func _spawn_damage_number(pos: Vector2i, damage: int) -> void:
	var lbl := Label.new()
	lbl.text = "-%d" % damage
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	lbl.z_index = 10
	lbl.position = ViewConstants.cell_to_world(pos) + Vector2(-8, -20)
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 14.0, 0.45)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.45)
	tw.tween_callback(lbl.queue_free)

## 立即清空子节点（换层时避免 queue_free 延迟造成帧间残留）。
func _clear_now() -> void:
	for child in get_children():
		remove_child(child)
		child.free()

func _find_view(actor_id: String) -> ActorView:
	for child in get_children():
		var ref: Object = child.get_meta("actor_ref", null)
		if ref != null and ref.id == actor_id:
			return child
	return null

func _find_item_view(pos: Vector2i) -> Sprite2D:
	for child in get_children():
		if child.get_meta("item_pos", Vector2i(-9, -9)) == pos:
			return child
	return null
