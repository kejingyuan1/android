extends "res://scripts/defense/defense_tower.gd"

func _ready():
    tower_name = "迫击炮"
    damage = 60
    attack_range = 350.0
    attack_speed = 4.0
    min_range = 80.0

func _get_texture_name():
    return "mortar"

func _filter_close_targets():
    targets_in_range = targets_in_range.filter(func(t):
        return is_instance_valid(t) and position.distance_to(t.position) > min_range
    )

func _try_attack():
    _filter_close_targets()
    # 调用基类方法
    if targets_in_range.size() == 0:
        return
    # 选目标
    var target = targets_in_range[0]
    var min_dist = INF
    for t in targets_in_range:
        var d = position.distance_squared_to(t.position)
        if d < min_dist:
            min_dist = d
            target = t
    _fire_at(target)

func _fire_at(target):
    if target.has_method("take_damage"):
        target.take_damage(damage)
        # AoE 溅射
        for t in targets_in_range:
            if t != target and is_instance_valid(t):
                var dist = t.position.distance_to(target.position)
                if dist < 80.0:
                    var splash = max(1, int(damage * 0.4))
                    if t.has_method("take_damage"):
                        t.take_damage(splash)
