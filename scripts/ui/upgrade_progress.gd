# UpgradeProgress.gd — 建筑升级进度条（显示在建筑上方）
extends Node2D

var _bar = null
var _building_ref = null
var _building_cx = 0
var _building_cy = 0
var _visible = false

func setup(building, cx, cy):
	_building_ref = building
	_building_cx = cx
	_building_cy = cy
	# 创建进度条
	_bar = ColorRect.new()
	_bar.color = Color(0, 0.8, 0.2, 0.8)
	_bar.size = Vector2(48, 6)
	_bar.position = Vector2(-24, -24)  # 建筑上方
	add_child(_bar)
	# 背景
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.2, 0.8)
	bg.size = Vector2(48, 6)
	bg.position = Vector2(-24, -24)
	add_child(bg)
	move_child(bg, 0)  # 背景放下面
	visible = false

func show():
	visible = true

func hide():
	visible = false

func update_progress(pct):
	if _bar:
		_bar.size.x = 48 * pct
