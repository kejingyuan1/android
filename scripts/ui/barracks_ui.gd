# BarracksUI.gd — 兵营管理界面
extends ColorRect

const TroopData = preload("res://scripts/combat/troop_data.gd")

signal confirm_deployment(deployment_data: Dictionary)
signal upgrade_requested()

var _manager: Node = null           # BarracksManager 引用
var _economy: Node = null            # Economy 引用
var _deployment: Dictionary = {}     # 当前界面调整的部署量
var _troop_rows: Dictionary = {}     # troop_type → {label, plus, minus, count_label, locked_label, ...}
var _upgrade_btn: Button = null
var _upgrade_cost_label: Label = null
var _total_label: Label = null
var _confirm_btn: Button = null

const PANEL_COLOR := Color(0.12, 0.12, 0.15, 0.95)
const ROW_COLOR := Color(0.18, 0.18, 0.22, 0.8)
const ROW_COLOR_ALT := Color(0.15, 0.15, 0.19, 0.8)
const BUTTON_COLOR := Color(0.25, 0.35, 0.5, 1.0)
const BUTTON_HOVER := Color(0.35, 0.45, 0.6, 1.0)
const ACCENT_COLOR := Color(0.4, 0.7, 0.4, 1.0)
const LOCKED_COLOR := Color(0.5, 0.3, 0.3, 1.0)
const TEXT_COLOR := Color(0.85, 0.85, 0.85, 1.0)

func setup(manager: Node, economy: Node):
	_manager = manager
	_economy = economy
	_deployment.clear()
	_clear_ui()
	_build_ui()

func _clear_ui():
	for c in get_children():
		c.queue_free()
	_troop_rows.clear()

func _build_ui():
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = PANEL_COLOR
	custom_minimum_size = Vector2(340, 460)
	size = Vector2(340, 460)

	# 主 VBox
	var main_vbox = VBoxContainer.new()
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 1.0
	main_vbox.add_theme_constant_override("separation", 6)
	add_child(main_vbox)

	# --- 标题行 ---
	_add_title(main_vbox)

	# --- 升级按钮行 ---
	_add_upgrade_row(main_vbox)

	# --- 分隔线 ---
	_add_separator(main_vbox)

	# --- 兵种列表标题 ---
	var header = Label.new()
	header.text = "兵种配置"
	header.add_theme_color_override("font_color", TEXT_COLOR)
	header.add_theme_font_size_override("font_size", 14)
	header.custom_minimum_size = Vector2(0, 22)
	main_vbox.add_child(header)

	# --- 兵种可滚动列表 ---
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	main_vbox.add_child(scroll)

	var troop_container = VBoxContainer.new()
	troop_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	troop_container.add_theme_constant_override("separation", 4)
	scroll.add_child(troop_container)

	# 遍历所有兵种
	for t in range(TroopData.TROOP_COUNT):
		_add_troop_row(troop_container, t)

	# --- 底部操作栏 ---
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.custom_minimum_size = Vector2(0, 40)
	bottom_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(bottom_hbox)

	_total_label = Label.new()
	_total_label.text = "总部署: 0"
	_total_label.add_theme_color_override("font_color", TEXT_COLOR)
	_total_label.add_theme_font_size_override("font_size", 14)
	_total_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(_total_label)

	_confirm_btn = Button.new()
	_confirm_btn.text = "确认部署"
	_confirm_btn.custom_minimum_size = Vector2(120, 32)
	_confirm_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	_confirm_btn.add_theme_color_override("button_normal", ACCENT_COLOR)
	_confirm_btn.add_theme_color_override("button_hover", Color(0.5, 0.8, 0.5, 1.0))
	_confirm_btn.connect("pressed", Callable(self, "_on_confirm_pressed"))
	bottom_hbox.add_child(_confirm_btn)

	_refresh_all()

func _add_title(parent: VBoxContainer):
	var title = Label.new()
	if _manager:
		title.text = "兵营 Lv.%d" % _manager.barracks_level
	else:
		title.text = "兵营"
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_font_size_override("font_size", 18)
	title.custom_minimum_size = Vector2(0, 28)
	parent.add_child(title)

func _add_upgrade_row(parent: VBoxContainer):
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 30)
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	_upgrade_btn = Button.new()
	_upgrade_btn.text = "升级"
	_upgrade_btn.custom_minimum_size = Vector2(60, 28)
	_upgrade_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	_upgrade_btn.add_theme_color_override("button_normal", BUTTON_COLOR)
	_upgrade_btn.add_theme_color_override("button_hover", BUTTON_HOVER)
	_upgrade_btn.connect("pressed", Callable(self, "_on_upgrade_pressed"))
	row.add_child(_upgrade_btn)

	_upgrade_cost_label = Label.new()
	_upgrade_cost_label.text = ""
	_upgrade_cost_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	_upgrade_cost_label.add_theme_font_size_override("font_size", 11)
	_upgrade_cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_upgrade_cost_label)

func _add_separator(parent: VBoxContainer):
	var sep = ColorRect.new()
	sep.color = Color(0.4, 0.4, 0.4, 0.5)
	sep.custom_minimum_size = Vector2(0, 1)
	parent.add_child(sep)

