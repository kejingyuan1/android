# IsoRenderer.gd — Phase 1: 等距地形渲染
# 使用 Godot 4 TileMap 原生等距模式渲染菱形地形
extends Node2D

const MAP_WIDTH := 240
const MAP_HEIGHT := 160
const TILE_W := 64
const TILE_H := 32
const HALF_W := 32.0
const HALF_H := 16.0

var _grid_map: Node = null
var _terrain: TileMap = null

func setup(grid_map: Node, _seed_val: int = 0):
	_grid_map = grid_map

func generate():
	if not _grid_map:
		return
	_clear_children()
	_create_terrain_tileset()
	_fill_terrain()
	_create_road_tileset()
	init_overlays()

# --- Phase 3: 等距道路 ---
var _road: TileMap = null
var _road_types := {"dirt": 0, "asphalt": 1, "highway": 2}

func _create_road_tileset():
	var tileset = TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_size = Vector2i(TILE_W, TILE_H)
	tileset.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tileset.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL

	for rname in ["dirt", "asphalt", "highway"]:
		var path = "res://assets/textures/roads/iso_%s.png" % rname
		if not ResourceLoader.exists(path):
			continue
		var tex = load(path)
		var src = TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(TILE_W, TILE_H)
		# 4 sub-tiles: h(0,0), v(1,0), cross(0,1), plain(1,1)
		for idx in range(4):
			var ax = idx % 2
			var ay = idx / 2
			src.create_tile(Vector2i(ax, ay))
		tileset.add_source(src)

	_road = TileMap.new()
	_road.tile_set = tileset
	_road.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_road.z_index = 1
	add_child(_road)

func update_road(gx: int, gy: int, road_type: int):
	if not _road:
		return
	var coords = _get_road_coords(gx, gy)
	_road.set_cell(0, Vector2i(gx, gy), road_type, coords)
	# 调试：同时更新 sprite 道路预览
	_update_road_sprite(gx, gy, road_type)

func _road_sprite_key(gx: int, gy: int) -> String:
	return "%d_%d" % [gx, gy]

var _road_sprites: Dictionary = {}

func _update_road_sprite(gx: int, gy: int, road_type: int):
	# 只用于调试和预览 - 使用简单的彩色菱形 Sprite 作为道路标记
	var key = _road_sprite_key(gx, gy)
	var sp = _road_sprites.get(key)
	if not sp:
		sp = Sprite2D.new()
		sp.name = "RoadSprite_%s" % key
		# 使用随路类型变化的颜色
		var colors = [Color(0.8, 0.6, 0.2, 0.9), Color(0.3, 0.3, 0.3, 0.9), Color(0.15, 0.15, 0.15, 0.9)]
		var tex = _create_color_diamond(64, 32, colors[road_type % 3])
		sp.texture = tex
		sp.centered = true
		sp.z_index = 2
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_road_sprites[key] = sp
		add_child(sp)
	sp.position = grid_to_world(gx, gy)

func _create_color_diamond(w: int, h: int, color: Color) -> Texture2D:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var cx = w / 2
			var cy = h / 2
			var dx = abs(x - cx) / float(cx)
			var dy = abs(y - cy) / float(cy)
			if dx + dy <= 1.0:
				img.set_pixel(x, y, color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func clear_road(gx: int, gy: int):
	if _road:
		_road.set_cell(0, Vector2i(gx, gy))
	_clear_road_sprite(gx, gy)

func clear_all_roads():
	if _road:
		_road.clear()
	_clear_all_road_sprites()

func _clear_road_sprite(gx: int, gy: int):
	var key = _road_sprite_key(gx, gy)
	var sp = _road_sprites.get(key)
	if sp:
		sp.queue_free()
		_road_sprites.erase(key)

func _clear_all_road_sprites():
	for key in _road_sprites.keys():
		var sp = _road_sprites[key]
		if sp:
			sp.queue_free()
	_road_sprites.clear()

func _get_road_coords(cx: int, cy: int) -> Vector2i:
	var is_road = func(x, y):
		var c = _grid_map.get_cell(x, y) if _grid_map else null
		return c and c.terrain == 1  # TerrainType.ROAD = 1
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
	if not _terrain:
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
				# 回退：找第一个可用的 source
				if ts and ts.get_source_count() > 0:
					_terrain.set_cell(0, Vector2i(gx, gy), 0, Vector2i(0,0))

func _find_source(name: String) -> int:
	if not _terrain: return -1
	var ts = _terrain.tile_set
	for i in range(ts.get_source_count()):
		var src = ts.get_source(i) as TileSetAtlasSource
		if src and src.texture and src.texture.resource_path.find(name) >= 0:
			return i
	return -1

# --- Phase 2: 菱形高亮 & 虚影 ---
var _highlight: Sprite2D = null
var _ghost: Sprite2D = null

func init_overlays():
	# 选中高亮菱形
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

	# 放置虚影
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

func show_highlight(gx: int, gy: int):
	if _highlight:
		_highlight.position = grid_to_world(gx, gy)
		_highlight.visible = true

func hide_highlight():
	if _highlight:
		_highlight.visible = false

func show_ghost(gx: int, gy: int, tex: Texture2D = null):
	if _ghost:
		_ghost.position = grid_to_world(gx, gy)
		if tex:
			_ghost.texture = tex
		_ghost.visible = true

func hide_ghost():
	if _ghost:
		_ghost.visible = false

# --- Phase 5: 建筑阴影 & 水面动画 ---
func create_shadow_sprite() -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = load("res://assets/textures/isometric/shadow.png") if ResourceLoader.exists("res://assets/textures/isometric/shadow.png") else null
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = true
	s.z_index = 3
	return s

## 网格 → 世界（放置 sprite 用）
func grid_to_world(gx: int, gy: int) -> Vector2:
	return Vector2((gx - gy) * HALF_W, (gx + gy) * HALF_H)

## 世界 → 网格（鼠标拾取用）
func world_to_grid(pos: Vector2) -> Vector2i:
	var gx = int(floor((pos.x / HALF_W + pos.y / HALF_H) / 2.0))
	var gy = int(floor((pos.y / HALF_H - pos.x / HALF_W) / 2.0))
	return Vector2i(gx, gy)
