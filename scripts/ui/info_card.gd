# InfoCard.gd — 建筑信息卡（含升级按钮）
extends ColorRect

var _gm: Node = null
var _title_label: Label = null
var _detail_label: Label = null
var _upgrade_btn: Button = null
var _close_btn: Button = null
var _target_cell = null
var _target_pos: Vector2i

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	_create_ui()

func _create_ui():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1280, 110)
	position = Vector2(0, 456)
	color = Color(0.1, 0.1, 0.15, 0.95)
	
	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("margin_left", 16)
	vbox.add_theme_constant_override("margin_right", 16)
	vbox.add_theme_constant_override("margin_top", 8)
	vbox.add_theme_constant_override("margin_bottom", 8)
	add_child(vbox)

	var top = HBoxContainer.new()
	vbox.add_child(top)

	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title_label)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.custom_minimum_size = Vector2(32, 32)
	_close_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_close_btn.add_theme_color_override("button_normal", Color(0.3, 0.15, 0.15))
	_close_btn.add_theme_color_override("button_hover", Color(0.4, 0.2, 0.2))
	_close_btn.connect("pressed", Callable(self, "hide"))
	top.add_child(_close_btn)

	_detail_label = Label.new()
	_detail_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_detail_label.add_theme_font_size_override("font_size", 13)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_detail_label)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	vbox.add_child(btn_hbox)

	_upgrade_btn = Button.new()
	_upgrade_btn.text = "⬆ 升级（100💰）"
	_upgrade_btn.custom_minimum_size = Vector2(160, 30)
	_upgrade_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	_upgrade_btn.add_theme_color_override("button_normal", Color(0.2, 0.5, 0.25))
	_upgrade_btn.add_theme_color_override("button_hover", Color(0.25, 0.6, 0.3))
	_upgrade_btn.connect("pressed", Callable(self, "_on_upgrade_pressed"))
	btn_hbox.add_child(_upgrade_btn)

func show_building_info(cell_pos: Vector2i, cell):
	if not cell or not cell.has_building or not cell.building_ref:
		hide()
		return
	_target_cell = cell
	_target_pos = cell_pos
	var info = cell.building_ref.get_building_info()
	
	_title_label.text = "%s (Lv.%d)" % [info.get("type_name", "建筑"), info.get("level", 1)]
	
	var details = "位置: (%d, %d)" % [cell_pos.x, cell_pos.y]
	match cell.terrain:
		2: details += "\n人口: %d" % info.get("population", 0)
		3: details += "\n收入: %d/tick" % info.get("revenue", 0)
		4: details += "\n就业: %d" % info.get("jobs", 0)
	
	var max_level = info.get("max_level", 3)
	details += "\n当前等级: %d/%d" % [info.get("level", 1), max_level]
	
	_detail_label.text = details
	
	if info.get("level", 1) >= max_level:
		_upgrade_btn.disabled = true
		_upgrade_btn.text = "✓ 已满级"
	elif _gm and _gm.economy:
		var cost = 100 * info.get("level", 1)
		_upgrade_btn.disabled = not _gm.economy.can_afford(cost)
		_upgrade_btn.text = "⬆ 升级（%d💰）" % cost
	
	show()

func _on_upgrade_pressed():
	if not _target_cell or not _gm:
		return
	_gm.try_upgrade_building(_target_pos, _target_cell)
	hide()
