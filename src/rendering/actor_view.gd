class_name ActorView
extends Sprite2D
## 单个实体的精灵视图：按 def 提供的图集坐标取贴图，走位补间、攻击冲刺、死亡淡出。

func setup(actor: Object) -> void:
	var coords: Vector2i = actor.sprite_coords
	if coords.x < 0 or coords.y < 0:
		coords = SpriteCatalog.PLAYER  # 兜底（无坐标数据的 def）
	texture = SpriteCatalog.tile_texture(coords)
	position = ViewConstants.cell_to_world(actor.pos)
	set_meta("actor_ref", actor)

func slide_to(cell: Vector2i) -> void:
	var tw := create_tween()
	tw.tween_property(self, "position", ViewConstants.cell_to_world(cell), 0.08)

## 攻击表现：向目标格冲刺后回弹。
func play_attack(target_cell: Vector2i) -> void:
	var origin := position
	var tw := create_tween()
	tw.tween_property(self, "position", ViewConstants.cell_to_world(target_cell), 0.05)
	tw.tween_property(self, "position", origin, 0.05)

## 死亡表现：淡出后自毁。
func die() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)
