# GlobalGame.gd — 全局游戏控制器
# 管理超级大地图 + 城市视图之间的切换
# 管理文明选择、世界地图生成、城市放置

extends Node

## 视图状态
enum ViewMode {
	CIV_SELECT = -1,  # 文明选择界面
	WORLD_MAP = 0,    # 超级大地图
	TRANSITION = 1,   # 过渡动画中
	CITY_VIEW = 2,    # 城市微地图
}

## 场景节点路径（在 main.tscn 中设置）
@onready var world_map_layer: Node2D = get_node("../WorldMapLayer")
@onready var city_view_layer: Node2D = get_node("../CityViewLayer")
@onready var ui_canvas: CanvasLayer = get_node("../UICanvas")
@onready var world_camera: Camera2D = get_node("../WorldMapLayer/WorldCamera")
@onready var city_camera: Camera2D = get_node("../CityViewLayer/CityCamera")
@onready var civ_select_ui: Node = get_node("../UICanvas/CivSelectUI")
@onready var loading_screen: Node = get_node("../UICanvas/LoadingScreen")

## 引用
var world_gen = null       # WorldGenerator (RefCounted)
var world_renderer: Node = null  # WorldRenderer (Node2D)
var city_manager: Node = null    # 城市管理器（原 game_manager）
var current_city_data = null     # WorldCityData
var save_manager: Node = null    # SaveManager
# 大本营在城市视图中的世界坐标（由 GameManager 初始化时设置）
var town_hall_world_pos := Vector2(1120, 2960)  # 默认 grid(110,75)→等距世界坐标
var city_popup: Control = null   # 主城弹出菜单
var _loading_show_time: float = 0.0  # 加载画面开始显示的时间戳
const MIN_LOADING_TIME: float = 2.5  # 最短显示时长（秒），确保动画可见

## 加载画面最短显示计时（供 _process 使用）
var _loading_min_timer: float = 0.0
var _loading_wait_done: bool = false

## 状态
var current_view: int = ViewMode.CIV_SELECT
var current_civ_id: int = -1
var _loaded_from_save := false

## 过渡参数
var transition_progress: float = 0.0
var transition_from_pos: Vector2 = Vector2.ZERO
var transition_to_pos: Vector2 = Vector2.ZERO
var transition_from_zoom: float = 1.0
var transition_to_zoom: float = 1.0

## 信号
signal view_changed(new_view: int)

## 战斗系统引用
var _barracks_manager: Node = null    # 兵营管理器
var _world_combat: Node = null        # 世界地图战斗管理器
var _creature_target: Node = null     # 当前选中的野怪节点
var _creature_info_bg: ColorRect = null
var _creature_info_panel: ColorRect = null
var _attack_config_ui: Control = null # 兵力配置界面

const CombatSystem = preload("res://scripts/combat/combat_system.gd")
const ArmyUnit = preload("res://scripts/combat/army_unit.gd")
const WorldCombat = preload("res://scripts/world_map/world_combat.gd")
const AttackConfigUI = preload("res://scripts/ui/attack_config_ui.gd")
const TroopData = preload("res://scripts/combat/troop_data.gd")

func _ready():
	# 预热 GPU 渲染管线：让世界地图提前可见 + 激活世界相机
	# 此时 Sprite2D 无贴图（空渲染），但 Godot 会编译 Sprite2D 的 Vulkan shader
	# 否则首次 make_current + sprite.texture 触发着色器编译会阻塞主线程 14 秒
	world_map_layer.visible = true
	world_camera.make_current()

	# 初始化存档管理器
	save_manager = Node.new()
	save_manager.set_script(preload("res://scripts/save_manager.gd"))
	add_child(save_manager)

	# 初始状态：显示文明选择（会隐藏世界地图）
	_show_civ_select()

	# 连接文明选择信号
	if civ_select_ui:
		civ_select_ui.connect("civilization_selected", Callable(self, "on_civilization_selected"))

func _process(delta):
	# 自动存档
	if save_manager and save_manager.has_method("update"):
		save_manager.update(delta)
	
	# 加载最短显示计时器
	if _loading_min_timer > 0.0:
		_loading_min_timer -= delta
		if _loading_min_timer <= 0.0:
			_loading_min_timer = 0.0
			_loading_wait_done = true
	
	# 直接驱动加载画面云朵动画（绕过 loading_screen._process 不工作的问题）
	if loading_screen and loading_screen.visible:
		var clouds = loading_screen.get("_clouds")
		if clouds:
			for c in clouds:
				var node = c["node"]
				node.position.x += c["dir"] * c["speed"] * delta
				if c["dir"] > 0 and node.position.x > 1400:
					node.position.x = -150
				elif c["dir"] < 0 and node.position.x < -150:
					node.position.x = 1400
			# 调试：每隔约15帧打印一朵云的位置 + 时间戳
			if Engine.get_frames_drawn() % 15 == 0:
				print("【T=", Time.get_ticks_msec(), " Cloud】云朵[0] x=", clouds[0]["node"].position.x)

## 获取当前城市数据（供 SaveManager 使用）
func get_current_city_data():
	return current_city_data

## 文明被选中
func on_civilization_selected(civ_id: int):
	current_civ_id = civ_id
	print("【T=", Time.get_ticks_msec(), "】选择了文明: ", WorldCityData.get_civilization_name(civ_id))
	print("【T=", Time.get_ticks_msec(), "】civ_select_ui 存在: ", civ_select_ui != null)
	call_deferred("_show_loading_transition", civ_id)

var _loading_layer: CanvasLayer = null  # 独立加载层，layer=100 确保覆盖一切

