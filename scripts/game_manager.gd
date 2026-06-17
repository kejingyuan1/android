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
var worker_sys: Node

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
var _building_info_panel = null

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

## 移动模式
var _move_mode := false
var _move_source_cell := Vector2i(-1, -1)
var _move_source_variant := -1

## 旋转模式
var _rotation_mode := false
var _rotation_angle := 0  # 0, 90, 180, 270

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
	# 防御建筑
	4000: {"texture": "wall", "label": "城墙", "cost": 50},
	4001: {"texture": "cannon", "label": "加农炮", "cost": 800},
	4002: {"texture": "archer_tower", "label": "箭塔", "cost": 1000},
	4003: {"texture": "wizard_tower", "label": "法师塔", "cost": 1500},
	4004: {"texture": "mortar", "label": "迫击炮", "cost": 2000},
	# 资源建筑
	5000: {"texture": "gold_mine", "label": "金矿", "cost": 150},
	5001: {"texture": "elixir_collector", "label": "圣水瓶", "cost": 200},
	5002: {"texture": "storage", "label": "仓库", "cost": 300},
	# 兵营
	6000: {"texture": "barracks", "label": "兵营", "cost": 1000},
	6001: {"texture": "camp", "label": "军营", "cost": 500},
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

	# 在全局 GameObject _ready 后放置大本营
	call_deferred("_place_town_hall")

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

	# 创建工人系统
	worker_sys = preload("res://scripts/worker/worker_system.gd").new()
	add_child(worker_sys)
	worker_sys.connect("job_completed", Callable(self, "_on_worker_job_completed"))

func _init_tilemaps():
	# 通过父节点查找兄弟节点下的子节点
	var parent = get_parent()
	grid_renderer = parent.get_node("GameWorld/GridRenderer")
	# 创建等距渲染器（如果不存在）
	var iso_node = parent.get_node_or_null("GameWorld/IsoRenderer")
	if not iso_node:
		iso_node = Node2D.new()
		iso_node.name = "IsoRenderer"
		iso_node.set_script(load("res://scripts/iso_renderer.gd"))
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
	
	# 创建建筑信息面板
	_building_info_panel = preload("res://scripts/ui/building_info_panel.gd").new()
	add_child(_building_info_panel)

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
	print("[TEX_LOAD] 尝试加载道路贴图: ", path, " 存在=", ResourceLoader.exists(path))
	if ResourceLoader.exists(path):
		var loaded = load(path)
		print("[TEX_LOAD]   load()成功: ", loaded != null, " 类型=", typeof(loaded) if loaded else "null")
		if loaded:
			var img = loaded.get_image()
			if img and img.get_width() == size * 2 and img.get_height() == size * 2:
				print("[TEX_LOAD]   贴图尺寸匹配: ", img.get_width(), "x", img.get_height())
				return loaded
			elif img:
				print("[TEX_LOAD]   尺寸不匹配: 期望 ", size*2, "x", size*2, " 实际 ", img.get_width(), "x", img.get_height())
	# 回退
	print("[TEX_LOAD]   道路贴图回退→程序生成")
	return _create_road_texture(Color(0.5, 0.5, 0.5), "土路", size)

func _create_road_texture(base_color: Color, road_type: String, size: int) -> Texture2D:
	# 使用 PNG 道路贴图替代程序生成
	var png_file = "road_dirt.png"
	if road_type == "沥青路":
		png_file = "road_asphalt.png"
	elif road_type == "高速路":
		png_file = "road_highway.png"

	var png_path = "res://assets/textures/roads/%s" % png_file
	print("[TEX_LOAD] _create_road_texture 尝试加载: ", png_path, " 存在=", ResourceLoader.exists(png_path))
	if ResourceLoader.exists(png_path):
		var png_img = load(png_path).get_image()
		print("[TEX_LOAD]   load()结果: png_img=", png_img != null, " 尺寸=", png_img.get_width() if png_img else -1, "x", png_img.get_height() if png_img else -1)
		if png_img:
			if png_img.get_width() != size:
				png_img.resize(size, size, Image.INTERPOLATE_NEAREST)
			var result = ImageTexture.create_from_image(png_img)
			print("[TEX_LOAD]   ImageTexture创建成功")
			return result

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

	# 移动模式
	if _move_mode:
		_handle_move_input(event, cell_pos)
		# 移动模式下显示拾起建筑的虚影
		if event is InputEventMouseMotion and _move_source_cell != Vector2i(-1, -1):
			var saved_variant = _current_variant
			_current_variant = _move_source_variant
			_update_ghost_position(cell_pos)
			_current_variant = saved_variant
		return

	# 工具模式
	if _current_tool >= 0 or _current_variant >= 0:
		if _is_press_event(event):
			print("[ROAD] Tool active v=", _current_variant, " t=", _current_tool, " @", cell_pos)
		_handle_tool_input(event, cell_pos)
		# mouse motion 时更新虚影位置
		if event is InputEventMouseMotion and _current_variant >= 0:
			_update_ghost_position(cell_pos)
	elif _is_press_event(event):
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
	if _is_press_event(event):
		print("[ROAD] _handle_tool_input v=", v)
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
		# 防御建筑 (4000~4004)
		4000, 4001, 4002, 4003, 4004:
			_handle_building_placement(event, cell_pos, v)
		# 资源建筑 (5000~5002)
		5000, 5001, 5002:
			_handle_building_placement(event, cell_pos, v)
		# 兵营 (6000~6001)
		6000, 6001:
			_handle_building_placement(event, cell_pos, v)
		202:  # 旋转模式
			if _is_press_event(event):
				_try_rotate_building(cell_pos)
		203:  # 拆除模式
			if _is_press_event(event):
				_try_demolish_building(cell_pos)

