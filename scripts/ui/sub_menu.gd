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
		var variant_id = v.id

		# 用 Button 作为整个可点击项，不使用 VBoxContainer
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(64, 86)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

		# 设置图标
		var tex = _load_texture(v.texture_file)
		if tex:
			btn.icon = tex

		# 设置文字（名称 + 成本）
		btn.text = v.label + "\n💰" + str(v.cost)
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		btn.add_theme_color_override("font_hover_color", Color(0.9, 0.9, 1.0))

		# 透明样式
		var bg_norm = StyleBoxEmpty.new()
		var bg_hover = StyleBoxFlat.new()
		bg_hover.bg_color = Color(0.35, 0.35, 0.45, 0.4)
		bg_hover.corner_radius_top_left = 4
		bg_hover.corner_radius_top_right = 4
		bg_hover.corner_radius_bottom_left = 4
		bg_hover.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", bg_norm)
		btn.add_theme_stylebox_override("hover", bg_hover)
		btn.add_theme_stylebox_override("pressed", bg_hover)

		btn.pressed.connect(_on_variant_pressed.bind(v.id))

		hbox.add_child(btn)
		_buttons.append({"btn": btn, "id": v.id})

	# 如果当前有已选中的建筑，恢复高亮
	_update_selection()

	visible = true

## 更新选中高亮
func _update_selection():
	for entry in _buttons:
		var is_selected = (entry["id"] == _selected_variant_id)
		var btn = entry["btn"] as Button
		if not btn:
			continue
		if is_selected:
			var bg_sel = StyleBoxFlat.new()
			bg_sel.bg_color = Color(0.4, 0.6, 0.4, 0.5)
			bg_sel.corner_radius_top_left = 4
			bg_sel.corner_radius_top_right = 4
			bg_sel.corner_radius_bottom_left = 4
			bg_sel.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("normal", bg_sel)
		else:
			btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())

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
	# 加载 spritesheet 中的水平道路格作为预览
	var png_file = road_type.replace("road_", "") + "_sheet.png"
	var png_path = "res://assets/textures/roads/%s" % png_file
	if ResourceLoader.exists(png_path):
		var img = load(png_path).get_image()
		if img:
			var tile = Image.create(32, 32, false, Image.FORMAT_RGBA8)
			tile.blit_rect(img, Rect2i(0, 0, 32, 32), Vector2i(0, 0))
			tile.resize(size, size, Image.INTERPOLATE_NEAREST)
			return ImageTexture.create_from_image(tile)

	# 回退：程序生成
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var color = Color(0.55, 0.45, 0.3)
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
					c = Color(0.85, 0.85, 0.85)
			else:
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
	# 先显示 0.5 秒高亮让用户看到选中了什么，再延迟隐藏
	call_deferred("_flash_selection_then_hide")

func _flash_selection_then_hide():
	var tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(_deferred_hide)

func _deferred_hide():
	visible = false
	_clear_buttons()
