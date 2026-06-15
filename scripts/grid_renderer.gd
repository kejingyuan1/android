# GridRenderer.gd — 像素风自然地形渲染（细节彩绘版）
# 使用彩色的地形基础色 + 亮点/阴影细节，使地图更丰富
extends Node2D

const MAP_WIDTH := 240
const MAP_HEIGHT := 160
const CELL_SIZE := 32
# 纹理每格像素数（提升分辨率使地形更精细平滑）
const PIXELS_PER_CELL := 24
const TEX_W := MAP_WIDTH * PIXELS_PER_CELL    # 5760
const TEX_H := MAP_HEIGHT * PIXELS_PER_CELL   # 3840
# 精灵缩放（填补与真实世界尺寸的差距）
const SPRITE_SCALE := float(CELL_SIZE) / float(PIXELS_PER_CELL)  # 1.33

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

	# 双层噪声：大尺度地形变化 + 小尺度纹理细节
	var large_noise = FastNoiseLite.new()
	large_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	large_noise.frequency = 0.006
	large_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	large_noise.fractal_octaves = 3
	large_noise.fractal_gain = 0.5
	large_noise.seed = _seed if _seed != 0 else randi()

	var detail_noise = FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	detail_noise.frequency = 0.04
	detail_noise.seed = (_seed + 1) if _seed != 0 else randi()

	var image = Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)

	for py in range(TEX_H):
		for px in range(TEX_W):
			var gx = px / PIXELS_PER_CELL
			var gy = py / PIXELS_PER_CELL
			if gx >= MAP_WIDTH or gy >= MAP_HEIGHT:
				image.set_pixel(px, py, Color(0.35, 0.6, 0.2))
				continue

			# 格内偏移（0~1），用于双线性插值
			var ppx = (px % PIXELS_PER_CELL) / float(PIXELS_PER_CELL)
			var ppy = (py % PIXELS_PER_CELL) / float(PIXELS_PER_CELL)

			var base = terrain_colors[gy][gx]

			# 双线性插值：在相邻 cell 之间平滑过渡，消除块状感
			if ppx > 0.0 or ppy > 0.0:
				var right = terrain_colors[gy][min(gx+1, MAP_WIDTH-1)]
				var down = terrain_colors[min(gy+1, MAP_HEIGHT-1)][gx]
				var down_right = terrain_colors[min(gy+1, MAP_HEIGHT-1)][min(gx+1, MAP_WIDTH-1)]
				base = Color(
					lerp(lerp(base.r, right.r, ppx), lerp(down.r, down_right.r, ppx), ppy),
					lerp(lerp(base.g, right.g, ppx), lerp(down.g, down_right.g, ppx), ppy),
					lerp(lerp(base.b, right.b, ppx), lerp(down.b, down_right.b, ppx), ppy)
				)

			# 噪声：大尺度地形明暗变化
			var n = large_noise.get_noise_2d(px, py) * 0.10  # -0.10~0.10
			# 细节噪声：小范围点缀（花朵、石块等）
			var dn = detail_noise.get_noise_2d(px, py)
			var color = Color(
				clamp(base.r + n, 0, 1),
				clamp(base.g + n, 0, 1),
				clamp(base.b + n, 0, 1),
				1.0)

			# 草地添加小花点缀（蜂窝噪声高值处）
			if terrain_colors[gy][gx].g > 0.3 and dn > 0.6:
				var flower = sin(px * 3.14 + py * 2.71) * 0.5 + 0.5
				if flower > 0.7:
					color = Color(1.0, 0.85, 0.3, 1.0)  # 黄色小花
				elif flower > 0.5:
					color = Color(0.9, 0.3, 0.5, 1.0)   # 粉色小花

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
		0:  return Color(0.18, 0.38, 0.65)  # WATER - deep blue
		1:  return Color(0.82, 0.74, 0.48)  # SAND - warm beige
		2:  return Color(0.42, 0.68, 0.25)  # GRASS - lush green
		3:  return Color(0.20, 0.50, 0.15)  # FOREST - dark green
		4:  return Color(0.55, 0.40, 0.25)  # HILL - earthy brown
		5:  return Color(0.45, 0.40, 0.35)  # MOUNTAIN - gray brown
		_:  return Color(0.42, 0.68, 0.25)
