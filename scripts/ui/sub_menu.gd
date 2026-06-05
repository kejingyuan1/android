# SubMenu.gd — 工具子菜单面板
# 选中主工具类别时弹出，展示该类别下的具体变体选项

extends ColorRect

signal variant_selected(variant_id: int)

var _buttons: Array = []
var _title_label: Label = null

## 子菜单配置：[{icon, label, id, cost, desc}]
var _current_variants: Array = []

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_create_ui()

func _create_ui():
	color = Color(0.08, 0.08, 0.12, 0.95)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1280, 90)
	position = Vector2(0, 476)
	z_index = 50

	# 标题行
	_title_label = Label.new()
	_title_label.position = Vector2(12, 6)
	_title_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_title_label.add_theme_font_size_override("font_size", 12)
	add_child(_title_label)

## 显示子菜单
func show_menu(title: String, variants: Array):
	_title_label.text = title
	_current_variants = variants
	_clear_buttons()

	var hbox = HBoxContainer.new()
	hbox.position = Vector2(8, 26)
	hbox.size = Vector2(704, 70)
	hbox.add_theme_constant_override("separation", 6)
	add_child(hbox)

	for v in variants:
		var container = VBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var btn = Button.new()
		btn.text = v.icon
		btn.custom_minimum_size = Vector2(0, 42)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.add_theme_color_override("button_normal", Color(0.25, 0.25, 0.35))
		btn.add_theme_color_override("button_hover", Color(0.35, 0.35, 0.45))
		btn.add_theme_color_override("button_pressed", Color(0.2, 0.2, 0.3))
		btn.connect("pressed", Callable(self, "_on_variant_pressed").bind(v.id))
		container.add_child(btn)

		var lbl = Label.new()
		lbl.text = v.label
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		lbl.add_theme_font_size_override("font_size", 10)
		container.add_child(lbl)

		var cost_lbl = Label.new()
		cost_lbl.text = "💰" + str(v.cost)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.3))
		cost_lbl.add_theme_font_size_override("font_size", 9)
		container.add_child(cost_lbl)

		hbox.add_child(container)
		_buttons.append(btn)

	visible = true

func hide_menu():
	visible = false
	_clear_buttons()

func _clear_buttons():
	_buttons = []
	for child in get_children():
		if child is HBoxContainer:
			child.queue_free()

func _on_variant_pressed(variant_id: int):
	emit_signal("variant_selected", variant_id)
	hide_menu()
