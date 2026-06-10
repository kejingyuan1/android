# WorldCombat.gd — 世界地图战斗管理器
extends Node

const CombatSystem = preload("res://scripts/combat/combat_system.gd")
const ArmyUnit = preload("res://scripts/combat/army_unit.gd")
const TroopData = preload("res://scripts/combat/troop_data.gd")

## 活跃的军队单位列表
var army_units: Array = []
## 当前正在攻击的野怪节点
var current_target: Node = null
## 回调引用
var _global_game: Node = null

## 设置全局游戏控制器引用
func setup(global_game: Node):
	_global_game = global_game

## 从城市派出部队攻击野怪
## city_pos: 城市世界坐标
## creature_node: 野怪精灵节点
## deployment: {troop_type: count, ...} 部署配置
func launch_attack(city_pos: Vector2, creature_node: Node, deployment: Dictionary) -> void:
	if not creature_node or not creature_node.has_meta("creature_data"):
		return
	if _global_game:
		_global_game._show_toast("⚔️ 部队已出发！")
	current_target = creature_node

	# 统计总攻击力和总血量
	var total_attack := 0
	var total_hp := 0
	var total_count := 0
	for troop_type in deployment.keys():
		var count = deployment[troop_type]
		if count <= 0:
			continue
		var stats = TroopData.get_base_stats(troop_type, 1)
		total_attack += stats.get("attack", 10) * count
		total_hp += stats.get("hp", 80)
		total_count += count

	if total_count <= 0:
		return

	# 创建单个军队单位（简化：合并所有兵种为一支军队）
	var unit = ArmyUnit.new()
	unit.troop_type = deployment.keys()[0] if deployment.size() == 1 else TroopData.TroopType.MILITIA
	unit.troop_count = total_count
	unit.speed = 80.0
	add_child(unit)

	# 存储战斗数据到元数据
	unit.set_meta("total_attack", total_attack)
	unit.set_meta("total_hp", total_hp)
	unit.set_meta("total_count", total_count)
	unit.set_meta("creature_node", creature_node)

	unit.connect("reached_target", Callable(self, "_on_unit_reached_target"))

	# 从城市位置出发，向野怪移动
	var creature_pos = creature_node.position
	unit.start_move(city_pos, creature_pos)
	army_units.append(unit)

## 军队到达野怪位置
func _on_unit_reached_target(unit: Node) -> void:
	var creature_node = unit.get_meta("creature_node", null)
	if not creature_node or not creature_node.has_meta("creature_data"):
		_cleanup_unit(unit)
		return

	var creature_data = creature_node.get_meta("creature_data")
	var total_attack = unit.get_meta("total_attack", 10)
	var total_hp = unit.get_meta("total_hp", 80)
	var total_count = unit.get_meta("total_count", 1)
	# 计算野怪攻击力（基于等级）
	var creature_attack = 5 + creature_data.level * 2
	var creature_defense = 2 + creature_data.level

	# 解析战斗
	var result = CombatSystem.resolve_battle(
		total_attack, total_hp, total_count,
		creature_attack, creature_data.hp, creature_defense
	)

	# 显示战斗结果
	var msg = "⚔️ 战斗结果！"
	if result["victory"]:
		msg += " 胜利！"
	else:
		msg += " 失败..."
	msg += " 剩余部队: %d, 部队损失: %d" % [result["surviving_units"], result["army_losses"]]
	msg += " 对野怪造成: %d 伤害" % result["damage_to_creature"]
	if _global_game:
		_global_game._show_toast(msg)

	# 更新野怪血量
	if result["victory"]:
		creature_data.hp = 0
		# 野怪死亡：移除并生成战利品标记
		_on_creature_defeated(creature_node)
	else:
		creature_data.hp = max(1, creature_data.hp - result["damage_to_creature"])
		# 更新野怪精灵显示（效果：闪烁提示受伤）
		_show_creature_hurt(creature_node)

	_cleanup_unit(unit)

## 野怪被击败
func _on_creature_defeated(creature_node: Node) -> void:
	# 生成战利品标记
	_spawn_loot_marker(creature_node.position)
	# 移除野怪精灵
	if creature_node and creature_node.get_parent():
		# 先停止所有动画（避免 tween 报错）
		creature_node.set_meta("creature_data", null)
		creature_node.queue_free()

## 生成战利品标记
func _spawn_loot_marker(pos: Vector2) -> void:
	var marker = Sprite2D.new()
	# 创建发光金色圆圈纹理
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var cx = 8
	var cy = 8
	for y in range(16):
		for x in range(16):
			var dx = x - cx
			var dy = y - cy
			var dist = sqrt(dx * dx + dy * dy)
			if dist < 6:
				img.set_pixel(x, y, Color(1.0, 0.85, 0.2, 0.9))
			elif dist < 8:
				img.set_pixel(x, y, Color(1.0, 0.9, 0.4, 0.4))
	marker.texture = ImageTexture.create_from_image(img)
	marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marker.centered = true
	marker.position = pos
	marker.scale = Vector2(15, 15)
	marker.z_index = 15
	add_child(marker)

	# 脉冲动画
	var tween = marker.create_tween().set_loops()
	tween.tween_property(marker, "scale", Vector2(20, 20), 0.8)
	tween.tween_property(marker, "scale", Vector2(15, 15), 0.8)

	marker.set_meta("is_loot", true)

## 野怪受伤反馈
func _show_creature_hurt(creature_node: Node) -> void:
	if not creature_node:
		return
	var original_modulate = creature_node.modulate
	creature_node.modulate = Color(1.0, 0.3, 0.3)
	var tween = creature_node.create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(Callable(creature_node, "set").bind("modulate", original_modulate))

## 清理军队单位
func _cleanup_unit(unit: Node) -> void:
	army_units.erase(unit)
	if unit and unit.get_parent():
		unit.queue_free()

## 获取所有活跃军队
func get_army_units() -> Array:
	return army_units.duplicate()

## 取消所有攻击
func cancel_all_attacks() -> void:
	for unit in army_units.duplicate():
		_cleanup_unit(unit)
	current_target = null