func _handle_road_input(event, cell_pos: Vector2i, road_type: int = 0):
	if _is_press_event(event):
		if _is_dragging:
			return  # 防止同一事件重复触发两次 PRESS
		print("[ROAD] PRESS @", cell_pos, " type=", road_type)
		road_system.start_draw(cell_pos, road_type)
		_update_cell_visual(cell_pos.x, cell_pos.y)
		_is_dragging = true
		var road_names = ["土路", "沥青路", "高速路"]
		_show_toast("🛣️ 开始铺设 " + road_names[road_type] + " - 拖拽延伸，松手结束")
	elif _is_release_event(event):
		print("[ROAD] RELEASE drag=", _is_dragging)
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
			# 手动放置的建筑（电厂、农场等）：单次点击移除
			if cell.has_building and cell.building_variant_id >= 0:
				var info = BUILDING_TEXTURES.get(cell.building_variant_id)
				_remove_building_at(cell_pos.x, cell_pos.y)
				_show_toast("已拆除 %s" % (info.label if info else "建筑"))
				return
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
		if not _can_place_building(cell_pos.x, cell_pos.y, variant_id):
			print("该位置不可放置 ", info.label)
			_is_dragging = false
			return

		var cell = grid_map.get_cell(cell_pos.x, cell_pos.y)

		# 检查资金
		if not economy.can_afford(info.cost):
			print("资金不足，无法放置 ", info.label)
			_is_dragging = false
			return

		# 扣费
		economy.spend(info.cost, "建造" + info.label)

		# 工人队列检查
		if worker_sys:
			var build_time = _get_build_time(variant_id, info.cost)
			if not worker_sys.add_to_queue(cell_pos.x, cell_pos.y, variant_id, false, build_time):
				_show_toast("⚠️ 没有空闲工人或队列已满")
				_is_dragging = false
				economy.add_money(info.cost)  # 退款
				return

		# 标记单元格
		cell.has_building = true
		cell.building_level = 1
		cell.building_size_x = 1
		cell.building_size_y = 1
		cell.building_variant_id = variant_id  # 保存 variant_id 用于移动/拆除

		# 防御建筑使用 DefenseTower 子类
		if variant_id >= 4000 and variant_id <= 4004:
			var tower = _create_defense_tower(variant_id, cell_pos)
			if tower:
				building_container.add_child(tower)
				# 阴影
				if iso_renderer and iso_renderer.has_method("create_shadow_sprite"):
					var iso_pos = iso_renderer.grid_to_world(cell_pos.x, cell_pos.y)
					var shadow = iso_renderer.create_shadow_sprite()
					shadow.position = iso_pos
					building_container.add_child(shadow)
				cell.building_ref = tower
		# 资源建筑使用 ResourceBuilding 子类
		elif variant_id >= 5000 and variant_id <= 5002:
			var res_bld = _create_resource_building(variant_id, cell_pos)
			if res_bld:
				building_container.add_child(res_bld)
				# 阴影
				if iso_renderer and iso_renderer.has_method("create_shadow_sprite"):
					var iso_pos = iso_renderer.grid_to_world(cell_pos.x, cell_pos.y)
					var shadow = iso_renderer.create_shadow_sprite()
					shadow.position = iso_pos
					building_container.add_child(shadow)
				cell.building_ref = res_bld
		else:
			# 创建建筑精灵
			var tex_path = "res://assets/textures/buildings/%s.png" % info.texture
			print("[TEX_LOAD] 放置建筑纹理: ", tex_path, " 存在=", ResourceLoader.exists(tex_path))
			if ResourceLoader.exists(tex_path):
				var sprite = Sprite2D.new()
				var loaded_tex = load(tex_path)
				print("[TEX_LOAD]   load()结果: tex=", loaded_tex != null)
				if loaded_tex:
					print("[TEX_LOAD]   纹理尺寸: ", loaded_tex.get_width(), "x", loaded_tex.get_height())
				sprite.texture = loaded_tex
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
				# 保存建筑精灵引用，供移动/拆除模式使用
				cell.building_ref = sprite

		_update_cell_visual(cell_pos.x, cell_pos.y)

		# 放置成功提示
		_show_toast("✅ %s 已建造" % info.label)
		print("放置了 ", info.label, " 在 (", cell_pos.x, ", ", cell_pos.y, ")")

		# 放置成功后清除虚影
		_remove_ghost()

	elif _is_release_event(event):
		_is_dragging = false

