# DamageNumber.gd — 飘浮伤害数字
extends Node2D

func show_damage(world_pos, amount, color = Color(1, 0.3, 0.3, 1)):
    position = world_pos
    var label = Label.new()
    label.text = "-" + str(amount)
    label.add_theme_color_override("font_color", color)
    label.add_theme_font_size_override("font_size", 18)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
    label.add_theme_constant_override("shadow_outline_size", 1)
    label.position = Vector2(-20, -10)
    add_child(label)
    # 动画：向上飘+渐隐
    var tween = create_tween()
    tween.set_parallel()
    tween.tween_property(self, "position", position + Vector2(0, -30), 0.8)
    tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.8)
    tween.tween_callback(queue_free)