func _show_loading_transition(civ_id: int):
	print("【T=", Time.get_ticks_msec(), "】_show_loading_transition 开始")
	
	# 删除文明选择界面
	if civ_select_ui and civ_select_ui.get_parent():
		civ_select_ui.get_parent().remove_child(civ_select_ui)
		civ_select_ui.queue_free()
		civ_select_ui = null
	
	# 隐藏底部工具栏
	var bottom_bar = ui_canvas.get_node_or_null("BottomBar")
	if bottom_bar:
		bottom_bar.visible = false
	
	await get_tree().process_frame
	
	# 预置世界地图可见（此时 world_map 尚未添加子节点，瞬间完成）
	# 避免 _switch_to_world_view 时突然可见导致主线程阻塞 10 秒
	world_map_layer.visible = true
	city_view_layer.visible = false
	
	# 显示加载过场动画（云朵由 loading_screen._process 自行驱动）
	if loading_screen and loading_screen.has_method("show_loading"):
		loading_screen.show_loading()
		ui_canvas.move_child(loading_screen, ui_canvas.get_child_count() - 1)
		_loading_show_time = Time.get_ticks_msec() / 1000.0
		_loading_min_timer = MIN_LOADING_TIME
		_loading_wait_done = false
		print("【T=", Time.get_ticks_msec(), "】加载画面已显示，最短等 ", MIN_LOADING_TIME, " 秒")

	print("【T=", Time.get_ticks_msec(), "】开始世界生成...")
	call_deferred("_start_world_generation", civ_id)

func _remove_loading_layer():
	# 等待 _process 中的最短显示计时器归零（确保即使缓存命中也能看到动画）
	while not _loading_wait_done:
		await get_tree().process_frame
	print("【T=", Time.get_ticks_msec(), "】最短显示时间已到，隐藏加载画面")
	if loading_screen and loading_screen.has_method("hide_loading"):
		await loading_screen.hide_loading()

## 生成进度回调
func _on_gen_progress(pct: float):
	if loading_screen and loading_screen.has_method("update_progress"):
		loading_screen.update_progress(pct)

## 开始世界生成（在加载画面显示后触发）
func _start_world_generation(civ_id: int):
	# 初始化城市弹出菜单
	if not city_popup:
		var popup_script = load("res://scripts/world_map/city_popup.gd")
		city_popup = popup_script.new() as Control
		ui_canvas.add_child(city_popup)
		city_popup.enter_city_pressed.connect(_on_popup_enter_city)
		city_popup.move_city_pressed.connect(_on_popup_move_city)

	# 连接 world_renderer 的进度信号→加载画面
	world_renderer = world_map_layer.get_node("WorldRenderer")
	if world_renderer and world_renderer.has_signal("generation_progress"):
		if not world_renderer.is_connected("generation_progress", Callable(self, "_on_gen_progress")):
			world_renderer.connect("generation_progress", Callable(self, "_on_gen_progress"))
		else:
			# 断开旧连接重新连（防止重复连接）
			world_renderer.disconnect("generation_progress", Callable(self, "_on_gen_progress"))
			world_renderer.connect("generation_progress", Callable(self, "_on_gen_progress"))

	# 等一帧让加载画面渲染出来
	await get_tree().process_frame

	# 检查是否有存档
	var save_data = null
	if save_manager and save_manager.has_method("load_save_data"):
		save_data = save_manager.load_save_data()

	if save_data and save_data.get("version", 0) >= 2 and save_data.get("civilization_id", -1) == civ_id:
		# 有存档 → 从存档恢复
		_loaded_from_save = true
		print("找到存档，正在恢复游戏...")
		await _load_from_save_data(save_data)
	else:
		# 无存档 → 新游戏
		_loaded_from_save = false
		await _start_new_world()

## 从存档恢复
func _load_from_save_data(data: Dictionary):
	var seed_val = data.get("world_seed", randi())
	var civ_id = data.get("civilization_id", current_civ_id)

	# 创建世界生成器
	world_gen = WorldGenerator.new(seed_val)
	current_civ_id = civ_id

	# 渲染世界地图（异步，await 完成）
	if world_renderer and world_renderer.has_method("generate"):
		await world_renderer.generate(world_gen)

	# 恢复城市数据
	var wx = data.get("city_world_x", 50000)
	var wy = data.get("city_world_y", 50000)
	var city_name = data.get("city_name", WorldCityData.get_civilization_name(civ_id) + "城")
	current_city_data = WorldCityData.new(1, city_name, wx, wy, civ_id)
	print("【T=", Time.get_ticks_msec(), "】WorldCityData 创建完成")

	# 放置城市标记
	if world_renderer and world_renderer.has_method("place_city_marker"):
		print("【T=", Time.get_ticks_msec(), "】开始 place_city_marker")
		world_renderer.place_city_marker(wx, wy, civ_id, city_name)
		print("【T=", Time.get_ticks_msec(), "】place_city_marker 完成")

	# 切换到世界地图视图
	print("【T=", Time.get_ticks_msec(), "】开始 _switch_to_world_view")
	_switch_to_world_view()
	print("【T=", Time.get_ticks_msec(), "】_switch_to_world_view 完成")

	# 摄像机入场动画（含最短加载等待）+ 资源标记并行
	var intro_tween = await _start_camera_intro(Vector2(wx, wy))
	if world_renderer and world_renderer.has_method("show_resource_markers"):
		world_renderer.show_resource_markers(wx, wy, 30)
	if world_renderer and world_renderer.has_method("spawn_ocean_fish"):
		world_renderer.spawn_ocean_fish(wx, wy, 30)
	await intro_tween.finished
	print("存档恢复完成")

	# 保存存档数据给城市管理器后续使用
	set_meta("save_city_data", data)

	print("存档恢复完成")

