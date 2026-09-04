class_name DungeonRenderer
extends TileMapLayer
## 规则层 DungeonModel -> 瓦片渲染同步器（含简易迷雾）。只读模型，不修改规则层状态。

# atlas 瓦片索引
const T_WALL := 0
const T_FLOOR := 1
const T_STAIRS := 2
const T_WALL_DIM := 3
const T_FLOOR_DIM := 4
const T_BLACK := 5

const COLORS := [
	Color(0.22, 0.22, 0.26),          # 墙
	Color(0.45, 0.40, 0.36),          # 地
	Color(0.90, 0.75, 0.30),          # 楼梯
	Color(0.22, 0.22, 0.26) * 0.45,   # 暗墙（已探索不可见）
	Color(0.45, 0.40, 0.36) * 0.45,   # 暗地（已探索不可见）
	Color(0.05, 0.05, 0.06),          # 未探索
]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tile_set = _build_tile_set()

## 运行时构建纯色 TileSet（色块占位，后续替换 Kenney 像素包）。
func _build_tile_set() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(ViewConstants.TILE_SIZE, ViewConstants.TILE_SIZE)
	var img := Image.create(COLORS.size() * ViewConstants.TILE_SIZE, ViewConstants.TILE_SIZE, false, Image.FORMAT_RGB8)
	for i in COLORS.size():
		img.fill_rect(Rect2i(i * ViewConstants.TILE_SIZE, 0, ViewConstants.TILE_SIZE, ViewConstants.TILE_SIZE), COLORS[i])
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(ViewConstants.TILE_SIZE, ViewConstants.TILE_SIZE)
	for i in COLORS.size():
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	return ts

## 全量重建瓦片（floor_changed / 开局时调用）。
func rebuild(model: Object) -> void:
	clear()
	refresh_fog(model)

## 按 visible/explored 重刷全部瓦片（每回合迷雾更新）。
func refresh_fog(model: Object) -> void:
	for y in model.height:
		for x in model.width:
			_paint_cell(model, Vector2i(x, y))

func _paint_cell(model: Object, pos: Vector2i) -> void:
	var idx := T_BLACK
	if model.explored.has(pos):
		var t: int = model.tile_at(pos)
		var lit: bool = model.visible.has(pos)
		match t:
			DungeonModel.Tile.WALL:
				idx = T_WALL if lit else T_WALL_DIM
			DungeonModel.Tile.STAIRS:
				idx = T_STAIRS if lit else T_FLOOR_DIM
			_:
				idx = T_FLOOR if lit else T_FLOOR_DIM
	set_cell(pos, 0, Vector2i(idx, 0))
