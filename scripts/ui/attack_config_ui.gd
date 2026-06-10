# AttackConfigUI.gd — 兵力配置界面（派兵攻击野怪）
extends ColorRect

const TroopData = preload("res://scripts/combat/troop_data.gd")

signal attack_confirmed(deployment: Dictionary)
signal cancelled()

## 野怪数据
var _creature_data = null
## 兵营管理器引用
var _barracks_manager: Node = null

var _deployment: Dictionary = {}  # troop_type → 部署数量
var _troop_rows: Dictionary = {}  # troop_type → {count_label, plus_btn, minus_btn}
var _total_power_label: Label = null
var _confirm_btn: Button = null

const PANEL_COLOR := Color(0.1, 0.1, 0.15, 0.95)
const ROW_COLOR := Color(0.18, 0.18, 0.22, 0.8)
const TEXT_COLOR := Color(0.85, 0.85, 0.85, 1.0)
const ACCENT_COLOR := Color(0.8, 0.4, 0.1, 1.0)

## 阻止滚轮事件穿透到世界地图相机
## 注意：不拦截 ScrollContainer 的滚动，仅阻止传播到 _unhandled_input
func _unhandled_input(event):
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if get_global_rect().has_point(get_global_mouse_position()):
			accept_event()
			return

func setup(creature_data, barracks_manager: Node):
	_creature_data = creature_data
	_barracks_manager = barracks_manager
	_deployment.clear()
	_build_ui()

func _build_ui():
	clear_children()

	mouse_filter = Control.MOUSE_FILTER_STOP
	color = PANEL_COLOR
	custom_minimum_size = Vector2(340, 380)
	size = Vector2(340, 380)

	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# 标题
	var title = Label.new()
	var type_names = ["鱼龙", "水母精", "海星怪", "海马龙"] if _creature_data.habitat == 0 else ["飞翼鸟"]
	var creature_type_name = type_names[_creature_data.sprite_type % type_names.size()]
	title.text = "兵力配置 - Lv.%d %s" % [_creature_data.level, creature_type_name]
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	title.add_theme_font_size_override("font_size", 18)
	title.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(title)

	# 野怪信息行
	var info_label = Label.new()
	info_label.text = "血量: %d/%d  攻击性: %.0f%%" % [_creature_data.hp, _creature_data.max_hp, _creature_data.aggression * 100]
	info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	info_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(info_label)

	# 分隔线
	var sep = ColorRect.new()
	sep.color = Color(0.4, 0.4, 0.4, 0.5)
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	# 兵种列表标题
	var header = Label.new()
	header.text = "可派遣部队"
	header.add_theme_color_override("font_color", TEXT_COLOR)
	header.add_theme_font_size_override("font_size", 14)
	vbox.add_child(header)

	# 可滚动的兵种列表
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 160)
	vbox.add_child(scroll)

	var troop_container = VBoxContainer.new()
	troop_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	troop_container.add_theme_constant_override("separation", 4)
	scroll.add_child(troop_container)

	for t in range(TroopData.TROOP_COUNT):
		add_troop_row(troop_container, t)

	# 分隔线
	var sep2 = ColorRect.new()
	sep2.color = Color(0.4, 0.4, 0.4, 0.5)
	sep2.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep2)

	# 总计攻击力
	_total_power_label = Label.new()
	_total_power_label.text = "总计攻击力: 0"
	_total_power_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_total_power_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_total_power_label)

	# 按钮行
	var btn_hbox = HBoxContainer.new()
	btn_hbox.custom_minimum_size = Vector2(0, 40)
	btn_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_hbox)

	_confirm_btn = Button.new()
	_confirm_btn.text = "出发!"
	_confirm_btn.custom_minimum_size = Vector2(140, 36)
	_confirm_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	_confirm_btn.add_theme_color_override("button_normal", ACCENT_COLOR)
	_confirm_btn.add_theme_color_override("button_hover", Color(1.0, 0.5, 0.15, 1.0))
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	btn_hbox.add_child(_confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(80, 36)
	cancel_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	cancel_btn.add_theme_color_override("button_normal", Color(0.4, 0.3, 0.3, 1.0))
	cancel_btn.add_theme_color_override("button_hover", Color(0.5, 0.4, 0.4, 1.0))
	cancel_btn.pressed.connect(_on_cancel_pressed)
	btn_hbox.add_child(cancel_btn)

	refresh_all()

func add_troop_row(parent: VBoxContainer, troop_type: int):
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 34)
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var info = {}
	_troop_rows[troop_type] = info
	info["row"] = row

	# 图标
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex_path = TroopData.get_texture_path(troop_type)
	if ResourceLoader.exists(tex_path):
		icon.texture = load(tex_path)
	row.add_child(icon)

	# 兵种名称+属性
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = TroopData.get_troop_name(troop_type)
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	name_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(name_label)

	var stats = TroopData.get_base_stats(troop_type, 1)
	var stats_text = "攻:%d 防:%d HP:%d 速:%.0f" % [stats.get("attack", 0), stats.get("defense", 0), stats.get("hp", 0), stats.get("speed", 0.0)]
	stats_text += "  库存:%d" % (_barracks_manager.get_troop_count(troop_type) if _barracks_manager else 0)
	var stats_label = Label.new()
	stats_label.text = stats_text
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	stats_label.add_theme_font_size_override("font_size", 9)
	info_vbox.add_child(stats_label)

	# 调整控件
	var controls = HBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_SHRINK_END
	controls.add_theme_constant_override("separation", 4)
	row.add_child(controls)

	# 减按钮
	var minus_btn = Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(24, 24)
	minus_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	minus_btn.add_theme_color_override("button_normal", Color(0.4, 0.3, 0.3, 1.0))
	minus_btn.pressed.connect(_on_adjust.bind(troop_type, -1))
	controls.add_child(minus_btn)
	info["minus_btn"] = minus_btn

	# 数量
	var count_label = Label.new()
	count_label.text = "0"
	count_label.custom_minimum_size = Vector2(30, 24)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_color_override("font_color", TEXT_COLOR)
	count_label.add_theme_font_size_override("font_size", 13)
	controls.add_child(count_label)
	info["count_label"] = count_label

	# 加按钮
	var plus_btn = Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(24, 24)
	plus_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	plus_btn.add_theme_color_override("button_normal", Color(0.3, 0.4, 0.3, 1.0))
	plus_btn.pressed.connect(_on_adjust.bind(troop_type, 1))
	controls.add_child(plus_btn)
	info["plus_btn"] = plus_btn