## 检查指定位置是否可以放置建筑
func _can_place_building(gx: int, gy: int, variant_id: int) -> bool:
	# 检查格子范围
	if gx < 0 or gx >= GRID_WIDTH or gy < 0 or gy >= GRID_HEIGHT:
		return false
	var cell = grid_map.get_cell(gx, gy)
	if not cell:
		return false
	# 不能放在已有建筑/道路上
	if cell.has_building or cell.terrain == grid_map.TerrainType.ROAD:
		return false
	# 水域和山上不能放
	if cell.natural_terrain in [grid_map.NaturalTerrain.WATER, grid_map.NaturalTerrain.MOUNTAIN]:
		return false
	# 已分区的格子可以放置（覆盖分区）
	return true

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
		print("[TEX_LOAD] 虚影纹理: ", tex_path, " 存在=", ResourceLoader.exists(tex_path))
		if not ResourceLoader.exists(tex_path):
			return
		_ghost_sprite = Sprite2D.new()
		_ghost_sprite.texture = load(tex_path)
		print("[TEX_LOAD] 虚影纹理加载完成: ", _ghost_sprite.texture != null)
		_ghost_sprite.centered = true
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

	# 颜色指示：绿色=可放置，红色=不可放置
	var can_place = _can_place_building(cell_pos.x, cell_pos.y, _current_variant)
	_ghost_sprite.modulate = Color(0, 1, 0, 0.4) if can_place else Color(1, 0, 0, 0.4)

func _remove_ghost():
	if _ghost_sprite:
		_ghost_sprite.queue_free()
		_ghost_sprite = null

## 尝试旋转建筑（点击触发）
func _try_rotate_building(cell_pos):
	var cell = grid_map.get_cell(cell_pos.x, cell_pos.y)
	if not cell or not cell.has_building or not cell.building_ref:
		_show_toast("该位置没有可旋转的建筑")
		return
	if cell.building_ref.has_method("rotate"):
		cell.building_ref.rotate(deg_to_rad(90))
	else:
		cell.building_ref.rotation += deg_to_rad(90)
	_show_toast("建筑已旋转")

## 尝试拆除建筑（点击触发，返还50%资源）
func _try_demolish_building(cell_pos):
	var cell = grid_map.get_cell(cell_pos.x, cell_pos.y)
	if not cell or not cell.has_building or not cell.building_ref:
		_show_toast("该位置没有可拆除的建筑")
		return
	# 返还50%资源
	var refund = 50
	if economy:
		economy.add_money(refund)
		_show_toast("建筑已拆除，返还 " + str(refund))
	# 移除建筑
	if is_instance_valid(cell.building_ref):
		cell.building_ref.queue_free()
	# 清除工人任务
	if worker_sys and worker_sys.has_method("cancel_job"):
		worker_sys.cancel_job(cell_pos.x, cell_pos.y)
	# 清除格子
	cell.has_building = false
	cell.building_ref = null
	cell.building_level = 0
	_update_cell_visual(cell_pos.x, cell_pos.y)

## 切换移动模式
func _toggle_move_mode():
	_move_mode = not _move_mode
	if _move_mode:
		_show_toast("点击一个建筑开始移动")
	else:
		_show_toast("移动模式已关闭")
	_move_source_cell = Vector2i(-1, -1)
	_move_source_variant = -1
	_remove_ghost()

