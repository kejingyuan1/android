# LabManager.gd — 实验室兵种升级管理
extends Node

const TroopData = preload("res://scripts/combat/troop_data.gd")

const MAX_LAB_LEVEL := 5
const MAX_TROOP_UPGRADE_LEVEL := 10

## 实验室等级 (1-5)
var lab_level: int = 1

## 兵种升级等级: troop_type → upgrade_level (1-10)
var troop_upgrade_levels: Dictionary = {}

func _ready():
	_init_troop_levels()

func _init_troop_levels():
	troop_upgrade_levels.clear()
	for t in range(TroopData.TROOP_COUNT):
		troop_upgrade_levels[t] = 1

## 获取兵种当前升级等级
func get_troop_level(troop_type: int) -> int:
	return troop_upgrade_levels.get(troop_type, 1)

## 获取实验室升级费用
func get_lab_upgrade_cost() -> Dictionary:
	var lv = lab_level
	return {
		"gold": 3000 * lv,
		"wood": 1500 * lv,
		"stone": 800 * lv,
	}

## 获取兵种升级费用
func get_troop_upgrade_cost(troop_type: int) -> Dictionary:
	var current_lv = get_troop_level(troop_type)
	return {
		"gold": 1000 * current_lv,
		"wood": 300 * current_lv,
		"stone": 200 * current_lv,
	}

## 检查实验室是否可以升级
func can_upgrade_lab(economy: Node) -> bool:
	if lab_level >= MAX_LAB_LEVEL:
		return false
	var cost = get_lab_upgrade_cost()
	return economy.can_afford_resources(cost.gold, cost.wood, cost.stone)

## 执行实验室升级
func do_upgrade_lab(economy: Node) -> bool:
	if lab_level >= MAX_LAB_LEVEL:
		return false
	var cost = get_lab_upgrade_cost()
	if not economy.spend_resources(cost.gold, cost.wood, cost.stone, "实验室升级"):
		return false
	lab_level += 1
	return true

## 检查兵种是否可以升级
## 兵种最高可升级等级 = lab_level * 2
func can_upgrade_troop(troop_type: int, economy: Node) -> bool:
	var current_lv = get_troop_level(troop_type)
	var max_allowed = lab_level * 2
	if current_lv >= min(MAX_TROOP_UPGRADE_LEVEL, max_allowed):
		return false
	var cost = get_troop_upgrade_cost(troop_type)
	return economy.can_afford_resources(cost.gold, cost.wood, cost.stone)

## 执行兵种升级
func do_upgrade_troop(troop_type: int, economy: Node) -> bool:
	var current_lv = get_troop_level(troop_type)
	var max_allowed = lab_level * 2
	if current_lv >= min(MAX_TROOP_UPGRADE_LEVEL, max_allowed):
		return false
	var cost = get_troop_upgrade_cost(troop_type)
	if not economy.spend_resources(cost.gold, cost.wood, cost.stone, "兵种升级"):
		return false
	troop_upgrade_levels[troop_type] = current_lv + 1
	return true

## 获取兵种当前等级属性的描述文本
func get_troop_stats_text(troop_type: int) -> String:
	var lv = get_troop_level(troop_type)
	var stats = TroopData.get_base_stats(troop_type, lv)
	return "攻:%d 防:%d HP:%d 速:%.0f" % [stats.get("attack", 0), stats.get("defense", 0), stats.get("hp", 0), stats.get("speed", 0.0)]

## 获取兵种下一级属性的描述文本（如果未满级）
func get_troop_next_stats_text(troop_type: int) -> String:
	var current_lv = get_troop_level(troop_type)
	var next_lv = current_lv + 1
	var max_allowed = lab_level * 2
	if current_lv >= min(MAX_TROOP_UPGRADE_LEVEL, max_allowed):
		return ""
	var stats = TroopData.get_base_stats(troop_type, next_lv)
	return "→ 攻:%d 防:%d HP:%d 速:%.0f" % [stats.get("attack", 0), stats.get("defense", 0), stats.get("hp", 0), stats.get("speed", 0.0)]

## 重置实验室
func reset():
	lab_level = 1
	_init_troop_levels()
