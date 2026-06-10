# BarracksData.gd — 单次部队部署配置（每名玩家）
extends RefCounted

# 当前部署配置: troop_type → 部署数量
var deployment: Dictionary = {}

func set_troop(t: int, count: int):
	deployment[t] = max(0, count)

func get_troop(t: int) -> int:
	return deployment.get(t, 0)

func get_total_count() -> int:
	var sum = 0
	for v in deployment.values():
		sum += v
	return sum

func clear():
	deployment.clear()
