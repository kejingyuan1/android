# WorldGenerator.gd — 超级大地图生成器
class_name WorldGenerator
# 使用种子驱动 Perlin 噪声，100,000×100,000 按需生成
# 任何 (x, y) 坐标可独立查询，无需预生成全图

extends RefCounted

## 世界地形枚举
enum TerrainType {
	DEEP_OCEAN = 0,
	SHALLOW_OCEAN = 1,
	SAND = 2,
	GRASS = 3,
	FOREST = 4,
	HILL = 5,
	MOUNTAIN = 6,
	SNOW = 7,
}

## 世界资源枚举
enum ResourceType {
	NONE = 0,
	FARM = 1,        # 肥沃农田 → 粮食加成
	TIMBER = 2,      # 森林 → 木材加成
	IRON = 3,        # 铁矿 → 工业加成
	FISHERY = 4,     # 渔场 → 渔业加成
	GEM = 5,         # 宝石 → 岛屿特产
	GOLD_MINE = 6,   # 金矿 → 金币直接收入
	VOLCANIC = 7,    # 火山土 → 农业超高加成（稀有）
	COAL = 8,        # 煤矿 → 工业燃料
	STONE = 9,       # 石材 → 建筑加速
}

## 世界常量
enum IslandType {
	CONTINENT = 0,   # 主大陆
	ISLAND = 1,      # 岛屿
}

const WORLD_SIZE := 100000          # 100,000 × 100,000
const SEED_RANGE := 2147483647

## 世界种子
var world_seed: int = 0

## 噪声层
var _elevation_noise: FastNoiseLite
var _moisture_noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _resource_noise: FastNoiseLite

## 岛屿分析缓存（粗粒度，100×100 精度）
var _continent_mask: Dictionary      # key: coarse_x,coarse_y → bool (is_continent)
var _continent_size: int = 0         # 大陆格点数（粗粒度）
var _island_analysis_done := false

func _init(seed_val: int = -1):
	world_seed = seed_val if seed_val >= 0 else randi()
	_init_noise()

func _init_noise():
	# 底层海拔噪声：低频 → 大陆尺度地貌
	_elevation_noise = FastNoiseLite.new()
	_elevation_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_elevation_noise.frequency = 0.00015   # 真·大陆尺度
	_elevation_noise.seed = world_seed
	_elevation_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_elevation_noise.fractal_octaves = 6
	_elevation_noise.fractal_lacunarity = 2.0
	_elevation_noise.fractal_gain = 0.5

	# 中层细节噪声：海岸线细节 + 岛屿
	var detail_seed = world_seed + 10000
	_moisture_noise = FastNoiseLite.new()
	_moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_moisture_noise.frequency = 0.0006
	_moisture_noise.seed = detail_seed
	_moisture_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_moisture_noise.fractal_octaves = 4

	# 湿度噪声：森林/草地分布
	var moist_seed = world_seed + 20000
	_detail_noise = FastNoiseLite.new()
	_detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_detail_noise.frequency = 0.0004
	_detail_noise.seed = moist_seed

	# 资源分布噪声
	var res_seed = world_seed + 30000
	_resource_noise = FastNoiseLite.new()
	_resource_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_resource_noise.frequency = 0.0008
	_resource_noise.seed = res_seed

## 获取指定坐标的海拔 (0.0 ~ 1.0)
func get_elevation(wx: int, wy: int) -> float:
	var val = _elevation_noise.get_noise_2d(wx, wy)
	# 加入细节噪声，让海岸线更丰富
	var detail = _moisture_noise.get_noise_2d(wx, wy) * 0.15
	val += detail
	return (val + 1.0) / 2.0

## 获取指定坐标的地形
func get_terrain(wx: int, wy: int) -> int:
	var e = get_elevation(wx, wy)
	if e < 0.42:
		return TerrainType.DEEP_OCEAN
	elif e < 0.48:
		return TerrainType.SHALLOW_OCEAN
	elif e < 0.52:
		return TerrainType.SAND
	elif e < 0.60:
		var m = (_detail_noise.get_noise_2d(wx, wy) + 1.0) / 2.0
		return TerrainType.FOREST if m > 0.6 else TerrainType.GRASS
	elif e < 0.72:
		return TerrainType.FOREST if e < 0.65 else TerrainType.HILL
	elif e < 0.85:
		return TerrainType.MOUNTAIN
	else:
		return TerrainType.SNOW

