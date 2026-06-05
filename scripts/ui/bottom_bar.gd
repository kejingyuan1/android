# BottomBar.gd — 底部主工具栏（主菜单 + 子菜单变体）
extends ColorRect

signal main_category_selected(category_id: int)

## 主菜单类别
enum Category {
	NONE = -1,
	ROAD = 1,
	ZONE = 2,
	SERVICE = 3,
	TOOLS = 4,
}

var _gm: Node = null
var current_category := Category.NONE
var _buttons: Array = []

const CATEGORIES := [
	{"icon": "🛣️", "label": "道路", "id": Category.ROAD},
	{"icon": "🏘️", "label": "分区", "id": Category.ZONE},
	{"icon": "🏛️", "label": "服务", "id": Category.SERVICE},
	{"icon": "🔧", "label": "工具", "id": Category.TOOLS},
]

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	_create_ui()

func _create_ui():
	var hbox = HBoxContainer.new()
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.add_theme_constant_override("separation", 10)
	add_child(hbox)

	for cat in CATEGORIES:
		var container = VBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var btn = Button.new()
		btn.text = cat.icon
		btn.custom_minimum_size = Vector2(0, 50)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 24)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.add_theme_color_override("button_normal", Color(0.2, 0.2, 0.3))
		btn.add_theme_color_override("button_hover", Color(0.3, 0.3, 0.4))
		btn.connect("pressed", Callable(self, "_on_category_pressed").bind(cat.id))
		container.add_child(btn)

		var lbl = Label.new()
		lbl.text = cat.label
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		lbl.add_theme_font_size_override("font_size", 12)
		container.add_child(lbl)

		hbox.add_child(container)
		_buttons.append(btn)

func _on_category_pressed(cat_id: int):
	if current_category == cat_id:
		current_category = Category.NONE
		_update_button_states()
		emit_signal("main_category_selected", Category.NONE)
		return
	current_category = cat_id
	_update_button_states()
	emit_signal("main_category_selected", cat_id)

func _update_button_states():
	for i in range(len(_buttons)):
		var cat = CATEGORIES[i]
		var is_active = (cat.id == current_category)
		_buttons[i].add_theme_color_override("button_normal",
			Color(0.4, 0.4, 0.55) if is_active else Color(0.2, 0.2, 0.3))

## 获取当前类别对应的子菜单变体
func get_variants_for_category(cat_id: int) -> Dictionary:
	match cat_id:
		Category.ROAD:
			return {
				"title": "选择道路类型",
				"variants": [
					{"icon": "🟫", "label": "土路", "id": 0, "cost": 10},
					{"icon": "⬛", "label": "沥青路", "id": 1, "cost": 50},
					{"icon": "🛤️", "label": "高速路", "id": 2, "cost": 200},
				]
			}
		Category.ZONE:
			return {
				"title": "选择分区类型",
				"variants": [
					{"icon": "🏠", "label": "低密度住宅", "id": 10, "cost": 0},
					{"icon": "🏢", "label": "高密度住宅", "id": 11, "cost": 0},
					{"icon": "🏪", "label": "商业", "id": 20, "cost": 0},
					{"icon": "🏭", "label": "工业", "id": 30, "cost": 0},
				]
			}
		Category.SERVICE:
			return {
				"title": "选择服务建筑",
				"variants": [
					{"icon": "🚔", "label": "警局", "id": 100, "cost": 2000},
					{"icon": "🚒", "label": "消防局", "id": 101, "cost": 1500},
					{"icon": "🏥", "label": "医院", "id": 102, "cost": 2500},
					{"icon": "🏫", "label": "学校", "id": 103, "cost": 3000},
				]
			}
		Category.TOOLS:
			return {
				"title": "工具",
				"variants": [
					{"icon": "🗑️", "label": "拆除", "id": 200, "cost": 0},
					{"icon": "ℹ️", "label": "信息查看", "id": 201, "cost": 0},
				]
			}
	return {"title": "", "variants": []}
