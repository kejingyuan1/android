# WorkerSystem.gd — 工人管理（5个工人）
extends Node

const MAX_WORKERS = 5
var available_workers = MAX_WORKERS
var build_queue = []  # 队列中的 BuildQueueItem
var active_jobs = []  # 正在进行的 BuildQueueItem

signal queue_changed()
signal job_completed(cx, cy, variant_id, is_upgrade)

func add_to_queue(cx, cy, variant_id, is_upgrade, build_time):
    if available_workers <= 0 and active_jobs.size() >= MAX_WORKERS:
        return false  # 队列满
    var item = BuildQueueItem.new(cx, cy, variant_id, is_upgrade, build_time)
    build_queue.append(item)
    _try_assign_workers()
    emit_signal("queue_changed")
    return true

func _try_assign_workers():
    # 把队列中的任务分配给空闲工人
    while available_workers > 0 and build_queue.size() > 0:
        var item = build_queue.pop_front()
        item.worker_id = MAX_WORKERS - available_workers
        available_workers -= 1
        active_jobs.append(item)

func process(delta):
    var completed = []
    for job in active_jobs:
        job.elapsed_time += delta
        if job.elapsed_time >= job.total_time:
            completed.append(job)
    for job in completed:
        active_jobs.erase(job)
        available_workers += 1
        emit_signal("job_completed", job.building_cell_x, job.building_cell_y, job.variant_id, job.is_upgrade)
    if completed.size() > 0:
        _try_assign_workers()
        emit_signal("queue_changed")

func cancel_job(cx, cy):
    # 从队列或激活任务中移除
    for arr in [build_queue, active_jobs]:
        for item in arr:
            if item.building_cell_x == cx and item.building_cell_y == cy:
                arr.erase(item)
                if item.worker_id >= 0:
                    available_workers += 1
                emit_signal("queue_changed")
                return true
    return false

func get_queue_size():
    return build_queue.size() + active_jobs.size()

func get_available_worker_count():
    return available_workers

func get_queue_progress(cx, cy):
    for job in active_jobs:
        if job.building_cell_x == cx and job.building_cell_y == cy:
            return job.elapsed_time / job.total_time
    return 0.0