## 开始新世界（新游戏）
func _start_new_world():
	# 从持久化文件读取种子，确保世界地图缓存跨会话可用
	var seed_val = _load_world_seed()
	if seed_val < 0:
		seed_val = randi()
		_save_world_seed(seed_val)
		print("生成新世界种子: ", seed_val)
	else:
		print("使用持久化种子: ", seed_val)

	world_gen = WorldGenerator.new(seed_val)
	print("【T=", Time.get_ticks_msec(), "】WorldGenerator 创建完成")

	# 渲染世界地图（异步，await 完成）
	if world_renderer and world_renderer.has_method("generate"):
		await world_renderer.generate(world_gen)

	print("【T=", Time.get_ticks_msec(), "】generate 完成, 开始检查出生点缓存")
	# 检查出生点缓存，避免每次重新扫描 15 秒
	var cache_path = _get_start_pos_path(seed_val)
	print("【T=", Time.get_ticks_msec(), "】缓存路径=", cache_path, " 存在=", FileAccess.file_exists(cache_path))
	var start_pos = _load_start_pos(seed_val)
	if start_pos.x < 0:
		print("【T=", Time.get_ticks_msec(), "】缓存未命中, 开始扫描出生点(约15秒)...")
		start_pos = world_gen.get_start_position()
		print("【T=", Time.get_ticks_msec(), "】扫描完成, 保存缓存")
		_save_start_pos(seed_val, start_pos)
	else:
		print("【T=", Time.get_ticks_msec(), "】出生点缓存命中:", start_pos)
	print("【T=", Time.get_ticks_msec(), "】出生点: (", start_pos.x, ", ", start_pos.y, ")")

	# 创建城市数据
	var city_name = WorldCityData.get_civilization_name(current_civ_id) + "城"
	current_city_data = WorldCityData.new(1, city_name, start_pos.x, start_pos.y, current_civ_id)
	print("【T=", Time.get_ticks_msec(), "】WorldCityData 创建完成")

	# 判断是否沿海
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var nx = start_pos.x + dx * 100
			var ny = start_pos.y + dy * 100
			if nx >= 0 and nx < 100000 and ny >= 0 and ny < 100000:
				var t = world_gen.get_terrain(nx, ny)
				if t == 0 or t == 1:  # ocean
					current_city_data.is_coastal = true
					break
		if current_city_data.is_coastal:
			break
	print("【T=", Time.get_ticks_msec(), "】沿海检查完成, is_coastal=", current_city_data.is_coastal)

	# 岛屿检查（有缓存则跳过 12 秒 BFS）
	var island_cached = _load_island_cache(seed_val)
	if island_cached != null:
		current_city_data.is_island_city = island_cached
		print("【T=", Time.get_ticks_msec(), "】岛屿缓存命中: ", island_cached)
	else:
		current_city_data.is_island_city = world_gen.is_island(start_pos.x, start_pos.y)
		print("【T=", Time.get_ticks_msec(), "】岛屿检查完成, is_island=", current_city_data.is_island_city)
		_save_island_cache(seed_val, current_city_data.is_island_city)

	# 计算资源加成
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var rx = start_pos.x + dx
			var ry = start_pos.y + dy
			if rx >= 0 and rx < 100000 and ry >= 0 and ry < 100000:
				var r = world_gen.get_resource(rx, ry)
				if r != 0:
					var key = str(r)
					current_city_data.resource_bonuses[key] = current_city_data.resource_bonuses.get(key, 0) + 1

	print("【T=", Time.get_ticks_msec(), "】资源计算完成")

	# 放置城市标记（在动画前完成，让用户第一时间看到城市位置）
	if world_renderer and world_renderer.has_method("place_city_marker"):
		world_renderer.place_city_marker(start_pos.x, start_pos.y, current_civ_id, city_name)

	# 切换到世界地图视图
	_switch_to_world_view()

	# 摄像机入场动画（含最短加载等待）+ 资源标记生成并行执行
	var intro_tween = await _start_camera_intro(Vector2(start_pos.x, start_pos.y))
	# 动画期间异步生成资源标记
	if world_renderer and world_renderer.has_method("show_resource_markers"):
		world_renderer.show_resource_markers(start_pos.x, start_pos.y, 30)
	# 生成海洋游鱼
	if world_renderer and world_renderer.has_method("spawn_ocean_fish"):
		world_renderer.spawn_ocean_fish(start_pos.x, start_pos.y, 30)
	# 等入场动画结束
	await intro_tween.finished
	print("摄像机入场动画完成")

func _switch_to_world_view():
	print("【T=", Time.get_ticks_msec(), "】_switch_to_world_view 世界地图可见")
	world_map_layer.visible = true
	city_view_layer.visible = false
	# 城市工具栏在世界地图隐藏
	var bottom_bar = ui_canvas.get_node_or_null("BottomBar")
	if bottom_bar:
		bottom_bar.visible = false
	# 重置相机拖拽状态，防止残留导致卡死
	world_camera._dragging = false
	world_camera._velocity = Vector2.ZERO
	world_camera.make_current()
	current_view = ViewMode.WORLD_MAP
	emit_signal("view_changed", current_view)

