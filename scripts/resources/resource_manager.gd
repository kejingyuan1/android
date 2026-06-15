# ResourceManager.gd — 统管所有资源生产建筑
extends Node

var _buildings = []  # 所有resource_building引用
var _storages = []   # 所有storage引用

# 全局存储上限
var max_gold = 10000
var max_elixir = 10000
var max_wood = 50000
var max_stone = 30000

func register_building(bld):
    if not _buildings.has(bld):
        _buildings.append(bld)
        _recalc_capacity()

func unregister_building(bld):
    _buildings.erase(bld)
    _storages.erase(bld)
    _recalc_capacity()

func register_storage(st):
    if not _storages.has(st):
        _storages.append(st)
        _recalc_capacity()

func _recalc_capacity():
    # 基础容量 + 仓库加成
    max_gold = 10000
    max_elixir = 10000
    for st in _storages:
        if is_instance_valid(st):
            max_gold += st.get_gold_bonus()
            max_elixir += st.get_elixir_bonus()

func collect_all_gold():
    var total = 0
    for bld in _buildings:
        if is_instance_valid(bld) and bld.resource_type == "gold":
            total += bld.collect_all()
    return total

func collect_all_elixir():
    var total = 0
    for bld in _buildings:
        if is_instance_valid(bld) and bld.resource_type == "elixir":
            total += bld.collect_all()
    return total

func get_total_stored_gold():
    var total = 0
    for bld in _buildings:
        if is_instance_valid(bld) and bld.resource_type == "gold":
            total += bld.get_collectable_amount()
    return total

func get_total_stored_elixir():
    var total = 0
    for bld in _buildings:
        if is_instance_valid(bld) and bld.resource_type == "elixir":
            total += bld.get_collectable_amount()
    return total
