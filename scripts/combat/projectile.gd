# Projectile.gd — 防御塔发射的投射物
extends Node2D

var speed = 300.0
var target = null
var damage = 0

func setup(from_pos, target_node, dmg, spd = 300.0):
    position = from_pos
    target = target_node
    damage = dmg
    speed = spd
    # 黄色小圆点视觉
    var dot = ColorRect.new()
    dot.color = Color(1, 0.8, 0.2, 1)
    dot.size = Vector2(6, 6)
    dot.position = Vector2(-3, -3)
    add_child(dot)

func _process(delta):
    if not is_instance_valid(target):
        queue_free()
        return
    # 飞向目标
    var dir = (target.position - position).normalized()
    position += dir * speed * delta
    # 到达目标
    if position.distance_to(target.position) < 15.0:
        if is_instance_valid(target) and target.has_method("take_damage"):
            target.take_damage(damage)
        # 击中特效
        _create_hit_effect()
        queue_free()

func _create_hit_effect():
    # 简单爆炸光晕
    var flash = ColorRect.new()
    flash.color = Color(1, 0.6, 0.1, 0.8)
    flash.size = Vector2(12, 12)
    flash.position = position - Vector2(6, 6)
    get_parent().add_child(flash)
    var tween = create_tween()
    tween.tween_property(flash, "modulate", Color(1, 1, 1, 0), 0.2)
    tween.tween_callback(flash.queue_free)
