# RoadSystem.gd — 道路系统
# 处理道路的放置、拆除、可达性更新

extends Node

var _grid_map: Node = null

## 绘制状态
enum DrawMode { NONE, PLACING, REMOVING }
var draw_mode := DrawMode.NONE
var _drag_start_cell := Vector2i(-1, -1)
var _last_drag_cell := Vector2i(-1, -1)
var _current_road_type := 0  # 0=dirt, 1=asphalt, 2=highway

## 道路类型配置
const ROAD_COLORS := [
	Color(0.45, 0.35, 0.2),   # 0: 土路
	Color(0.3, 0.3, 0.3),     # 1: 沥青路
	Color(0.15, 0.15, 0.15),  # 2: 高速路
]

signal road_changed

func setup(grid_map: Node):
	_grid_map = grid_map

## 开始绘制道路
func start_draw(cell_pos: Vector2i, road_type: int = 0):
	draw_mode = DrawMode.PLACING
	_current_road_type = road_type
	_drag_start_cell = cell_pos
	_last_drag_cell = cell_pos
	_place_road_cell(cell_pos)

## 继续绘制（拖拽中）
func continue_draw(cell_pos: Vector2i, road_type: int = -1):
	if draw_mode != DrawMode.PLACING:
		return
	if cell_pos == _last_drag_cell:
		return
	if road_type >= 0:
		_current_road_type = road_type

	# 画直线（从上一个点到当前点）
	_draw_line(_last_drag_cell, cell_pos)
	_last_drag_cell = cell_pos

## 结束绘制
func end_draw():
	if draw_mode == DrawMode.PLACING:
		_grid_map.recalc_reachability()
		emit_signal("road_changed")
	draw_mode = DrawMode.NONE
	_drag_start_cell = Vector2i(-1, -1)

## 开始拆除
func start_remove(cell_pos: Vector2i):
	draw_mode = DrawMode.REMOVING
	_remove_road_cell(cell_pos)

## 继续拆除
func continue_remove(cell_pos: Vector2i):
	if draw_mode != DrawMode.REMOVING:
		return
	_remove_road_cell(cell_pos)

## 结束拆除
func end_remove():
	if draw_mode == DrawMode.REMOVING:
		_grid_map.recalc_reachability()
		emit_signal("road_changed")
	draw_mode = DrawMode.NONE

func _place_road_cell(cell_pos: Vector2i):
	if _grid_map.is_buildable(cell_pos.x, cell_pos.y):
		_grid_map.set_terrain(cell_pos.x, cell_pos.y, _grid_map.TerrainType.ROAD)
		var cell = _grid_map.get_cell(cell_pos.x, cell_pos.y)
		if cell:
			cell.road_type = _current_road_type

func _remove_road_cell(cell_pos: Vector2i):
	var cell = _grid_map.get_cell(cell_pos.x, cell_pos.y)
	if cell and cell.terrain == _grid_map.TerrainType.ROAD:
		_grid_map.set_terrain(cell_pos.x, cell_pos.y, _grid_map.TerrainType.GRASS)

## 画线算法（Bresenham 直线）
func _draw_line(from: Vector2i, to: Vector2i):
	var x0 = from.x
	var y0 = from.y
	var x1 = to.x
	var y1 = to.y

	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy

	while true:
		_place_road_cell(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy

## 获取道路总长度（用于维护费计算）
func get_road_cell_count() -> int:
	var count = 0
	for y in range(_grid_map.GRID_HEIGHT):
		for x in range(_grid_map.GRID_WIDTH):
			if _grid_map.is_road(x, y):
				count += 1
	return count

## 获取所有道路格坐标
func get_all_road_cells() -> Array:
	var cells = []
	for y in range(_grid_map.GRID_HEIGHT):
		for x in range(_grid_map.GRID_WIDTH):
			if _grid_map.is_road(x, y):
				cells.append(Vector2i(x, y))
	return cells
