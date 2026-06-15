extends "res://scripts/resources/resource_building.gd"

func _ready():
    building_name = "圣水瓶"
    production_rate = 1.5     # 每秒1.5圣水
    storage_capacity = 1500
    resource_type = "elixir"

func _get_texture_name():
    return "elixir_collector"