#	# 摄像机入场动画：从远视图拉近到城市位置
func _start_camera_intro(city_pos: Vector2):
	# 从城市位置的远视图开始 → 拉近到城市周边
	world_camera.position = city_pos
	world_camera.zoom = Vector2(0.0008, 0.0008)
	# 禁用位置钳制，避免 _clamp_position 在动画过程中拉回世界中心
	world_camera.set_clamp_enabled(false)

	# 先确保最短加载时间已到，再淡出
	await _remove_loading_layer()

	# 缩放 Tween：从全图拉近到城市区域（16000×9000 世界单位）
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(world_camera, "zoom", Vector2(0.08, 0.08), 1.2)
	tween.tween_callback(Callable(world_camera, "set_clamp_enabled").bind(true))
	return tween

## 进入城市视图（点击主城时调用）— 含淡入过场动画
func enter_city_view():
	if not current_city_data:
		return

	print("进入城市视图: ", current_city_data.city_name)
	current_view = ViewMode.TRANSITION

	# 淡入黑色过渡遮罩
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 1)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.name = "TransitionOverlay"
	ui_canvas.add_child(overlay)
	# 移到最上层确保覆盖所有 UI
	ui_canvas.move_child(overlay, ui_canvas.get_child_count() - 1)

	# 等待一帧让遮罩渲染
	await get_tree().process_frame

	# 在黑色遮罩下切换视图
	world_map_layer.visible = false
	city_view_layer.visible = true
	# 显示城市工具栏
	var bottom_bar = ui_canvas.get_node_or_null("BottomBar")
	if bottom_bar:
		bottom_bar.visible = true
	city_camera.make_current()

	# 强制隐藏平面渲染图层，确保只显示等距视图
	var game_world = city_view_layer.get_node_or_null("GameWorld")
	if game_world:
		var flat_grid = game_world.get_node_or_null("GridRenderer")
		if flat_grid: flat_grid.visible = false
		var flat_road = game_world.get_node_or_null("RoadMap")
		if flat_road: flat_road.visible = false
		var flat_zone = game_world.get_node_or_null("ZoneMap")
		if flat_zone: flat_zone.visible = false
		var flat_hl = game_world.get_node_or_null("HighlightMap")
		if flat_hl: flat_hl.visible = false

	# 计算城市视图的中心坐标和初始缩放
	# 使用大本营位置作为中心点，而非地图几何中心
	var city_center_x = town_hall_world_pos.x
	var city_center_y = town_hall_world_pos.y
	city_camera.position = Vector2(city_center_x, city_center_y)
	# 从较近的视图开始 → 拉近到大本营（避免初始时大量空白）
	city_camera.zoom = Vector2(0.22, 0.22)
	# 禁用边界钳制，避免动画过程中被拉回
	if city_camera.has_method("set_clamp_enabled"):
		city_camera.set_clamp_enabled(false)
	
	# 缩放动画：从近处拉近到大本营周边
	var zoom_tween = create_tween()
	zoom_tween.set_ease(Tween.EASE_IN_OUT)
	zoom_tween.set_trans(Tween.TRANS_SINE)
	zoom_tween.tween_property(city_camera, "zoom", Vector2(0.55, 0.55), 1.2)
	if city_camera.has_method("set_clamp_enabled"):
		zoom_tween.tween_callback(Callable(city_camera, "set_clamp_enabled").bind(true))

	# 初始化城市管理器
	if not city_manager:
		city_manager = city_view_layer.get_node("GameManager")
		_init_city_manager()

	# 如果有存档的城市数据，传给 city_manager
	if _loaded_from_save:
		var save_data = get_meta("save_city_data", {})
		var grid_data = save_data.get("grid", null) if save_data else null
		if grid_data and city_manager and city_manager.has_method("load_from_save_data"):
			city_manager.load_from_save_data(grid_data, save_data.get("money", 500000.0))

	# 设置自动存档的引用
	if save_manager and city_manager:
		var city_grid = city_manager.get_node_or_null("grid_map")
		var city_economy = city_manager.get_node_or_null("economy")
		var city_building = city_manager.get_node_or_null("building_system")
		var city_road = city_manager.get_node_or_null("road_system")
		if city_grid and city_economy:
			save_manager.setup(city_grid, city_economy, city_building, city_road, self)

	# 淡入：从黑色过渡到城市视图
	var tween = create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0), 0.6)
	await tween.finished

	overlay.queue_free()

	current_view = ViewMode.CITY_VIEW
	emit_signal("view_changed", current_view)
	print("城市视图过渡完成")

## 返回世界地图（点击时间图标时调用）— 含淡出过场动画
func exit_to_world_map():
	if not current_city_data:
		return

	print("返回世界地图")
	current_view = ViewMode.TRANSITION

	# 淡入黑色过渡遮罩
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.name = "TransitionOverlay"
	ui_canvas.add_child(overlay)
	ui_canvas.move_child(overlay, ui_canvas.get_child_count() - 1)

	# 淡入到黑色
	var tween_in = create_tween()
	tween_in.tween_property(overlay, "color", Color(0, 0, 0, 1), 0.3)
	await tween_in.finished

	# 在黑色遮罩下切换
	city_view_layer.visible = false
	world_map_layer.visible = true
	# 重置相机状态
	world_camera._dragging = false
	world_camera._velocity = Vector2.ZERO
	world_camera.make_current()

	# 回到主城位置
	world_camera.position = Vector2(current_city_data.world_x, current_city_data.world_y)
	world_camera.zoom = Vector2(0.003, 0.003)

	# 淡出遮罩
	var tween_out = create_tween()
	tween_out.tween_property(overlay, "color", Color(0, 0, 0, 0), 0.4)
	await tween_out.finished

	overlay.queue_free()

	current_view = ViewMode.WORLD_MAP
	emit_signal("view_changed", current_view)
	print("返回世界地图完成")

