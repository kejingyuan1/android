# ArmyUnit.gd — 在世界地图上移动的部队
extends Node2D

signal reached_target(unit: Node)

const TroopData = preload("res://scripts/combat/troop_data.gd")

## 兵种类型 (TroopData.TroopType)
var troop_type: int = TroopData.TroopType.MILITIA
## 部队数量
var troop_count: int = 1
## 目标位置（世界坐标）
var target_position: Vector2 = Vector2.ZERO
## 移动速度（世界单位/秒）
var speed: float = 60.0

var _sprite: Sprite2D = null
var _label: Label = null
var _moving: bool = false

func _ready():
	# 创建精灵
	_sprite = Sprite2D.new()
	_sprite.centered = true
	var tex_path = TroopData.get_texture_path(troop_type)
	if ResourceLoader.exists(tex_path):
		_sprite.texture = load(tex_path)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(0.6, 0.6)
	_sprite.z_index = 20
	add_child(_sprite)

	# 上方数量标签
	_label = Label.new()
	_label.text = str(troop_count)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("shadow_outline_size", 2)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-20, -30)
	_label.size = Vector2(40, 24)
	add_child(_label)

func _process(delta):
	if not _moving:
		return
	var diff = target_position - position
	var dist = diff.length()
	if dist < 5.0:
		position = target_position
		_moving = false
		emit_signal("reached_target", self)
		return
	var step = speed * delta
	if step >= dist:
		position = target_position
		_moving = false
		emit_signal("reached_target", self)
	else:
		position += diff.normalized() * step

## 设置起点和终点，开始移动
func start_move(from_pos: Vector2, to_pos: Vector2):
	position = from_pos
	target_position = to_pos
	_moving = true

## 更新显示数量
func update_count(count: int):
	troop_count = count
	if _label:
		_label.text = str(count)
