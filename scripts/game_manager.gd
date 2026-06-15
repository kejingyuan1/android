# GameManager.gd — 游戏主控制器
# 初始化所有系统、运行游戏循环、处理输入分发

extends Node

## 常量（横屏 240×160）
const GRID_WIDTH := 240
const GRID_HEIGHT := 160
const CELL_SIZE := 32

## 各系统引用
var grid_map: Node
var economy: Node
var road_system: Node
var zone_system: Node
var building_system: Node
var save_manager: Node
var service_system: Node

## 节点引用（使用 var 声明，在 _init_tilemaps 中手动赋值）
var camera: Node
var grid_renderer: Node2D
var iso_renderer: Node2D
var road_map_layer: TileMapLayer
var zone_map_layer: TileMapLayer
var highlight_map_layer: TileMapLayer
var building_container: Node2D
var selection_rect: ColorRect
var drag_preview: ColorRect
var top_bar: Node
var rci_bar: Node
var bottom_bar: Node
var info_card: Node
var sub_menu: Node

## RCI 需求
class RCIDemand:
	var residential: float = 50.0
	var commercial: float = 30.0
	var industrial: float = 20.0

var rci_demand: RCIDemand = RCIDemand.new()

## 游戏速度
enum Speed { PAUSED = 0, NORMAL = 1, FAST = 2 }
var current_speed: int = Speed.NORMAL
var sim_tick_timer: float = 0.0
var tick_interval: float = 2.0  # NORMAL 速度

## 输入状态
var _tool_active := false
var _current_tool := -1
var _current_category := -1
var _current_variant := -1
var _is_dragging := false
var _drag_start_cell := Vector2i(-1, -1)
var _info_mode := false
var _ghost_sprite: Sprite2D = null   # 放置预览虚影
var _remove_mode := false

## 建筑类型 → 纹理信息映射（variant_id → {texture, label, cost}）
const BUILDING_TEXTURES := {
	# 基本民生
	1000: {"texture": "power_plant", "label": "电力", "cost": 500},
	1001: {"texture": "farm", "label": "农场", "cost": 200},
	1002: {"texture": "water_pump", "label": "水", "cost": 300},
	# 公共
	2000: {"texture": "house1", "label": "住宅", "cost": 100},
	2001: {"texture": "shop", "label": "商业", "cost": 300},
	2002: {"texture": "trade_post", "label": "贸易", "cost": 400},
	2003: {"texture": "office", "label": "办公", "cost": 500},
	2004: {"texture": "factory", "label": "工厂", "cost": 600},
	# 科技
	3000: {"texture": "barracks", "label": "兵营", "cost": 800},
	3001: {"texture": "lab", "label": "实验室", "cost": 1000},
	3002: {"texture": "fire_station", "label": "消防", "cost": 700},
	3003: {"texture": "hospital", "label": "医院", "cost": 1200},
	3004: {"texture": "police", "label": "警局", "cost": 900},
}

## TileMap 源 ID（每个图层只有一个 source，ID 固定为 0）

signal money_changed(amount: float)

func _ready():
	_init_systems()
	_generate_terrain()
	_init_tilemaps()
	_generate_terrain_texture()
	_init_connections()
	_init_ui()

	# 尝试加载存档
	try_load_game()

	# 初始渲染
	_full_render()

func _generate_terrain():
	var terrain_gen = preload("res://scripts/terrain_generator.gd").new()
	add_child(terrain_gen)
	terrain_gen._ready()
	var terrain_data = terrain_gen.generate()
	grid_map.apply_natural_terrain(terrain_data)
	terrain_gen.queue_free()

func _generate_terrain_texture():
	# 使用等距渲染器
	if not iso_renderer:
		print("[WARN] iso_renderer is null, skipping isometric terrain generation")
		return
	if not grid_map:
		print("[WARN] grid_map is null, skipping terrain")
		return
	var world_seed = 0
	var global_game = get_node("/root/Main/GlobalGame")
	if global_game and global_game.world_gen:
		world_seed = global_game.world_gen.world_seed
	iso_renderer.setup(grid_map, world_seed)
	iso_renderer.generate()
	print("[DONE] Iso terrain generated, hiding flat renderer")
	
	# 隐藏旧的平面渲染器，只显示等距渲染
	if grid_renderer:
		grid_renderer.visible = false
		print("  - grid_renderer hidden")
	else:
		print("  - WARN: grid_renderer is null, cannot hide")
	# 隐藏平面的道路图层，只使用等距道路
	if road_map_layer:
		road_map_layer.visible = false
		print("  - road_map_layer hidden")
	else:
		print("  - WARN: road_map_layer is null")
	if zone_map_layer:
		zone_map_layer.visible = false
		print("  - zone_map_layer hidden")
	if highlight_map_layer:
		highlight_map_layer.visible = false
		print("  - highlight_map_layer hidden")

