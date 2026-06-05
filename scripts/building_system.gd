# BuildingSystem.gd ? ??????
extends Node

var _grid_map = null
var _economy = null
var _building_container = null
var _service_system = null
var _game_manager = null

signal buildings_updated

const BUILD_COST := 100
const UPGRADE_COST_MULTIPLIER := 3.0

func setup(grid_map, economy, container, service_system = null, game_manager = null):
	_grid_map = grid_map
	_economy = economy
	_building_container = container
	_service_system = service_system
	_game_manager = game_manager

func process_tick():
	var changes = false
	var checked = 0
	var gs = _grid_map.GRID_SIZE if _grid_map else 160
	for y in range(gs):
		for x in range(gs):
			var cell = _grid_map.get_cell(x, y)
			if not cell:
				continue
			if not _grid_map.is_zoned(x, y):
				continue
			checked += 1
			if not cell.has_building:
				if _try_grow_building(cell):
					changes = true
			else:
				if _try_upgrade_building(cell):
					changes = true
	if checked > 0:
		print("process_tick: checked ", checked, " zoned cells, changes=", changes)
	if changes:
		emit_signal("buildings_updated")

func _try_grow_building(cell) -> bool:
	if randf() > 0.8:
		return false
	var density = _get_zone_density(cell.x, cell.y, cell.terrain)
	if density < 1:
		return false
	if not _economy.can_afford(10):
		return false
	if not _economy.spend(10, "建筑建造"):
		return false

	# 根据地类随机分配建筑尺寸
	var sz_x = 1
	var sz_y = 1
	match cell.terrain:
		2:  # Residential — 1×1 到 2×2
			sz_x = 1 + (0 if randf() < 0.6 else 1)
			sz_y = 1 + (0 if randf() < 0.6 else 1)
		3:  # Commercial — 1×1 到 4×2
			sz_x = 1 + int(randf() * 3)  # 1~4
			sz_y = 1 + int(randf() * 2)  # 1~2
		4:  # Industrial — 2×2 到 4×3
			sz_x = 2 + int(randf() * 3)  # 2~4
			sz_y = 2 + int(randf() * 2)  # 2~3

	# 检查占地面积是否可用
	if not _is_area_clear(cell.x, cell.y, sz_x, sz_y):
		return false

	# 标记所有占地格
	for dy in range(sz_y):
		for dx in range(sz_x):
			var nx = cell.x + dx
			var ny = cell.y + dy
			var c = _grid_map.get_cell(nx, ny)
			if c:
				c.has_building = true
				c.building_ref = cell.building_ref
				# 清除分区颜色显示
				if _game_manager and _game_manager.has_method("_update_cell_visual"):
					_game_manager._update_cell_visual(nx, ny)

	# 主格设置
	cell.building_level = 1
	cell.building_size_x = sz_x
	cell.building_size_y = sz_y
	var bld = _create_building_node(cell.x, cell.y, cell.terrain, 1, sz_x, sz_y)
	cell.building_ref = bld
	# 清除主格分区颜色
	if _game_manager and _game_manager.has_method("_update_cell_visual"):
		_game_manager._update_cell_visual(cell.x, cell.y)
	return true

## 检查 x,y 开始的 w×h 区域是否可建造
func _is_area_clear(start_x: int, start_y: int, w: int, h: int) -> bool:
	for dy in range(h):
		for dx in range(w):
			var nx = start_x + dx
			var ny = start_y + dy
			var gs = _grid_map.GRID_SIZE if _grid_map else 160
			if nx < 0 or nx >= gs or ny < 0 or ny >= gs:
				return false
			var c = _grid_map.get_cell(nx, ny)
			if not c or c.has_building or not _grid_map.is_zoned(nx, ny):
				return false
	return true

func _try_upgrade_building(cell) -> bool:
	var current_level = cell.building_level
	if current_level >= 3:
		return false
	var upgrade_chance = 0.1 * (1.0 / current_level)
	if randf() > upgrade_chance:
		return false
	var total_pop = _get_total_population()
	var level_req = current_level * 50
	if total_pop < level_req:
		return false
	if _service_system:
		var cov = _service_system.get_coverage(cell.x, cell.y)
		if current_level >= 2 and cov["police"] == 0:
			return false
		if current_level >= 3 and cov["fire"] == 0:
			return false
	var cost = BUILD_COST * UPGRADE_COST_MULTIPLIER * current_level
	if not _economy.can_afford(cost):
		return false
	if not _economy.spend(cost, "????"):
		return false
	cell.building_level = current_level + 1
	if cell.building_ref:
		cell.building_ref.update_level(cell.building_level)
	else:
		var bld = _create_building_node(cell.x, cell.y, cell.terrain, cell.building_level)
		cell.building_ref = bld
		cell.has_building = true
	if _game_manager and _game_manager.has_method("_update_cell_visual"):
		_game_manager._update_cell_visual(cell.x, cell.y)
	return true

func _create_building_node(gx, gy, zone_type, level, size_x = 1, size_y = 1):
	var node = Node2D.new()
	node.set_script(preload("res://scripts/building_node.gd"))
	node.z_index = 5
	node.setup(gx, gy, zone_type, level, size_x, size_y)
	_building_container.add_child(node)
	print("创建了建筑: (", gx, ",", gy, ") type=", zone_type, " size=", size_x, "x", size_y)
	return node

func _get_zone_density(cx, cy, zone_type) -> int:
	var count = 0
	var gs = _grid_map.GRID_SIZE if _grid_map else 160
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var nx = cx + dx
			var ny = cy + dy
			if nx >= 0 and nx < gs and ny >= 0 and ny < gs:
				var cell = _grid_map.get_cell(nx, ny)
				if cell and cell.terrain == zone_type:
					count += 1
	return count

func _get_total_population() -> int:
	var total = 0
	var gs = _grid_map.GRID_SIZE if _grid_map else 160
	for y in range(gs):
		for x in range(gs):
			var cell = _grid_map.get_cell(x, y)
			if cell and cell.has_building:
				total += _get_building_population(cell)
	return total

func _get_building_population(cell) -> int:
	if not cell.has_building:
		return 0
	var base_pop = _get_zone_base_population(cell.terrain)
	return base_pop * cell.building_level

func _get_zone_base_population(zone_type) -> int:
	match zone_type:
		2: return 10
		3: return 5
		4: return 3
	return 0

func get_residential_population() -> int:
	var total = 0
	var gs = _grid_map.GRID_SIZE if _grid_map else 160
	for y in range(gs):
		for x in range(gs):
			var cell = _grid_map.get_cell(x, y)
			if cell and cell.has_building and cell.terrain == 2:
				total += _get_building_population(cell)
	return total

func get_commercial_count() -> int:
	var count = 0
	var gs = _grid_map.GRID_SIZE if _grid_map else 160
	for y in range(gs):
		for x in range(gs):
			var cell = _grid_map.get_cell(x, y)
			if cell and cell.has_building and cell.terrain == 3:
				count += 1
	return count

func get_industrial_count() -> int:
	var count = 0
	var gs = _grid_map.GRID_SIZE if _grid_map else 160
	for y in range(gs):
		for x in range(gs):
			var cell = _grid_map.get_cell(x, y)
			if cell and cell.has_building and cell.terrain == 4:
				count += 1
	return count

func get_developed_cell_count(zone_type) -> int:
	var count = 0
	var gs = _grid_map.GRID_SIZE if _grid_map else 160
	for y in range(gs):
		for x in range(gs):
			var cell = _grid_map.get_cell(x, y)
			if cell and cell.terrain == zone_type and cell.has_building:
				count += 1
	return count
