class_name EntityLayer
extends Node2D
## 实体精灵容器：按事件同步显示，不触碰规则层状态。

func spawn_from_model(model: Object) -> void:
	_clear_now()
	if model.player != null:
		var pv := ActorView.new()
		pv.setup(model.player, Color(0.9, 0.9, 0.95))
		add_child(pv)
	for mon in model.monsters:
		var mv := ActorView.new()
		mv.setup(mon, Color(0.85, 0.3, 0.25))
		add_child(mv)

## 消费事件流：moved->补间位移、attacked->冲刺回弹、died->淡出移除。
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
			"died":
				var dv := _find_view(e.data.actor_id)
				if dv != null:
					dv.die()

func player_view() -> ActorView:
	return _find_view("player")

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
