extends "res://scripts/resources/resource_building.gd"

func _ready():
    building_name = "金矿"
    production_rate = 2.0     # 每秒2金币
    storage_capacity = 2000   # 存储2000
    resource_type = "gold"

func _get_texture_name():
    return "gold_mine"
