# TerrainGenerator.gd — 随机地形生成
# 使用 Perlin 噪声 + 多图层叠加生成自然地形

extends Node

## 地形类型
enum TerrainType {
	WATER = 0,     # 水域（湖/河）
	SAND = 1,      # 沙滩（水域边缘）
	GRASS = 2,     # 草地（默认）
	FOREST = 3,    # 森林
	HILL = 4,      # 丘陵
	MOUNTAIN = 5,  # 山地
}

## 生成参数（横屏 240×160）
const MAP_WIDTH := 240
const MAP_HEIGHT := 160
const TILE_SIZE := 64

## 主循环噪声层（控制海拔/地形起伏）
var _elevation_noise: FastNoiseLite

## 湿度噪声层（控制森林分布）
var _moisture_noise: FastNoiseLite

## 细节噪声层（用于水域点缀等）
var _detail_noise: FastNoiseLite

func _ready():
	randomize()
	_init_noise()

func _init_noise():
	# 海拔噪声 — 低频，产生大陆级别的地形（类似世界地图的大洲）
	_elevation_noise = FastNoiseLite.new()
	_elevation_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_elevation_noise.frequency = 0.022
	_elevation_noise.seed = randi()
	_elevation_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_elevation_noise.fractal_octaves = 5
	_elevation_noise.fractal_lacunarity = 2.0
	_elevation_noise.fractal_gain = 0.5

	# 湿度噪声 — 控制森林/草地过渡
	_moisture_noise = FastNoiseLite.new()
	_moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_moisture_noise.frequency = 0.04
	_moisture_noise.seed = randi()
	_moisture_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_moisture_noise.fractal_octaves = 3

	# 细节噪声 — 点缀
	_detail_noise = FastNoiseLite.new()
	_detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_detail_noise.frequency = 0.12
	_detail_noise.seed = randi()

## 生成全图地形数据，返回 2D 数组 [y][x] of TerrainType
func generate() -> Array:
	var result = []
	result.resize(MAP_HEIGHT)

	# 第一步：生成海拔图
	var elevation = []
	elevation.resize(MAP_HEIGHT)
	for y in range(MAP_HEIGHT):
		elevation[y] = []
		elevation[y].resize(MAP_WIDTH)
		for x in range(MAP_WIDTH):
			var val = _elevation_noise.get_noise_2d(x, y)
			# 归一化到 0~1
			var e = (val + 1.0) / 2.0
			elevation[y][x] = e

	# 第二步：根据海拔映射地形
	var moisture = []
	moisture.resize(MAP_HEIGHT)

	var terrain = []
	terrain.resize(MAP_HEIGHT)

	for y in range(MAP_HEIGHT):
		terrain[y] = []
		terrain[y].resize(MAP_WIDTH)
		moisture[y] = []
		moisture[y].resize(MAP_WIDTH)

		for x in range(MAP_WIDTH):
			var e = elevation[y][x]
			var m = (_moisture_noise.get_noise_2d(x, y) + 1.0) / 2.0
			moisture[y][x] = m

			# ===== 海拔决定基本地形（模拟世界地图比例）=====
			if e < 0.38:
				# 低海拔 → 海洋/湖泊
				terrain[y][x] = TerrainType.WATER
			elif e < 0.45:
				# 海岸线 → 沙滩
				terrain[y][x] = TerrainType.SAND
			elif e < 0.60:
				# 平原
				if m > 0.6:
					terrain[y][x] = TerrainType.FOREST
				else:
					terrain[y][x] = TerrainType.GRASS
			elif e < 0.75:
				# 丘陵
				terrain[y][x] = TerrainType.HILL
			else:
				# 高山
				terrain[y][x] = TerrainType.MOUNTAIN

	# 第三步：后处理——去噪
	# 铲除孤立的单格水域（太小的水坑不好看）
	terrain = _remove_isolated_water(terrain)
	# 扩展沙滩
	terrain = _expand_beach(terrain)
	# 添加少量湖泊点缀（可选）
	terrain = _add_small_lakes(terrain, elevation)

	return terrain

## 铲除孤立的单格水域
func _remove_isolated_water(terrain: Array) -> Array:
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			if terrain[y][x] == TerrainType.WATER:
				var water_neighbors = 0
				var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
					Vector2i(1,1), Vector2i(-1,1), Vector2i(1,-1), Vector2i(-1,-1)]
				for d in dirs:
					var nx = x + d.x
					var ny = y + d.y
					if nx >= 0 and nx < MAP_WIDTH and ny >= 0 and ny < MAP_HEIGHT:
						if terrain[ny][nx] == TerrainType.WATER:
							water_neighbors += 1
				# 少于 2 个水邻居 → 太小，改为草地
				if water_neighbors <= 1:
					var m = (_moisture_noise.get_noise_2d(x, y) + 1.0) / 2.0
					terrain[y][x] = TerrainType.FOREST if m > 0.6 else TerrainType.GRASS
	return terrain

## 在水域边缘扩展沙滩
func _expand_beach(terrain: Array) -> Array:
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			if terrain[y][x] == TerrainType.WATER:
				var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
				for d in dirs:
					var nx = x + d.x
					var ny = y + d.y
					if nx >= 0 and nx < MAP_WIDTH and ny >= 0 and ny < MAP_HEIGHT:
						if terrain[ny][nx] == TerrainType.GRASS or terrain[ny][nx] == TerrainType.FOREST:
							terrain[ny][nx] = TerrainType.SAND
	return terrain

## 添加小湖泊点缀（在平原区域）
func _add_small_lakes(terrain: Array, elevation: Array) -> Array:
	# 使用细节噪声生成小水坑
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			if terrain[y][x] == TerrainType.GRASS or terrain[y][x] == TerrainType.FOREST:
				var detail = (_detail_noise.get_noise_2d(x * 2, y * 2) + 1.0) / 2.0
				if detail < 0.08 and elevation[y][x] < 0.4:
					terrain[y][x] = TerrainType.WATER
	return terrain

## 获取地形的颜色（用于程序化生成 Sprite）
func get_terrain_color(terrain_type: int) -> Color:
	match terrain_type:
		TerrainType.WATER:
			return Color(0.15, 0.42, 0.72)
		TerrainType.SAND:
			return Color(0.72, 0.65, 0.42)
		TerrainType.GRASS:
			return Color(0.22, 0.58, 0.12)
		TerrainType.FOREST:
			return Color(0.10, 0.38, 0.06)
		TerrainType.HILL:
			return Color(0.52, 0.38, 0.18)
		TerrainType.MOUNTAIN:
			return Color(0.45, 0.42, 0.38)
		_:
			return Color(0.22, 0.58, 0.12)

## 获取地形的网格线颜色（略亮于底色）
func get_terrain_grid_color(terrain_type: int) -> Color:
	var base = get_terrain_color(terrain_type)
	return Color(
		min(base.r + 0.12, 1.0),
		min(base.g + 0.12, 1.0),
		min(base.b + 0.12, 1.0),
		0.35
	)