func _init_systems():
	# 创建网格数据
	grid_map = Node.new()
	grid_map.set_script(preload("res://scripts/grid_map.gd"))
	add_child(grid_map)
	grid_map._ready()

	# 创建经济系统
	economy = Node.new()
	economy.set_script(preload("res://scripts/economy.gd"))
	add_child(economy)

	# 创建道路系统
	road_system = Node.new()
	road_system.set_script(preload("res://scripts/road_system.gd"))
	add_child(road_system)

	# 创建分区系统
	zone_system = Node.new()
	zone_system.set_script(preload("res://scripts/zone_system.gd"))
	add_child(zone_system)

	# 创建建筑系统
	building_system = Node.new()
	building_system.set_script(preload("res://scripts/building_system.gd"))
	add_child(building_system)

	# 创建存档管理器
	save_manager = Node.new()
	save_manager.set_script(preload("res://scripts/save_manager.gd"))
	add_child(save_manager)

	# 创建公共服务系统
	service_system = Node.new()
	service_system.set_script(preload("res://scripts/service_system.gd"))
	add_child(service_system)

	# 获取建筑容器（在 _init_tilemaps 之前预加载，给 service/building 系统用）
	building_container = get_parent().get_node("GameWorld/BuildingContainer")

	# 初始化系统
	service_system.setup(grid_map, building_system, economy, self, building_container)
	economy.setup(grid_map, building_system, road_system, service_system)
	road_system.setup(grid_map)
	zone_system.setup(grid_map, economy)
	building_system.setup(grid_map, economy, building_container, service_system, self)
	save_manager.setup(grid_map, economy, building_system, road_system)

	# 需求信号连接
	road_system.connect("road_changed", Callable(self, "_on_road_changed"))
	building_system.connect("buildings_updated", Callable(self, "_on_buildings_updated"))

func _init_tilemaps():
	# 通过父节点查找兄弟节点下的子节点
	var parent = get_parent()
	grid_renderer = parent.get_node("GameWorld/GridRenderer")
	# 创建等距渲染器（如果不存在）
	var iso_node = parent.get_node_or_null("GameWorld/IsoRenderer")
	if not iso_node:
		iso_node = Node2D.new()
		iso_node.name = "IsoRenderer"
		iso_node.set_script(preload("res://scripts/iso_renderer.gd"))
		parent.get_node("GameWorld").add_child(iso_node)
	iso_renderer = iso_node
	road_map_layer = parent.get_node("GameWorld/RoadMap")
	zone_map_layer = parent.get_node("GameWorld/ZoneMap")
	highlight_map_layer = parent.get_node("GameWorld/HighlightMap")
	selection_rect = parent.get_node("GameWorld/SelectionRect")
	drag_preview = parent.get_node_or_null("GameWorld/DragPreview")
	building_container = parent.get_node("GameWorld/BuildingContainer")

	# 创建 TileSet
	_create_tilesets()

func _init_connections():
	var parent = get_parent()
	camera = parent.get_node("CityCamera")
	economy.connect("money_changed", Callable(self, "_on_money_changed"))

	# UI 引用（通过根节点 Main 查找）
	top_bar = get_node("/root/Main/UICanvas/TopBar")
	rci_bar = get_node("/root/Main/UICanvas/RCIPanel")
	bottom_bar = get_node("/root/Main/UICanvas/BottomBar")
	info_card = get_node("/root/Main/UICanvas/InfoCard")
	sub_menu = get_node("/root/Main/UICanvas/SubMenu")

func _init_ui():
	top_bar._gm = self
	rci_bar._gm = self
	bottom_bar._gm = self

	# 连接子菜单信号
	if sub_menu and sub_menu.has_signal("variant_selected"):
		sub_menu.connect("variant_selected", Callable(self, "_on_variant_selected"))
	if bottom_bar and bottom_bar.has_signal("main_category_selected"):
		bottom_bar.connect("main_category_selected", Callable(self, "_on_main_category_selected"))