## 判断是否为陆地
func is_land(wx: int, wy: int) -> bool:
	var t = get_terrain(wx, wy)
	return t != TerrainType.DEEP_OCEAN and t != TerrainType.SHALLOW_OCEAN

## 判断是否为岛屿（非大陆连通区域）
func is_island(wx: int, wy: int) -> bool:
	if not is_land(wx, wy):
		return false
	# 使用粗粒度掩码判断
	var cx = wx / 100
	var cy = wy / 100
	var key = str(cx) + "," + str(cy)
	if not _continent_mask.has(key):
		_analyze_island_at(cx, cy)
	return not _continent_mask.get(key, false)

## 粗粒度岛屿分析：从该粗格开始 BFS
func _analyze_island_at(start_cx: int, start_cy: int):
	var coarse_land = {}  # key → true: 这片区域的粗格
	var queue = [Vector2i(start_cx, start_cy)]
	coarse_land[str(start_cx) + "," + str(start_cy)] = true

	# BFS 找出所有连通的粗格陆地块
	var checked = {}
	while queue.size() > 0:
		var cur = queue.pop_front()
		var k = str(cur.x) + "," + str(cur.y)
		if checked.has(k):
			continue
		checked[k] = true

		# 检查此粗格是否包含陆地
		var has_land = false
		for dy in range(10):
			for dx in range(10):
				var wx = cur.x * 100 + dx * 10
				var wy = cur.y * 100 + dy * 10
				if wx < WORLD_SIZE and wy < WORLD_SIZE and is_land(wx, wy):
					has_land = true
					break
			if has_land:
				break
		if not has_land:
			continue

		coarse_land[k] = true

		# 向四邻域扩展
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var nx = cur.x + d.x
			var ny = cur.y + d.y
			if nx >= 0 and nx < WORLD_SIZE / 100 and ny >= 0 and ny < WORLD_SIZE / 100:
				var nk = str(nx) + "," + str(ny)
				if not checked.has(nk):
					queue.append(Vector2i(nx, ny))

	# 如果该陆地块的粗格数超过阈值 → 大陆
	var threshold = 200  # 200+ 粗格 ≈ 200×100×100 = 2M 格
	if coarse_land.size() >= _continent_size:
		_continent_size = coarse_land.size()

	# 标记所有大陆粗格
	if coarse_land.size() > threshold:
		for k in coarse_land.keys():
			_continent_mask[k] = true
	else:
		for k in coarse_land.keys():
			_continent_mask[k] = false

## 获取指定坐标的资源类型
func get_resource(wx: int, wy: int) -> int:
	var t = get_terrain(wx, wy)
	if not _is_land_type(t):
		return ResourceType.NONE

	var rn = (_resource_noise.get_noise_2d(wx, wy) + 1.0) / 2.0
	var e = get_elevation(wx, wy)

	# 岛屿上的资源更丰富（临时禁用，is_island BFS 会导致 10 秒卡顿）
	var island_bonus = 0.0  # 0.15 if is_island(wx, wy) else 0.0

	# 地形决定资源分布
	match t:
		TerrainType.GRASS:
			if rn < 0.3 + island_bonus:
				return ResourceType.FARM
			return ResourceType.NONE
		TerrainType.FOREST:
			if rn < 0.5 + island_bonus:
				return ResourceType.TIMBER
			return ResourceType.NONE
		TerrainType.HILL:
			if rn < 0.2:
				return ResourceType.IRON
			elif rn < 0.4:
				return ResourceType.COAL
			elif rn < 0.5:
				return ResourceType.STONE
			return ResourceType.NONE
		TerrainType.MOUNTAIN:
			if rn < 0.15:
				return ResourceType.IRON
			elif rn < 0.3:
				return ResourceType.COAL
			elif rn < 0.4:
				return ResourceType.STONE
			elif rn < 0.45 + island_bonus * 2:
				return ResourceType.GOLD_MINE
			return ResourceType.NONE
		TerrainType.SAND:
			if rn < 0.15 + island_bonus:
				return ResourceType.FISHERY
			return ResourceType.NONE
		TerrainType.SNOW:
			return ResourceType.NONE
	return ResourceType.NONE