## 初始化城市管理器（已有的 game_manager 功能）
func _init_city_manager():
	# 城市管理器是 CityViewLayer 下的 GameManager 节点
	city_manager = city_view_layer.get_node("GameManager")
	if city_manager and city_manager.has_method("_ready"):
		# 应用文明加成
		if current_city_data:
			var bonuses = WorldCityData.get_civilization_bonuses(current_civ_id)
			city_manager.set_meta("civilization_id", current_civ_id)
			city_manager.set_meta("civilization_bonuses", bonuses)

## 主城弹出菜单 → 进入主城
func _on_popup_enter_city():
	enter_city_view()

## 主城弹出菜单 → 移动主城（预留）
func _on_popup_move_city():
	print("进入移动主城模式")
	_start_move_city_mode()

var _move_mode := false
var _move_highlight: Node2D = null
var _pending_move_pos := Vector2.ZERO
var _has_pending_move := false
var _dialog_active := false  # 对话框打开时阻止地图操作
var _click_markers: Array = []  # 临时点击位置标记
const MOVE_HALF_SIZE := 3000  # 高亮框半宽（世界单位）

func _start_move_city_mode() -> void:
	if not current_city_data or not world_renderer:
		return
	_move_mode = true

	var cx = current_city_data.world_x
	var cy = current_city_data.world_y
	var h = MOVE_HALF_SIZE

	# 方法1：Sprite2D 方式生成绿色边框纹理
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var col = Color(0.0, 1.0, 0.2, 0.9)
	# 用 4 层不同透明度的绿色叠加，让边框更醒目
	var border_colors = [
		Color(0.0, 1.0, 0.2, 0.9),
		Color(0.0, 0.9, 0.3, 0.7),
		Color(0.0, 1.0, 0.2, 0.5),
		Color(0.2, 1.0, 0.4, 0.3),
	]
	for layer in 4:
		var bw = layer + 2  # 边框宽度从 2→5
		for y in range(64):
			for x in range(64):
				var edge_x = x < bw or x >= 64 - bw
				var edge_y = y < bw or y >= 64 - bw
				if edge_x or edge_y:
					var px_color = img.get_pixel(x, y)
					img.set_pixel(x, y, border_colors[layer] if px_color.a < 0.01 else px_color)

	# 在四个角画出 L 形标记（让边框在某些方向更粗）
	# 左上角
	for dy in range(16):
		for dx in range(16):
			if dx < 4 or dy < 4:
				img.set_pixel(dx, dy, col)

	# 右上角
	for dy in range(16):
		for dx in range(48, 64):
			if dx >= 60 or dy < 4:
				img.set_pixel(dx, dy, col)

	# 左下角
	for dy in range(48, 64):
		for dx in range(16):
			if dx < 4 or dy >= 60:
				img.set_pixel(dx, dy, col)

	# 右下角
	for dy in range(48, 64):
		for dx in range(48, 64):
			if dx >= 60 or dy >= 60:
				img.set_pixel(dx, dy, col)

	var tex = ImageTexture.create_from_image(img)
	var sprite = Sprite2D.new()
	sprite.name = "MoveHighlight"
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.position = Vector2(cx, cy)
	sprite.scale = Vector2(h * 2 / 64.0, h * 2 / 64.0)
	sprite.z_index = 100
	sprite.modulate = Color(0.0, 1.0, 0.2, 0.85)
	world_renderer.add_child(sprite)
	_move_highlight = sprite

	# 四个角落的发光点
	var corner_positions = [
		Vector2(cx - h, cy - h),
		Vector2(cx + h, cy - h),
		Vector2(cx - h, cy + h),
		Vector2(cx + h, cy + h),
	]
	for i in range(4):
		var dot = Sprite2D.new()
		dot.name = "MoveCorner" + str(i)
		var dot_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		dot_img.fill(Color(0.0, 1.0, 0.2, 1.0))
		dot.texture = ImageTexture.create_from_image(dot_img)
		dot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		dot.centered = true
		dot.position = corner_positions[i]
		dot.scale = Vector2(10, 10)
		dot.z_index = 101
		world_renderer.add_child(dot)

	# 脉动动画让边框更醒目
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "modulate", Color(0.0, 1.0, 0.2, 0.3), 0.8)
	tween.tween_property(sprite, "modulate", Color(0.0, 1.0, 0.2, 0.9), 0.8)

	print("提示：点击地图上的空地来放置主城，右键/Esc 取消")

func _cancel_move_city_mode() -> void:
	_move_mode = false
	if _move_highlight:
		_move_highlight.queue_free()
		_move_highlight = null
	# 清理四个角落的发光点
	if world_renderer:
		for child in world_renderer.get_children():
			if child.name.begins_with("MoveCorner"):
				child.queue_free()
	# 清理所有临时点击标记
	for marker in _click_markers:
		if marker and marker.get_parent():
			marker.queue_free()
	_click_markers.clear()
	_has_pending_move = false
	print("取消移动主城")