## 处理移动模式输入
func _handle_move_input(event, cell_pos: Vector2i):
	if not _is_press_event(event):
		return

	if _move_source_cell == Vector2i(-1, -1):
		# 第一步：点击源建筑
		var cell = grid_map.get_cell(cell_pos.x, cell_pos.y)
		if cell and cell.has_building and cell.building_variant_id >= 0:
			_move_source_cell = cell_pos
			_move_source_variant = cell.building_variant_id
			_show_toast("已拾起建筑，点击新位置放置")
		else:
			_show_toast("该位置没有可移动的建筑")
	else:
		# 第二步：点击目标位置
		var variant = _move_source_variant
		if _can_place_building(cell_pos.x, cell_pos.y, variant):
			# 检查资金
			var info = BUILDING_TEXTURES.get(variant)
			if info and not economy.can_afford(info.cost):
				_show_toast("资金不足，无法移动")
				_move_source_cell = Vector2i(-1, -1)
				_move_source_variant = -1
				_remove_ghost()
				return

			# 删除旧建筑
			_remove_building_at(_move_source_cell.x, _move_source_cell.y)
			# 扣费并放置新建筑
			if info:
				economy.spend(info.cost, "移动" + info.label)
			_place_building_at(cell_pos.x, cell_pos.y, variant)
			_show_toast("建筑已移动")
		else:
			_show_toast("该位置不可放置")
		_move_source_cell = Vector2i(-1, -1)
		_move_source_variant = -1
		_remove_ghost()

## 在指定位置放置建筑（移动模式用）
func _place_building_at(gx: int, gy: int, variant_id: int):
	if not BUILDING_TEXTURES.has(variant_id):
		return
	var info = BUILDING_TEXTURES[variant_id]
	var cell = grid_map.get_cell(gx, gy)
	if not cell:
		return

	# 标记单元格
	cell.has_building = true
	cell.building_level = 1
	cell.building_size_x = 1
	cell.building_size_y = 1
	cell.building_variant_id = variant_id

	# 防御建筑使用 DefenseTower 子类
	if variant_id >= 4000 and variant_id <= 4004:
		var tower = _create_defense_tower(variant_id, Vector2i(gx, gy))
		if tower:
			building_container.add_child(tower)
			if iso_renderer and iso_renderer.has_method("create_shadow_sprite"):
				var iso_pos = iso_renderer.grid_to_world(gx, gy)
				var shadow = iso_renderer.create_shadow_sprite()
				shadow.position = iso_pos
				building_container.add_child(shadow)
			cell.building_ref = tower
	# 资源建筑使用 ResourceBuilding 子类
	elif variant_id >= 5000 and variant_id <= 5002:
		var res_bld = _create_resource_building(variant_id, Vector2i(gx, gy))
		if res_bld:
			building_container.add_child(res_bld)
			if iso_renderer and iso_renderer.has_method("create_shadow_sprite"):
				var iso_pos = iso_renderer.grid_to_world(gx, gy)
				var shadow = iso_renderer.create_shadow_sprite()
				shadow.position = iso_pos
				building_container.add_child(shadow)
			cell.building_ref = res_bld
	else:
		# 创建建筑精灵
		var tex_path = "res://assets/textures/buildings/%s.png" % info.texture
		print("[TEX_LOAD] _place_building_at(移动模式): ", tex_path, " 存在=", ResourceLoader.exists(tex_path))
		if ResourceLoader.exists(tex_path):
			var sprite = Sprite2D.new()
			var loaded_tex = load(tex_path)
			print("[TEX_LOAD]   移动模式 load()结果: tex=", loaded_tex != null, " 尺寸=", loaded_tex.get_width() if loaded_tex else -1, "x", loaded_tex.get_height() if loaded_tex else -1)
			sprite.texture = loaded_tex
			sprite.centered = true
			if iso_renderer and iso_renderer.has_method("grid_to_world"):
				var iso_pos = iso_renderer.grid_to_world(gx, gy)
				sprite.position = iso_pos
				if iso_renderer.has_method("create_shadow_sprite"):
					var shadow = iso_renderer.create_shadow_sprite()
					shadow.position = iso_pos
					building_container.add_child(shadow)
			else:
				sprite.position = Vector2(
					gx * CELL_SIZE + CELL_SIZE / 2.0,
					gy * CELL_SIZE + CELL_SIZE / 2.0
				)
			sprite.z_index = 5 + gy * 0.01
			sprite.scale = Vector2(0.8, 0.8)
			building_container.add_child(sprite)
			cell.building_ref = sprite

	_update_cell_visual(gx, gy)

