# ServiceSystem.gd — 公共服务系统
extends Node

enum ServiceType { POLICE = 0, FIRE = 1, MEDICAL = 2, SCHOOL = 3 }

class ServiceBuilding:
	var type: int
	var grid_x: int
	var grid_y: int
	var name: String
	var radius: int
	var cost: float
	var upkeep: float

	func _init(t: int, gx: int, gy: int):
		type = t; grid_x = gx; grid_y = gy
		match t:
			0: name = "警局"; radius = 8; cost = 500; upkeep = 10
			1: name = "消防局"; radius = 7; cost = 400; upkeep = 8
			2: name = "医院"; radius = 6; cost = 600; upkeep = 12
			3: name = "学校"; radius = 5; cost = 800; upkeep = 15

var _grid_map = null
var _building_system = null
var _economy = null
var _game_manager = null
var _container = null

var buildings: Array = []
var _visual_nodes: Array = []
var _coverage: Array = []

signal service_changed

func setup(grid_map, building_system, economy, game_manager, container = null):
	_grid_map = grid_map
	_building_system = building_system
	_economy = economy
	_game_manager = game_manager
	_container = container
	_init_coverage()

func _init_coverage():
	_coverage = []
	var gs = _grid_map.GRID_SIZE if _grid_map else 160
	for y in range(gs):
		var row = []
		for x in range(gs):
			row.append({"police": 0, "fire": 0, "medical": 0, "school": 0})
		_coverage.append(row)

func place_service(type: int, gx: int, gy: int) -> bool:
	var cell = _grid_map.get_cell(gx, gy)
	if not cell or not _grid_map.is_buildable(gx, gy):
		return false
	var svc = ServiceBuilding.new(type, gx, gy)
	if not _economy.can_afford(svc.cost):
		return false
	_economy.spend(svc.cost, "建造" + svc.name)
	buildings.append(svc)
	_grid_map.set_terrain(gx, gy, _grid_map.TerrainType.ROAD)
	# 创建视觉节点
	if _container:
		var node = Node2D.new()
		node.set_script(preload("res://scripts/service_building_node.gd"))
		node.z_index = 5
		node.setup(gx, gy, type)
		_container.add_child(node)
		_visual_nodes.append(node)
	_recalc_coverage()
	emit_signal("service_changed")
	return true

func remove_service(gx: int, gy: int) -> bool:
	for i in range(buildings.size()):
		if buildings[i].grid_x == gx and buildings[i].grid_y == gy:
			buildings.remove_at(i)
			if i < _visual_nodes.size() and _visual_nodes[i]:
				_visual_nodes[i].queue_free()
			_visual_nodes.remove_at(i)
			_grid_map.set_terrain(gx, gy, _grid_map.TerrainType.GRASS)
			_recalc_coverage()
			emit_signal("service_changed")
			return true
	return false

func _recalc_coverage():
	_init_coverage()
	for b in buildings:
		for dy in range(-b.radius, b.radius + 1):
			for dx in range(-b.radius, b.radius + 1):
				var nx = b.grid_x + dx; var ny = b.grid_y + dy
				if nx >= 0 and nx < _grid_map.GRID_SIZE and ny >= 0 and ny < _grid_map.GRID_SIZE:
					if sqrt(dx*dx + dy*dy) <= b.radius:
						match b.type:
							0: _coverage[ny][nx]["police"] += 1
							1: _coverage[ny][nx]["fire"] += 1
							2: _coverage[ny][nx]["medical"] += 1
							3: _coverage[ny][nx]["school"] += 1

func get_coverage(gx: int, gy: int) -> Dictionary:
	var gs = _grid_map.GRID_SIZE if _grid_map else 160
	if gx < 0 or gx >= gs or gy < 0 or gy >= gs:
		return {"police": 0, "fire": 0, "medical": 0, "school": 0}
	return _coverage[gy][gx]

func get_total_upkeep() -> float:
	var total = 0.0
	for b in buildings:
		total += b.upkeep
	return total

func get_building_count(type: int) -> int:
	var count = 0
	for b in buildings:
		if b.type == type: count += 1
	return count

func get_happiness() -> float:
	var total = 0; var covered = 0
	var gs = _grid_map.GRID_SIZE if _grid_map else 160
	for y in range(gs):
		for x in range(gs):
			var cell = _grid_map.get_cell(x, y)
			if cell and cell.has_building:
				total += 1
				var cov = _coverage[y][x]
				if cov["police"] > 0 and cov["fire"] > 0 and cov["medical"] > 0:
					covered += 1
	return float(covered) / float(total) if total > 0 else 0.5

func get_education_rate() -> float:
	var total = 0; var covered = 0
	var gs = _grid_map.GRID_SIZE if _grid_map else 160
	for y in range(gs):
		for x in range(gs):
			if _coverage[y][x]["school"] > 0: covered += 1
			total += 1
	return float(covered) / float(total) if total > 0 else 0.0

func process_tick():
	pass