func _confirm_move_city(world_pos: Vector2) -> void:
	if not _move_mode or not current_city_data or not world_renderer:
		return

	# 检查目标位置是否是陆地
	if not world_gen or not world_gen.is_land(int(world_pos.x), int(world_pos.y)):
		_show_click_marker(world_pos, false)  # 红色虚影标记失败位置
		_show_toast("❌ 目标位置不是陆地，无法放置主城")
		return

	# 检查是否与当前位置太近
	var dx = abs(world_pos.x - current_city_data.world_x)
	var dy = abs(world_pos.y - current_city_data.world_y)
	if dx < 100 and dy < 100:
		_show_click_marker(world_pos, false)  # 红色虚影标记失败位置
		_show_toast("📍 目标位置与当前主城太近")
		return

	# 记录待移动位置，弹出确认框
	_has_pending_move = true
	_pending_move_pos = world_pos
	_show_click_marker(world_pos, true)  # 绿色虚影标识目标位置
	_show_confirm_dialog("确定将主城移动到指定位置？", _execute_move_city)

func _execute_move_city() -> void:
	if not _has_pending_move or not current_city_data or not world_renderer:
		_has_pending_move = false
		return

	var world_pos = _pending_move_pos
	_has_pending_move = false

	# 移除旧的城市标记
	var old_key = str(current_city_data.world_x) + "," + str(current_city_data.world_y)
	if world_renderer.city_sprites.has(old_key):
		var old_marker = world_renderer.city_sprites[old_key]
		old_marker.queue_free()
		world_renderer.city_sprites.erase(old_key)

	# 更新城市数据
	current_city_data.world_x = int(world_pos.x)
	current_city_data.world_y = int(world_pos.y)

	# 在新的位置放城市标记
	var city_name = current_city_data.city_name
	world_renderer.place_city_marker(int(world_pos.x), int(world_pos.y), current_civ_id, city_name)

	# 清理移动模式
	_cancel_move_city_mode()
	_show_toast("✅ 主城已移动到新位置")

## 在屏幕中心显示浮动提示（Toast）
func _show_toast(msg: String) -> void:
	var label = Label.new()
	label.text = msg
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 半透明背景
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.size = Vector2(400, 50)
	bg.position = Vector2(
		(get_viewport().get_visible_rect().size.x - 400) * 0.5,
		get_viewport().get_visible_rect().size.y * 0.25
	)
	bg.add_child(label)
	label.position = Vector2(0, 0)
	label.size = bg.size
	ui_canvas.add_child(bg)
	# 3 秒后自动消失
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(bg, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(bg.queue_free)

## 在点击位置显示临时标记（虚影），2 秒后自动消失
func _show_click_marker(world_pos: Vector2, is_valid: bool) -> void:
	if not world_renderer:
		return

	# 创建圆形标记纹理：有效=绿色半透明，无效=红色半透明
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var col = Color(0.0, 1.0, 0.2, 0.6) if is_valid else Color(1.0, 0.2, 0.2, 0.6)
	var cx = 16
	var cy = 16
	for y in range(32):
		for x in range(32):
			var dx = x - cx
			var dy = y - cy
			var dist = sqrt(dx * dx + dy * dy)
			if dist < 14:
				img.set_pixel(x, y, col)
			elif dist < 16:
				img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * 0.5))

	# 圈圈：半透明外环
	for angle in range(0, 360, 15):
		var rad = deg_to_rad(angle)
		var rx = cx + cos(rad) * 10
		var ry = cy + sin(rad) * 10
		# 画一个小亮块模拟虚线圆
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var px = int(rx + dx)
				var py = int(ry + dy)
				if px >= 0 and px < 32 and py >= 0 and py < 32:
					var c = img.get_pixel(px, py)
					img.set_pixel(px, py, Color(col.r, col.g, col.b, min(c.a + 0.4, 1.0)))

	var tex = ImageTexture.create_from_image(img)
	var marker = Sprite2D.new()
	marker.texture = tex
	marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marker.centered = true
	marker.position = world_pos
	marker.scale = Vector2(20, 20)  # 640×640 世界单位
	marker.z_index = 150
	world_renderer.add_child(marker)
	_click_markers.append(marker)

	# 2 秒后自动消失（淡出 0.5s）
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(marker, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(Callable(self, "_remove_click_marker").bind(marker))

func _remove_click_marker(marker: Node2D) -> void:
	if marker and marker.get_parent():
		marker.queue_free()
	_click_markers.erase(marker)

## 显示确认对话框
func _show_confirm_dialog(msg: String, on_confirm: Callable) -> void:
	_dialog_active = true

	# 半透明遮罩，阻止后方点击 + 提供居中锚点
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.3)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.name = "ConfirmBG"
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_canvas.add_child(bg)

	# 对话框面板（通过 PRESET_CENTER 自动居中）
	var panel = Panel.new()
	panel.name = "ConfirmDialogPanel"
	panel.custom_minimum_size = Vector2(340, 140)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	bg.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var lbl = Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(lbl)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(hbox)

	var confirm_btn = Button.new()
	confirm_btn.text = "✅ 确认"
	confirm_btn.custom_minimum_size = Vector2(120, 36)
	confirm_btn.pressed.connect(func():
		_dialog_active = false
		bg.queue_free()
		on_confirm.call()
	)
	hbox.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "❌ 取消"
	cancel_btn.custom_minimum_size = Vector2(120, 36)
	cancel_btn.pressed.connect(func():
		_dialog_active = false
		bg.queue_free()
		_has_pending_move = false
		_pending_move_pos = Vector2.ZERO
	)
	hbox.add_child(cancel_btn)

	get_viewport().set_input_as_handled()

