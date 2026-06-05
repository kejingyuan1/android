# GridRenderer.gd — Perlin 噪声驱动的自然地形渲染（优化版）
# 降低纹理分辨率 + 简化噪声采样以加速启动
extends Node2D

const MAP_WIDTH := 240
const MAP_HEIGHT := 160
const CELL_SIZE := 32
# 纹理每格像素数（降低以加速生成；用 LINEAR 过滤平滑放大）
const PIXELS_PER_CELL := 16
const TEX_W := MAP_WIDTH * PIXELS_PER_CELL    # 3840
const TEX_H := MAP_HEIGHT * PIXELS_PER_CELL   # 2560
# 精灵缩放（填补与真实世界尺寸的差距）
const SPRITE_SCALE := float(CELL_SIZE) / float(PIXELS_PER_CELL)  # 2.0

var _grid_map: Node = null
var _sprite: Sprite2D = null
var _seed: int = 0

func setup(grid_map: Node, seed_val: int = 0):
	_grid_map = grid_map
	_seed = seed_val

func generate() -> ImageTexture:
	if not _grid_map:
		return null

	# 检查缓存
	var cache_path = "user://cache_city_terrain_%d.png" % _seed
	if FileAccess.file_exists(cache_path):
		var cached_img = Image.load_from_file(cache_path)
		if cached_img and cached_img.get_size() == Vector2i(TEX_W, TEX_H):
			print("城市地形从缓存加载: ", cache_path)
			return ImageTexture.create_from_image(cached_img)

	# 预计算地形颜色图（按格计算，避免重复查表）
	var terrain_colors = []
	for gy in range(MAP_HEIGHT):
		terrain_colors.append([])
		for gx in range(MAP_WIDTH):
			var nt = _grid_map.get_natural_terrain(gx, gy)
			terrain_colors[gy].append(_get_base_color(nt))

	# 单层 Perlin 噪声（使用种子确保确定性）
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.006
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5
	noise.seed = _seed if _seed != 0 else randi()

	var image = Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)

	for py in range(TEX_H):
		for px in range(TEX_W):
			var gx = px / PIXELS_PER_CELL
			var gy = py / PIXELS_PER_CELL
			if gx >= MAP_WIDTH or gy >= MAP_HEIGHT:
				image.set_pixel(px, py, Color(0.35, 0.6, 0.2))
				continue

			var base = terrain_colors[gy][gx]

			# 噪声：用纹理坐标（非格坐标）采样，产生像素级自然变化
			var n = noise.get_noise_2d(px, py) * 0.25  # -0.25~0.25
			var color = Color(
				clamp(base.r + n, 0, 1),
				clamp(base.g + n, 0, 1),
				clamp(base.b + n, 0, 1),
				1.0)

			# 水域添加波形
			if terrain_colors[gy][gx].b > 0.4:
				var wave = sin(px * 0.08 + py * 0.04) * 0.03
				color = Color(
					clamp(color.r - wave * 0.5, 0, 1),
					clamp(color.g - wave * 0.5, 0, 1),
					clamp(color.b + wave, 0, 1),
					1.0)

			image.set_pixel(px, py, color)

	# 保存缓存（复用已声明的 cache_path）
	var err = image.save_png(cache_path)
	if err == OK:
		print("城市地形缓存已保存: ", cache_path)
	else:
		push_warning("城市地形缓存保存失败: ", err)

	return ImageTexture.create_from_image(image)

func _get_base_color(nt: int) -> Color:
	match nt:
		0:  return Color(0.15, 0.28, 0.55)  # WATER
		1:  return Color(0.85, 0.78, 0.52)  # SAND
		2:  return Color(0.40, 0.62, 0.22)  # GRASS
		3:  return Color(0.22, 0.45, 0.12)  # FOREST
		4:  return Color(0.52, 0.38, 0.22)  # HILL
		5:  return Color(0.42, 0.38, 0.32)  # MOUNTAIN
		_:  return Color(0.40, 0.62, 0.22)