func _on_adjust(troop_type: int, delta: int):
	var current = _deployment.get(troop_type, 0)
	var new_val = current + delta
	if new_val < 0:
		new_val = 0
	# 上限：兵营库存
	var max_count = _barracks_manager.get_troop_count(troop_type) if _barracks_manager else 999
	if new_val > max_count:
		new_val = max_count
	_deployment[troop_type] = new_val
	refresh_troop_row(troop_type)
	refresh_total()

func refresh_troop_row(troop_type: int):
	var info = _troop_rows.get(troop_type)
	if not info:
		return
	var is_unlocked = _barracks_manager and _barracks_manager.is_troop_unlocked(troop_type)
	var has_stock = _barracks_manager and _barracks_manager.get_troop_count(troop_type) > 0
	var can_use = is_unlocked and has_stock

	info["minus_btn"].disabled = not can_use and _deployment.get(troop_type, 0) == 0
	info["plus_btn"].disabled = not can_use
	var count = _deployment.get(troop_type, 0)
	info["count_label"].text = str(count)
	info["row"].modulate = Color(1, 1, 1) if can_use or count > 0 else Color(0.5, 0.5, 0.5)

func refresh_total():
	var total_power := 0
	var total_count := 0
	for troop_type in _deployment.keys():
		var count = _deployment.get(troop_type, 0)
		if count <= 0:
			continue
		var stats = TroopData.get_base_stats(troop_type, 1)
		total_power += stats.get("attack", 10) * count
		total_count += count

	if _total_power_label:
		_total_power_label.text = "总计攻击力: %d  (总兵力: %d)" % [total_power, total_count]
	if _confirm_btn:
		_confirm_btn.disabled = (total_count == 0)

func refresh_all():
	for t in range(TroopData.TROOP_COUNT):
		refresh_troop_row(t)
	refresh_total()

func _on_confirm_pressed():
	var deploy_data = {}
	for t in range(TroopData.TROOP_COUNT):
		var count = _deployment.get(t, 0)
		if count > 0:
			deploy_data[t] = count
	if deploy_data.is_empty():
		return
	# 从兵营消耗兵力
	if _barracks_manager:
		for t in deploy_data.keys():
			_barracks_manager.consume_troops(t, deploy_data[t])
	emit_signal("attack_confirmed", deploy_data)

func _on_cancel_pressed():
	emit_signal("cancelled")

func clear_children():
	for c in get_children():
		c.queue_free()
	_troop_rows.clear()
