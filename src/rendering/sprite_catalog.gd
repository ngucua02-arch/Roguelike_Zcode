class_name SpriteCatalog
extends RefCounted
## Kenney Tiny Dungeon 图集访问器（16×16 tile，12×11 格，CC0）。

const SHEET_PATH := "res://assets/sprites/tiny_dungeon.png"
const TILE := 16
const PLAYER := Vector2i(1, 8)  # 玩家默认精灵（sprite_coords 无效时的兜底）

static var _sheet: Texture2D = null

static func sheet_texture() -> Texture2D:
	if _sheet == null:
		_sheet = load(SHEET_PATH)
	return _sheet

## 裁切图集坐标处的 16×16 贴图。
static func tile_texture(coords: Vector2i) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = sheet_texture()
	tex.region = Rect2(coords.x * TILE, coords.y * TILE, TILE, TILE)
	return tex
