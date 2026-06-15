# EnemyUnit.gd — 可攻击的敌方单位
extends Node2D

var hp = 200
var max_hp = 200
var defense = 5
var speed = 60.0  # 像素/秒
var target_pos = Vector2.ZERO
var alive = true
var _attack_target = Vector2.ZERO

func _ready():
	add_to_group("enemies")

func setup(start_pos, target, h = 200, d = 5, sp = 60.0):
	position = start_pos
	target_pos = target
	hp = h
	max_hp = h
	defense = d
	speed = sp
	alive = true

func take_damage(dmg):
	if not alive:
		return
	hp -= dmg
	# 显示伤害数字
	var dn = preload("res://scripts/combat/damage_number.gd").new()
	dn.show(position, dmg)
	get_parent().add_child(dn)
	if hp <= 0:
		die()

func die():
	alive = false
	# 死亡效果
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0, 0, 0), 0.3)
	tween.tween_callback(queue_free)

func _process(delta):
	if not alive:
		return
	if target_pos == Vector2.ZERO:
		return
	# 寻找攻击目标
	if _attack_target == Vector2.ZERO or position.distance_to(_attack_target) < 10.0:
		_find_new_target()
	# 向目标移动
	if _attack_target != Vector2.ZERO:
		var dir = (_attack_target - position).normalized()
		position += dir * speed * delta
	else:
		var dir = (target_pos - position).normalized()
		position += dir * speed * delta
	# 到达目标
	if position.distance_to(target_pos) < 10.0:
		_on_reach_target()

func _find_new_target():
	# 查找最近的防御建筑或资源建筑
	var nearest = null
	var min_dist = INF
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child.is_in_group("defense_towers") or child.is_in_group("resource_buildings"):
				var d = position.distance_squared_to(child.position)
				if d < min_dist:
					min_dist = d
					nearest = child
	if nearest:
		_attack_target = nearest.position

func _on_reach_target():
	# 到达目标后自爆/攻击建筑（简化版）
	die()