## 获取文明起始位置（基于种子自动选择一个宜居区域）
func get_start_position() -> Vector2i:
	# 在若干个候选点中找最宜居的位置
	var best_pos = Vector2i(WORLD_SIZE / 2, WORLD_SIZE / 2)
	var best_score = -999.0

	for attempt in range(50):
		var ax = randi() % WORLD_SIZE
		var ay = randi() % WORLD_SIZE

		if not is_land(ax, ay):
			continue

		# 评分：平坦 + 靠近水 + 资源
		var score = 0.0
		var e = get_elevation(ax, ay)
		if e < 0.55 and e > 0.48:
			score += 30.0  # 理想海拔（沿海平原）

		# 检查周围资源
		for dy in range(-5, 6):
			for dx in range(-5, 6):
				var nx = ax + dx
				var ny = ay + dy
				if nx >= 0 and nx < WORLD_SIZE and ny >= 0 and ny < WORLD_SIZE:
					var r = get_resource(nx, ny)
					if r == ResourceType.FARM:
						score += 3.0
					elif r == ResourceType.TIMBER:
						score += 2.0
					elif r == ResourceType.FISHERY:
						score += 5.0
					elif r == ResourceType.IRON:
						score += 4.0

		# 靠近水域加分
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var nx = ax + dx
				var ny = ay + dy
				if nx >= 0 and nx < WORLD_SIZE and ny >= 0 and ny < WORLD_SIZE:
					var t = get_terrain(nx, ny)
					if t == TerrainType.SHALLOW_OCEAN or t == TerrainType.SAND:
						score += 5.0

		if score > best_score:
			best_score = score
			best_pos = Vector2i(ax, ay)

	return best_pos

func _is_land_type(t: int) -> bool:
	return t >= TerrainType.SAND and t <= TerrainType.SNOW

## 获取地形颜色（用于渲染）
func get_terrain_color(t: int) -> Color:
	match t:
		TerrainType.DEEP_OCEAN:
			return Color(0.08, 0.18, 0.45)
		TerrainType.SHALLOW_OCEAN:
			return Color(0.12, 0.30, 0.55)
		TerrainType.SAND:
			return Color(0.76, 0.70, 0.50)
		TerrainType.GRASS:
			return Color(0.25, 0.55, 0.15)
		TerrainType.FOREST:
			return Color(0.18, 0.42, 0.10)
		TerrainType.HILL:
			return Color(0.45, 0.38, 0.25)
		TerrainType.MOUNTAIN:
			return Color(0.55, 0.50, 0.42)
		TerrainType.SNOW:
			return Color(0.85, 0.88, 0.92)
		_:
			return Color(0.2, 0.2, 0.3)

## 获取资源颜色标记（用于地图渲染）
func get_resource_color(r: int) -> Color:
	match r:
		ResourceType.FARM:
			return Color(0.8, 0.9, 0.3, 0.6)
		ResourceType.TIMBER:
			return Color(0.3, 0.6, 0.2, 0.6)
		ResourceType.IRON:
			return Color(0.7, 0.3, 0.2, 0.6)
		ResourceType.FISHERY:
			return Color(0.2, 0.5, 0.8, 0.6)
		ResourceType.GEM:
			return Color(1.0, 0.5, 0.8, 0.7)
		ResourceType.GOLD_MINE:
			return Color(1.0, 0.85, 0.2, 0.7)
		ResourceType.COAL:
			return Color(0.3, 0.3, 0.3, 0.6)
		ResourceType.STONE:
			return Color(0.6, 0.6, 0.6, 0.6)
		ResourceType.VOLCANIC:
			return Color(1.0, 0.3, 0.1, 0.7)
		_:
			return Color(0, 0, 0, 0)