## 显示野怪信息面板
func _show_creature_info(world_pos: Vector2, data) -> void:
	# 清除旧的野怪面板（防止重复叠加）
	if _creature_info_bg:
		_creature_info_bg.queue_free()
		_creature_info_bg = null
	if _creature_info_panel:
		_creature_info_panel.queue_free()
		_creature_info_panel = null

	var habitat_name = "🌊 海洋" if data.habitat == 0 else "🌿 陆地"
	var type_names = ["鱼龙", "水母精", "海星怪", "海马龙"] if data.habitat == 0 else ["飞翼鸟"]

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.35)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.name = "CreatureInfoBG"
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_canvas.add_child(bg)
	_creature_info_bg = bg

	var panel = ColorRect.new()
	panel.color = Color(0.08, 0.08, 0.15, 0.95)
	panel.size = Vector2(320, 280)
	var vp = get_viewport().get_visible_rect().size
	panel.position = Vector2((vp.x - 320) * 0.5, (vp.y - 280) * 0.3)
	ui_canvas.add_child(panel)
	_creature_info_panel = panel

	var title = Label.new()
	title.text = "⚔️ 野生 " + type_names[data.sprite_type % type_names.size()]
	title.position = Vector2(12, 8)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	panel.add_child(title)

	var info_lines = [
		"栖地: " + habitat_name,
		"等级: Lv.%d" % data.level,
		"血量: %d/%d" % [data.hp, data.max_hp],
		"攻击性: %.1f" % (data.aggression * 100) + "%",
		"速度: %.0f" % data.speed,
		"",
		"威胁度: " + "⚠️".repeat(min(5, max(1, data.level / 6 + 1))),
	]

	var y = 36
	for line in info_lines:
		var lbl = Label.new()
		lbl.text = line
		lbl.position = Vector2(14, y)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
		panel.add_child(lbl)
		y += 20

	# 捕获本地引用，通过元数据传递，避免闭包捕获陷阱
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(260, 8)
	close_btn.custom_minimum_size = Vector2(50, 24)
	close_btn.set_meta("target_bg", bg)
	close_btn.set_meta("target_panel", panel)
	close_btn.pressed.connect(_on_close_creature_info.bind(close_btn))
	panel.add_child(close_btn)

	var attack_btn = Button.new()
	attack_btn.text = "⚔️ 派兵攻击"
	attack_btn.position = Vector2(60, y + 10)
	attack_btn.custom_minimum_size = Vector2(200, 40)
	attack_btn.add_theme_color_override("font_color", Color(0, 0, 0))
	attack_btn.add_theme_color_override("font_hover_color", Color(0, 0, 0))
	attack_btn.add_theme_stylebox_override("normal", _make_btn_style(Color(1, 0.7, 0.1)))
	attack_btn.add_theme_stylebox_override("hover", _make_btn_style(Color(1, 0.8, 0.3)))
	attack_btn.set_meta("target_bg", bg)
	attack_btn.set_meta("target_panel", panel)
	attack_btn.pressed.connect(_on_attack_creature)
	panel.add_child(attack_btn)

## 关闭野怪信息面板
func _on_close_creature_info(btn: Button) -> void:
	var bg = btn.get_meta("target_bg") as ColorRect
	var panel = btn.get_meta("target_panel") as ColorRect
	if bg and bg.get_parent():
		bg.queue_free()
	if panel and panel.get_parent():
		panel.queue_free()
	_creature_info_bg = null
	_creature_info_panel = null

## 攻击野怪
func _on_attack_creature() -> void:
	if _creature_info_bg and _creature_info_bg.get_parent():
		_creature_info_bg.queue_free()
		_creature_info_bg = null
	if _creature_info_panel and _creature_info_panel.get_parent():
		_creature_info_panel.queue_free()
		_creature_info_panel = null
	if _creature_target and _creature_target.has_meta("creature_data") and world_renderer:
		var cdata = _creature_target.get_meta("creature_data")
		_show_attack_config_ui(cdata, _creature_target)

