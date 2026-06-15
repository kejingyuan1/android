# StorageBuilding.gd — 仓库（增加资源存储上限）
extends Node2D

var building_name = "仓库"
var gold_capacity_bonus = 5000
var elixir_capacity_bonus = 5000
var cell_x = 0
var cell_y = 0
var level = 1
var _sprite = null

func setup(gx, gy, lv = 1):
    cell_x = gx
    cell_y = gy
    level = lv
    _sprite = Sprite2D.new()
    _sprite.texture = load("res://assets/textures/buildings/storage.png")
    _sprite.centered = true
    _sprite.z_index = 5
    add_child(_sprite)

func get_gold_bonus():
    return gold_capacity_bonus * level

func get_elixir_bonus():
    return elixir_capacity_bonus * level
