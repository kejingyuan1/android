# IsoRenderer.gd — 等距视角（Isometric）地形渲染器
# 使用 TileMap 的 TILE_SHAPE_ISOMETRIC 模式，类似部落冲突（COC）效果
extends Node2D

const MAP_WIDTH := 240
const MAP_HEIGHT := 160
const ISO_TILE_W := 64   # 等距图块宽度
const ISO_TILE_H := 32   # 等距图块高度
const HALF_W := ISO_TILE_W / 2.0
const HALF_H := ISO_TILE_H / 2.0

var _grid_map: Node = null
var _seed: int = 0
var _terrain_layer: TileMap = null
var _road_layer: TileMap = null

func setup(grid_map: Node, seed_val: int = 0):
	_grid_map = grid_map
	_seed = seed_val

func generate():
	if not _grid_map:
		return
	_clear_layers()
	_create_tilesets()
	_fill_terrain()

## 清除旧层
func _clear_layers():
	for c in get_children():
		if c is TileMap:
			c.queue_free()

## 创建等距 TileSet
func _create_tilesets():
	# === 地形 TileSet ===
	var terrain_tileset = TileSet.new()
	terrain_tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	terrain_tileset.tile_size = Vector2i(ISO_TILE_W, ISO_TILE_H)

	# 等距偏移量（菱形布局）
	terrain_tileset.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	terrain_tileset.tile_layout = TileSet.TILE_LAYOUT_STACKED

	# 添加地形图块
	var terrain_textures = {
		"grass_0": "res://assets/textures/isometric/grass_0.png",
		"grass_1": "res://assets/textures/isometric/grass_1.png",
		"grass_2": "res://assets/textures/isometric/grass_2.png",
		"water_0": "res://assets/textures/isometric/water_0.png",
		"water_1": "res://assets/textures/isometric/water_1.png",
		"water_2": "res://assets/textures/isometric/water_2.png",
		"sand": "res://assets/textures/isometric/sand.png",
		"forest": "res://assets/textures/isometric/forest.png",
		"mountain": "res://assets/textures/isometric/mountain.png",
	}
	var terrain_ids = {}
	var source_idx = 0
	for name in terrain_textures.keys():
		var path = terrain_textures[name]
		if ResourceLoader.exists(path):
			var tex = load(path)
			var source = TileSetAtlasSource.new()
			source.texture = tex
			source.texture_region_size = Vector2i(ISO_TILE_W, ISO_TILE_H)
			source.create_tile(Vector2i(0, 0))
			terrain_tileset.add_source(source)
			terrain_ids[name] = source_idx
			source_idx += 1

	_terrain_layer = TileMap.new()
	_terrain_layer.tile_set = terrain_tileset
	_terrain_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_terrain_layer)

	# === 道路 TileSet（等距）===
	var road_tileset = TileSet.new()
	road_tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	road_tileset.tile_size = Vector2i(ISO_TILE_W, ISO_TILE_H)
	road_tileset.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	road_tileset.tile_layout = TileSet.TILE_LAYOUT_STACKED

	# 加载道路贴图
	var road_sources = ["dirt_sheet.png", "asphalt_sheet.png", "highway_sheet.png"]
	for rsrc in road_sources:
		var path = "res://assets/textures/roads/%s" % rsrc
		if ResourceLoader.exists(path):
			var tex = load(path)
			var source = TileSetAtlasSource.new()
			source.texture = tex
			source.texture_region_size = Vector2i(32, 32)  # 原道路贴图 32x32
			for idx in range(4):
				var ax = idx % 2
				var ay = idx / 2
				source.create_tile(Vector2i(ax, ay))
			road_tileset.add_source(source)

	_road_layer = TileMap.new()
	_road_layer.tile_set = road_tileset
	_road_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_road_layer.z_index = 1
	add_child(_road_layer)

## 填充地形
func _fill_terrain():
	if not _grid_map or not _terrain_layer:
		return
	var terrain_tile_map = {
		0: ["water_0", "water_1", "water_2"],  # WATER
		1: ["sand", "sand", "sand"],            # SAND
		2: ["grass_0", "grass_1", "grass_2"],   # GRASS
		3: ["forest", "forest", "forest"],       # FOREST
		4: ["mountain", "mountain", "mountain"], # HILL (use mountain)
		5: ["mountain", "mountain", "mountain"], # MOUNTAIN
	}

	# 等距格子坐标：在 TileMap 中，(x, y) 对应菱形格
	for gy in range(MAP_HEIGHT):
		for gx in range(MAP_WIDTH):
			var nt = _grid_map.get_natural_terrain(gx, gy)
			var tile_names = terrain_tile_map.get(nt, ["grass_0"])
			var tile_name = tile_names[hash(gx * 1000 + gy * 7) % tile_names.size()]
			
			# 在 TileMap 中设置等距格
			var src_id = _get_tile_source_id(tile_name)
			if src_id >= 0:
				_terrain_layer.set_cell(Vector2i(gx, gy), src_id, Vector2i(0, 0))

## 获取图块在 TileSet 中的 source ID
func _get_tile_source_id(tile_name: String) -> int:
	if not _terrain_layer or not _terrain_layer.tile_set:
		return -1
	for i in range(_terrain_layer.tile_set.get_source_count()):
		var src = _terrain_layer.tile_set.get_source(i)
		if src is TileSetAtlasSource:
			var tex_path = src.texture.resource_path if src.texture else ""
			if tex_path.find(tile_name) >= 0:
				return i
	return -1

## 等距坐标转换：网格 → 世界坐标（用于放置 Sprite）
func grid_to_world(gx: int, gy: int) -> Vector2:
	var sx = (gx - gy) * HALF_W
	var sy = (gx + gy) * HALF_H
	return Vector2(sx, sy)

## 等距坐标转换：世界坐标 → 网格
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var gx = int(floor((world_pos.x / HALF_W + world_pos.y / HALF_H) / 2.0))
	var gy = int(floor((world_pos.y / HALF_H - world_pos.x / HALF_W) / 2.0))
	return Vector2i(gx, gy)

## 更新道路显示
func update_road(cell_pos: Vector2i, road_type: int):
	if not _road_layer:
		return
	var coords = _get_road_tile_coords(cell_pos.x, cell_pos.y)
	_road_layer.set_cell(cell_pos, road_type, coords)

## 清除道路格
func clear_road(cell_pos: Vector2i):
	if _road_layer:
		_road_layer.set_cell(cell_pos)

## 根据邻居计算道路图块坐标
func _get_road_tile_coords(cx: int, cy: int) -> Vector2i:
	var u = cy > 0 and _grid_map.get_cell(cx, cy-1) and _grid_map.get_cell(cx, cy-1).terrain == _grid_map.TerrainType.ROAD
	var d = cy < MAP_HEIGHT-1 and _grid_map.get_cell(cx, cy+1) and _grid_map.get_cell(cx, cy+1).terrain == _grid_map.TerrainType.ROAD
	var l = cx > 0 and _grid_map.get_cell(cx-1, cy) and _grid_map.get_cell(cx-1, cy).terrain == _grid_map.TerrainType.ROAD
	var r = cx < MAP_WIDTH-1 and _grid_map.get_cell(cx+1, cy) and _grid_map.get_cell(cx+1, cy).terrain == _grid_map.TerrainType.ROAD
	if (l or r) and (u or d):
		return Vector2i(0, 1)
	elif l or r:
		return Vector2i(0, 0)
	elif u or d:
		return Vector2i(1, 0)
	else:
		return Vector2i(1, 1)