func _add_troop_row(parent: VBoxContainer, troop_type: int):
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 34)
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var info = {}
	_troop_rows[troop_type] = info
	info["row"] = row

	# 图标
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex_path = TroopData.get_texture_path(troop_type)
	if ResourceLoader.exists(tex_path):
		icon_rect.texture = load(tex_path)
	row.add_child(icon_rect)

	# 兵种信息列
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_vbox)

	# 兵种名
	var name_label = Label.new()
	name_label.text = TroopData.get_troop_name(troop_type)
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	name_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(name_label)

	# 属性预览行
	var stats = TroopData.get_base_stats(troop_type, 1)
	var stats_text = "攻:%d 防:%d HP:%d 速:%.0f" % [stats.get("attack", 0), stats.get("defense", 0), stats.get("hp", 0), stats.get("speed", 0.0)]
	var stats_label = Label.new()
	stats_label.text = stats_text
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	stats_label.add_theme_font_size_override("font_size", 9)
	info_vbox.add_child(stats_label)

	# 数量调整和锁定指示
	var controls_hbox = HBoxContainer.new()
	controls_hbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	controls_hbox.add_theme_constant_override("separation", 4)
	row.add_child(controls_hbox)

	# 锁定指示
	var locked_label = Label.new()
	locked_label.text = "🔒"
	locked_label.add_theme_font_size_override("font_size", 14)
	locked_label.visible = false
	controls_hbox.add_child(locked_label)
	info["locked_label"] = locked_label

	# 减
	var minus_btn = Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(24, 24)
	minus_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	minus_btn.add_theme_color_override("button_normal", Color(0.4, 0.3, 0.3, 1.0))
	minus_btn.add_theme_color_override("button_hover", Color(0.5, 0.4, 0.4, 1.0))
	minus_btn.connect("pressed", Callable(self, "_on_adjust_troop").bind(troop_type, -1))
	controls_hbox.add_child(minus_btn)
	info["minus_btn"] = minus_btn

	# 数量
	var count_label = Label.new()
	count_label.text = "0"
	count_label.custom_minimum_size = Vector2(30, 24)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_color_override("font_color", TEXT_COLOR)
	count_label.add_theme_font_size_override("font_size", 13)
	controls_hbox.add_child(count_label)
	info["count_label"] = count_label

	# 加
	var plus_btn = Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(24, 24)
	plus_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	plus_btn.add_theme_color_override("button_normal", Color(0.3, 0.4, 0.3, 1.0))
	plus_btn.add_theme_color_override("button_hover", Color(0.4, 0.5, 0.4, 1.0))
	plus_btn.connect("pressed", Callable(self, "_on_adjust_troop").bind(troop_type, 1))
	controls_hbox.add_child(plus_btn)
	info["plus_btn"] = plus_btn

func _on_adjust_troop(troop_type: int, delta: int):
	var current = _deployment.get(troop_type, 0)
	var new_val = current + delta
	if new_val < 0:
		new_val = 0
	# 上限不能超过兵营中该兵种的数量
	var max_count = _manager.get_troop_count(troop_type) if _manager else 999
	if new_val > max_count:
		new_val = max_count
	_deployment[troop_type] = new_val
	_refresh_troop_row(troop_type)
	_refresh_total()

func _refresh_troop_row(troop_type: int):
	var info = _troop_rows.get(troop_type)
	if not info:
		return
	var is_unlocked = _manager and _manager.is_troop_unlocked(troop_type)

	# 锁定/解锁状态
	info["locked_label"].visible = not is_unlocked
	info["minus_btn"].disabled = not is_unlocked
	info["plus_btn"].disabled = not is_unlocked

	if not is_unlocked:
		var stats = TroopData.get_base_stats(troop_type, 1)
		var unlock_lv = stats.get("unlock_barracks_lv", 999)
		info["count_label"].text = "Lv.%d" % unlock_lv
	else:
		var count = _deployment.get(troop_type, 0)
		info["count_label"].text = str(count)

func _refresh_total():
	var total = 0
	for v in _deployment.values():
		total += v
	if _total_label:
		_total_label.text = "总部署: %d" % total
	# 确认按钮状态
	if _confirm_btn:
		_confirm_btn.disabled = (total == 0)

func _refresh_all():
	# 刷新标题
	var title = null
	for c in get_children():
		if c is VBoxContainer:
			for child in c.get_children():
				if child is Label and child.text.begins_with("兵营"):
					title = child
					break
	if title and _manager:
		title.text = "兵营 Lv.%d" % _manager.barracks_level

	# 刷新升级成本
	if _manager and _upgrade_cost_label:
		var cost = _manager.get_upgrade_cost()
		_upgrade_cost_label.text = "💰 %d 🪵 %d 🪨 %d" % [cost.gold, cost.wood, cost.stone]
		if _manager.barracks_level >= _manager.MAX_LEVEL:
			_upgrade_btn.disabled = true
			_upgrade_cost_label.text = "已达最大等级"
		else:
			_upgrade_btn.disabled = false

	# 刷新所有兵种行
	for t in range(TroopData.TROOP_COUNT):
		_refresh_troop_row(t)

	_refresh_total()

func _on_upgrade_pressed():
	if _manager and _economy:
		var cost = _manager.get_upgrade_cost()
		# 简化处理：检查金线是否足够（后续可接入资源系统）
		if _economy.can_afford(cost.gold):
			_economy.spend(cost.gold, "兵营升级")
			if _manager.do_upgrade():
				_refresh_all()
				emit_signal("upgrade_requested")
		else:
			# 显示"金币不足"提示
			print("金币不足，无法升级兵营")

func _on_confirm_pressed():
	var deploy_data = {}
	for t in range(TroopData.TROOP_COUNT):
		var count = _deployment.get(t, 0)
		if count > 0:
			deploy_data[t] = count
	if deploy_data.size() > 0:
		# 从兵营消耗兵种
		for t in deploy_data.keys():
			_manager.consume_troops(t, deploy_data[t])
		emit_signal("confirm_deployment", deploy_data)
		_deployment.clear()
		_refresh_all()
