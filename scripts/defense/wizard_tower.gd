extends "res://scripts/defense/defense_tower.gd"

func _ready():
    tower_name = "法师塔"
    damage = 30
    attack_range = 150.0
    attack_speed = 2.5

func _get_texture_name():
    return "wizard_tower"

# AOE溅射
func _fire_at(target):
    if target.has_method("take_damage"):
        target.take_damage(damage)
        # 对附近所有敌人造成50%溅射
        for t in targets_in_range:
            if t != target and is_instance_valid(t):
                var dist = t.position.distance_to(target.position)
                if dist < 50.0:
                    var splash = max(1, damage / 2)
                    if t.has_method("take_damage"):
                        t.take_damage(splash)
