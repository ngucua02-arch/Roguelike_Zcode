class_name GameConfig
extends RefCounted
## 数值装配器：从 .tres 数据表加载玩家与 3 层地牢配置（板块 4）。
## 调平衡只改 resources/ 下的 .tres，不碰代码。

const PLAYER_PATH := "res://resources/player/player.tres"
const FLOOR_PATHS := [
	"res://resources/floors/floor_1.tres",
	"res://resources/floors/floor_2.tres",
	"res://resources/floors/floor_3.tres",
]

static func player_def() -> Object:
	return load(PLAYER_PATH)

static func floor_defs() -> Array:
	var defs: Array = []
	for path in FLOOR_PATHS:
		defs.append(load(path))
	return defs
