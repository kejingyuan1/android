# SaveManager.gd — 全局存档系统 v2
# 保存世界地图种子 + 文明 + 城市数据
# JSON 持久化到本地文件

extends Node

const SAVE_VERSION := 2
const SAVE_FILE := "user://skyline_lite_save.json"
const AUTOSAVE_INTERVAL := 30.0  # 秒

## 被引用的系统（由 GlobalGame 设置引用关系）
var _grid_map: Node = null
var _economy: Node = null
var _building_system: Node = null
var _road_system: Node = null
var _global_game: Node = null

var _autosave_timer: float = 0.0
var _save_enabled := false  # 仅在初始化完成后启用

signal save_completed
signal load_completed
signal load_failed(reason: String)

## 初始化引用（由 GlobalGame 调用）
func setup(grid_map: Node, economy: Node, building_system: Node, road_system: Node, global_game: Node = null):
	_grid_map = grid_map
	_economy = economy
	_building_system = building_system
	_road_system = road_system
	_global_game = global_game
	_save_enabled = true

## 每帧更新自动存档计时器
func update(delta: float):
	if not _save_enabled:
		return
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game()

## 保存游戏
func save_game() -> bool:
	if not _save_enabled:
		return false
	var data = _serialize()
	var json_str = JSON.stringify(data, "\t")
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if not file:
		push_error("无法打开存档文件进行写入: ", SAVE_FILE)
		return false
	file.store_string(json_str)
	file.close()
	emit_signal("save_completed")
	return true

## 检查是否有存档
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_FILE)

## 加载存档（返回数据，由 GlobalGame 直接处理）
func load_save_data():
	if not FileAccess.file_exists(SAVE_FILE):
		return null

	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if not file:
		return null

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_err = json.parse(json_str)
	if parse_err != OK:
		return null

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return null

	return data

## 序列化
func _serialize() -> Dictionary:
	var result = {
		"version": SAVE_VERSION,
	}

	# ===== 世界地图数据 =====
	if _global_game:
		var current_city_data = _global_game.current_city_data if _global_game.has_method("get_current_city_data") else null
		if current_city_data:
			result["world_seed"] = _global_game.world_gen.world_seed if _global_game.world_gen else 0
			result["civilization_id"] = current_city_data.civilization_id
			result["city_world_x"] = current_city_data.world_x
			result["city_world_y"] = current_city_data.world_y
			result["city_name"] = current_city_data.city_name

	# ===== 城市数据 =====
	if _grid_map and _economy:
		result["money"] = _economy.money

		# 网格数据
		var grid_data = []
		for y in range(_grid_map.GRID_HEIGHT):
			var row = []
			for x in range(_grid_map.GRID_WIDTH):
				var cell = _grid_map.get_cell(x, y)
				if cell:
					row.append({
						"terrain": cell.terrain,
						"road_type": cell.road_type if "road_type" in cell else 0,
						"reachable": cell.reachable,
						"zone_connected": cell.zone_connected,
						"has_building": cell.has_building,
						"building_level": cell.building_level,
						"building_size_x": cell.building_size_x if "building_size_x" in cell else 1,
						"building_size_y": cell.building_size_y if "building_size_y" in cell else 1,
					})
				else:
					row.append(null)
			grid_data.append(row)
		result["grid"] = grid_data

	return result