## 移除指定位置的建筑
func _remove_building_at(gx: int, gy: int):
	var cell = grid_map.get_cell(gx, gy)
	if not cell:
		return
	# 清除建筑精灵
	if cell.building_ref and is_instance_valid(cell.building_ref):
		cell.building_ref.queue_free()
	cell.has_building = false
	cell.building_ref = null
	cell.building_level = 0
	cell.building_variant_id = -1
	_update_cell_visual(gx, gy)

## 创建防御建筑实例
func _create_defense_tower(variant_id, cell_pos):
	var tower = null
	var iso_pos = iso_renderer.grid_to_world(cell_pos.x, cell_pos.y) if iso_renderer else Vector2(cell_pos.x * CELL_SIZE, cell_pos.y * CELL_SIZE)
	match variant_id:
		4000:
			# 城墙
			tower = preload("res://scripts/defense/wall_building.gd").new()
			tower.position = iso_pos
			tower.setup(cell_pos.x, cell_pos.y, grid_map)
		4001:
			tower = preload("res://scripts/defense/cannon_tower.gd").new()
			tower.position = iso_pos
			tower.setup(cell_pos.x, cell_pos.y, 1)
		4002:
			tower = preload("res://scripts/defense/archer_tower.gd").new()
			tower.position = iso_pos
			tower.setup(cell_pos.x, cell_pos.y, 1)
		4003:
			tower = preload("res://scripts/defense/wizard_tower.gd").new()
			tower.position = iso_pos
			tower.setup(cell_pos.x, cell_pos.y, 1)
		4004:
			tower = preload("res://scripts/defense/mortar_tower.gd").new()
			tower.position = iso_pos
			tower.setup(cell_pos.x, cell_pos.y, 1)
	return tower

## 创建资源建筑实例
func _create_resource_building(variant_id, cell_pos):
	var bld = null
	var iso_pos = iso_renderer.grid_to_world(cell_pos.x, cell_pos.y) if iso_renderer else Vector2(cell_pos.x * CELL_SIZE, cell_pos.y * CELL_SIZE)
	match variant_id:
		5000:
			bld = preload("res://scripts/resources/gold_mine.gd").new()
			bld.position = iso_pos
			bld.setup(cell_pos.x, cell_pos.y, 1)
		5001:
			bld = preload("res://scripts/resources/elixir_collector.gd").new()
			bld.position = iso_pos
			bld.setup(cell_pos.x, cell_pos.y, 1)
		5002:
			bld = preload("res://scripts/resources/storage_building.gd").new()
			bld.position = iso_pos
			bld.setup(cell_pos.x, cell_pos.y, 1)
	return bld

## 更新资源生产（从 ResourceBuilding 收集资源到经济系统）
func _update_resource_production():
	# 遍历建筑容器，找到所有 ResourceBuilding，收集它们的产出
	for child in building_container.get_children():
		if child.has_method("get_collectable_amount") and child.has_method("collect_all"):
			var amount = child.collect_all()
			if amount > 0:
				match child.resource_type:
					"gold":
						economy.add_money(amount)
					"elixir":
						# elixir 暂时作为金钱处理（后续可独立）
						economy.add_money(amount)
					"wood":
						economy.add_wood(amount)
					"stone":
						economy.add_stone(amount)

## 获取所有圣水瓶中可收集的圣水总量
func get_total_elixir():
	var total = 0
	for child in building_container.get_children():
		if child.has_method("get_collectable_amount") and "resource_type" in child and child.resource_type == "elixir":
			total += child.get_collectable_amount()
	return total

