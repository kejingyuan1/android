# BuildingNode.gd — 使用裁剪后的透明精灵贴图，支持多尺寸
extends Node2D

const CELL_SIZE := 32

var _cell_x: int = 0
var _cell_y: int = 0
var _zone_type: int = 0
var _level: int = 1
var _size_x: int = 1  # 建筑占几格宽
var _size_y: int = 1  # 建筑占几格高
var _sprite: Sprite2D = null

# 独立精灵（像素风，已裁剪透明背景）
const SPRITE_PATHS := {
	"house1": "res://assets/textures/buildings/house1.png",
	"house2": "res://assets/textures/buildings/house2.png",
	"apartment": "res://assets/textures/buildings/apartment.png",
	"shop": "res://assets/textures/buildings/shop.png",
	"factory": "res://assets/textures/buildings/factory.png",
	"office": "res://assets/textures/buildings/office.png",
}

func setup(gx: int, gy: int, zone_type: int, level: int, size_x: int = 1, size_y: int = 1):
	_cell_x = gx
	_cell_y = gy
	_zone_type = zone_type
	_size_x = size_x
	_size_y = size_y
	# 锚点在建筑中心（左上角 + 半宽）
	position = Vector2(
		gx * CELL_SIZE + size_x * CELL_SIZE / 2.0,
		gy * CELL_SIZE + size_y * CELL_SIZE / 2.0
	)

	_sprite = Sprite2D.new()
	_sprite.z_index = 5
	add_child(_sprite)

	update_level(level)

func update_level(new_level: int):
	_level = clamp(new_level, 1, 3)
	_update_texture()

func _update_texture():
	if not _sprite:
		return

	var tex_path = ""
	match _zone_type:
		2:  # Residential
			if _level == 1:
				tex_path = SPRITE_PATHS["house1"]
			elif _level == 2:
				tex_path = SPRITE_PATHS["house2"]
			else:
				tex_path = SPRITE_PATHS["apartment"]
		3:  # Commercial
			tex_path = SPRITE_PATHS["shop"]
		4:  # Industrial
			tex_path = SPRITE_PATHS["factory"]

	if tex_path == "" or not ResourceLoader.exists(tex_path):
		print("[TEX_LOAD] building_node 纹理不存在: ", tex_path)
		return

	print("[TEX_LOAD] building_node 加载纹理: ", tex_path)
	var tex = load(tex_path)
	print("[TEX_LOAD]   load()结果: ", tex != null, " 尺寸=", tex.get_width() if tex else -1, "x", tex.get_height() if tex else -1)
	_sprite.texture = tex
	_sprite.centered = true

	# 按建筑尺寸缩放精灵
	# 基础：一个格子 = CELL_SIZE 像素
	# 2×2 建筑 = CELL_SIZE * 2 世界单位
	# 精灵原生尺寸加载后，按占用格数缩放
	var base_scale = float(max(_size_x, _size_y))
	_sprite.scale = Vector2(base_scale, base_scale)

func get_building_info() -> Dictionary:
	var pop_mult = _size_x * _size_y
	match _zone_type:
		2: return {"type_name": "住宅", "level": _level, "population": 10 * _level * pop_mult}
		3: return {"type_name": "商业", "level": _level, "revenue": 50 * _level * pop_mult}
		4: return {"type_name": "工业", "level": _level, "jobs": 20 * _level * pop_mult}
	return {"type_name": "未知", "level": _level}