## 创建按钮样式
func _make_btn_style(bg_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _input(event):
	if current_view == ViewMode.WORLD_MAP:
		# 移动主城模式下：Escape 或 鼠标右键取消
		if _move_mode:
			if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
				_cancel_move_city_mode()
				get_viewport().set_input_as_handled()
				return
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_move_city_mode()
				get_viewport().set_input_as_handled()
				return
		_handle_world_input(event)

func _handle_world_input(event):
	# 确认对话框打开时，不处理任何地图交互
	if _dialog_active:
		return

	# 移动主城模式：左键点击空地 → 放置
	if _move_mode and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos = _screen_to_world(event.position)
		if world_pos:
			_confirm_move_city(world_pos)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 如果弹出菜单已打开，不处理地图点击（由 CityPopup 自己处理点击关闭）
		if city_popup and city_popup.is_showing():
			return
		# 点击世界地图 → 检测是否点到城市或野怪
		var world_pos = _screen_to_world(event.position)
		if world_pos:
			# 检测野怪点击（优先级高于城市）
			var creature_node = world_renderer.get_creature_at(world_pos.x, world_pos.y) if world_renderer else null
			if creature_node and creature_node.has_meta("creature_data"):
				get_viewport().set_input_as_handled()
				var data = creature_node.get_meta("creature_data")
				_creature_target = creature_node  # 记录选中的野怪
				_show_creature_info(creature_node.position, data)
				return
			# 检测城市点击
			var city_key = world_renderer.get_city_at(world_pos.x, world_pos.y) if world_renderer else null
			if city_key and current_city_data:
				# 显示城市弹出菜单，并消耗事件阻止相机开始拖拽
				get_viewport().set_input_as_handled()
				city_popup.show_at(Vector2(current_city_data.world_x, current_city_data.world_y), current_city_data.city_name)
			else:
				# 点击空白处关闭弹出菜单
				if city_popup:
					city_popup.dismiss()

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var viewport = get_viewport()
	if not viewport:
		return Vector2.ZERO
	var cam = viewport.get_camera_2d()
	if not cam:
		return Vector2.ZERO
	var center = viewport.get_visible_rect().size / 2.0
	var world_center = cam.get_screen_center_position()
	return world_center + (screen_pos - center) / cam.zoom

## 显示文明选择界面
func _show_civ_select():
	world_map_layer.visible = false
	city_view_layer.visible = false
	if civ_select_ui:
		civ_select_ui.visible = true
	current_view = ViewMode.CIV_SELECT
	emit_signal("view_changed", current_view)

## 持久化世界种子到文件（确保世界地图缓存跨会话可用）
const SEED_FILE := "user://world_seed.dat"

func _save_world_seed(seed_val: int) -> void:
	var f = FileAccess.open(SEED_FILE, FileAccess.WRITE)
	if f:
		f.store_32(seed_val)
		f.close()

func _load_world_seed() -> int:
	if not FileAccess.file_exists(SEED_FILE):
		return -1
	var f = FileAccess.open(SEED_FILE, FileAccess.READ)
	if not f:
		return -1
	var val = f.get_32()
	f.close()
	return val

## 持久化出生点到文件（避免每次缓存命中后重新扫描 15 秒）
func _get_start_pos_path(seed_val: int) -> String:
	return "user://start_pos_%d.dat" % seed_val

func _save_start_pos(seed_val: int, pos: Vector2i) -> void:
	var f = FileAccess.open(_get_start_pos_path(seed_val), FileAccess.WRITE)
	if f:
		f.store_32(pos.x)
		f.store_32(pos.y)
		f.close()

func _load_start_pos(seed_val: int) -> Vector2i:
	var path = _get_start_pos_path(seed_val)
	if not FileAccess.file_exists(path):
		return Vector2i(-1, -1)
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return Vector2i(-1, -1)
	var x = f.get_32()
	var y = f.get_32()
	f.close()
	return Vector2i(x, y)

## 岛屿分析缓存（完成后保存到独立文件，避免 12 秒重新 BFS）
func _get_island_cache_path(seed_val: int) -> String:
	return "user://island_%d.dat" % seed_val

var _island_cache: Dictionary = {}

func _save_island_cache(seed_val: int, is_island: bool) -> void:
	var f = FileAccess.open(_get_island_cache_path(seed_val), FileAccess.WRITE)
	if f:
		f.store_8(1 if is_island else 0)
		f.close()

func _load_island_cache(seed_val: int) -> Variant:
	var path = _get_island_cache_path(seed_val)
	if not FileAccess.file_exists(path):
		return null
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return null
	var val = f.get_8()
	f.close()
	return val == 1

# ========== 战斗系统 ==========

## 获取或初始化兵营管理器
func _get_barracks_manager() -> Node:
	if _barracks_manager:
		return _barracks_manager
	# 尝试从城市视图层寻找兵营管理器
	if city_manager:
		# 检查 GameManager 下是否有 barracks_manager 子节点
		for child in city_manager.get_children():
			if child is Node:
				var script_path = ""
				if child.get_script():
					script_path = child.get_script().get_path() if child.get_script().has_method("get_path") else ""
				if "barracks_manager" in child.name.to_lower() or "barracks_manager" in script_path:
					_barracks_manager = child
					return _barracks_manager
		# 未找到，创建一个
		var bm = Node.new()
		bm.set_script(preload("res://scripts/combat/barracks_manager.gd"))
		city_manager.add_child(bm)
		_barracks_manager = bm
	return _barracks_manager

## 获取或初始化世界战斗管理器
func _get_world_combat() -> Node:
	if _world_combat:
		return _world_combat
	var wc = Node.new()
	wc.set_script(WorldCombat)
	wc.setup(self)
	world_renderer.add_child(wc)
	_world_combat = wc
	return _world_combat

## 显示兵力配置界面
func _show_attack_config_ui(data, creature_node: Node):
	if _attack_config_ui:
		_attack_config_ui.queue_free()
		_attack_config_ui = null

	_creature_target = creature_node

	_attack_config_ui = AttackConfigUI.new()
	var bm = _get_barracks_manager()
	_attack_config_ui.setup(data, bm)

	# 定位到屏幕中央
	var vp = get_viewport().get_visible_rect().size
	_attack_config_ui.position = Vector2((vp.x - 340) * 0.5, (vp.y - 380) * 0.25)
	_attack_config_ui.attack_confirmed.connect(_on_attack_confirmed)
	_attack_config_ui.cancelled.connect(_close_attack_config_ui)
	ui_canvas.add_child(_attack_config_ui)

## 关闭兵力配置界面
func _close_attack_config_ui():
	if _attack_config_ui:
		_attack_config_ui.queue_free()
		_attack_config_ui = null

## 攻击确认回调
func _on_attack_confirmed(deployment: Dictionary):
	_close_attack_config_ui()
	if not _creature_target or not current_city_data:
		return
	var city_pos = Vector2(current_city_data.world_x, current_city_data.world_y)
	var combat = _get_world_combat()
	combat.launch_attack(city_pos, _creature_target, deployment)
	_creature_target = null

## 直接请求派兵攻击（供外部调用）
func request_attack(creature_node: Node, deployment: Dictionary) -> void:
	if not creature_node or not current_city_data:
		return
	var city_pos = Vector2(current_city_data.world_x, current_city_data.world_y)
	var combat = _get_world_combat()
	combat.launch_attack(city_pos, creature_node, deployment)
