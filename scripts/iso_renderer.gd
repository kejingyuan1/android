# IsoRenderer.gd — 等距地形和道路渲染
# 地形使用 Sprite2D 大纹理方案（替代 TileMap，规避 Godot 4.6 等距 TileMap 渲染兼容问题）
extends Node2D

const MAP_WIDTH := 240
const MAP_HEIGHT := 160
const TILE_W := 64
const TILE_H := 32
const HALF_W := 32.0
const HALF_H := 16.0
const EXTRA_TOP := 30  # 山脉/森林向上突起所需的额外纹理空间

var _grid_map = null
var _terrain_sprite = null
var _road_container = null
var _road_sprites = {}
var _road_sheets = {}
var _seed_val := 0

func _ready():
	_preload_road_textures()

func _preload_road_textures():
	for rname in ["dirt", "asphalt", "highway"]:
		var path = "res://assets/textures/roads/iso_%s.png" % rname
		print("[TEX_LOAD] iso道路纹理预加载: ", path, " 存在=", ResourceLoader.exists(path))
		if ResourceLoader.exists(path):
			var tex = load(path)
			if tex:
				print("[TEX_LOAD]   加载成功: 尺寸=", tex.get_width(), "x", tex.get_height())
				_road_sheets[rname] = tex
			else:
				print("[TEX_LOAD]   加载失败: load()返回null")

func setup(grid_map_node, seed_val = 0):
	_grid_map = grid_map_node
	_seed_val = seed_val

func generate():
	if _grid_map == null:
		return
	_clear_children()
	_road_container = null
	_road_sprites.clear()
	_render_terrain_texture()
	_create_road_container()
	init_overlays()

func _clear_children():
	for c in get_children():
		c.queue_free()

# ===== 地形渲染：精致3D等距地形，烘焙到 Sprite2D 大纹理 =====
# 每个菱形 tile 有 3D 光照：顶部亮（受光面）、左下中灰（侧光面）、右下暗（背光面）
# 山脉向上突起带雪顶，水域带波纹，森林有树冠纹理

# 在菱形内绘制带3D光照的像素
func _iso_set_pixel_3d(img: Image, x: int, y: int, base_col: Color, cx: float, cy: float):
	# 计算像素在菱形中的归一化位置
	var dx: float = float(x) / cx - 1.0  # -1..1
	var dy: float = float(y) / cy - 1.0  # -1..1
	
	# 3D 光照：模拟光源从左上方照射
	# 上方平坦区域 → 亮度最高 (top face)
	# 左下方 → 中等亮度 (left face)
	# 右下方 → 较暗 (right face / shadow)
	var brightness: float = 1.0
	
	if dy > 0:
		# 下半部分（正面/侧面）按位置分左右
		if x < cx:
			# 左半（左下侧光面）: 亮度 0.75~0.9
			var t: float = abs(dx) / (1.0 - abs(dy) + 0.001)
			brightness = 0.92 - t * 0.17
		else:
			# 右半（右下背光面）: 亮度 0.55~0.7
			var t: float = dx / (1.0 - abs(dy) + 0.001)
			brightness = 0.72 - t * 0.17
	else:
		# 上半部分（顶面）: 亮度 0.95~1.05
		var dist_from_edge: float = abs(dy)  # 0 at center, 1 at top
		brightness = 1.05 - dist_from_edge * 0.08
	
	brightness = clampf(brightness, 0.45, 1.15)
	
	img.set_pixel(x, y, Color(
		clampf(base_col.r * brightness, 0.0, 1.0),
		clampf(base_col.g * brightness, 0.0, 1.0),
		clampf(base_col.b * brightness, 0.0, 1.0),
		1.0
	))