## 查找单元格对应的 variant_id
func _get_variant_for_cell(cell) -> int:
	if not cell or not cell.has_building:
		return -1
	# 优先使用保存的 building_variant_id
	if cell.building_variant_id >= 0:
		return cell.building_variant_id
	# 回退：遍历 BUILDING_TEXTURES 查找匹配
	for vid in BUILDING_TEXTURES:
		var info = BUILDING_TEXTURES[vid]
		if cell.terrain == grid_map.TerrainType.ROAD:
			continue
		if cell.has_building and cell.building_level > 0:
			return vid
	return -1

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
	# Shift+点击生成敌人用于测试
	if Input.is_key_pressed(KEY_SHIFT):
		var world_pos = iso_renderer.grid_to_world(cell_pos.x, cell_pos.y) if iso_renderer else Vector2(cell_pos.x * CELL_SIZE, cell_pos.y * CELL_SIZE)
		_spawn_test_enemy(world_pos)
		return

	var cell = grid_map.get_cell(cell_pos.x, cell_pos.y)
	if cell:
		# 高亮显示选中格
		selection_rect.visible = true
		selection_rect.position = grid_map.grid_to_world(cell_pos.x, cell_pos.y)

	if cell and cell.has_building and cell.building_ref:
		info_card.show_building_info(cell_pos, cell)
		# 建筑信息面板（增强版）
		# 资源建筑自动收集
		if cell.building_ref and cell.building_ref.has_method("collect_all"):
			var collected = cell.building_ref.collect_all()
			if collected > 0:
				if cell.building_ref.has_method("resource_type") or ("resource_type" in cell.building_ref):
					var rtype = ""
					if cell.building_ref.has_method("get"):
						pass
					# 默认加入金币
				economy.add_money(collected)
				_show_toast("💰 收集了 " + str(collected) + " 金币")
		# 显示建筑信息
		if _building_info_panel:
			_building_info_panel.show_building_info(cell)
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

	# 单项工具（非连续绘制的）直接关闭子菜单
	if variant_id in [202, 203]:
		_tool_active = true
		if variant_id == 203:
			pass  # 拆除模式 — 点击后保持工具激活

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

	if worker_sys:
		worker_sys.process(delta)
		# 更新建筑上的进度条
		for child in building_container.get_children():
			if child.has_method("update_progress"):
				child.update_progress(worker_sys.get_queue_progress(child._building_cx, child._building_cy))

func _run_sim_tick():
	# 1. 计算 RCI 需求
	_calculate_rci_demand()

	# 2. 建筑生长
	building_system.process_tick()

	# 2.5 资源收集（从 ResourceBuilding 采集资源到经济系统）
	_update_resource_production()

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

# ============ 大本营系统 ============

# 大本营网格位置
const TOWN_HALL_GX := 120
const TOWN_HALL_GY := 80
var _town_hall_pos := Vector2i(-1, -1)  # 实际放置位置

## 寻找适合放置大本营的格子（避开水域/山脉）
func _find_town_hall_pos() -> Vector2i:
	var cx := TOWN_HALL_GX
	var cy := TOWN_HALL_GY
	if not grid_map:
		return Vector2i(cx, cy)
	var search_radius := 30
	for r in range(search_radius):
		for dx in range(-r, r+1):
			for dy in range(-r, r+1):
				var gx = cx + dx
				var gy = cy + dy
				if gx < 2 or gx >= 238 or gy < 2 or gy >= 158:
					continue
				var cell = grid_map.get_cell(gx, gy)
				if cell and cell.natural_terrain == grid_map.NaturalTerrain.GRASS: 
					# 检查周围 2×2 范围是否都是草地
					var all_grass := true
					for sx in range(2):
						for sy in range(2):
							var nc = grid_map.get_cell(gx + sx, gy + sy)
							if not nc or nc.natural_terrain != grid_map.NaturalTerrain.GRASS:
								all_grass = false
								break
						if not all_grass:
							break
					if all_grass:
						return Vector2i(gx, gy)
	return Vector2i(cx, cy)

