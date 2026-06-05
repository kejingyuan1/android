# CityPopup.gd — 世界地图主城弹出菜单
extends Control

signal enter_city_pressed()
signal move_city_pressed()

var _target_world_pos := Vector2.ZERO
var _is_showing := false
var _panel: Panel
var _enter_btn: Button
var _move_btn: Button

const POPUP_W := 200
const POPUP_H := 110

func _ready():
	# 填满整个屏幕，确保 _input 中 event.position 与 _panel.position 在同一坐标系
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP

	_panel = Panel.new()
	_panel.size = Vector2(POPUP_W, POPUP_H)
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size = Vector2(POPUP_W, POPUP_H)
	vbox.position = Vector2(4, 4)
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	# 标题：城市名称
	var title_lbl = Label.new()
	title_lbl.name = "Title"
	title_lbl.text = ""
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.custom_minimum_size = Vector2(POPUP_W - 8, 22)
	vbox.add_child(title_lbl)

	# 分隔线
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# 进入主城
	_enter_btn = Button.new()
	_enter_btn.name = "EnterBtn"
	_enter_btn.text = "🏙 进入主城"
	_enter_btn.size = Vector2(POPUP_W - 8, 28)
	_enter_btn.pressed.connect(_on_enter)
	vbox.add_child(_enter_btn)

	# 移动主城
	_move_btn = Button.new()
	_move_btn.name = "MoveBtn"
	_move_btn.text = "📌 移动主城"
	_move_btn.size = Vector2(POPUP_W - 8, 28)
	_move_btn.pressed.connect(_on_move)
	vbox.add_child(_move_btn)

	hide()

func _input(event):
	if not _is_showing:
		return
	
	# 鼠标/触屏按下
	if event is InputEventMouseButton and event.pressed:
		var panel_rect = Rect2(_panel.position, _panel.size)
		if panel_rect.has_point(event.position):
			# 在面板内——不做任何操作，让事件自然传递给子控件（按钮）
			pass
		else:
			# 点击面板外 → 关闭
			dismiss()
			get_viewport().set_input_as_handled()
		return
	
	# 触屏
	if event is InputEventScreenTouch and event.pressed:
		var panel_rect = Rect2(_panel.position, _panel.size)
		if panel_rect.has_point(event.position):
			pass
		else:
			dismiss()
			get_viewport().set_input_as_handled()
		return

func is_showing() -> bool:
	return _is_showing

func show_at(world_pos: Vector2, city_name: String) -> void:
	_target_world_pos = world_pos
	_is_showing = true
	
	# 立即设置面板位置
	var screen_pos = get_viewport().get_canvas_transform() * world_pos
	var vp_size = get_viewport().get_visible_rect().size
	var px = screen_pos.x - POPUP_W * 0.5
	var py = screen_pos.y + 30
	px = clampf(px, 8, vp_size.x - POPUP_W - 8)
	py = clampf(py, 8, vp_size.y - POPUP_H - 8)
	_panel.position = Vector2(px, py)
	
	# 更新标题
	var title = _panel.get_node("VBox/Title") as Label
	if title:
		title.text = city_name
	
	show()

func dismiss() -> void:
	_is_showing = false
	hide()

func _on_enter() -> void:
	dismiss()
	enter_city_pressed.emit()

func _on_move() -> void:
	dismiss()
	move_city_pressed.emit()
