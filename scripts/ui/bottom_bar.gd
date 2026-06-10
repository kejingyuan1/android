# BottomBar.gd — 底部主工具栏（三大主类别 + 子菜单变体）
extends ColorRect

signal main_category_selected(category_id: int)

## 三大主类别
enum Category {
	BASIC = 0,    # 基本民生
	PUBLIC = 1,   # 公共
	TECH = 2,     # 科技
}

var _gm: Node = null
var current_category := -1
var _buttons: Array = []

const CATEGORIES := [
	{"icon": "⚒️", "label": "基本民生", "id": Category.BASIC},
	{"icon": "🏙️", "label": "公共", "id": Category.PUBLIC},
	{"icon": "🔬", "label": "科技", "id": Category.TECH},
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
		btn.text = cat.icon + "  " + cat.label
		btn.custom_minimum_size = Vector2(0, 50)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.add_theme_color_override("button_normal", Color(0.2, 0.2, 0.3))
		btn.add_theme_color_override("button_hover", Color(0.3, 0.3, 0.4))
		btn.connect("pressed", Callable(self, "_on_category_pressed").bind(cat.id))
		container.add_child(btn)

		hbox.add_child(container)
		_buttons.append(btn)

func _on_category_pressed(cat_id: int):
	if current_category == cat_id:
		current_category = -1
		_update_button_states()
		emit_signal("main_category_selected", -1)
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

## 获取当前类别对应的子菜单变体列表
func get_variants_for_category(cat_id: int) -> Dictionary:
	match cat_id:
		Category.BASIC:
			return {
				"title": "基本民生 - 选择建筑",
				"variants": [
					{"texture_file": "road_dirt", "label": "土路", "id": 0, "cost": 10},
					{"texture_file": "road_asphalt", "label": "沥青路", "id": 1, "cost": 50},
					{"texture_file": "road_highway", "label": "高速路", "id": 2, "cost": 200},
					{"texture_file": "power_plant", "label": "电力", "id": 1000, "cost": 500},
					{"texture_file": "farm", "label": "农场", "id": 1001, "cost": 200},
					{"texture_file": "water_pump", "label": "水", "id": 1002, "cost": 300},
				]
			}
		Category.PUBLIC:
			return {
				"title": "公共 - 选择建筑",
				"variants": [
					{"texture_file": "house1", "label": "住宅", "id": 2000, "cost": 100},
					{"texture_file": "shop", "label": "商业", "id": 2001, "cost": 300},
					{"texture_file": "trade_post", "label": "贸易", "id": 2002, "cost": 400},
					{"texture_file": "office", "label": "办公", "id": 2003, "cost": 500},
					{"texture_file": "factory", "label": "工厂", "id": 2004, "cost": 600},
				]
			}
		Category.TECH:
			return {
				"title": "科技 - 选择建筑",
				"variants": [
					{"texture_file": "barracks", "label": "兵营", "id": 3000, "cost": 800},
					{"texture_file": "lab", "label": "实验室", "id": 3001, "cost": 1000},
					{"texture_file": "fire_station", "label": "消防", "id": 3002, "cost": 700},
					{"texture_file": "hospital", "label": "医院", "id": 3003, "cost": 1200},
					{"texture_file": "police", "label": "警局", "id": 3004, "cost": 900},
				]
			}
	return {"title": "", "variants": []}
