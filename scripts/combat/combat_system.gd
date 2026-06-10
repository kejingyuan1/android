# CombatSystem.gd — 核心战斗逻辑
extends RefCounted

## 计算伤害：攻击力 * (1 - 防御 / (防御 + 100))
static func calc_damage(attack: int, defense: int) -> int:
	var reduction = float(defense) / (float(defense) + 100.0)
	return max(1, int(float(attack) * (1.0 - reduction)))

## 解析一支军队与一只野怪的战斗
## 返回: {victory, surviving_units, damage_to_creature, creature_damage_to_army, army_losses}
static func resolve_battle(army_attack: int, army_hp: int, army_count: int,
						  creature_attack: int, creature_hp: int, creature_defense: int) -> Dictionary:
	var total_army_hp = army_hp * army_count
	var damage_per_hit = calc_damage(army_attack, creature_defense)
	var hits_to_kill = ceil(float(creature_hp) / float(max(1, damage_per_hit)))
	var creature_damage = calc_damage(creature_attack, 5)  # 军队基础防御 5
	var damage_to_army = creature_damage * hits_to_kill
	var losses = ceil(float(damage_to_army) / float(max(1, army_hp)))
	losses = min(losses, army_count)
	return {
		"victory": hits_to_kill <= 10,  # 10回合内击杀即胜利
		"damage_to_creature": damage_per_hit * hits_to_kill,
		"creature_damage_to_army": damage_to_army,
		"army_losses": losses,
		"surviving_units": army_count - losses
	}
