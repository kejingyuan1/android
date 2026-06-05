# LoadingScreen.gd — 加载动画
extends ColorRect

var _title_label: Label
var _subtitle_label: Label
var _bar_fill: ColorRect
var _dots := 0
var _dot_timer := 0.0

# 云朵数据：[Label节点, 方向(±1), 速度(px/s), 初始X]
var _clouds: Array = []

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0.05, 0.05, 0.1, 1.0)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	# 强制处理模式：始终运行，不受暂停等影响
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 创建 5 朵流云，不同大小、速度、高度，形成层次感
	# 所有云朵初始位置都在屏幕可视范围内（0~1280），确保一出现就能看到
	var cloud_configs = [
		{"x": 80.0,   "y": 80.0,  "dir": 1,  "speed": 80.0, "font": 72, "alpha": 0.25},
		{"x": 600.0,  "y": 150.0, "dir": -1, "speed": 60.0, "font": 56, "alpha": 0.2},
		{"x": 200.0,  "y": 280.0, "dir": 1,  "speed": 100.0, "font": 80, "alpha": 0.18},
		{"x": 900.0,  "y": 380.0, "dir": 1,  "speed": 50.0, "font": 48, "alpha": 0.3},
		{"x": 1100.0, "y": 50.0,  "dir": -1, "speed": 70.0, "font": 64, "alpha": 0.22},
	]

	for cfg in cloud_configs:
		var cloud = Label.new()
		cloud.text = "☁️"
		cloud.add_theme_font_size_override("font_size", cfg["font"])
		cloud.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, cfg["alpha"]))
		cloud.position = Vector2(cfg["x"], cfg["y"])
		add_child(cloud)
		_clouds.append({
			"node": cloud,
			"dir": cfg["dir"],
			"speed": cfg["speed"],
			"start_x": cfg["x"],
		})

	# 标题
	_title_label = Label.new()
	_title_label.text = "正在生成世界"
	_title_label.position = Vector2(440, 530)
	_title_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	_title_label.add_theme_font_size_override("font_size", 32)
	add_child(_title_label)

	# 副标题
	_subtitle_label = Label.new()
	_subtitle_label.text = "大陆正在升起，海洋正在成形..."
	_subtitle_label.position = Vector2(460, 575)
	_subtitle_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_subtitle_label.add_theme_font_size_override("font_size", 16)
	add_child(_subtitle_label)

	# 进度条背景
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.2, 0.25, 0.8)
	bar_bg.size = Vector2(300, 8)
	bar_bg.position = Vector2(490, 620)
	bar_bg.name = "BarBg"
	add_child(bar_bg)

	# 进度条填充
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.5, 0.75, 0.3, 1.0)
	_bar_fill.size = Vector2(0, 8)
	_bar_fill.position = Vector2(490, 620)
	_bar_fill.name = "BarFill"
	add_child(_bar_fill)

func show_loading():
	visible = true
	# 重置所有云朵到初始位置，避免多次 show/hide 后位置错乱
	for c in _clouds:
		c["node"].position.x = c["start_x"]
	print("【T=", Time.get_ticks_msec(), " LoadingScreen】show_loading() visible=", visible, " 云朵数=", _clouds.size())
	for i in range(_clouds.size()):
		print("  [T=", Time.get_ticks_msec(), "] 云朵[", i, "] pos=", _clouds[i]["node"].position, " dir=", _clouds[i]["dir"], " speed=", _clouds[i]["speed"])

func hide_loading():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	await tween.finished
	visible = false
	modulate = Color(1, 1, 1, 1)

func update_progress(pct: float):
	if _bar_fill:
		_bar_fill.size.x = pct * 300.0

func _process(delta):
	if not visible:
		return

	# 驱动所有云朵水平飘动
	for c in _clouds:
		var node = c["node"]
		var dir = c["dir"]
		var speed = c["speed"]
		node.position.x += dir * speed * delta
		# 超出右边界 → 从左边重新进入
		if dir > 0 and node.position.x > 1400:
			node.position.x = -150
		# 超出左边界 → 从右边重新进入
		elif dir < 0 and node.position.x < -150:
			node.position.x = 1400

	# 标题省略号动画
	_dot_timer += delta
	if _dot_timer > 0.5:
		_dot_timer = 0.0
		_dots = (_dots + 1) % 4
		_title_label.text = "正在生成世界" + ".".repeat(_dots)
		print("【T=", Time.get_ticks_msec(), " LoadingScreen】_process 运行中")
