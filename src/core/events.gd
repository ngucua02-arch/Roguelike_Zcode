class_name GameEvents
extends RefCounted
## 事件流类型常量与玩家动作常量。事件字典统一 {type, pos, data}。

const MOVED := "moved"
const ATTACKED := "attacked"
const DIED := "died"
const XP_GAINED := "xp_gained"
const LEVELED_UP := "leveled_up"
const PICKED_UP := "picked_up"
const WAITED := "waited"
const USE_FAILED := "use_failed"
const DESCENDED := "descended"
const FLOOR_CHANGED := "floor_changed"
const GAME_OVER := "game_over"
const GAME_WON := "game_won"

const ACTION_MOVE := "move"
const ACTION_WAIT := "wait"
const ACTION_DESCEND := "descend"
