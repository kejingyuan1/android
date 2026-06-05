# WorldCamera.gd — 超级大地图摄像机控制
extends Camera2D

const MIN_ZOOM := 0.0001
const MAX_ZOOM := 0.3
const WORLD_W := 100000
const WORLD_H := 100000
const FRICTION := 0.90
const DRAG_THRESHOLD := 5.0

var _dragging := false
var _drag_start := Vector2.ZERO        # 拖拽起始屏幕坐标
var _cam_start := Vector2.ZERO         # 拖拽起始世界坐标
var _touch_count := 0
var _velocity := Vector2.ZERO          # 惯性速度（世界坐标/秒）
var _prev_mouse_pos := Vector2.ZERO    # 上一帧鼠标位置（用于计算 motion delta）
var _clamp_enabled := true            # 入场动画期间禁用（避免拉回世界中心）

func _ready():
	position = Vector2(WORLD_W / 2, WORLD_H / 2)
	zoom = Vector2(0.003, 0.003)

func _unhandled_input(event):
	# === 鼠标左键 ===
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_start = event.position
			_cam_start = position
			_prev_mouse_pos = event.position
			_velocity = Vector2.ZERO
		else:
			_dragging = false
		return

	# === 鼠标拖拽平移 ===
	if event is InputEventMouseMotion and _dragging:
		var screen_delta = event.position - _prev_mouse_pos
		_prev_mouse_pos = event.position
		var world_delta = screen_delta / zoom
		position -= world_delta
		_velocity = -world_delta / get_process_delta_time()
		return

	# === 触屏事件（经由 _input，因为 unhandled 有时序问题） ===

func _input(event):
	# === 触屏单指拖拽 ===
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_count += 1
			if _touch_count == 1:
				_dragging = true
				_drag_start = event.position
				_cam_start = position
				_velocity = Vector2.ZERO
		else:
			_touch_count = max(0, _touch_count - 1)
			if _touch_count == 0:
				_dragging = false
		return

	if event is InputEventScreenDrag:
		if _touch_count == 1:
			var delta = event.position - _drag_start
			if delta.length() > DRAG_THRESHOLD:
				position = _cam_start - delta / zoom
				# 触屏 velocity 用每帧相对增量
				var frame_delta = event.relative / zoom
				_velocity = -frame_delta / get_process_delta_time()
		return

	# === 滚轮缩放（鼠标滚轮） ===
	if event is InputEventMouseButton and event.pressed:
		var factor := 1.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			factor = 1.15
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			factor = 1.0 / 1.15
		else:
			return

		var new_zoom = clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
		var vp_size = get_viewport().get_visible_rect().size
		var mouse_world_before = position + (event.position - vp_size * 0.5) / zoom
		zoom = Vector2(new_zoom, new_zoom)
		var mouse_world_after = position + (event.position - vp_size * 0.5) / zoom
		position += mouse_world_before - mouse_world_after
		_clamp_position()

func _process(delta):
	if not _dragging and _velocity.length_squared() > 0.5:
		position += _velocity * delta
		_velocity *= FRICTION
		if _velocity.length_squared() < 0.5:
			_velocity = Vector2.ZERO
	if _clamp_enabled:
		_clamp_position()

func set_clamp_enabled(val: bool) -> void:
	_clamp_enabled = val

func _clamp_position():
	var vp_size = get_viewport().get_visible_rect().size
	var half_w = (vp_size.x / zoom.x) * 0.5
	var half_h = (vp_size.y / zoom.y) * 0.5

	var min_x = half_w
	var max_x = WORLD_W - half_w
	var min_y = half_h
	var max_y = WORLD_H - half_h

	var prev_x = position.x
	var prev_y = position.y

	# 当地图比 viewport 小时，不做强制居中——允许自由拖拽
	if min_x < max_x:
		position.x = clampf(position.x, min_x, max_x)
	if min_y < max_y:
		position.y = clampf(position.y, min_y, max_y)

	# 触边时清零惯性
	if position.x != prev_x:
		_velocity.x = 0.0
	if position.y != prev_y:
		_velocity.y = 0.0
