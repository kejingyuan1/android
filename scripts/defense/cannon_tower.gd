extends "res://scripts/defense/defense_tower.gd"

func _ready():
    tower_name = "加农炮"
    damage = 50
    attack_range = 150.0
    attack_speed = 1.5

func _get_texture_name():
    return "cannon"
