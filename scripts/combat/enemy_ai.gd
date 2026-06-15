# EnemyAI.gd — 敌人进攻AI（找到最优目标）
class_name EnemyAI
extends RefCounted

# 给定所有建筑列表和敌人位置，返回要攻击的目标位置
static func find_target(enemy_pos, buildings):
    var best_target = null
    var best_score = -INF
    
    for bld in buildings:
        if not is_instance_valid(bld):
            continue
        var score = _rate_target(enemy_pos, bld)
        if score > best_score:
            best_score = score
            best_target = bld
    
    return best_target.position if best_target else Vector2.ZERO

static func _rate_target(enemy_pos, building):
    var score = 0.0
    var dist = enemy_pos.distance_to(building.position)
    
    # 距离越近分数越高
    score += max(0, 500 - dist)
    
    # 优先攻击防御塔（基于z_index判断或类名）
    if building.is_in_group("defense_towers"):
        score += 300
    elif building.is_in_group("resource_buildings"):
        score += 200
    
    return score
