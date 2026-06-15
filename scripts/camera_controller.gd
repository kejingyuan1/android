# CameraController.gd — 触摸摄像机控制
# 支持单指平移、双指缩放、惯性滑动

extends Camera2D

## 缩放范围
const MIN_ZOOM := 0.12
const MAX_ZOOM := 3.0

## 惯性参数
const FRICTION := 0.92
const DRAG_THRESHOLD := 5.0

## 地图边界
var map_bounds: Rect2 = Rect2(-5200, -200, 13000, 6700)  # 等距地图范围 (-5088~7900, 0~6500)
var _dragging := false
var _prev_mouse_pos := Vector2.ZERO
var _drag_start_pos := Vector2.ZERO
var _drag_start_cam_pos := Vector2.ZERO
var _velocity := Vector2.ZERO
var _is_panning := false

## 触摸状态
var _touch_count := 0
var _touch_start_pos := Vector2.ZERO
var _pinch_initial_dist := 0.0
var _pinch_initial_zoom := 1.0
var _last_touch_id := -1

## 工具激活状态（由 GameManager 设置）
var tool_active := false
var _right_dragging := false
var _right_drag_start := Vector2.ZERO
var _right_drag_cam_start := Vector2.ZERO

func _input(event):
	# ===== 鼠标左键（工具模式时由 GameManager 处理） =====
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not tool_active:
					_prev_mouse_pos = event.position
					_drag_start_pos = event.position
					_drag_start_cam_pos = position
					_dragging = true
					_is_panning = false
					_velocity = Vector2.ZERO
			else:
				if _dragging:
					_dragging = false

	# 鼠标左键拖拽平移（仅非工具模式）
	if event is InputEventMouseMotion:
		if _dragging and not tool_active:
			var screen_delta = event.position - _prev_mouse_pos
			_prev_mouse_pos = event.position
			if screen_delta.length() > DRAG_THRESHOLD:
				_is_panning = true
				position -= screen_delta / zoom
				_velocity = -(screen_delta / zoom) / get_process_delta_time()

	# ===== 鼠标右键（始终可以平移） =====
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_right_dragging = true
				_right_drag_start = event.position
				_right_drag_cam_start = position
				_dragging = false
				_velocity = Vector2.ZERO
			else:
				_right_dragging = false

	if event is InputEventMouseMotion:
		if _right_dragging:
			var screen_delta = event.position - _right_drag_start
			if screen_delta.length() > DRAG_THRESHOLD:
				position = _right_drag_cam_start - screen_delta / zoom
				_velocity = -(screen_delta / zoom) / get_process_delta_time()

	# ===== 鼠标滚轮（始终可用） =====
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = Vector2(clamp(zoom.x * 1.15, MIN_ZOOM, MAX_ZOOM), clamp(zoom.y * 1.15, MIN_ZOOM, MAX_ZOOM))
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = Vector2(clamp(zoom.x / 1.15, MIN_ZOOM, MAX_ZOOM), clamp(zoom.y / 1.15, MIN_ZOOM, MAX_ZOOM))

	# ===== 触摸 =====
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_count += 1
			_last_touch_id = event.index
			if _touch_count == 1:
				_drag_start_pos = event.position
				_drag_start_cam_pos = position
				_dragging = true
				_is_panning = false
				_velocity = Vector2.ZERO
			elif _touch_count == 2:
				_pinch_initial_dist = _drag_start_pos.distance_to(event.position)
				_pinch_initial_zoom = zoom.x
				_dragging = false
		else:
			_touch_count = max(0, _touch_count - 1)

	if event is InputEventScreenDrag:
		if _touch_count == 1 and not tool_active:
			var delta = event.position - _drag_start_pos
			if delta.length() > DRAG_THRESHOLD:
				_is_panning = true
				var frame_delta = event.relative / zoom
				position = _drag_start_cam_pos - delta / zoom
				_velocity = -(frame_delta) / get_process_delta_time()

func _process(delta):
	# 惯性滑动
	if not _dragging and _velocity.length_squared() > 0.5:
		position += _velocity * delta
		_velocity *= FRICTION
		if _velocity.length_squared() < 0.5:
			_velocity = Vector2.ZERO

	if _clamp_enabled:
		_clamp_position()

func _clamp_position():
	var viewport_size = get_viewport_rect().size
	var half_w = (viewport_size.x / zoom.x) * 0.5
	var half_h = (viewport_size.y / zoom.y) * 0.5
	
	var min_x = map_bounds.position.x + half_w
	var max_x = map_bounds.end.x - half_w
	var min_y = map_bounds.position.y + half_h
	var max_y = map_bounds.end.y - half_h
	
	var prev_x = position.x
	var prev_y = position.y
	
	# 当地图比 viewport 小时，不做强制居中——允许自由拖拽
	if min_x < max_x:
		position.x = clamp(position.x, min_x, max_x)
	if min_y < max_y:
		position.y = clamp(position.y, min_y, max_y)
	
	# 触边时清零对应轴向的惯性速度，防止抖动
	if position.x != prev_x:
		_velocity.x = 0.0
	if position.y != prev_y:
		_velocity.y = 0.0

## 在工具激活时禁用摄像机平移（缩放仍可用）
func set_tool_active(active: bool):
	tool_active = active
	if active:
		_dragging = false
		_is_panning = false
		_velocity = Vector2.ZERO

## 启用/禁用位置钳制（入场动画期间禁用）
var _clamp_enabled := true
func set_clamp_enabled(enabled: bool):
	_clamp_enabled = enabled
