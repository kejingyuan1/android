# IsoRenderer.gd — 等距地形和道路渲染
extends Node2D

const MAP_WIDTH := 240
const MAP_HEIGHT := 160
const TILE_W := 64
const TILE_H := 32
const HALF_W := 32.0
const HALF_H := 16.0

var _grid_map = null
var _terrain = null
var _road_container = null
var _road_sprites = {}
var _road_sheets = {}

func setup(grid_map_node, _seed_val = 0):
	_grid_map = grid_map_node

func generate():
	if _grid_map == null:
		return
	_clear_children()
	_create_terrain_tileset()
	_fill_terrain()
	_create_road_sprites()
	init_overlays()

func _create_road_sprites():
	_road_container = Node2D.new()
	_road_container.name = "RoadContainer"
	_road_container.z_index = 1
	add_child(_road_container)
	
	for rname in ["dirt", "asphalt", "highway"]:
		var path = "res://assets/textures/roads/iso_%s.png" % rname
		if ResourceLoader.exists(path):
			_road_sheets[rname] = load(path)

func _get_road_sheet_key(road_type):
	match road_type:
		0: return "dirt"
		1: return "asphalt"
		2: return "highway"
	return "dirt"

func update_road(gx, gy, road_type):
	if _road_container == null:
		return
	
	# 尝试加载纹理（懒加载方式）
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
	
	# 使用 Sprite2D region_rect 裁剪子图块（最可靠的方案）
	sprite.texture = sheet
	sprite.region_enabled = true
	sprite.region_rect = Rect2(atlas_x, atlas_y, TILE_W, TILE_H)
	sprite.position = grid_to_world(gx, gy)

func _get_or_load_sheet(road_type):
	var key = _get_road_sheet_key(road_type)
	# 检查缓存
	if _road_sheets.has(key):
		return _road_sheets[key]
	# 尝试加载
	var path = "res://assets/textures/roads/iso_%s.png" % key
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex:
			_road_sheets[key] = tex
			return tex
	return null

func _create_fallback_road(gx, gy, road_type):
	# 备选方案：程序生成彩色菱形
	var sprite_key = str(gx) + "_" + str(gy)
	var sprite = _road_sprites.get(sprite_key)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Road_fallback_" + sprite_key
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_road_container.add_child(sprite)
		_road_sprites[sprite_key] = sprite
	
	# 生成彩色菱形纹理
	var colors = [Color(0.8, 0.6, 0.2, 0.9), Color(0.3, 0.3, 0.3, 0.9), Color(0.15, 0.15, 0.15, 0.9)]
	var col = colors[road_type % 3]
	var img = Image.create(TILE_W, TILE_H, false, Image.FORMAT_RGBA8)
	for y in range(TILE_H):
		for x in range(TILE_W):
			var cx = TILE_W / 2
			var cy = TILE_H / 2
			var dx = abs(x - cx) / float(cx)
			var dy = abs(y - cy) / float(cy)
			if dx + dy <= 1.0:
				img.set_pixel(x, y, col)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.position = grid_to_world(gx, gy)

func clear_road(gx, gy):
	var sprite_key = str(gx) + "_" + str(gy)
	var sprite = _road_sprites.get(sprite_key)
	if sprite != null:
		sprite.queue_free()
		_road_sprites.erase(sprite_key)

func clear_all_roads():
	for key in _road_sprites.keys():
		var sp = _road_sprites[key]
		if sp != null:
			sp.queue_free()
	_road_sprites.clear()

func _get_road_coords(cx, cy):
	var is_road = func(x, y):
		var c = _grid_map.get_cell(x, y) if _grid_map else null
		return c and c.terrain == 1
	var u = cy > 0 and is_road.call(cx, cy-1)
	var d = cy < MAP_HEIGHT-1 and is_road.call(cx, cy+1)
	var l = cx > 0 and is_road.call(cx-1, cy)
	var r = cx < MAP_WIDTH-1 and is_road.call(cx+1, cy)
	if (l or r) and (u or d): return Vector2i(0, 1)
	elif l or r: return Vector2i(0, 0)
	elif u or d: return Vector2i(1, 0)
	else: return Vector2i(1, 1)

func _clear_children():
	for c in get_children():
		c.queue_free()

func _create_terrain_tileset():
	var tileset = TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_size = Vector2i(TILE_W, TILE_H)
	tileset.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tileset.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL

	var tile_names = [
		"grass_0", "grass_1", "grass_2",
		"water_0", "water_1", "water_2",
		"sand", "forest", "mountain", "dirt"
	]
	for name in tile_names:
		var path = "res://assets/textures/isometric/%s.png" % name
		if not ResourceLoader.exists(path):
			continue
		var tex = load(path)
		var src = TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(TILE_W, TILE_H)
		src.create_tile(Vector2i(0, 0))
		tileset.add_source(src)

	_terrain = TileMap.new()
	_terrain.tile_set = tileset
	_terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_terrain)

func _fill_terrain():
	if _terrain == null:
		return
	var map = {0:["water_0","water_1","water_2"], 1:["sand"], 2:["grass_0","grass_1","grass_2"],
		3:["forest"], 4:["mountain"], 5:["mountain"]}
	var ts = _terrain.tile_set
	for gy in range(MAP_HEIGHT):
		for gx in range(MAP_WIDTH):
			var nt = _grid_map.get_natural_terrain(gx, gy)
			var names = map.get(nt, ["grass_0"])
			var chosen = names[hash(str(gx)+","+str(gy)) % names.size()]
			var sid = _find_source(chosen)
			if sid >= 0:
				_terrain.set_cell(0, Vector2i(gx, gy), sid, Vector2i(0,0))
			else:
				if ts and ts.get_source_count() > 0:
					_terrain.set_cell(0, Vector2i(gx, gy), 0, Vector2i(0,0))

func _find_source(name):
	if _terrain == null: return -1
	var ts = _terrain.tile_set
	for i in range(ts.get_source_count()):
		var src = ts.get_source(i)
		if src and src.texture and src.texture.resource_path.find(name) >= 0:
			return i
	return -1

# 高亮 & 虚影
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