# 生成单个地形 tile（64x32 菱形，带3D光照和纹理细节）
func _gen_grass_tile(variant: int, rng: RandomNumberGenerator) -> Image:
	var img := Image.create(TILE_W, TILE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = TILE_W / 2.0
	var cy: float = TILE_H / 2.0
	var base := Color(0.28, 0.66, 0.22)
	
	for y in range(TILE_H):
		for x in range(TILE_W):
			var dx: float = abs(float(x) - cx) / cx
			var dy: float = abs(float(y) - cy) / cy
			if dx + dy > 1.0:
				continue
			
			# 3D光照
			var col := base
			_iso_set_pixel_3d(img, x, y, col, cx, cy)
			
			# 纹理细节：随机草点
			var hash_val: int = (x * 73856093 + y * 19349663 + variant * 83492791) & 0x7FFFFFFF
			if hash_val % 13 == 0:
				# 暗色草斑
				var dark := Color(
					clampf(col.r - 0.04, 0, 1),
					clampf(col.g - 0.04, 0, 1),
					clampf(col.b - 0.04, 0, 1), 1)
				img.set_pixel(x, y, dark)
			elif hash_val % 23 == 0:
				# 亮色高光草
				var light := Color(
					clampf(col.r + 0.06, 0, 1),
					clampf(col.g + 0.06, 0, 1),
					clampf(col.b + 0.03, 0, 1), 1)
				img.set_pixel(x, y, light)
	return img

func _gen_water_tile(variant: int, rng: RandomNumberGenerator) -> Image:
	var img := Image.create(TILE_W, TILE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = TILE_W / 2.0
	var cy: float = TILE_H / 2.0
	var base := Color(0.16, 0.38, 0.72)
	
	for y in range(TILE_H):
		for x in range(TILE_W):
			var dx: float = abs(float(x) - cx) / cx
			var dy: float = abs(float(y) - cy) / cy
			if dx + dy > 1.0:
				continue
			
			_iso_set_pixel_3d(img, x, y, base, cx, cy)
			
			# 水面波纹（水平线）
			var wave: int = (y + variant * 4) / 4  # 每4行一波
			if wave % 3 == 0:
				var col := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(
					clampf(col.r + 0.08, 0, 1),
					clampf(col.g + 0.10, 0, 1),
					clampf(col.b + 0.12, 0, 1), 1))
			
			# 水面闪烁（随机亮点）
			var hash_val: int = (x * 193939 + y * 8380417 + variant) & 0x7FFFFFFF
			if hash_val % 67 == 0 and dx + dy < 0.85:
				img.set_pixel(x, y, Color(0.9, 0.95, 1.0, 0.9))
	return img

func _gen_sand_tile(rng: RandomNumberGenerator) -> Image:
	var img := Image.create(TILE_W, TILE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = TILE_W / 2.0
	var cy: float = TILE_H / 2.0
	var base := Color(0.82, 0.75, 0.58)
	
	for y in range(TILE_H):
		for x in range(TILE_W):
			var dx: float = abs(float(x) - cx) / cx
			var dy: float = abs(float(y) - cy) / cy
			if dx + dy > 1.0:
				continue
			
			_iso_set_pixel_3d(img, x, y, base, cx, cy)
			
			# 沙粒纹理
			var hv: int = (x * 27449 + y * 77237) & 0x7FFFFFFF
			if hv % 9 == 0:
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(clampf(c.r+0.04,0,1), clampf(c.g+0.04,0,1), clampf(c.b+0.02,0,1), 1))
			elif hv % 15 == 0:
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(clampf(c.r-0.03,0,1), clampf(c.g-0.03,0,1), clampf(c.b-0.02,0,1), 1))
	return img

