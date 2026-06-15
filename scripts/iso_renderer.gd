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

func _find_source(name: String) -> int:
	if not _terrain: return -1
	var ts = _terrain.tile_set
	for i in range(ts.get_source_count()):
		var src = ts.get_source(i) as TileSetAtlasSource
		if src and src.texture and src.texture.resource_path.find(name) >= 0:
			return i
	return -1

## 网格 → 世界（放置 sprite 用）
func grid_to_world(gx: int, gy: int) -> Vector2:
	return Vector2((gx - gy) * HALF_W, (gx + gy) * HALF_H)

## 世界 → 网格（鼠标拾取用）
func world_to_grid(pos: Vector2) -> Vector2i:
	var gx = int(floor((pos.x / HALF_W + pos.y / HALF_H) / 2.0))
	var gy = int(floor((pos.y / HALF_H - pos.x / HALF_W) / 2.0))
	return Vector2i(gx, gy)
