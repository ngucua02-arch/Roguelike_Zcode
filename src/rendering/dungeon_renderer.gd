class_name DungeonRenderer
extends TileMapLayer
## 规则层 DungeonModel -> 瓦片渲染同步器（Kenney Tiny Dungeon 图集 + 简易迷雾）。
## 只读模型，不修改规则层状态。

# 原版图集坐标（暗版 source 使用相同坐标）
const C_WALL := Vector2i(10, 4)
const C_FLOOR := Vector2i(2, 0)
const C_STAIRS := Vector2i(8, 4)

const SRC_MAIN := 0   # 原版（可见）
const SRC_DIM := 1    # 亮度 45%（已探索不可见）
const SRC_BLACK := 2  # 未探索纯黑

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tile_set = _build_tile_set()

func _build_tile_set() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(ViewConstants.TILE_SIZE, ViewConstants.TILE_SIZE)
	var main_img: Image = SpriteCatalog.sheet_texture().get_image()
	main_img.convert(Image.FORMAT_RGBA8)
	var dim_img: Image = main_img.duplicate()
	dim_img.adjust_bcs(0.45, 1.0, 1.0)  # 迷雾暗版（亮度 45%）
	ts.add_source(_atlas_source(main_img), SRC_MAIN)
	ts.add_source(_atlas_source(dim_img), SRC_DIM)

	var black := Image.create(ViewConstants.TILE_SIZE, ViewConstants.TILE_SIZE, false, Image.FORMAT_RGBA8)
	black.fill(Color(0.05, 0.05, 0.06))
	var black_src := TileSetAtlasSource.new()
	black_src.texture = ImageTexture.create_from_image(black)
	black_src.texture_region_size = Vector2i(ViewConstants.TILE_SIZE, ViewConstants.TILE_SIZE)
	black_src.create_tile(Vector2i.ZERO)
	ts.add_source(black_src, SRC_BLACK)
	return ts

func _atlas_source(img: Image) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(ViewConstants.TILE_SIZE, ViewConstants.TILE_SIZE)
	for coords in [C_WALL, C_FLOOR, C_STAIRS]:
		src.create_tile(coords)
	return src

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
	var src_id := SRC_BLACK
	var coords := Vector2i.ZERO
	if model.explored.has(pos):
		var lit: bool = model.visible.has(pos)
		src_id = SRC_MAIN if lit else SRC_DIM
		match model.tile_at(pos):
			DungeonModel.Tile.WALL:
				coords = C_WALL
			DungeonModel.Tile.STAIRS:
				coords = C_STAIRS
			_:
				coords = C_FLOOR
	set_cell(pos, src_id, coords)