func _create_tilesets():
	# 道路 TileSet — 4 种道路贴图（水平/垂直/交叉/单格）
	var road_tileset = TileSet.new()
	road_tileset.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	var road_configs = [
		{"color": Color(0.55, 0.45, 0.3), "name": "土路", "sheet": "dirt_sheet.png"},
		{"color": Color(0.25, 0.25, 0.25), "name": "沥青路", "sheet": "asphalt_sheet.png"},
		{"color": Color(0.12, 0.12, 0.12), "name": "高速路", "sheet": "highway_sheet.png"},
	]
	for cfg in road_configs:
		var tex = _load_road_sheet(cfg.sheet, CELL_SIZE)
		var source = TileSetAtlasSource.new()
		source.texture = tex
		source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
		# 4 个子图块：0=水平, 1=垂直, 2=十字交叉, 3=纯路面
		for idx in range(4):
			var ax = idx % 2
			var ay = idx / 2
			source.create_tile(Vector2i(ax, ay))
		road_tileset.add_source(source)
	road_map_layer.tile_set = road_tileset
	road_map_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# 分区 TileSet
	var zone_tileset = TileSet.new()
	zone_tileset.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	var zone_colors = [
		Color(0.15, 0.75, 0.2, 0.65),
		Color(0.15, 0.5, 0.9, 0.65),
		Color(0.9, 0.7, 0.1, 0.65),
	]
	for c in zone_colors:
		var tex = _create_zone_texture(c, CELL_SIZE)
		var source = TileSetAtlasSource.new()
		source.texture = tex
		source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
		source.create_tile(Vector2i(0, 0))
		zone_tileset.add_source(source)
	zone_map_layer.tile_set = zone_tileset
	zone_map_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# 高亮 TileSet
	var hl_tileset = TileSet.new()
	hl_tileset.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	var hl_tex = _create_highlight_texture(CELL_SIZE)
	var hl_source = TileSetAtlasSource.new()
	hl_source.texture = hl_tex
	hl_source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
	hl_source.create_tile(Vector2i(0, 0))
	hl_tileset.add_source(hl_source)
	highlight_map_layer.tile_set = hl_tileset

## 创建道路纹理（噪声路面 + 车道标线）
## 加载道路 spritesheet（64x64，包含 4 个 32x32 子图块）
func _load_road_sheet(sheet_name: String, size: int) -> Texture2D:
	var path = "res://assets/textures/roads/%s" % sheet_name
	if ResourceLoader.exists(path):
		var img = load(path).get_image()
		if img and img.get_width() == size * 2 and img.get_height() == size * 2:
			return load(path)
	# 回退
	return _create_road_texture(Color(0.5, 0.5, 0.5), "土路", size)

func _create_road_texture(base_color: Color, road_type: String, size: int) -> Texture2D:
	# 使用 PNG 道路贴图替代程序生成
	var png_file = "road_dirt.png"
	if road_type == "沥青路":
		png_file = "road_asphalt.png"
	elif road_type == "高速路":
		png_file = "road_highway.png"

	var png_path = "res://assets/textures/roads/%s" % png_file
	if ResourceLoader.exists(png_path):
		var png_img = load(png_path).get_image()
		if png_img:
			if png_img.get_width() != size:
				png_img.resize(size, size, Image.INTERPOLATE_NEAREST)
			return ImageTexture.create_from_image(png_img)

	# 回退：程序生成
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.15
	noise.seed = randi()

	var is_paved = road_type != "土路"

	for y in range(size):
		for x in range(size):
			var n = noise.get_noise_2d(x, y) * 0.5 + 0.5  # 0~1
			var r = base_color.r + n * 0.08
			var g = base_color.g + n * 0.08
			var b = base_color.b + n * 0.08

			if is_paved:
				var mid = size / 2
				var lane_offset = 6 if road_type == "高速路" else 3
				var dash = (y / 4) % 2 == 0
				if abs(x - mid) < 1 and dash:
					r += 0.5; g += 0.5; b += 0.5
				if road_type == "高速路":
					if (x < 2 or x > size - 3) and (y > 2 and y < size - 2):
						r += 0.6; g += 0.6; b += 0.6
			else:
				# 土路：两侧草边
				if x < 2 or x > size - 3:
					r += 0.1; g += 0.2; b -= 0.05

			img.set_pixel(x, y, Color(clamp(r, 0, 1), clamp(g, 0, 1), clamp(b, 0, 1), 1.0))

	return ImageTexture.create_from_image(img)

## 创建分区纹理（半透明色 + 边界线）
func _create_zone_texture(color: Color, size: int) -> Texture2D:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var c = color
			# 边界线
			if x == 0 or y == 0 or x == size - 1 or y == size - 1:
				c = Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, 0.5)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

## 创建高亮纹理
func _create_highlight_texture(size: int) -> Texture2D:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			# 边缘亮线，内部透明
			var edge = (x == 0 or y == 0 or x == size - 1 or y == size - 1)
			img.set_pixel(x, y, Color(1, 1, 0, 0.35) if edge else Color(1, 1, 0, 0.08))
	return ImageTexture.create_from_image(img)

## 输入处理
func _input(event):
	if event is InputEventMouseButton or event is InputEventMouseMotion \
		or event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_game_input(event)

