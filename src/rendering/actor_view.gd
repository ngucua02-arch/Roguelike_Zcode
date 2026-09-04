class_name ActorView
extends Sprite2D
## 单个实体的色块占位视图：走位补间、攻击冲刺、死亡淡出。

func setup(actor: Object, color: Color) -> void:
	var img := Image.create(12, 12, false, Image.FORMAT_RGB8)
	img.fill(color)
	texture = ImageTexture.create_from_image(img)
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