func _gen_forest_tile(variant: int, rng: RandomNumberGenerator) -> Image:
	var img := Image.create(TILE_W, TILE_H + 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = TILE_W / 2.0
	var cy: float = TILE_H / 2.0 + 4  # 树冠向上突起
	var base := Color(0.10, 0.35, 0.09)
	
	for y in range(TILE_H + 8):
		for x in range(TILE_W):
			var ex: float = abs(float(x) - cx) / cx
			var ey: float = abs(float(y) - cy) / cy
			
			# 树冠不是完美菱形，按 x 偏移做圆顶效果
			var canopy_r: float = 0.9 + abs(float(x) - cx) / cx * 0.15
			if ex + ey > canopy_r:
				continue
			
			# 树冠基本色
			var col := Color(0.10, 0.35, 0.09)
			
			# 3D光照效果
			var bright: float = 1.0
			if y <= cy:
				bright = 1.05 - ey * 0.1
			else:
				var tx: float = float(x) / cx - 1.0
				if tx < 0:
					bright = 0.88 + tx * 0.1
				else:
					bright = 0.70 - tx * 0.1
			bright = clampf(bright, 0.5, 1.15)
			
			# 树冠凸起纹理
			var hv: int = (x * 31627 + y * 64783 + variant * 911) & 0x7FFFFFFF
			if hv % 7 == 0:
				col = Color(0.08, 0.28, 0.06)
			elif hv % 11 == 0:
				col = Color(0.13, 0.40, 0.11)
			
			var r: float = clampf(col.r * bright, 0, 1)
			var g: float = clampf(col.g * bright, 0, 1)
			var b: float = clampf(col.b * bright, 0, 1)
			img.set_pixel(x, y, Color(r, g, b, 1))
	return img

func _gen_mountain_tile(variant: int, rng: RandomNumberGenerator) -> Image:
	# 山脉：顶部突起到 32+24=56px 高，雪顶约 1/3 高度
	var mt_h: int = TILE_H + 24  # 山脉总高度
	var img := Image.create(TILE_W, mt_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = TILE_W / 2.0
	var base_cy: float = TILE_H / 2.0 + 12  # 菱形中心在中间偏下
	var base := Color(0.48, 0.44, 0.40)
	var snow := Color(0.95, 0.94, 0.92)
	
	for y in range(mt_h):
		for x in range(TILE_W):
			var ex: float = abs(float(x) - cx) / cx
			var y_center: float = base_cy - 8 * (1.0 - ex)  # 山形：越靠边越矮
			var ey: float = abs(float(y) - y_center) / (y_center + 0.01) if y_center > 0 else 1.5
			
			# 山体形状：中部高、边缘矮的锥形
			if y < y_center * 0.1:
				continue  # 山顶以上无像素
			if ex > 1.0:
				continue
			
			# 岩体颜色（带渐变）
			var rock := base
			var frac: float = y / float(mt_h)
			
			if frac < 0.35 and variant == 0:
				# 雪顶
				rock = snow
			elif frac < 0.40 and variant == 0:
				# 雪岩过渡
				var t: float = (frac - 0.35) / 0.05
				rock = Color(
					lerp(snow.r, base.r, t),
					lerp(snow.g, base.g, t),
					lerp(snow.b, base.b, t))
			
			# 3D光照
			var bright: float = 1.0
			if x < cx:
				bright = 0.90 + abs(float(cx - x) / cx) * 0.15
			else:
				bright = 0.72 + abs(float(x - cx) / cx) * 0.08
			bright = clampf(bright, 0.50, 1.15)
			
			# 岩缝纹理
			var hv: int = (x * 683 + y * 1471 + variant * 1297) & 0x7FFFFFFF
			if hv % 29 == 0:
				rock = Color(clampf(rock.r-0.06,0,1), clampf(rock.g-0.06,0,1), clampf(rock.b-0.06,0,1))
			elif hv % 41 == 0:
				rock = Color(clampf(rock.r+0.04,0,1), clampf(rock.g+0.04,0,1), clampf(rock.b+0.04,0,1))
			
			img.set_pixel(x, y, Color(
				clampf(rock.r * bright, 0, 1),
				clampf(rock.g * bright, 0, 1),
				clampf(rock.b * bright, 0, 1), 1))
	return img

func _gen_dirt_tile(rng: RandomNumberGenerator) -> Image:
	var img := Image.create(TILE_W, TILE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = TILE_W / 2.0
	var cy: float = TILE_H / 2.0
	var base := Color(0.55, 0.42, 0.25)
	
	for y in range(TILE_H):
		for x in range(TILE_W):
			var dx: float = abs(float(x) - cx) / cx
			var dy: float = abs(float(y) - cy) / cy
			if dx + dy > 1.0:
				continue
			
			_iso_set_pixel_3d(img, x, y, base, cx, cy)
			
			# 土块纹理
			var hv: int = (x * 13337 + y * 41141) & 0x7FFFFFFF
			if hv % 11 == 0:
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(clampf(c.r+0.04,0,1), clampf(c.g+0.03,0,1), clampf(c.b+0.02,0,1), 1))
			elif hv % 19 == 0:
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(clampf(c.r-0.05,0,1), clampf(c.g-0.04,0,1), clampf(c.b-0.03,0,1), 1))
	return img

func _render_terrain_texture():
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_val
	
	print("[TERRAIN] 生成精致3D等距地形纹理...")
	
	var tile_images := {}
	# 草坪（3变体）
	tile_images["grass_0"] = _gen_grass_tile(0, rng)
	tile_images["grass_1"] = _gen_grass_tile(1, rng)
	tile_images["grass_2"] = _gen_grass_tile(2, rng)
	print("[TERRAIN] 草坪3变体生成完毕")
	
	# 水域（3变体）
	tile_images["water_0"] = _gen_water_tile(0, rng)
	tile_images["water_1"] = _gen_water_tile(1, rng)
	tile_images["water_2"] = _gen_water_tile(2, rng)
	print("[TERRAIN] 水域3变体生成完毕")
	
	# 沙地
	tile_images["sand"] = _gen_sand_tile(rng)
	print("[TERRAIN] 沙地生成完毕")
	
	# 森林（2变体）
	tile_images["forest_0"] = _gen_forest_tile(0, rng)
	tile_images["forest_1"] = _gen_forest_tile(1, rng)
	print("[TERRAIN] 森林2变体生成完毕")
	
	# 山脉（2变体）
	tile_images["mountain_0"] = _gen_mountain_tile(0, rng)
	tile_images["mountain_1"] = _gen_mountain_tile(1, rng)
	print("[TERRAIN] 山脉2变体生成完毕")
	
	# 土地
	tile_images["dirt"] = _gen_dirt_tile(rng)
	print("[TERRAIN] 土地生成完毕")
	
	# 计算纹理尺寸（山脉/森林需要额外顶部空间）
	var img_w: float = (MAP_WIDTH + MAP_HEIGHT) * HALF_W
	var img_h: float = (MAP_WIDTH + MAP_HEIGHT) * HALF_H + EXTRA_TOP * 2
	var img := Image.create(int(img_w), int(img_h), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# 精灵定位（加了 EXTRA_TOP 偏移，保证山脉顶部不溢出）
	var sprite_pos := Vector2(
		(MAP_WIDTH - MAP_HEIGHT) * HALF_W / 2.0,
		(MAP_WIDTH + MAP_HEIGHT) * HALF_H / 2.0 + EXTRA_TOP
	)
	
	var terrain_map := {
		0: ["water_0", "water_1", "water_2"],
		1: ["sand"],
		2: ["grass_0", "grass_1", "grass_2"],
		3: ["forest_0", "forest_1"],
		4: ["mountain_0", "mountain_1"],
		5: ["mountain_0", "mountain_1"]
	}
	
	var drawn := 0
	for gy in range(MAP_HEIGHT):
		for gx in range(MAP_WIDTH):
			var tx: float = HALF_W * (gx - gy + MAP_HEIGHT)
			var ty: float = HALF_H * (gx + gy) + EXTRA_TOP
			
			var nt = _grid_map.get_natural_terrain(gx, gy)
			var names = terrain_map.get(nt, ["grass_0"])
			var chosen = names[hash(str(gx) + "," + str(gy)) % names.size()]
			var simg = tile_images.get(chosen)
			if simg == null:
				continue
			
			var offset_y: int = EXTRA_TOP  # 普通地板：偏移 EXTRA_TOP
			if nt >= 4:
				# 山脉：底部对齐地面
				offset_y = EXTRA_TOP - (simg.get_height() - TILE_H)
			elif nt == 3:
				# 森林：树冠中心对齐菱形中心
				offset_y = EXTRA_TOP - (simg.get_height() / 2 - TILE_H / 2)
			
			img.blit_rect(simg, Rect2i(0, 0, TILE_W, simg.get_height()), Vector2i(tx, ty + offset_y - EXTRA_TOP))
			drawn += 1
	
	print("[TERRAIN] 地形渲染完成: ", drawn, " tiles → ", img_w, "x", img_h)
	
	_terrain_sprite = Sprite2D.new()
	_terrain_sprite.name = "IsoTerrain"
	var tex := ImageTexture.create_from_image(img)
	_terrain_sprite.texture = tex
	_terrain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_terrain_sprite.centered = true
	_terrain_sprite.position = sprite_pos
	_terrain_sprite.z_index = 0
	add_child(_terrain_sprite)
	print("[TERRAIN] 地形精灵已创建: pos=", sprite_pos, " tex=", img_w, "x", img_h)

# ===== 道路系统 =====
func _create_road_container():
	_road_container = Node2D.new()
	_road_container.name = "RoadContainer"
	_road_container.z_index = 1
	add_child(_road_container)

func _get_road_sheet_key(road_type):
	match road_type:
		0: return "dirt"
		1: return "asphalt"
		2: return "highway"
	return "dirt"

func update_road(gx, gy, road_type):
	if _road_container == null:
		_create_road_container()
		if _road_container == null:
			return
	var sheet = _get_or_load_sheet(road_type)
	if sheet == null:
		_create_fallback_road(gx, gy, road_type)
		return
	var coords = _get_road_coords(gx, gy)
	var atlas_x = coords.x * TILE_W
	var atlas_y = coords.y * TILE_H
	var sprite_key = str(gx) + "_" + str(gy)
	var sprite = _road_sprites.get(sprite_key)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Road_" + sprite_key
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_road_container.add_child(sprite)
		_road_sprites[sprite_key] = sprite
	elif not is_instance_valid(sprite) or sprite.get_parent() == null:
		_road_sprites.erase(sprite_key)
		sprite = Sprite2D.new()
		sprite.name = "Road_" + sprite_key
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_road_container.add_child(sprite)
		_road_sprites[sprite_key] = sprite
	sprite.texture = sheet
	sprite.region_enabled = true
	sprite.region_rect = Rect2(atlas_x, atlas_y, TILE_W, TILE_H)
	sprite.position = grid_to_world(gx, gy)

func _get_or_load_sheet(road_type):
	var key = _get_road_sheet_key(road_type)
	if _road_sheets.has(key):
		return _road_sheets[key]
	var path = "res://assets/textures/roads/iso_%s.png" % key
	print("[TEX_LOAD] iso道路贴图按需加载: ", path, " 存在=", ResourceLoader.exists(path))
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex:
			print("[TEX_LOAD]   加载成功: 尺寸=", tex.get_width(), "x", tex.get_height())
			_road_sheets[key] = tex
			return tex
		else:
			print("[TEX_LOAD]   load()返回null")
	else:
		print("[TEX_LOAD]   文件不存在")
	return null

func _create_fallback_road(gx, gy, road_type):
	if _road_container == null:
		_create_road_container()
	var sprite_key = str(gx) + "_" + str(gy)
	var sprite = _road_sprites.get(sprite_key)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Road_fallback_" + sprite_key
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_road_container.add_child(sprite)
		_road_sprites[sprite_key] = sprite
	var colors = [Color(0.8, 0.6, 0.2, 0.9), Color(0.3, 0.3, 0.3, 0.9), Color(0.15, 0.15, 0.15, 0.9)]
	var col = colors[road_type % 3]
	var img = Image.create(TILE_W, TILE_H, false, Image.FORMAT_RGBA8)
	var cx_f = TILE_W / 2.0
	var cy_f = TILE_H / 2.0
	for y in range(TILE_H):
		for x in range(TILE_W):
			var dx = abs(x - cx_f) / cx_f
			var dy = abs(y - cy_f) / cy_f
			if dx + dy <= 1.0:
				if abs(dy) <= 0.65:
					img.set_pixel(x, y, col)
				else:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var tex = ImageTexture.create_from_image(img)
	if tex:
		sprite.texture = tex
	sprite.position = grid_to_world(gx, gy)

func clear_road(gx, gy):
	var sprite_key = str(gx) + "_" + str(gy)
	var sprite = _road_sprites.get(sprite_key)
	if sprite != null and is_instance_valid(sprite):
		if _road_container != null and sprite.get_parent() != null:
			sprite.get_parent().remove_child(sprite)
		sprite.queue_free()
		_road_sprites.erase(sprite_key)

func clear_all_roads():
	for key in _road_sprites.keys():
		var sp = _road_sprites[key]
		if sp != null and is_instance_valid(sp):
			if sp.get_parent() != null:
				sp.get_parent().remove_child(sp)
			sp.queue_free()
	_road_sprites.clear()

func _get_road_coords(cx, cy):
	# 计算 4 邻域连接掩码: bit0=上, bit1=下, bit2=左, bit3=右
	var rt = _grid_map.TerrainType.ROAD if _grid_map else 1
	var is_road = func(x, y):
		var c = _grid_map.get_cell(x, y) if _grid_map else null
		return c and c.terrain == rt
	var mask := 0
	if cy > 0 and is_road.call(cx, cy-1): mask |= 1
	if cy < MAP_HEIGHT-1 and is_road.call(cx, cy+1): mask |= 2
	if cx > 0 and is_road.call(cx-1, cy): mask |= 4
	if cx < MAP_WIDTH-1 and is_road.call(cx+1, cy): mask |= 8
	# atlas坐标 = (mask%4, mask//4)，基于4列×4行的spritesheet布局
	return Vector2i(mask % 4, mask / 4)

# ===== 高亮 & 虚影 =====
var _highlight = null
var _ghost = null

func init_overlays():
	_highlight = Sprite2D.new()
	_highlight.name = "IsoHighlight"
	var hl_path = "res://assets/textures/isometric/highlight.png"
	print("[TEX_LOAD] 等距高亮纹理: ", hl_path, " 存在=", ResourceLoader.exists(hl_path))
	var hl_tex = load(hl_path)
	if hl_tex:
		print("[TEX_LOAD]   高亮纹理尺寸: ", hl_tex.get_width(), "x", hl_tex.get_height())
		_highlight.texture = hl_tex
	else:
		print("[TEX_LOAD]   高亮纹理加载失败")
	_highlight.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_highlight.centered = true
	_highlight.z_index = 50
	_highlight.visible = false
	add_child(_highlight)

	_ghost = Sprite2D.new()
	_ghost.name = "IsoGhost"
	var gh_path = "res://assets/textures/isometric/ghost.png"
	print("[TEX_LOAD] 等距虚影纹理: ", gh_path, " 存在=", ResourceLoader.exists(gh_path))
	var gh_tex = load(gh_path)
	if gh_tex:
		print("[TEX_LOAD]   虚影纹理尺寸: ", gh_tex.get_width(), "x", gh_tex.get_height())
		_ghost.texture = gh_tex
	else:
		print("[TEX_LOAD]   虚影纹理加载失败")
	_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ghost.centered = true
	_ghost.z_index = 40
	_ghost.visible = false
	add_child(_ghost)

func show_highlight(gx, gy):
	if _highlight:
		_highlight.position = grid_to_world(gx, gy)
		_highlight.visible = true

func hide_highlight():
	if _highlight:
		_highlight.visible = false

func show_ghost(gx, gy, tex = null):
	if _ghost:
		_ghost.position = grid_to_world(gx, gy)
		if tex:
			_ghost.texture = tex
		_ghost.visible = true

func hide_ghost():
	if _ghost:
		_ghost.visible = false

func create_shadow_sprite():
	var s = Sprite2D.new()
	var shadow_path = "res://assets/textures/isometric/shadow.png"
	var shadow_exists = ResourceLoader.exists(shadow_path)
	print("[TEX_LOAD] 阴影纹理: ", shadow_path, " 存在=", shadow_exists)
	s.texture = load(shadow_path) if shadow_exists else null
	if s.texture:
		print("[TEX_LOAD]   阴影纹理尺寸: ", s.texture.get_width(), "x", s.texture.get_height())
	else:
		print("[TEX_LOAD]   阴影纹理加载失败或不存在")
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = true
	s.z_index = 3
	return s

func grid_to_world(gx, gy):
	return Vector2((gx - gy) * HALF_W, (gx + gy) * HALF_H)

func world_to_grid(pos):
	var gx = int(floor((pos.x / HALF_W + pos.y / HALF_H) / 2.0))
	var gy = int(floor((pos.y / HALF_H - pos.x / HALF_W) / 2.0))
	return Vector2i(gx, gy)