func _handle_game_input(event):
	# 忽略 UI 上的事件
	if _is_ui_event(event):
		return

	var world_pos = _get_world_position(event)
	var cell_pos = Vector2i.ZERO
	if iso_renderer and iso_renderer.has_method("world_to_grid"):
		cell_pos = iso_renderer.world_to_grid(world_pos)
	else:
		cell_pos = grid_map.world_to_grid(world_pos)

	# 检查是否在地图范围内
	if cell_pos.x < 0 or cell_pos.x >= GRID_WIDTH or cell_pos.y < 0 or cell_pos.y >= GRID_HEIGHT:
		if iso_renderer and iso_renderer.has_method("hide_highlight"):
			iso_renderer.hide_highlight()
			iso_renderer.hide_ghost()
		return

	# 等距高亮跟随鼠标
	if iso_renderer and iso_renderer.has_method("show_highlight"):
		iso_renderer.show_highlight(cell_pos.x, cell_pos.y)
		# 建筑放置模式：显示虚影
		if _current_variant >= 0 and event is InputEventMouseMotion:
			_update_ghost_position(cell_pos)

	# 工具模式
	if _current_tool >= 0 or _current_variant >= 0:
		_handle_tool_input(event, cell_pos)
		# mouse motion 时更新虚影位置
		if event is InputEventMouseMotion and _current_variant >= 0:
			_update_ghost_position(cell_pos)
	else:
		if _is_press_event(event):
			_handle_normal_tap(cell_pos)
		# 清除虚影
		if _ghost_sprite and _current_variant < 0:
			_remove_ghost()

func _is_ui_event(event) -> bool:
	var pos_y = 0.0
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		pos_y = event.position.y
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		pos_y = event.position.y
	else:
		return false
	return pos_y < 76.0 or (pos_y > 480.0 and sub_menu.visible) or pos_y > 566.0

func _get_world_position(event) -> Vector2:
	var viewport = get_viewport()
	var cam = camera
	if not cam or not viewport:
		return Vector2.ZERO
	# 使用 canvas_transform 进行精确转换（包含 offset/rotation 等）
	var inv_xform = viewport.get_canvas_transform().affine_inverse()
	return inv_xform * event.position

func _handle_tool_input(event, cell_pos: Vector2i):
	# 优先使用 _current_variant（新建筑系统），回退到 _current_tool（旧道路/分区系统）
	var v = _current_variant if _current_variant >= 0 else _current_tool
	match v:
		0, 1, 2:  # Road variants
			_handle_road_input(event, cell_pos, v)
			# 更新邻居格子的道路图块（连接性变化）
			if event is InputEventMouseButton:
				_update_road_neighbors(cell_pos)
		10, 11:  # Residential (low/high density, same zone type)
			_handle_zone_input(event, cell_pos, 2)
		20:  # Commercial
			_handle_zone_input(event, cell_pos, 3)
		30:  # Industrial
			_handle_zone_input(event, cell_pos, 4)
		100, 101, 102, 103:  # Service (legacy)
			_handle_service_input(event, cell_pos, v - 100)
		# 新建筑变体：基本民生 (1000~1002)
		1000, 1001, 1002:
			_handle_building_placement(event, cell_pos, v)
		# 公共建筑 (2000~2004)
		2000, 2001, 2002, 2003, 2004:
			_handle_building_placement(event, cell_pos, v)
		# 科技建筑 (3000~3004)
		3000, 3001, 3002, 3003, 3004:
			_handle_building_placement(event, cell_pos, v)
		200:  # Remove
			_handle_remove_input(event, cell_pos)
		201:  # Info
			_handle_info_input(event, cell_pos)

func _handle_road_input(event, cell_pos: Vector2i, road_type: int = 0):
	if _is_press_event(event):
		road_system.start_draw(cell_pos, road_type)
		_update_cell_visual(cell_pos.x, cell_pos.y)
		_is_dragging = true
		# 道路铺设提示
		var road_names = ["土路", "沥青路", "高速路"]
		_show_toast("🛣️ 开始铺设 " + road_names[road_type] + " - 拖拽延伸，松手结束")
	elif _is_release_event(event):
		if _is_dragging:
			road_system.end_draw()
			_is_dragging = false
			_full_render()
			_show_toast("✅ 道路铺设完成")
	elif _is_drag_event(event):
		if _is_dragging:
			road_system.continue_draw(cell_pos, road_type)
			_update_cell_visual(cell_pos.x, cell_pos.y)

func _handle_zone_input(event, cell_pos: Vector2i, zone_type: int = 2):
	zone_system.set_zone_type(zone_type)

	if _is_press_event(event):
		zone_system.start_zone(cell_pos)
		_update_cell_visual(cell_pos.x, cell_pos.y)
		_is_dragging = true
	elif _is_release_event(event):
		if _is_dragging:
			zone_system.end_zone()
			_is_dragging = false
			_full_render()
			building_system.process_tick()
	elif _is_drag_event(event):
		if _is_dragging:
			zone_system.continue_zone(cell_pos)
			_update_cell_visual(cell_pos.x, cell_pos.y)