## 放置大本营（在初始化完成后调用）
func _place_town_hall():
	if not grid_map or not iso_renderer:
		return
	
	# 读取出兵营对应的文明ID
	var global_game = get_node("/root/Main/GlobalGame")
	var civ_id = global_game.current_civ_id if global_game else 0
	var civ_names = ["chinese", "roman", "british", "egyptian", "japanese", "viking"]
	civ_id = clampi(civ_id, 0, 5)
	var civ_name = civ_names[civ_id]
	
	# 使用搜索找到的合适位置
	var th_pos = _find_town_hall_pos()
	var th_gx = th_pos.x
	var th_gy = th_pos.y
	_town_hall_pos = Vector2i(th_gx, th_gy)
	
	# 设置大本营数据
	var cell = grid_map.get_cell(th_gx, th_gy)
	if not cell:
		return
	cell.has_building = true
	cell.building_level = 1
	cell.building_size_x = 2
	cell.building_size_y = 2
	cell.building_variant_id = 9999  # 大本营保留ID
	
	# 清除大本营周围 3×3 区域内已有道路（给大本营留空间）
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var nx = th_gx + dx
			var ny = th_gy + dy
			var nc = grid_map.get_cell(nx, ny)
			if nc and nc.terrain == grid_map.TerrainType.ROAD:
				nc.terrain = grid_map.TerrainType.GRASS
				if iso_renderer and iso_renderer.has_method("clear_road"):
					iso_renderer.clear_road(nx, ny)
	
	# 加载大本营纹理（新路径: civ/l1_v3.png）
	var tex_path = "res://assets/textures/buildings/%s/l1_v3.png" % civ_name
	var texture = null
	var png_path = ProjectSettings.globalize_path(tex_path)
	print("[TEX_LOAD] 大本营 FileAccess加载: ", tex_path)
	print("[TEX_LOAD]   全局路径: ", png_path)
	var file = FileAccess.open(png_path, FileAccess.READ)
	if file:
		var file_size = file.get_length()
		var buffer = file.get_buffer(file_size)
		file.close()
		print("[TEX_LOAD]   文件打开成功, 大小: ", file_size, " 字节")
		var img = Image.new()
		var load_result = img.load_png_from_buffer(buffer)
		print("[TEX_LOAD]   PNG解码: ", load_result == OK, " 结果码=", load_result)
		if load_result == OK:
			print("[TEX_LOAD]   图片尺寸: ", img.get_width(), "x", img.get_height())
			texture = ImageTexture.create_from_image(img)
			print("[TEX_LOAD]   ImageTexture创建: ", texture != null)
	
	if not texture:
		print("[WARN] 大本营纹理不存在: ", tex_path, "，使用默认建筑纹理")
		var fallback_path = "res://assets/textures/buildings/house1.png"
		print("[TEX_LOAD]   尝试回退纹理: ", fallback_path)
		var fb_file = FileAccess.open(ProjectSettings.globalize_path(fallback_path), FileAccess.READ)
		if fb_file:
			var fb_buf = fb_file.get_buffer(fb_file.get_length())
			fb_file.close()
			var fb_img = Image.new()
			if fb_img.load_png_from_buffer(fb_buf) == OK:
				print("[TEX_LOAD]   回退纹理加载成功: ", fb_img.get_width(), "x", fb_img.get_height())
				texture = ImageTexture.create_from_image(fb_img)
	
	if not texture:
		print("[WARN] 默认建筑纹理也不存在")
		return
	
	# 创建精灵
	var sprite = Sprite2D.new()
	sprite.name = "TownHall"
	sprite.texture = texture
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	print("[TEX_LOAD] 大本营精灵纹理已赋值: tex=", texture != null, " 纹理尺寸=", texture.get_width() if texture else -1, "x", texture.get_height() if texture else -1)
	
	# 等距坐标定位
	if iso_renderer and iso_renderer.has_method("grid_to_world"):
		var iso_pos = iso_renderer.grid_to_world(th_gx, th_gy)
		sprite.position = iso_pos
		# 添加阴影
		if iso_renderer.has_method("create_shadow_sprite"):
			var shadow = iso_renderer.create_shadow_sprite()
			shadow.position = iso_pos
			building_container.add_child(shadow)
	
	sprite.z_index = 10 + th_gy * 0.01
	sprite.scale = Vector2(0.45, 0.45)  # 大本营比普通建筑更大更醒目
	
	building_container.add_child(sprite)
	cell.building_ref = sprite
	
	# 通知 GlobalGame 更新大本营位置（供摄像机居中）
	var th_world_pos = iso_renderer.grid_to_world(TOWN_HALL_GX, TOWN_HALL_GY)
	if global_game:
		global_game.town_hall_world_pos = th_world_pos
	
	print("[TOWN_HALL] 大本营已放置: ", civ_name, " L1 @ (", th_gx, ", ", th_gy, ") 世界坐标=", th_world_pos)

