# BattleSpawner.gd — 波次生成器
extends Node

var wave_index = 0
var enemies_per_wave = 3
var spawn_interval = 1.0  # 每个敌人间隔
var wave_interval = 10.0  # 波次间隔
var spawn_timer = 0.0
var wave_timer = 0.0
var is_spawning = false
var battle_active = false
var total_enemies_spawned = 0
var total_enemies_killed = 0
var _target_position = Vector2.ZERO
var _game_world = null
var _iso_renderer = null

signal battle_completed(won, killed, total)
signal wave_started(wave_num)
signal enemy_spawned(count)

func start_battle(target_world_pos, game_world, iso_renderer_ref):
    _target_position = target_world_pos
    _game_world = game_world
    _iso_renderer = iso_renderer_ref
    wave_index = 0
    total_enemies_spawned = 0
    total_enemies_killed = 0
    battle_active = true
    is_spawning = true
    spawn_timer = 0.0
    wave_timer = 0.0
    _start_next_wave()

func _start_next_wave():
    wave_index += 1
    enemies_per_wave = 2 + wave_index * 2  # 每波多2个
    spawn_interval = max(0.5, 1.5 - wave_index * 0.1)
    var spawned = 0
    emit_signal("wave_started", wave_index)
    _spawn_enemy(spawned)

func _spawn_enemy(index_in_wave):
    if not battle_active:
        return
    if index_in_wave >= enemies_per_wave:
        # 本波完成，等待下一波
        is_spawning = false
        wave_timer = 0.0
        return
    
    total_enemies_spawned += 1
    # 从随机边缘位置生成
    var edge = randi() % 4
    var spawn_pos = Vector2.ZERO
    var map_w = 240
    var map_h = 160
    match edge:
        0: spawn_pos = _iso_renderer.grid_to_world(randi() % map_w, 0) if _iso_renderer else Vector2(randi() % 7680, 0)
        1: spawn_pos = _iso_renderer.grid_to_world(randi() % map_w, map_h - 1) if _iso_renderer else Vector2(randi() % 7680, 5120)
        2: spawn_pos = _iso_renderer.grid_to_world(0, randi() % map_h) if _iso_renderer else Vector2(0, randi() % 5120)
        3: spawn_pos = _iso_renderer.grid_to_world(map_w - 1, randi() % map_h) if _iso_renderer else Vector2(7680, randi() % 5120)
    
    # 敌人属性随波次增强
    var hp = 100 + wave_index * 50
    var def = 2 + wave_index * 2
    var spd = 40.0 + randi() % 40
    
    var enemy = preload("res://scripts/combat/enemy_unit.gd").new()
    enemy.setup(spawn_pos, _target_position, hp, def, spd)
    _game_world.add_child(enemy)
    # 监听敌人死亡
    # 由于enemy没有死亡信号，我们在_process中检查
    emit_signal("enemy_spawned", total_enemies_spawned)

func _process(delta):
    if not battle_active:
        return
    # 检查敌人存活（简单方式：检查场景中还有多少敌人）
    var alive_count = 0
    if _game_world:
        for child in _game_world.get_children():
            if child.is_in_group("enemies") and is_instance_valid(child):
                if child.has_method("is_alive"):
                    if child.is_alive():
                        alive_count += 1
                else:
                    alive_count += 1
    
    if is_spawning:
        spawn_timer += delta
        if spawn_timer >= spawn_interval:
            spawn_timer = 0.0
            _spawn_enemy(int(total_enemies_spawned) - (wave_index - 1) * enemies_per_wave)
    else:
        wave_timer += delta
        if wave_timer >= wave_interval and alive_count == 0:
            # 下一波
            _start_next_wave()
    
    # 检查战斗结束（所有波次完成 + 无敌人存活）
    if wave_index >= 5 and alive_count == 0:
        battle_active = false
        emit_signal("battle_completed", true, total_enemies_killed, total_enemies_spawned)
