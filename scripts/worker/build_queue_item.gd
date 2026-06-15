# BuildQueueItem.gd — 单个建造/升级任务
class_name BuildQueueItem
extends RefCounted

var building_cell_x: int
var building_cell_y: int
var variant_id: int       # 建筑类型
var is_upgrade: bool      # true=升级 false=新建
var total_time: float     # 总建造时间（秒）
var elapsed_time: float   # 已用时间
var worker_id: int        # -1=未分配, 0-4=已分配工人

func _init(cx, cy, vid, upgrade, time_sec):
    building_cell_x = cx
    building_cell_y = cy
    variant_id = vid
    is_upgrade = upgrade
    total_time = time_sec
    elapsed_time = 0.0
    worker_id = -1