## 升级大本营
func upgrade_town_hall():
	if _town_hall_pos.x < 0:
		return
	var cell = grid_map.get_cell(_town_hall_pos.x, _town_hall_pos.y)
	if not cell or not cell.has_building or not cell.building_ref:
		return
	
	var current_level = cell.building_level
	if current_level >= 10:
		_show_toast("🏆 大本营已满级！")
		return
	
	# 获取文明名称
	var global_game = get_node("/root/Main/GlobalGame")
	var civ_names = ["chinese", "roman", "british", "egyptian", "japanese", "viking"]
	var civ_id = clampi(global_game.current_civ_id if global_game else 0, 0, 5)
	var civ_name = civ_names[civ_id]
	
	var new_level = current_level + 1
	var new_tex_path = "res://assets/textures/buildings/%s/l%d_v3.png" % [civ_name, new_level]
	
	# 使用原始 PNG 加载绕过导入缓存
	var new_texture = null
	var new_png_path = ProjectSettings.globalize_path(new_tex_path)
	print("[TEX_LOAD] 大本营升级 FileAccess加载: ", new_tex_path)
	print("[TEX_LOAD]   全局路径: ", new_png_path)
	var new_file = FileAccess.open(new_png_path, FileAccess.READ)
	if new_file:
		var buf = new_file.get_buffer(new_file.get_length())
		new_file.close()
		print("[TEX_LOAD]   文件大小: ", buf.size(), " 字节")
		var nimg = Image.new()
		var load_result = nimg.load_png_from_buffer(buf)
		print("[TEX_LOAD]   PNG解码: ", load_result == OK, " 结果码=", load_result)
		if load_result == OK:
			print("[TEX_LOAD]   图片尺寸: ", nimg.get_width(), "x", nimg.get_height())
			new_texture = ImageTexture.create_from_image(nimg)
			print("[TEX_LOAD]   ImageTexture创建: ", new_texture != null)
	
	if new_texture and is_instance_valid(cell.building_ref):
		cell.building_ref.texture = new_texture
		cell.building_level = new_level
		# 逐级增大比例
		cell.building_ref.scale = Vector2(0.45 + (new_level - 1) * 0.035, 0.45 + (new_level - 1) * 0.035)
		_show_toast("⬆️ 大本营升级到 Lv." + str(new_level))
		print("[TOWN_HALL] 升级到 L", new_level)
	else:
		_show_toast("⚠️ 大本营升级纹理缺失: " + new_tex_path)
		print("[TOWN_HALL] WARN: ", new_tex_path, " 不存在")

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

## 工人回调：建造/升级完成
func _on_worker_job_completed(cx, cy, variant_id, is_upgrade):
	if is_upgrade:
		# 升级完成
		var cell = grid_map.get_cell(cx, cy)
		if cell:
			cell.building_level += 1
			if cell.building_ref and cell.building_ref.has_method("update_level"):
				cell.building_ref.update_level(cell.building_level)
		_show_toast("⬆️ 建筑已升级到 " + str(cell.building_level if cell else "?"))
		# 移除升级进度条
		for child in building_container.get_children():
			if child.has_method("update_progress") and child._building_cx == cx and child._building_cy == cy:
				child.queue_free()
				break
	else:
		# 新建完成 -> 调用现有的 _place_building_at 逻辑
		_show_toast("✅ 建造完成！")
	_full_render()

## 获取建筑的建造时间
func _get_build_time(variant_id, cost):
	# 基础建造时间 = 成本 / 100 秒（上限300秒）
	return clamp(float(cost) / 100.0 * 60.0, 5.0, 300.0)

## 调试：生成测试用敌方单位（多波次）
func _spawn_test_enemy(target_world_pos):
	# 从地图边缘多个位置生成敌人
	var spawn_points = [
		iso_renderer.grid_to_world(0, 0) if iso_renderer else Vector2(0, 0),
		iso_renderer.grid_to_world(120, 0) if iso_renderer else Vector2(3840, 0),
		iso_renderer.grid_to_world(0, 80) if iso_renderer else Vector2(0, 2560),
	]
	for sp in spawn_points:
		var enemy = preload("res://scripts/combat/enemy_unit.gd").new()
		enemy.setup(sp, target_world_pos, 200 + randi() % 100, 5, 50.0 + randi() % 30)
		var game_world = get_parent().get_node("GameWorld") if get_parent().has_node("GameWorld") else null
		if game_world:
			game_world.add_child(enemy)
		else:
			get_parent().add_child(enemy)
	_show_toast("调试敌人 × 3 已生成")

## 按键处理（F2 启动波次战斗）
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F2:
				_start_wave_battle()
			KEY_U:
				upgrade_town_hall()

func _start_wave_battle():
	if not iso_renderer:
		return
	var game_world = get_parent().get_node("GameWorld")
	if not game_world:
		return
	# 在城市中心生成
	var center = iso_renderer.grid_to_world(120, 80)
	var spawner = preload("res://scripts/combat/battle_spawner.gd").new()
	spawner.start_battle(center, game_world, iso_renderer)
	add_child(spawner)
	spawner.connect("battle_completed", Callable(self, "_on_battle_completed"))
	spawner.connect("wave_started", Callable(self, "_on_wave_started"))
	_show_toast("⚔️ 战斗开始！按F2启动波次")

func _on_battle_completed(won, killed, total):
	_show_toast("🏆 战斗结束！消灭 " + str(killed) + "/" + str(total) + " 敌人")

func _on_wave_started(wave_num):
	_show_toast("🌊 第 " + str(wave_num) + " 波敌人来袭！")
