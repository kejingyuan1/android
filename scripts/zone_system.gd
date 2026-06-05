# ZoneSystem.gd — 分区系统
# 处理三种分区（住宅/商业/工业）的涂色和拆除

extends Node

var _grid_map: Node = null
var _economy: Node = null

## 当前选中的分区类型
var current_zone_type := -1  # -1=未选中

## 绘制状态
enum DrawMode { NONE, ZONING, REMOVING }
var draw_mode := DrawMode.NONE

signal zone_changed

func setup(grid_map: Node, economy: Node):
	_grid_map = grid_map
	_economy = economy

func set_zone_type(zone_type: int):
	current_zone_type = zone_type

func get_zone_type() -> int:
	return current_zone_type

func start_zone(cell_pos: Vector2i):
	if current_zone_type < 0:
		return
	draw_mode = DrawMode.ZONING
	_apply_zone(cell_pos)

func continue_zone(cell_pos: Vector2i):
	if draw_mode != DrawMode.ZONING:
		return
	_apply_zone(cell_pos)

func end_zone():
	draw_mode = DrawMode.NONE
	emit_signal("zone_changed")

func start_remove(cell_pos: Vector2i):
	draw_mode = DrawMode.REMOVING
	_remove_zone(cell_pos)

func continue_remove(cell_pos: Vector2i):
	if draw_mode != DrawMode.REMOVING:
		return
	_remove_zone(cell_pos)

func end_remove():
	draw_mode = DrawMode.NONE
	emit_signal("zone_changed")

func _apply_zone(cell_pos: Vector2i):
	var cell = _grid_map.get_cell(cell_pos.x, cell_pos.y)
	if not cell:
		return
	# 必须是可以建造的格子
	if not _grid_map.is_buildable(cell_pos.x, cell_pos.y):
		return
	# 如果上面有建筑则不能分区
	if cell.has_building:
		return

	_grid_map.set_terrain(cell_pos.x, cell_pos.y, current_zone_type)

func _remove_zone(cell_pos: Vector2i):
	var cell = _grid_map.get_cell(cell_pos.x, cell_pos.y)
	if not cell:
		return
	if cell.terrain in [_grid_map.TerrainType.ZONE_RESIDENTIAL,
			_grid_map.TerrainType.ZONE_COMMERCIAL,
			_grid_map.TerrainType.ZONE_INDUSTRIAL]:
		# 如果上面有建筑，先清除建筑
		if cell.has_building and cell.building_ref:
			cell.building_ref.queue_free()
			cell.has_building = false
			cell.building_level = 0
			cell.building_ref = null
		_grid_map.set_terrain(cell_pos.x, cell_pos.y, _grid_map.TerrainType.GRASS)

func _has_adjacent_road(cell_pos: Vector2i) -> bool:
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for d in dirs:
		var nx = cell_pos.x + d.x
		var ny = cell_pos.y + d.y
		if nx >= 0 and nx < _grid_map.GRID_WIDTH and ny >= 0 and ny < _grid_map.GRID_HEIGHT:
			if _grid_map.is_road(nx, ny):
				return true
	return false

## 获取已分区格总数（根据类型）
func get_zone_cell_count(zone_type: int) -> int:
	var count = 0
	for y in range(_grid_map.GRID_HEIGHT):
		for x in range(_grid_map.GRID_WIDTH):
			if _grid_map.get_terrain(x, y) == zone_type:
				count += 1
	return count

## 获取有建筑的分区格数
func get_developed_cell_count(zone_type: int) -> int:
	var count = 0
	for y in range(_grid_map.GRID_HEIGHT):
		for x in range(_grid_map.GRID_WIDTH):
			var cell = _grid_map.get_cell(x, y)
			if cell and cell.terrain == zone_type and cell.has_building:
				count += 1
	return count
