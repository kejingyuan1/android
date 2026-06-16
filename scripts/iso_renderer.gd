# IsoRenderer.gd — 等距地形和道路渲染
# 地形使用 Sprite2D 大纹理方案（替代 TileMap，规避 Godot 4.6 等距 TileMap 渲染兼容问题）
extends Node2D

const MAP_WIDTH := 240
const MAP_HEIGHT := 160
const TILE_W := 64
const TILE_H := 32
const HALF_W := 32.0
const HALF_H := 16.0

var _grid_map = null
var _terrain_sprite = null
var _road_container = null
var _road_sprites = {}
var _road_sheets = {}

func _ready():
	_preload_road_textures()

func _preload_road_textures():
	for rname in ["dirt", "asphalt", "highway"]:
		var path = "res://assets/textures/roads/iso_%s.png" % rname
		if ResourceLoader.exists(path):
			var tex = load(path)
			if tex:
				_road_sheets[rname] = tex

func setup(grid_map_node, _seed_val = 0):
	_grid_map = grid_map_node

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

# ===== 地形渲染：烘焙到 Sprite2D 大纹理 =====
func _render_terrain_texture():
	# 程序化生成地形贴图（完全不依赖任何外部文件，杜绝导入问题）
	var tile_images := {}
	var names_arr = ["grass_0","grass_1","grass_2","water_0","water_1","water_2",
		"sand","forest","mountain","dirt"]
	
	# 程序化生成各地形菱形纹理（64x32）
	for n in names_arr:
		var simg = Image.create(TILE_W, TILE_H, false, Image.FORMAT_RGBA8)
		simg.fill(Color(0, 0, 0, 0))
		
		# 根据纹理类型选择颜色
		var base_color := Color(0.27, 0.63, 0.20)  # 默认绿色（草地）
		if n.begins_with("grass"): base_color = Color(0.27, 0.63, 0.20)
		elif n.begins_with("water"): base_color = Color(0.18, 0.41, 0.75)
		elif n == "sand": base_color = Color(0.76, 0.71, 0.55)
		elif n == "forest": base_color = Color(0.16, 0.39, 0.14)
		elif n == "mountain": base_color = Color(0.47, 0.45, 0.43)
		elif n == "dirt": base_color = Color(0.55, 0.45, 0.29)
		
		# 轻微随机化（草地变体）
		var variant_offset := 0.0
		if n.ends_with("_1"): variant_offset = 0.03
		elif n.ends_with("_2"): variant_offset = -0.03
		
		# 绘制菱形
		var cx := TILE_W / 2.0
		var cy := TILE_H / 2.0
		for y in range(TILE_H):
			for x in range(TILE_W):
				var dx := abs(float(x) - cx) / cx
				var dy := abs(float(y) - cy) / cy
				if dx + dy <= 1.0:
					var r := base_color.r + variant_offset + randf_range(-0.02, 0.02)
					var g := base_color.g + variant_offset + randf_range(-0.02, 0.02)
					var b := base_color.b + variant_offset + randf_range(-0.02, 0.02)
					simg.set_pixel(x, y, Color(clampf(r, 0, 1), clampf(g, 0, 1), clampf(b, 0, 1), 1.0))
		
		tile_images[n] = simg
		# 打印第一个像素供调试
		var first_color = Color()
		var found := false
		for sy in range(TILE_H):
			for sx in range(TILE_W):
				if simg.get_pixel(sx, sy).a > 0.5:
					first_color = simg.get_pixel(sx, sy)
					found = true
					break
			if found: break
		print("[TERRAIN] 程序生成: ", n, " 首像素=(", int(first_color.r*255), ",", int(first_color.g*255), ",", int(first_color.b*255), ")")
	
	# 计算纹理尺寸：等距地图的完整矩形区域
	# grid_to_world(0,0) = (0,0); grid_to_world(MAP_W,MAP_H) = ((W-H)*32, (W+H)*16)
	# 计算纹理尺寸
	var img_w = (MAP_WIDTH + MAP_HEIGHT) * HALF_W  # 12800
	var img_h = (MAP_WIDTH + MAP_HEIGHT) * HALF_H  # 6400
	var img = Image.create(int(img_w), int(img_h), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# 精灵定位：等距地图的几何中心（grid_to_world(120,80)）
	var sprite_pos = Vector2((MAP_WIDTH - MAP_HEIGHT) * HALF_W / 2.0, (MAP_WIDTH + MAP_HEIGHT) * HALF_H / 2.0)
	
	var terrain_map = {0:["water_0","water_1","water_2"], 1:["sand"],
		2:["grass_0","grass_1","grass_2"], 3:["forest"], 4:["mountain"], 5:["mountain"]}
	
	var drawn := 0
	for gy in range(MAP_HEIGHT):
		for gx in range(MAP_WIDTH):
			# 等距格子 → 纹理像素坐标（确保与 grid_to_world 映射一致）
			# tx = (gx - gy) * HALF_W - sprite_pos.x + img_w/2 = 32*(gx - gy + MAP_HEIGHT)
			# ty = (gx + gy) * HALF_H - sprite_pos.y + img_h/2 = 16*(gx + gy)
			var tx = HALF_W * (gx - gy + MAP_HEIGHT)
			var ty = HALF_H * (gx + gy)
			
			var nt = _grid_map.get_natural_terrain(gx, gy)
			var names = terrain_map.get(nt, ["grass_0"])
			var chosen = names[hash(str(gx)+","+str(gy)) % names.size()]
			var simg = tile_images.get(chosen)
			if simg == null:
				continue
			img.blit_rect(simg, Rect2i(0, 0, TILE_W, TILE_H), Vector2i(tx, ty))
			drawn += 1
	
	print("[TERRAIN] 地形图渲染: ", drawn, " tiles → ", img_w, "x", img_h)
	
	_terrain_sprite = Sprite2D.new()
	_terrain_sprite.name = "IsoTerrain"
	var tex = ImageTexture.create_from_image(img)
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
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex:
			_road_sheets[key] = tex
			return tex
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
	var hl_tex = load("res://assets/textures/isometric/highlight.png")
	if hl_tex:
		_highlight.texture = hl_tex
	_highlight.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_highlight.centered = true
	_highlight.z_index = 50
	_highlight.visible = false
	add_child(_highlight)

	_ghost = Sprite2D.new()
	_ghost.name = "IsoGhost"
	var gh_tex = load("res://assets/textures/isometric/ghost.png")
	if gh_tex:
		_ghost.texture = gh_tex
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
	s.texture = load("res://assets/textures/isometric/shadow.png") if ResourceLoader.exists("res://assets/textures/isometric/shadow.png") else null
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
