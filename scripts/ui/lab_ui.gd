# LabUI.gd — 实验室升级界面
extends ColorRect

const TroopData = preload("res://scripts/combat/troop_data.gd")

signal upgrade_requested()

var _lab_manager: Node = null
var _economy: Node = null

# UI 控件引用
var _title_label: Label = null
var _lab_upgrade_btn: Button = null
var _lab_upgrade_cost_label: Label = null
var _troop_rows: Dictionary = {}  # troop_type → { row, name_label, lv_label, stats_label, next_label, upgrade_btn, cost_label, max_label }

const PANEL_COLOR := Color(0.12, 0.12, 0.15, 0.95)
const ROW_COLOR := Color(0.18, 0.18, 0.22, 0.8)
const ROW_COLOR_ALT := Color(0.15, 0.15, 0.19, 0.8)
const BUTTON_COLOR := Color(0.25, 0.35, 0.5, 1.0)
const BUTTON_HOVER := Color(0.35, 0.45, 0.6, 1.0)
const ACCENT_COLOR := Color(0.4, 0.7, 0.4, 1.0)
const MAXED_COLOR := Color(0.7, 0.7, 0.3, 1.0)
const TEXT_COLOR := Color(0.85, 0.85, 0.85, 1.0)

func setup(lab_manager: Node, economy: Node):
	_lab_manager = lab_manager
	_economy = economy
	_clear_ui()
	_build_ui()

func _clear_ui():
	for c in get_children():
		c.queue_free()
	_troop_rows.clear()

func _build_ui():
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = PANEL_COLOR
	custom_minimum_size = Vector2(340, 520)
	size = Vector2(340, 520)

	# 主 VBox
	var main_vbox = VBoxContainer.new()
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 1.0
	main_vbox.add_theme_constant_override("separation", 6)
	add_child(main_vbox)

	# 标题
	_add_title(main_vbox)

	# 实验室升级按钮行
	_add_lab_upgrade_row(main_vbox)

	# 分隔线
	_add_separator(main_vbox)

	# 兵种列表标题
	var header = Label.new()
	header.text = "兵种升级"
	header.add_theme_color_override("font_color", TEXT_COLOR)
	header.add_theme_font_size_override("font_size", 14)
	header.custom_minimum_size = Vector2(0, 22)
	main_vbox.add_child(header)

	# 可滚动列表
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

	_refresh_all()

func _add_title(parent: VBoxContainer):
	_title_label = Label.new()
	if _lab_manager:
		_title_label.text = "实验室 Lv.%d" % _lab_manager.lab_level
	else:
		_title_label.text = "实验室"
	_title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.custom_minimum_size = Vector2(0, 28)
	parent.add_child(_title_label)

func _add_lab_upgrade_row(parent: VBoxContainer):
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 30)
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	_lab_upgrade_btn = Button.new()
	_lab_upgrade_btn.text = "升级实验室"
	_lab_upgrade_btn.custom_minimum_size = Vector2(90, 28)
	_lab_upgrade_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	_lab_upgrade_btn.add_theme_color_override("button_normal", BUTTON_COLOR)
	_lab_upgrade_btn.add_theme_color_override("button_hover", BUTTON_HOVER)
	_lab_upgrade_btn.connect("pressed", Callable(self, "_on_lab_upgrade_pressed"))
	row.add_child(_lab_upgrade_btn)

	_lab_upgrade_cost_label = Label.new()
	_lab_upgrade_cost_label.text = ""
	_lab_upgrade_cost_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	_lab_upgrade_cost_label.add_theme_font_size_override("font_size", 11)
	_lab_upgrade_cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_lab_upgrade_cost_label)

func _add_separator(parent: VBoxContainer):
	var sep = ColorRect.new()
	sep.color = Color(0.4, 0.4, 0.4, 0.5)
	sep.custom_minimum_size = Vector2(0, 1)
	parent.add_child(sep)

