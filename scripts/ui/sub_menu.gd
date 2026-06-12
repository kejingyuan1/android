# SubMenu.gd — 工具子菜单面板
# 选中主工具类别时弹出，以建筑纹理图标 + 名称 + 成本展示所有变体

extends ColorRect

signal variant_selected(variant_id: int)

var _buttons: Array = []
var _title_label: Label = null
var _current_variants: Array = []
var _selected_variant_id: int = -1    # 当前选中项

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_create_ui()

func _create_ui():
	color = Color(0.08, 0.08, 0.12, 0.95)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1280, 120)
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

	# 水平滚动区域
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(8, 24)
	scroll.size = Vector2(1260, 92)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 8)
	scroll.add_child(hbox)

	for v in variants:
		var container = VBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.custom_minimum_size = Vector2(64, 88)
		container.alignment = VBoxContainer.ALIGNMENT_CENTER

		# 建筑纹理图标 48x48
		var tex_rect = TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(48, 48)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var tex = _load_texture(v.texture_file)
		if tex:
			tex_rect.texture = tex
		container.add_child(tex_rect)

		# 建筑名称
		var lbl = Label.new()
		lbl.text = v.label
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		lbl.add_theme_font_size_override("font_size", 10)
		container.add_child(lbl)

		# 成本
		var cost_lbl = Label.new()
		cost_lbl.text = "💰" + str(v.cost)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.3))
		cost_lbl.add_theme_font_size_override("font_size", 9)
		container.add_child(cost_lbl)

		# 用 ColorRect 作为背景，点击用透明按钮覆盖
		var btn = Button.new()
		btn.text = ""
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_color_override("font_color", Color(0, 0, 0, 0))
		btn.add_theme_stylebox_override("normal", _make_transparent_style(Color(0.25, 0.25, 0.35, 0.0)))
		btn.add_theme_stylebox_override("hover", _make_transparent_style(Color(0.35, 0.35, 0.45, 0.4)))
		btn.add_theme_stylebox_override("pressed", _make_transparent_style(Color(0.2, 0.2, 0.3, 0.5)))
		btn.pressed.connect(_on_variant_pressed.bind(v.id))
		container.add_child(btn)

		hbox.add_child(container)
		_buttons.append({"btn": btn, "container": container, "id": v.id})

	# 如果当前有已选中的建筑，恢复高亮
	_update_selection()

	visible = true

## 更新选中高亮
func _update_selection():
	for entry in _buttons:
		var is_selected = (entry["id"] == _selected_variant_id)
		var style = _make_transparent_style(Color(0.4, 0.6, 0.4, 0.35) if is_selected else Color(0.25, 0.25, 0.35, 0.0))
		entry["btn"].add_theme_stylebox_override("normal", style)
		entry["btn"].add_theme_stylebox_override("hover", _make_transparent_style(Color(0.35, 0.35, 0.45, 0.4)))

## 创建透明点击样式
func _make_transparent_style(bg_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	return style

## 加载纹理：道路类型使用程序生成，建筑使用 PNG 贴图
func _load_texture(texture_file: String) -> Texture2D:
	if texture_file.begins_with("road_"):
		return _create_road_texture(texture_file)

	var tex_path = "res://assets/textures/buildings/%s.png" % texture_file
	if ResourceLoader.exists(tex_path):
		return load(tex_path)
	return null

## 为道路类型生成预览纹理（48x48）
func _create_road_texture(road_type: String) -> Texture2D:
	var size = 48
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var color = Color(0.55, 0.45, 0.3)  # 土路
	if road_type == "road_asphalt":
		color = Color(0.25, 0.25, 0.25)
	elif road_type == "road_highway":
		color = Color(0.12, 0.12, 0.12)

	for y in range(size):
		for x in range(size):
			var c = color
			if road_type == "road_asphalt" or road_type == "road_highway":
				var mid = size / 2
				var dash = (y / 6) % 2 == 0
				if abs(x - mid) < 2 and dash:
					c = Color(0.85, 0.85, 0.85)  # 白色虚线
			else:
				# 土路：两侧草边
				if x < 2 or x > size - 3:
					c = Color(0.3, 0.55, 0.2)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func hide_menu():
	visible = false
	_clear_buttons()

func _clear_buttons():
	_buttons = []
	for child in get_children():
		if child is ScrollContainer:
			child.queue_free()

func _on_variant_pressed(variant_id: int):
	_selected_variant_id = variant_id
	_update_selection()
	emit_signal("variant_selected", variant_id)
	# 延迟隐藏菜单，让当前点击事件先经过 _input，但 _is_ui_event 仍能识别
	call_deferred("_deferred_hide")

func _deferred_hide():
	visible = false
	_clear_buttons()
