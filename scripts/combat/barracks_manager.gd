# BarracksManager.gd — 兵营状态管理
extends Node

const TroopData = preload("res://scripts/combat/troop_data.gd")

const MAX_LEVEL := 5
const BASE_UPGRADE_COST_GOLD := 5000
const BASE_UPGRADE_COST_WOOD := 2000
const BASE_UPGRADE_COST_STONE := 1000

var barracks_level: int = 1

# 当前兵营内各兵种等待部署的数量: troop_type → 数量
var troop_count: Dictionary = {}

func _ready():
	_clear_troops()

## 检查兵种是否已解锁
func is_troop_unlocked(troop_type: int) -> bool:
	var stats = TroopData.get_base_stats(troop_type, 1)
	if stats.is_empty():
		return false
	return barracks_level >= stats.get("unlock_barracks_lv", 999)

## 获取兵营升级费用
func get_upgrade_cost() -> Dictionary:
	var lv = barracks_level
	return {
		"gold": BASE_UPGRADE_COST_GOLD * lv,
		"wood": BASE_UPGRADE_COST_WOOD * lv,
		"stone": BASE_UPGRADE_COST_STONE * lv,
	}

## 执行升级
func do_upgrade() -> bool:
	if barracks_level >= MAX_LEVEL:
		return false
	# 这里不直接扣除资源，由调用方（UI/GameManager）处理经济
	barracks_level += 1
	return true

## 添加兵种到兵营
func add_troops(troop_type: int, amount: int):
	var current = troop_count.get(troop_type, 0)
	troop_count[troop_type] = current + max(0, amount)

## 消耗兵种（部署时调用）
func consume_troops(troop_type: int, amount: int) -> bool:
	var current = troop_count.get(troop_type, 0)
	if current < amount:
		return false
	troop_count[troop_type] = current - amount
	return true

## 获取兵营中某兵种总数
func get_troop_count(troop_type: int) -> int:
	return troop_count.get(troop_type, 0)

## 获取所有兵种总数
func get_total_troops() -> int:
	var sum = 0
	for v in troop_count.values():
		sum += v
	return sum

## 清空兵营
func _clear_troops():
	troop_count.clear()
	for t in range(TroopData.TROOP_COUNT):
		troop_count[t] = 0

## 重置兵营到初始状态
func reset():
	barracks_level = 1
	_clear_troops()
