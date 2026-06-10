# LabNode.gd — 实验室建筑精灵
extends Node2D

const CELL_SIZE := 32

var _cell_x: int = 0
var _cell_y: int = 0
var _level: int = 1
var _sprite: Sprite2D = null
var _lab_manager: Node = null

const TEXTURE_PATH := "res://assets/textures/buildings/lab.png"

func setup(cell_x: int, cell_y: int, level: int = 1):
	_cell_x = cell_x
	_cell_y = cell_y
	_level = level
	position = Vector2(cell_x * CELL_SIZE + CELL_SIZE / 2, cell_y * CELL_SIZE + CELL_SIZE / 2)

	_sprite = Sprite2D.new()
	_sprite.z_index = 5
	add_child(_sprite)
	_update_texture()

## 设置实验室管理器引用
func set_lab_manager(manager: Node):
	_lab_manager = manager

## 获取实验室管理器
func get_lab_manager() -> Node:
	return _lab_manager

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
		"type_name": "实验室",
		"level": _level,
		"description": "研究和升级部队",
	}
