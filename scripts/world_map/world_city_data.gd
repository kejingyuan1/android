# WorldCityData.gd — 世界地图上的城市数据
class_name WorldCityData
extends RefCounted

## 城市状态
enum CityStatus {
	FOUNDED = 0,    # 刚建立
	DEVELOPING = 1, # 发展中
	PROSPEROUS = 2, # 繁荣
}

## 城市数据
var city_id: int
var city_name: String
var world_x: int           # 世界地图坐标
var world_y: int
var civilization_id: int   # 0=中国 1=罗马 2=英国 3=埃及 4=日本 5=维京
var status: int = CityStatus.FOUNDED

## 城市属性
var is_coastal: bool = false   # 沿海城市（有港口功能）
var is_island_city: bool = false  # 岛屿城市

## 资源加成（基于世界地图位置）
var resource_bonuses: Dictionary = {}

func _init(id: int, name: String, wx: int, wy: int, civ_id: int):
	city_id = id
	city_name = name
	world_x = wx
	world_y = wy
	civilization_id = civ_id

## 文明配置
static func get_civilization_name(civ_id: int) -> String:
	match civ_id:
		0: return "中国"
		1: return "罗马"
		2: return "英国"
		3: return "埃及"
		4: return "日本"
		5: return "维京"
	return "未知"

static func get_civilization_icon(civ_id: int) -> String:
	match civ_id:
		0: return "🏮"
		1: return "🏛️"
		2: return "🏰"
		3: return "🕌"
		4: return "⛩️"
		5: return "⛵"
	return "❓"

## 文明特色产品
static func get_special_products(civ_id: int) -> Array:
	match civ_id:
		0: return ["丝绸", "瓷器"]
		1: return ["大理石建材", "葡萄酒"]
		2: return ["纺织品", "工业机械"]
		3: return ["纸莎草", "香料"]
		4: return ["漆器", "武士刀"]
		5: return ["木材", "毛皮"]
	return []

## 文明特性加成
static func get_civilization_bonuses(civ_id: int) -> Dictionary:
	match civ_id:
		0: return {"population_growth": 0.15, "culture": 0.2}
		1: return {"build_speed": 0.15, "road_efficiency": 0.2}
		2: return {"industrial_output": 0.2, "trade_income": 0.15}
		3: return {"agriculture": 0.25, "mountain_resources": 0.3}
		4: return {"fishing": 0.3, "island_bonus": 0.25}
		5: return {"shipping_speed": 0.25, "exploration": 0.3}
	return {}
