# TroopData.gd — 兵种数据定义
# 所有兵种配置、属性曲线
extends RefCounted

## 兵种枚举
enum TroopType {
	MILITIA = 0,    # 民兵
	ARCHER = 1,     # 弓箭手
	CAVALRY = 2,    # 骑兵
	SHIELD = 3,     # 盾兵
	CATAPULT = 4,   # 投石车
	MAGE = 5,       # 法师
}

const TROOP_COUNT := 6

## 获取兵种名称
static func get_troop_name(t: int) -> String:
	match t:
		TroopType.MILITIA:  return "民兵"
		TroopType.ARCHER:   return "弓箭手"
		TroopType.CAVALRY:  return "骑兵"
		TroopType.SHIELD:   return "盾兵"
		TroopType.CATAPULT: return "投石车"
		TroopType.MAGE:     return "法师"
	return "未知"

## 获取兵种描述
static func get_troop_desc(t: int) -> String:
	match t:
		TroopType.MILITIA:  return "基础步兵，攻守均衡"
		TroopType.ARCHER:   return "远程射击，高攻击低防御"
		TroopType.CAVALRY:  return "高速冲锋，擅长突袭"
		TroopType.SHIELD:   return "重装盾兵，防御强悍"
		TroopType.CATAPULT: return "投石车，超远程攻城"
		TroopType.MAGE:     return "法师，范围魔法伤害"
	return ""

## 获取兵种基础属性
## upgrade_level: 兵种升级等级 (1-10, 总等级=兵营等级+兵种升级等级?)
## 返回: {attack, defense, hp, speed, range, attack_speed, cost_gold, cost_wood, cost_stone, unlock_barracks_lv}
static func get_base_stats(t: int, upgrade_lv: int = 1) -> Dictionary:
	var lv = max(1, upgrade_lv)
	var mul = 1.0 + (lv - 1) * 0.3  # 每级提升 30%
	match t:
		TroopType.MILITIA:
			return {
				"attack": int(10 * mul), "defense": int(8 * mul), "hp": int(80 * mul),
				"speed": 60.0, "range": 30, "attack_speed": 1.0,
				"cost_gold": 50 * lv, "cost_wood": 20 * lv, "cost_stone": 10 * lv,
				"unlock_barracks_lv": 1
			}
		TroopType.ARCHER:
			return {
				"attack": int(18 * mul), "defense": int(4 * mul), "hp": int(50 * mul),
				"speed": 50.0, "range": 200, "attack_speed": 0.8,
				"cost_gold": 80 * lv, "cost_wood": 40 * lv, "cost_stone": 15 * lv,
				"unlock_barracks_lv": 2
			}
		TroopType.CAVALRY:
			return {
				"attack": int(15 * mul), "defense": int(6 * mul), "hp": int(70 * mul),
				"speed": 120.0, "range": 30, "attack_speed": 1.2,
				"cost_gold": 100 * lv, "cost_wood": 30 * lv, "cost_stone": 20 * lv,
				"unlock_barracks_lv": 3
			}
		TroopType.SHIELD:
			return {
				"attack": int(6 * mul), "defense": int(20 * mul), "hp": int(150 * mul),
				"speed": 40.0, "range": 25, "attack_speed": 0.7,
				"cost_gold": 60 * lv, "cost_wood": 50 * lv, "cost_stone": 60 * lv,
				"unlock_barracks_lv": 2
			}
		TroopType.CATAPULT:
			return {
				"attack": int(35 * mul), "defense": int(2 * mul), "hp": int(40 * mul),
				"speed": 25.0, "range": 400, "attack_speed": 0.3,
				"cost_gold": 200 * lv, "cost_wood": 100 * lv, "cost_stone": 150 * lv,
				"unlock_barracks_lv": 4
			}
		TroopType.MAGE:
			return {
				"attack": int(25 * mul), "defense": int(3 * mul), "hp": int(45 * mul),
				"speed": 45.0, "range": 150, "attack_speed": 0.6,
				"cost_gold": 150 * lv, "cost_wood": 60 * lv, "cost_stone": 80 * lv,
				"unlock_barracks_lv": 3
			}
	return {}

## 获取兵种贴图路径
static func get_texture_path(t: int) -> String:
	var names = ["militia", "archer", "cavalry", "shield", "catapult", "mage"]
	if t < 0 or t >= names.size():
		t = 0
	return "res://assets/textures/troops/troop_%s.png" % names[t]
