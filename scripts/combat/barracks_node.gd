# BarracksNode.gd — 兵营建筑精灵
extends Node2D

const CELL_SIZE := 32

var _cell_x: int = 0
var _cell_y: int = 0
var _level: int = 1
var _sprite: Sprite2D = null
var _barracks_manager: Node = null

const TEXTURE_PATH := "res://assets/textures/buildings/barracks.png"

func setup(cell_x: int, cell_y: int, level: int = 1):
	_cell_x = cell_x
	_cell_y = cell_y
	_level = level
	position = Vector2(cell_x * CELL_SIZE + CELL_SIZE / 2, cell_y * CELL_SIZE + CELL_SIZE / 2)

	_sprite = Sprite2D.new()
	_sprite.z_index = 5
	add_child(_sprite)
	_update_texture()

## 设置兵营管理器引用
func set_barracks_manager(manager: Node):
	_barracks_manager = manager

## 获取兵营管理器
func get_barracks_manager() -> Node:
	return _barracks_manager

func _update_texture():
	if not _sprite:
		return
	if not ResourceLoader.exists(TEXTURE_PATH):
		return
	var tex = load(TEXTURE_PATH)
	_sprite.texture = tex
	_sprite.centered = true
	_sprite.scale = Vector2(0.8, 0.8)

func get_building_info() -> Dictionary:
	return {
		"type_name": "兵营",
		"level": _level,
		"description": "训练和部署部队",
	}