func _handle_remove_input(event, cell_pos: Vector2i):
	if _is_press_event(event):
		var cell = grid_map.get_cell(cell_pos.x, cell_pos.y)
		if cell:
			if cell.terrain == grid_map.TerrainType.ROAD:
				road_system.start_remove(cell_pos)
			elif grid_map.is_zoned(cell_pos.x, cell_pos.y):
				zone_system.start_remove(cell_pos)
		_is_dragging = true
	elif _is_release_event(event):
		if _is_dragging:
			if road_system.draw_mode == road_system.DrawMode.REMOVING:
				road_system.end_remove()
			elif zone_system.draw_mode == zone_system.DrawMode.REMOVING:
				zone_system.end_remove()
			_is_dragging = false
			_full_render()
	elif _is_drag_event(event):
		if _is_dragging:
			var cell = grid_map.get_cell(cell_pos.x, cell_pos.y)
			if cell and cell.terrain == grid_map.TerrainType.ROAD:
				road_system.continue_remove(cell_pos)
			elif cell and grid_map.is_zoned(cell_pos.x, cell_pos.y):
				zone_system.continue_remove(cell_pos)

func _handle_info_input(event, cell_pos: Vector2i):
	if _is_press_event(event):
		var cell = grid_map.get_cell(cell_pos.x, cell_pos.y)
		if cell:
			if cell.has_building and cell.building_ref:
				info_card.show_building_info(cell_pos, cell)
			elif grid_map.is_zoned(cell_pos.x, cell_pos.y):
				info_card._title_label.text = "分区"
				var type_name = "住宅" if cell.terrain == grid_map.TerrainType.ZONE_RESIDENTIAL else "商业" if cell.terrain == grid_map.TerrainType.ZONE_COMMERCIAL else "工业"
				info_card._detail_label.text = "类型: %s\n已开发: %s\n连通: %s" % [type_name, "是" if cell.has_building else "否", "是" if cell.zone_connected else "否"]
				info_card.show()

## 服务建筑放置
func _handle_service_input(event, cell_pos: Vector2i, service_type: int = 0):
	if _is_press_event(event) and not _is_dragging:
		_is_dragging = true
		if service_system.place_service(service_type, cell_pos.x, cell_pos.y):
			_update_cell_visual(cell_pos.x, cell_pos.y)
			var names = ["警局", "消防局", "医院", "学校"]
			print("放置了 ", names[service_type], " 在 (", cell_pos.x, ", ", cell_pos.y, ")")
	elif _is_release_event(event):
		_is_dragging = false

## 通用建筑放置（单格点击，放置建筑纹理精灵）
func _handle_building_placement(event, cell_pos: Vector2i, variant_id: int):
	if not BUILDING_TEXTURES.has(variant_id):
		return

	var info = BUILDING_TEXTURES[variant_id]

	if _is_press_event(event) and not _is_dragging:
		_is_dragging = true

		# 检查单元格是否可用
		var cell = grid_map.get_cell(cell_pos.x, cell_pos.y)
		if not cell or cell.has_building or cell.terrain == grid_map.TerrainType.ROAD:
			print("该位置不可放置 ", info.label)
			_is_dragging = false
			return

		# 检查资金
		if not economy.can_afford(info.cost):
			print("资金不足，无法放置 ", info.label)
			_is_dragging = false
			return

		# 扣费
		economy.spend(info.cost, "建造" + info.label)

		# 标记单元格
		cell.has_building = true
		cell.building_level = 1
		cell.building_size_x = 1
		cell.building_size_y = 1

		# 创建建筑精灵
		var tex_path = "res://assets/textures/buildings/%s.png" % info.texture
		if ResourceLoader.exists(tex_path):
			var sprite = Sprite2D.new()
			sprite.texture = load(tex_path)
			sprite.centered = true
			# 等距坐标 + 阴影
			if iso_renderer and iso_renderer.has_method("grid_to_world"):
				var iso_pos = iso_renderer.grid_to_world(cell_pos.x, cell_pos.y)
				sprite.position = iso_pos
				# 添加建筑菱形阴影
				if iso_renderer.has_method("create_shadow_sprite"):
					var shadow = iso_renderer.create_shadow_sprite()
					shadow.position = iso_pos
					building_container.add_child(shadow)
			else:
				sprite.position = Vector2(
					cell_pos.x * CELL_SIZE + CELL_SIZE / 2.0,
					cell_pos.y * CELL_SIZE + CELL_SIZE / 2.0
				)
			sprite.z_index = 5 + cell_pos.y * 0.01
			sprite.scale = Vector2(0.8, 0.8)
			building_container.add_child(sprite)
			# 手动放置的建筑（如电厂、农场）不设置 building_ref，防止与 zone 自动生长系统混淆

		_update_cell_visual(cell_pos.x, cell_pos.y)

		# 放置成功提示
		_show_toast("✅ %s 已建造" % info.label)
		print("放置了 ", info.label, " 在 (", cell_pos.x, ", ", cell_pos.y, ")")

		# 放置成功后清除虚影
		_remove_ghost()

	elif _is_release_event(event):
		_is_dragging = false

