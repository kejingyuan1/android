# EnemyUnit.gd — 可攻击的敌方单位
extends Node2D

var hp = 200
var max_hp = 200
var defense = 5
var speed = 60.0  # 像素/秒
var target_pos = Vector2.ZERO
var alive = true

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
    # 向目标移动
    var dir = (target_pos - position).normalized()
    position += dir * speed * delta
    # 到达目标
    if position.distance_to(target_pos) < 10.0:
        _on_reach_target()

func _on_reach_target():
    # 到达目标后自爆/攻击建筑（简化版）
    die()
