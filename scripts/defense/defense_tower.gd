# DefenseTower.gd — 防御塔基类（Area2D检测+Timer攻击）
extends Node2D

# 可配置属性（子类覆盖）
var tower_name = "防御塔"
var damage = 10
var attack_range = 200.0
var attack_speed = 1.0
var min_range = 0.0

# 运行时状态
var cell_x = 0
var cell_y = 0
var level = 1
var targets_in_range = []
var _sprite = null
var _detection = null
var _attack_timer = null

func setup(gx, gy, lv = 1):
    cell_x = gx
    cell_y = gy
    level = lv
    # 精灵
    _sprite = Sprite2D.new()
    _sprite.texture = load("res://assets/textures/buildings/" + _get_texture_name() + ".png")
    _sprite.centered = true
    _sprite.z_index = 5
    add_child(_sprite)
    # 检测区域
    _detection = Area2D.new()
    var col = CollisionShape2D.new()
    var shape = CircleShape2D.new()
    shape.radius = attack_range
    col.shape = shape
    _detection.add_child(col)
    add_child(_detection)
    # 攻击计时器
    _attack_timer = Timer.new()
    _attack_timer.wait_time = attack_speed
    _attack_timer.one_shot = false
    _attack_timer.timeout.connect(_try_attack)
    add_child(_attack_timer)
    _attack_timer.start()
    # 连接信号
    _detection.body_entered.connect(_on_enemy_entered)
    _detection.body_exited.connect(_on_enemy_exited)

func _get_texture_name():
    return "cannon"  # 子类覆盖

func _on_enemy_entered(body):
    if body.is_in_group("enemies") and not targets_in_range.has(body):
        targets_in_range.append(body)

func _on_enemy_exited(body):
    targets_in_range.erase(body)

func _try_attack():
    # 清理无效目标
    targets_in_range = targets_in_range.filter(func(t): return is_instance_valid(t))
    if targets_in_range.size() == 0:
        return
    # 选最近目标
    var target = targets_in_range[0]
    var min_dist = INF
    for t in targets_in_range:
        var d = position.distance_squared_to(t.position)
        if d < min_dist:
            min_dist = d
            target = t
    _fire_at(target)

func _fire_at(target):
    # 发射投射物
    var proj = preload("res://scripts/combat/projectile.gd").new()
    proj.setup(position, target, damage, 300.0)
    get_parent().add_child(proj)