## 创建放置虚影（半透明建筑预览）
func _update_ghost_position(cell_pos: Vector2i):
	if _current_variant < 0:
		_remove_ghost()
		return

	var info = BUILDING_TEXTURES.get(_current_variant)
	if not info:
		return

	if not _ghost_sprite:
		var tex_path = "res://assets/textures/buildings/%s.png" % info.texture
		if not ResourceLoader.exists(tex_path):
			return
		_ghost_sprite = Sprite2D.new()
		_ghost_sprite.texture = load(tex_path)
		_ghost_sprite.centered = true
		_ghost_sprite.modulate = Color(1, 1, 1, 0.5)
		_ghost_sprite.z_index = 50
		_ghost_sprite.scale = Vector2(0.8, 0.8)
		building_container.add_child(_ghost_sprite)

	if iso_renderer and iso_renderer.has_method("grid_to_world"):
		_ghost_sprite.position = iso_renderer.grid_to_world(cell_pos.x, cell_pos.y)
	else:
		_ghost_sprite.position = Vector2(
			cell_pos.x * CELL_SIZE + CELL_SIZE / 2.0,
			cell_pos.y * CELL_SIZE + CELL_SIZE / 2.0
		)

func _remove_ghost():
	if _ghost_sprite:
		_ghost_sprite.queue_free()
		_ghost_sprite = null

## 显示顶部通知提示
func _show_toast(msg: String):
	if not top_bar or not is_inside_tree():
		print("[Toast] ", msg)
		return
	var label = Label.new()
	label.text = msg
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(400, 80)
	label.size = Vector2(480, 36)
	top_bar.add_child(label)
	var t = label.create_tween().set_parallel()
	t.tween_property(label, "modulate", Color(1, 1, 1, 0), 2.5).set_delay(1.5)
	t.tween_callback(func(): if label and label.get_parent(): label.queue_free()).set_delay(4.0)

## 辅助：判断按键按下（鼠标或触摸）
func _is_press_event(event) -> bool:
	return (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)