func _add_troop_row(parent: VBoxContainer, troop_type: int):
	var bg = ColorRect.new()
	bg.color = ROW_COLOR_ALT if troop_type % 2 == 1 else ROW_COLOR
	bg.custom_minimum_size = Vector2(0, 48)
	parent.add_child(bg)

	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.add_theme_constant_override("separation", 6)
	bg.add_child(row)

	var info = {}
	_troop_rows[troop_type] = info
	info["bg"] = bg

	# 兵种图标
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex_path = TroopData.get_texture_path(troop_type)
	if ResourceLoader.exists(tex_path):
		icon_rect.texture = load(tex_path)
	row.add_child(icon_rect)

	# 信息列
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_vbox)

	# 兵种名 + 等级
	var name_lv_hbox = HBoxContainer.new()
	name_lv_hbox.add_theme_constant_override("separation", 8)
	info_vbox.add_child(name_lv_hbox)

	var name_label = Label.new()
	name_label.text = TroopData.get_troop_name(troop_type)
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	name_label.add_theme_font_size_override("font_size", 12)
	name_lv_hbox.add_child(name_label)
	info["name_label"] = name_label

	var lv_label = Label.new()
	lv_label.text = ""
	lv_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1.0))
	lv_label.add_theme_font_size_override("font_size", 11)
	name_lv_hbox.add_child(lv_label)
	info["lv_label"] = lv_label

	# 当前/下一级属性
	var stats_hbox = HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 6)
	info_vbox.add_child(stats_hbox)

	var stats_label = Label.new()
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	stats_label.add_theme_font_size_override("font_size", 9)
	stats_hbox.add_child(stats_label)
	info["stats_label"] = stats_label

	var next_label = Label.new()
	next_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5, 1.0))
	next_label.add_theme_font_size_override("font_size", 9)
	stats_hbox.add_child(next_label)
	info["next_label"] = next_label

	# 操作列
	var controls_vbox = VBoxContainer.new()
	controls_vbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	controls_vbox.add_theme_constant_override("separation", 2)
	row.add_child(controls_vbox)

	# 升级按钮
	var upgrade_btn = Button.new()
	upgrade_btn.text = "升级"
	upgrade_btn.custom_minimum_size = Vector2(60, 22)
	upgrade_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	upgrade_btn.add_theme_color_override("button_normal", ACCENT_COLOR)
	upgrade_btn.add_theme_color_override("button_hover", Color(0.5, 0.8, 0.5, 1.0))
	upgrade_btn.connect("pressed", Callable(self, "_on_troop_upgrade_pressed").bind(troop_type))
	controls_vbox.add_child(upgrade_btn)
	info["upgrade_btn"] = upgrade_btn

	# 费用标签
	var cost_label = Label.new()
	cost_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	cost_label.add_theme_font_size_override("font_size", 9)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_vbox.add_child(cost_label)
	info["cost_label"] = cost_label

	# 已满级标签
	var max_label = Label.new()
	max_label.text = "已满级"
	max_label.add_theme_color_override("font_color", MAXED_COLOR)
	max_label.add_theme_font_size_override("font_size", 11)
	max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	max_label.visible = false
	controls_vbox.add_child(max_label)
	info["max_label"] = max_label

func _refresh_all():
	if not _lab_manager:
		return

	# 刷新标题
	if _title_label:
		_title_label.text = "实验室 Lv.%d" % _lab_manager.lab_level

	# 刷新实验室升级
	if _lab_upgrade_btn and _lab_upgrade_cost_label:
		if _lab_manager.lab_level >= _lab_manager.MAX_LAB_LEVEL:
			_lab_upgrade_btn.disabled = true
			_lab_upgrade_cost_label.text = "已满级"
		else:
			var cost = _lab_manager.get_lab_upgrade_cost()
			_lab_upgrade_cost_label.text = "💰 %d 🪵 %d 🪨 %d" % [cost.gold, cost.wood, cost.stone]
			_lab_upgrade_btn.disabled = not _lab_manager.can_upgrade_lab(_economy)

	# 刷新所有兵种行
	for t in range(TroopData.TROOP_COUNT):
		_refresh_troop_row(t)

func _refresh_troop_row(troop_type: int):
	var info = _troop_rows.get(troop_type)
	if not info or not _lab_manager:
		return

	var current_lv = _lab_manager.get_troop_level(troop_type)
	var max_allowed = min(_lab_manager.MAX_TROOP_UPGRADE_LEVEL, _lab_manager.lab_level * 2)
	var is_maxed = current_lv >= max_allowed

	# 等级标签
	info["lv_label"].text = "Lv.%d / %d" % [current_lv, _lab_manager.MAX_TROOP_UPGRADE_LEVEL]

	# 当前属性
	var stats = TroopData.get_base_stats(troop_type, current_lv)
	info["stats_label"].text = "攻:%d 防:%d HP:%d 速:%.0f" % [stats.get("attack", 0), stats.get("defense", 0), stats.get("hp", 0), stats.get("speed", 0.0)]

	# 下一级属性
	if is_maxed:
		info["next_label"].text = ""
		info["upgrade_btn"].visible = false
		info["cost_label"].visible = false
		info["max_label"].visible = true
	else:
		var next_lv = current_lv + 1
		var next_stats = TroopData.get_base_stats(troop_type, next_lv)
		info["next_label"].text = "→ 攻:%d 防:%d HP:%d" % [next_stats.get("attack", 0), next_stats.get("defense", 0), next_stats.get("hp", 0)]
		info["upgrade_btn"].visible = true
		info["cost_label"].visible = true
		info["max_label"].visible = false

		# 费用和可用性
		var cost = _lab_manager.get_troop_upgrade_cost(troop_type)
		info["cost_label"].text = "💰%d 🪵%d 🪨%d" % [cost.gold, cost.wood, cost.stone]
		info["upgrade_btn"].disabled = not _lab_manager.can_upgrade_troop(troop_type, _economy)

func _on_lab_upgrade_pressed():
	if _lab_manager and _economy:
		if _lab_manager.do_upgrade_lab(_economy):
			_refresh_all()
			emit_signal("upgrade_requested")

func _on_troop_upgrade_pressed(troop_type: int):
	if _lab_manager and _economy:
		if _lab_manager.do_upgrade_troop(troop_type, _economy):
			_refresh_all()
			emit_signal("upgrade_requested")
