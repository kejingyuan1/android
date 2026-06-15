# GridMap.gd — 网格数据模型
# 存储 40×40 网格的所有单元格数据，作为纯数据层

extends Node

## 地形类型枚举
enum TerrainType {
	GRASS = 0,
	ROAD = 1,
	ZONE_RESIDENTIAL = 2,
	ZONE_COMMERCIAL = 3,
	ZONE_INDUSTRIAL = 4,
}

## 自然地形枚举（随机生成的基础地貌）
enum NaturalTerrain {
	WATER = 0,
	SAND = 1,
	GRASS = 2,
	FOREST = 3,
	HILL = 4,
	MOUNTAIN = 5,
}

## 单元格数据结构
class CellData:
	var x: int
	var y: int
	var terrain: int         # TerrainType（玩家建造的结果）
	var road_type: int       # 0=dirt, 1=asphalt, 2=highway
	var natural_terrain: int # NaturalTerrain（基础地貌，由地形生成器产生）
	var reachable: bool      # 是否沿路可达
	var has_building: bool
	var building_level: int  # 0=无, 1-3=等级
	var building_size_x: int  # 建筑占地宽度（格）
	var building_size_y: int  # 建筑占地高度（格）
	var building_ref         # BuildingNode 弱引用（手动放置建筑为 Sprite2D，分区自动生长为 BuildingNode）
	var building_variant_id: int = -1  # 手动放置建筑的 variant_id（用于移动/拆除时识别）
	var zone_connected: bool # 是否已接入分区网络

	func _init(p_x: int, p_y: int):
		x = p_x
		y = p_y
		terrain = TerrainType.GRASS
		road_type = 0
		natural_terrain = NaturalTerrain.GRASS
		reachable = false
		has_building = false
		building_level = 0
		building_size_x = 1
		building_size_y = 1
		building_ref = null
		building_variant_id = -1
		zone_connected = false

## 网格属性（横屏 240×160）
const GRID_WIDTH := 240
const GRID_HEIGHT := 160
const GRID_SIZE := GRID_HEIGHT  # 兼容旧代码（保留下边界）
const CELL_SIZE := 32
var grid: Array  # 2D array [y][x] of CellData

func _ready():
	_init_grid()

func _init_grid():
	grid = []
	for y in range(GRID_HEIGHT):
		var row: Array = []
		for x in range(GRID_WIDTH):
			row.append(CellData.new(x, y))
		grid.append(row)

## 应用自然地形到全图
func apply_natural_terrain(terrain_data: Array):
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell = get_cell(x, y)
			if cell:
				cell.natural_terrain = terrain_data[y][x]

func get_cell(x: int, y: int) -> CellData:
	if x < 0 or x >= GRID_WIDTH or y < 0 or y >= GRID_HEIGHT:
		return null
	return grid[y][x]

func set_terrain(x: int, y: int, terrain_type: int):
	var cell = get_cell(x, y)
	if cell:
		cell.terrain = terrain_type

func get_terrain(x: int, y: int) -> int:
	var cell = get_cell(x, y)
	return cell.terrain if cell else TerrainType.GRASS

func get_natural_terrain(x: int, y: int) -> int:
	var cell = get_cell(x, y)
	return cell.natural_terrain if cell else NaturalTerrain.GRASS

func is_road(x: int, y: int) -> bool:
	var cell = get_cell(x, y)
	return cell != null and cell.terrain == TerrainType.ROAD

func is_zoned(x: int, y: int) -> bool:
	var cell = get_cell(x, y)
	if not cell:
		return false
	return cell.terrain in [TerrainType.ZONE_RESIDENTIAL, TerrainType.ZONE_COMMERCIAL, TerrainType.ZONE_INDUSTRIAL]

func is_buildable(x: int, y: int) -> bool:
	var cell = get_cell(x, y)
	if not cell:
		return false
	# 水域和山上不能建造
	if cell.natural_terrain in [NaturalTerrain.WATER, NaturalTerrain.MOUNTAIN]:
		return false
	return cell.terrain == TerrainType.GRASS

func get_zone_type(x: int, y: int) -> int:
	var cell = get_cell(x, y)
	return cell.terrain if cell else TerrainType.GRASS

## 计算所有道路格的可达性（BFS 从地图四周边界道路开始）
func recalc_reachability():
	# 先全部重置
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell = grid[y][x]
			cell.reachable = false
			cell.zone_connected = false

	# 从最外圈的道路格开始 BFS
	var queue = []
	# 检查地图四边
	for x in range(GRID_WIDTH):
		if grid[0][x].terrain == TerrainType.ROAD:
			queue.append(Vector2i(x, 0))
		if grid[GRID_HEIGHT-1][x].terrain == TerrainType.ROAD:
			queue.append(Vector2i(x, GRID_HEIGHT-1))
	for y in range(GRID_HEIGHT):
		if grid[y][0].terrain == TerrainType.ROAD:
			queue.append(Vector2i(0, y))
		if grid[y][GRID_WIDTH-1].terrain == TerrainType.ROAD:
			queue.append(Vector2i(GRID_WIDTH-1, y))

	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	while queue.size() > 0:
		var pos = queue.pop_front()
		var cell = grid[pos.y][pos.x]
		if cell.reachable:
			continue
		cell.reachable = true
		# 标记沿路 1 格范围的分区格为 connected
		for d in dirs:
			var nx = pos.x + d.x
			var ny = pos.y + d.y
			if nx >= 0 and nx < GRID_WIDTH and ny >= 0 and ny < GRID_HEIGHT:
				var neighbor = grid[ny][nx]
				if neighbor.terrain == TerrainType.ROAD and not neighbor.reachable:
					queue.append(Vector2i(nx, ny))
				elif neighbor.terrain != TerrainType.ROAD and neighbor.terrain != TerrainType.GRASS:
					neighbor.zone_connected = true

	# 第二步：从已连通的分区格扩散连通状态到相邻同类型分区
	queue = []
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x].zone_connected:
				queue.append(Vector2i(x, y))

	while queue.size() > 0:
		var pos = queue.pop_front()
		for d in dirs:
			var nx = pos.x + d.x
			var ny = pos.y + d.y
			if nx >= 0 and nx < GRID_WIDTH and ny >= 0 and ny < GRID_HEIGHT:
				var neighbor = grid[ny][nx]
				if neighbor.is_zoned() and not neighbor.zone_connected:
					neighbor.zone_connected = true
					queue.append(Vector2i(nx, ny))

## 世界坐标 ↔ 网格坐标
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var gx = int(floor(world_pos.x / CELL_SIZE))
	var gy = int(floor(world_pos.y / CELL_SIZE))
	return Vector2i(gx, gy)

func grid_to_world(gx: int, gy: int) -> Vector2:
	return Vector2(gx * CELL_SIZE, gy * CELL_SIZE)

func grid_to_world_center(gx: int, gy: int) -> Vector2:
	return Vector2(gx * CELL_SIZE + CELL_SIZE / 2, gy * CELL_SIZE + CELL_SIZE / 2)
