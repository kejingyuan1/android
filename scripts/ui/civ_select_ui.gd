# CivSelectUI.gd — 文明选择界面（带文明背景图）
extends ColorRect

signal civilization_selected(civ_id: int)

var _buttons: Array = []
var _global_game: Node = null

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	_create_ui()

func _create_ui():
	color = Color(0.05, 0.05, 0.1, 1.0)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1280, 720)

	# 标题
	var title = Label.new()
	title.text = "选择你的文明"
	title.position = Vector2(500, 15)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_constant_override("outline_size", 1)
	add_child(title)

	# 文明卡片列表
	var civs = [
		{"id": 0, "name": "中国", "file": "china", "color": Color(0.9, 0.2, 0.15), "desc": "飞檐琉璃·千年帝都"},
		{"id": 1, "name": "罗马", "file": "rome", "color": Color(0.7, 0.2, 0.5), "desc": "石柱拱门·帝国荣光"},
		{"id": 2, "name": "英国", "file": "britain", "color": Color(0.2, 0.4, 0.7), "desc": "城堡塔楼·工业先驱"},
		{"id": 3, "name": "埃及", "file": "egypt", "color": Color(0.85, 0.7, 0.2), "desc": "金字塔下·尼罗河谷"},
		{"id": 4, "name": "日本", "file": "japan", "color": Color(0.8, 0.2, 0.2), "desc": "富士山雪·樱花烂漫"},
		{"id": 5, "name": "维京", "file": "viking", "color": Color(0.2, 0.5, 0.3), "desc": "峡湾长船·北欧荣光"},
	]

	var start_x = 20
	var start_y = 60
	var card_w = 200
	var card_h = 310
	var gap = 8

	for i in range(civs.size()):
		var c = civs[i]
		var x = start_x + i * (card_w + gap)
		var y = start_y

		# 卡片容器
		var card = ColorRect.new()
		card.color = Color(0.08, 0.08, 0.14, 0.95)
		card.size = Vector2(card_w, card_h)
		card.position = Vector2(x, y)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(card)

		# 文明背景图
		var bg_path = "res://assets/textures/civ_bg/civ_bg_" + c.file + ".png"
		print("[TEX_LOAD] 文明背景纹理: ", bg_path, " 存在=", ResourceLoader.exists(bg_path))
		var bg_tex = load(bg_path)
		if bg_tex:
			print("[TEX_LOAD]   加载成功: 尺寸=", bg_tex.get_width(), "x", bg_tex.get_height())
			var bg_rect = TextureRect.new()
			bg_rect.texture = bg_tex
			bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			bg_rect.size = Vector2(card_w, 130)
			bg_rect.position = Vector2(0, 0)
			card.add_child(bg_rect)

		# 半透明遮罩（让文字更清晰）
		var overlay = ColorRect.new()
		overlay.color = Color(0.08, 0.08, 0.14, 0.55)
		overlay.size = Vector2(card_w, 130)
		overlay.position = Vector2(0, 0)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(overlay)

		# 文明名称（覆盖在背景图上）
		var name_lbl = Label.new()
		name_lbl.text = c.name
		name_lbl.position = Vector2(10, 95)
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", c.color)
		card.add_child(name_lbl)

		# 描述文字
		var desc_lbl = Label.new()
		desc_lbl.text = c.desc
		desc_lbl.position = Vector2(10, 125)
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		card.add_child(desc_lbl)

		# 分隔线
		var line = ColorRect.new()
		line.color = Color(0.3, 0.3, 0.4, 0.5)
		line.size = Vector2(card_w - 20, 1)
		line.position = Vector2(10, 145)
		card.add_child(line)

		# 文明特色标签
		var feature_labels = []
		match c.id:
			0: feature_labels = ["城墙", "陶瓷", "丝绸"]
			1: feature_labels = ["道路", "大理石", "法典"]
			2: feature_labels = ["工业", "纺织", "贸易"]
			3: feature_labels = ["农业", "纸莎草", "香料"]
			4: feature_labels = ["渔业", "漆器", "武士"]
			5: feature_labels = ["航海", "木材", "毛皮"]

		var flb_y = 155
		for j in range(feature_labels.size()):
			var flb = Label.new()
			flb.text = "▪ " + feature_labels[j]
			flb.position = Vector2(12, flb_y + j * 18)
			flb.add_theme_font_size_override("font_size", 11)
			flb.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
			card.add_child(flb)

		# 选择按钮
		var btn = Button.new()
		btn.text = "选 择"
		btn.position = Vector2(15, 260)
		btn.custom_minimum_size = Vector2(170, 38)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.add_theme_color_override("button_normal", c.color * 1.2)
		btn.add_theme_color_override("button_hover", c.color.lightened(0.2))
		btn.add_theme_color_override("button_pressed", c.color.darkened(0.3))
		btn.add_theme_font_size_override("font_size", 14)
		btn.connect("pressed", Callable(self, "_on_civ_selected").bind(c.id))
		card.add_child(btn)

		_buttons.append(btn)

func _on_civ_selected(civ_id: int):
	print("文明被选择: ", civ_id)
	visible = false
	emit_signal("civilization_selected", civ_id)
