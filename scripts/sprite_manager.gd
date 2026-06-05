# SpriteManager.gd — 精灵管理
# 从精灵表中加载建筑贴图，替代代码绘制

extends Node

var _sprite_sheet: Texture2D = null
var _cell_w := 0
var _cell_h := 0

# 建筑精灵配置 {name: {row, col}}
const BUILDING_SPRITES := {
	"residential_l1":  {"row": 0, "col": 0},
	"residential_l2":  {"row": 0, "col": 1},
	"commercial":      {"row": 1, "col": 0},
	"industrial":      {"row": 1, "col": 2},
	"police":          {"row": 2, "col": 1},
	"fire":            {"row": 2, "col": 0},
	"medical":         {"row": 2, "col": 2},
}

func _ready():
	load_sheet()

func load_sheet():
	var path = "res://assets/textures/A_sprite_sheet_of_8_buildings__2026-06-03T00-30-18.png"
	if ResourceLoader.exists(path):
		_sprite_sheet = load(path)
		if _sprite_sheet:
			_cell_w = _sprite_sheet.get_width() / 3
			_cell_h = _sprite_sheet.get_height() / 3
			print("精灵表加载成功: ", _sprite_sheet.get_width(), "x", _sprite_sheet.get_height())
		else:
			print("精灵表加载失败: ", path)

## 获取建筑纹理
func get_building_texture(name: String) -> AtlasTexture:
	if not _sprite_sheet:
		return null
	var cfg = BUILDING_SPRITES.get(name)
	if not cfg:
		return null
	var atlas = AtlasTexture.new()
	atlas.atlas = _sprite_sheet
	atlas.region = Rect2(cfg.col * _cell_w, cfg.row * _cell_h, _cell_w, _cell_h)
	return atlas

## 获取道路纹理（从已有贴图裁剪）
func get_road_texture(road_type: int) -> Texture2D:
	if not _sprite_sheet:
		return null
	# 使用 office 贴图（第1行第1列）裁剪为道路色，或直接使用灰色方块
	var atlas = AtlasTexture.new()
	atlas.atlas = _sprite_sheet
	# 从无意义区域裁剪一个小方块作为纯色替代
	atlas.region = Rect2(0, 0, 1, 1)  # 1像素，之后设置modulate
	return atlas