func _is_release_event(event) -> bool:
	return (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
		or (event is InputEventScreenTouch and not event.pressed)

func _is_drag_event(event) -> bool:
	return event is InputEventMouseMotion or event is InputEventScreenDrag

func _handle_normal_tap(cell_pos: Vector2i):
	var cell = grid_map.get_cell(cell_pos.x, cell_pos.y)
	if cell:
		# 高亮显示选中格
		selection_rect.visible = true
		selection_rect.position = grid_map.grid_to_world(cell_pos.x, cell_pos.y)

	if cell and cell.has_building and cell.building_ref:
		info_card.show_building_info(cell_pos, cell)
	else:
		info_card.hide()

func _on_tool_selected(tool_type: int):
	_current_tool = tool_type
	_tool_active = (tool_type >= 0)
	_info_mode = (tool_type == 6)

	if camera and camera.has_method("set_tool_active"):
		camera.set_tool_active(_tool_active)

	if not _tool_active:
		selection_rect.visible = false

## 主菜单选中 → 弹出子菜单
func _on_main_category_selected(category_id: int):
	if category_id < 0:
		if sub_menu:
			sub_menu.hide_menu()
		_current_category = -1
		_current_variant = -1
		_tool_active = false
		_current_tool = -1
		_remove_ghost()
		return

	_current_category = category_id
	_current_variant = -1
	_tool_active = false
	_current_tool = -1
	camera.set_tool_active(false)
	if not sub_menu:
		return

	var data = bottom_bar.get_variants_for_category(category_id)
	if data and data.variants.size() > 0:
		sub_menu.show_menu(data.title, data.variants)
	else:
		sub_menu.hide_menu()

## 子菜单变体选中 → 激活工具
func _on_variant_selected(variant_id: int):
	_current_variant = variant_id
	_tool_active = true

	camera.set_tool_active(true)

	# 单项工具（非连续绘制的）直接清除选择
	if variant_id in [200, 201]:
		_tool_active = true
		_info_mode = (variant_id == 201)

	# 关闭子菜单
	if sub_menu:
		sub_menu.hide_menu()

	# 重置底部栏高亮
	bottom_bar.current_category = -1
	bottom_bar._update_button_states()

## 模拟 Tick
func _process(delta):
	if current_speed == Speed.PAUSED:
		return

	tick_interval = 2.0 if current_speed == Speed.NORMAL else 1.0
	sim_tick_timer += delta

	if sim_tick_timer >= tick_interval:
		sim_tick_timer = 0.0
		_run_sim_tick()

	save_manager.update(delta)

func _run_sim_tick():
	# 1. 计算 RCI 需求
	_calculate_rci_demand()

	# 2. 建筑生长
	building_system.process_tick()

	# 3. 经济结算
	economy.process_tick()

	# 4. 更新显示
	_update_visuals()

	# 5. 更新人口显示
	var pop = building_system.get_residential_population()
	top_bar.update_population(pop)

	# 6. 检查破产
	if economy.is_bankrupt():
		_display_bankrupt_warning()

func _calculate_rci_demand():
	var total_pop = building_system.get_residential_population()
	var commercial_count = building_system.get_commercial_count()
	var industrial_count = building_system.get_industrial_count()

	# 服务覆盖加成
	var happiness = service_system.get_happiness() if service_system else 0.5
	var edu_rate = service_system.get_education_rate() if service_system else 0.0

	# 住宅需求：服务覆盖越好需求越高
	rci_demand.residential = 40.0
	rci_demand.residential += happiness * 30.0  # 服务加成
	rci_demand.residential -= zone_system.get_developed_cell_count(grid_map.TerrainType.ZONE_RESIDENTIAL) * 1.5
	rci_demand.residential += commercial_count * 2.0
	rci_demand.residential += industrial_count * 1.5
	rci_demand.residential = clamp(rci_demand.residential, -50.0, 100.0)

	# 商业需求：人口 + 教育
	rci_demand.commercial = 20.0
	rci_demand.commercial += total_pop * 0.4
	rci_demand.commercial += edu_rate * 20.0
	rci_demand.commercial -= commercial_count * 2.5
	rci_demand.commercial = clamp(rci_demand.commercial, -50.0, 100.0)

	# 工业需求
	rci_demand.industrial = 20.0
	rci_demand.industrial += total_pop * 0.2
	rci_demand.industrial -= industrial_count * 2.0
	rci_demand.industrial = clamp(rci_demand.industrial, -50.0, 100.0)

func _update_visuals():
	_full_render()

## 更新指定格子周围四格的���路显示
func _update_road_neighbors(pos: Vector2i):
	var dirs = [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]
	for d in dirs:
		var nx = pos.x + d.x
		var ny = pos.y + d.y
		if nx >= 0 and nx < GRID_WIDTH and ny >= 0 and ny < GRID_HEIGHT:
			var cell = grid_map.get_cell(nx, ny)
			if cell and cell.terrain == grid_map.TerrainType.ROAD:
				_update_cell_visual(nx, ny)

## 根据邻居计算道路图块坐标 (0,0)=水平 (1,0)=垂直 (0,1)=十字 (1,1)=孤岛
func _get_road_tile_coords(cx: int, cy: int) -> Vector2i:
	var u = cy > 0 and grid_map.get_cell(cx, cy-1) and grid_map.get_cell(cx, cy-1).terrain == grid_map.TerrainType.ROAD
	var d = cy < GRID_HEIGHT-1 and grid_map.get_cell(cx, cy+1) and grid_map.get_cell(cx, cy+1).terrain == grid_map.TerrainType.ROAD
	var l = cx > 0 and grid_map.get_cell(cx-1, cy) and grid_map.get_cell(cx-1, cy).terrain == grid_map.TerrainType.ROAD
	var r = cx < GRID_WIDTH-1 and grid_map.get_cell(cx+1, cy) and grid_map.get_cell(cx+1, cy).terrain == grid_map.TerrainType.ROAD
	if (l or r) and (u or d):
		return Vector2i(0, 1)
	elif l or r:
		return Vector2i(0, 0)
	elif u or d:
		return Vector2i(1, 0)
	else:
		return Vector2i(1, 1)

## 增量更新：只更新道路/分区显示（地形是静态纹理，不变）
func _update_cell_visual(x: int, y: int):
	var cell = grid_map.get_cell(x, y)
	if not cell:
		return
	var pos = Vector2i(x, y)
	# 等距模式下使用 IsoRenderer 渲染道路
	if cell.terrain == grid_map.TerrainType.ROAD:
		if iso_renderer and iso_renderer.has_method("update_road"):
			iso_renderer.update_road(x, y, cell.road_type if cell.road_type < 3 else 0)
		else:
			road_map_layer.set_cell(pos)
			var coords = _get_road_tile_coords(x, y)
			road_map_layer.set_cell(pos, cell.road_type if cell.road_type < 3 else 0, coords)
	elif grid_map.is_zoned(x, y) and not cell.has_building:
		road_map_layer.set_cell(pos)
		zone_map_layer.set_cell(pos)
		var src = 0
		match cell.terrain:
			grid_map.TerrainType.ZONE_RESIDENTIAL: src = 0
			grid_map.TerrainType.ZONE_COMMERCIAL: src = 1
			grid_map.TerrainType.ZONE_INDUSTRIAL: src = 2
		zone_map_layer.set_cell(pos, src, Vector2i(0, 0))

func _full_render():
	# 只更新道路和分区 TileMap（地形纹理是静态的）
	road_map_layer.clear()
	zone_map_layer.clear()
	highlight_map_layer.clear()
	
	# 等距模式：先清除等距道路层再重新渲染
	if iso_renderer and iso_renderer.has_method("clear_all_roads"):
		iso_renderer.clear_all_roads()

	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell = grid_map.get_cell(x, y)
			if not cell:
				continue

			var pos = Vector2i(x, y)

			if cell.terrain == grid_map.TerrainType.ROAD:
				# 等距模式下使用 IsoRenderer 渲染道路
				if iso_renderer and iso_renderer.has_method("update_road"):
					iso_renderer.update_road(x, y, cell.road_type if cell.road_type < 3 else 0)
				else:
					var coords = _get_road_tile_coords(x, y)
					road_map_layer.set_cell(pos, cell.road_type if cell.road_type < 3 else 0, coords)
			elif cell.terrain == grid_map.TerrainType.ZONE_RESIDENTIAL and not cell.has_building:
				zone_map_layer.set_cell(pos, 0, Vector2i(0, 0))
			elif cell.terrain == grid_map.TerrainType.ZONE_COMMERCIAL and not cell.has_building:
				zone_map_layer.set_cell(pos, 1, Vector2i(0, 0))
			elif cell.terrain == grid_map.TerrainType.ZONE_INDUSTRIAL and not cell.has_building:
				zone_map_layer.set_cell(pos, 2, Vector2i(0, 0))

func set_speed(speed_idx: int):
	current_speed = speed_idx
	tick_interval = 2.0 if current_speed == Speed.NORMAL else 1.0

func save_game():
	save_manager.save_game()

func try_load_game():
	# 旧版存档系统已废弃，存档由 GlobalGame 的 SaveManager v2 管理
	# 保留此方法供 load_from_save_data 使用
	pass

## 从 GlobalGame 的存档数据恢复城市状态
func load_from_save_data(grid_data: Array, money: float):
	if not grid_map or not economy:
		return

	economy.money = money

	# 恢复网格数据
	for y in range(min(grid_data.size(), GRID_HEIGHT)):
		var row = grid_data[y]
		for x in range(min(row.size(), GRID_WIDTH)):
			var cell_data = row[x]
			if cell_data == null:
				continue
			var cell = grid_map.get_cell(x, y)
			if not cell:
				continue
			cell.terrain = cell_data.get("terrain", 0)
			cell.road_type = cell_data.get("road_type", 0)
			cell.reachable = cell_data.get("reachable", false)
			cell.zone_connected = cell_data.get("zone_connected", false)
			cell.has_building = cell_data.get("has_building", false)
			cell.building_level = cell_data.get("building_level", 0)
			cell.building_size_x = cell_data.get("building_size_x", 1) if "building_size_x" in cell_data else 1
			cell.building_size_y = cell_data.get("building_size_y", 1) if "building_size_y" in cell_data else 1

	# 全量渲染
	_full_render()
	_rebuild_buildings()

	economy.emit_signal("money_changed", economy.money)
	print("城市数据从存档恢复完成")

func _rebuild_buildings():
	# 清除现有建筑
	for child in building_container.get_children():
		child.queue_free()

	# 从数据重建
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell = grid_map.get_cell(x, y)
			if cell and cell.has_building and cell.building_level > 0:
				var sz_x = max(1, cell.building_size_x if "building_size_x" in cell else 1)
				var sz_y = max(1, cell.building_size_y if "building_size_y" in cell else 1)
				var bld = building_system._create_building_node(x, y, cell.terrain, cell.building_level, sz_x, sz_y)
				cell.building_ref = bld

func _on_road_changed():
	pass

func _on_buildings_updated():
	pass

func _on_money_changed(amount: float):
	pass

func _display_bankrupt_warning():
	print("⚠️ 城市破产了！")

## 从信息卡触发的建筑升级
func try_upgrade_building(cell_pos: Vector2i, cell):
	if not cell or not cell.has_building:
		return
	var level = cell.building_level
	if level >= 3:
		return
	if building_system and building_system.has_method("_try_upgrade_building"):
		building_system._try_upgrade_building(cell)
		_update_cell_visual(cell_pos.x, cell_pos.y)
