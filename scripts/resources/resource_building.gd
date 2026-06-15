# ResourceBuilding.gd — 资源生产建筑基类
extends Node2D

# 可配置
var building_name = "资源建筑"
var production_rate = 1.0     # 每秒产量
var storage_capacity = 1000   # 最大存储
var resource_type = "gold"    # gold / elixir / wood / stone

# 运行时
var cell_x = 0
var cell_y = 0
var level = 1
var stored_amount = 0.0
var _sprite = null
var _production_timer = null

signal resources_updated()

func setup(gx, gy, lv = 1):
    cell_x = gx
    cell_y = gy
    level = lv
    # 等级加成：每级 +25% 产量和容量
    var level_mult = 1.0 + (level - 1) * 0.25
    var actual_production = production_rate * level_mult
    var actual_capacity = storage_capacity * level_mult
    
    # 精灵
    _sprite = Sprite2D.new()
    _sprite.texture = load("res://assets/textures/buildings/" + _get_texture_name() + ".png")
    _sprite.centered = true
    _sprite.z_index = 5
    add_child(_sprite)
    
    # 生产计时器（每5秒产出一批）
    _production_timer = Timer.new()
    _production_timer.wait_time = 5.0
    _production_timer.one_shot = false
    _production_timer.timeout.connect(_on_produce)
    add_child(_production_timer)
    _production_timer.start()
    # 加入资源建筑组，供敌人 AI 识别
    add_to_group("resource_buildings")

func _get_texture_name():
    return "gold_mine"  # 子类覆盖

func _on_produce():
    # 每5秒生产 amount 资源（不超过容量）
    var level_mult = 1.0 + (level - 1) * 0.25
    var amount = production_rate * 5.0 * level_mult
    stored_amount = min(stored_amount + amount, storage_capacity * level_mult)
    emit_signal("resources_updated")

func collect_all():
    var amount = int(stored_amount)
    stored_amount = 0
    emit_signal("resources_updated")
    return amount

func get_collectable_amount():
    return int(stored_amount)

func get_capacity():
    var level_mult = 1.0 + (level - 1) * 0.25
    return int(storage_capacity * level_mult)

func get_production_per_sec():
    var level_mult = 1.0 + (level - 1) * 0.25
    return production_rate * level_mult
