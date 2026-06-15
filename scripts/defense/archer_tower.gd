extends "res://scripts/defense/defense_tower.gd"

func _ready():
    tower_name = "箭塔"
    damage = 15
    attack_range = 200.0
    attack_speed = 0.8

func _get_texture_name():
    return "archer_tower"
