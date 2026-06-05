# RCIPanel.gd — RCI 需求条面板
# 显示住宅/商业/工业的需求水平
# 人口 < 100 时自动隐藏

extends ColorRect

var _gm: Node = null
var _pop_threshold := 100  # 人口超过此值才显示

## 各需求条 UI
var _rci_bars: Array = []
var _rci_labels: Array = []

## 需求条颜色
const BAR_COLORS := [
	Color(0.2, 0.7, 0.3),   # Residential - 绿
	Color(0.2, 0.5, 0.8),   # Commercial - 蓝
	Color(0.8, 0.6, 0.15),  # Industrial - 金
]

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_ui()
	visible = false  # 初始隐藏

func _create_ui():
	var hbox = HBoxContainer.new()
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.add_theme_constant_override("separation", 4)
	add_child(hbox)

	var labels = ["R", "C", "I"]
	for i in range(3):
		# 标签
		var lbl = Label.new()
		lbl.text = labels[i]
		lbl.custom_minimum_size = Vector2(18, 28)
		lbl.add_theme_color_override("font_color", BAR_COLORS[i])
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_constant_override("outline_size", 1)
		hbox.add_child(lbl)

		# 进度条背景
		var bar_bg = ColorRect.new()
		bar_bg.color = Color(0.2, 0.2, 0.25, 0.8)
		bar_bg.custom_minimum_size = Vector2(200, 14)
		bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(bar_bg)

		# 进度条填充
		var bar_fill = ColorRect.new()
		bar_fill.color = BAR_COLORS[i]
		bar_fill.size = Vector2(0, 14)
		bar_fill.anchor_right = 0.0
		bar_fill.anchor_bottom = 1.0
		bar_bg.add_child(bar_fill)

		_rci_bars.append(bar_fill)
		_rci_labels.append(lbl)

func _process(delta):
	if not _gm:
		_gm = get_node("/root/Main/GameManager")
		return

	# 人口不足时隐藏
	var pop = _get_population()
	if pop < _pop_threshold:
		visible = false
		return
	else:
		visible = true

	# 更新需求条
	var rci = _gm.rci_demand
	for i in range(3):
		var demand = 0.0
		match i:
			0: demand = rci.residential
			1: demand = rci.commercial
			2: demand = rci.industrial

		var pct = clamp(demand / 100.0, 0.0, 1.0)
		if _rci_bars[i]:
			_rci_bars[i].size = Vector2(pct * _rci_bars[i].get_parent().size.x, 14)

func _get_population() -> int:
	if _gm and _gm.building_system and _gm.building_system.has_method("get_residential_population"):
		return _gm.building_system.get_residential_population()
	return 0
