# TopBar.gd — 顶部状态栏
# 显示金钱、人口、游戏速度控制、时间/世界地图切换

extends ColorRect

var _gm: Node = null

## UI 元素引用
var _money_label: Label = null
var _pop_label: Label = null
var _speed_buttons: Array = []
var _speed_indicators: Array = []
var _world_map_btn: Button = null  # 太阳/月亮按钮，点击返回世界地图

## 时间系统
var _game_hour: float = 8.0        # 起始时间：早上 8 点
var _day_length: float = 120.0     # 每完整昼夜 = 120 游戏秒

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	_create_ui()

func _create_ui():
	var hbox = HBoxContainer.new()
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	add_child(hbox)

	# ===== 世界地图按钮（太阳/月亮 图标，点击返回超级大地图） =====
	_world_map_btn = Button.new()
	_world_map_btn.text = "☀️"
	_world_map_btn.custom_minimum_size = Vector2(44, 44)
	_world_map_btn.add_theme_color_override("font_color", Color(1, 1, 0.8))
	_world_map_btn.add_theme_color_override("button_normal", Color(0.15, 0.15, 0.25))
	_world_map_btn.add_theme_color_override("button_hover", Color(0.25, 0.25, 0.35))
	_world_map_btn.tooltip_text = "返回世界地图"
	_world_map_btn.connect("pressed", Callable(self, "_on_world_map_pressed"))
	hbox.add_child(_world_map_btn)

	# 货币
	var money_icon = Label.new()
	money_icon.text = "💰"
	money_icon.custom_minimum_size = Vector2(28, 52)
	hbox.add_child(money_icon)

	_money_label = Label.new()
	_money_label.text = "100,000"
	_money_label.custom_minimum_size = Vector2(100, 52)
	_money_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	_money_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(_money_label)

	# 人口
	var pop_icon = Label.new()
	pop_icon.text = "👥"
	pop_icon.custom_minimum_size = Vector2(28, 52)
	hbox.add_child(pop_icon)

	_pop_label = Label.new()
	_pop_label.text = "0"
	_pop_label.custom_minimum_size = Vector2(80, 52)
	_pop_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_pop_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(_pop_label)

	# 弹性空间
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# 速度控制
	var speeds = ["⏸", "▶", "▶▶"]
	for i in range(3):
		var btn = Button.new()
		btn.text = speeds[i]
		btn.custom_minimum_size = Vector2(44, 44)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.add_theme_color_override("button_normal", Color(0.2, 0.2, 0.3))
		btn.add_theme_color_override("button_hover", Color(0.3, 0.3, 0.4))
		btn.add_theme_color_override("button_pressed", Color(0.15, 0.15, 0.2))
		btn.connect("pressed", Callable(self, "_on_speed_pressed").bind(i))
		hbox.add_child(btn)
		_speed_buttons.append(btn)
		_speed_indicators.append(btn)

	# 默认高亮 1x
	_update_speed_highlight(1)

	# 保存按钮
	var save_btn = Button.new()
	save_btn.text = "💾"
	save_btn.custom_minimum_size = Vector2(44, 44)
	save_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	save_btn.add_theme_color_override("button_normal", Color(0.2, 0.2, 0.3))
	save_btn.add_theme_color_override("button_hover", Color(0.3, 0.3, 0.4))
	save_btn.connect("pressed", Callable(self, "_on_save_pressed"))
	hbox.add_child(save_btn)

func _ready_after_gm():
	if _gm:
		_gm.connect("money_changed", Callable(self, "_on_money_changed"))
		_on_money_changed(_gm.economy.money)

func _on_money_changed(amount: float):
	if _money_label:
		_money_label.text = _format_money(amount)

func _on_speed_pressed(speed_idx: int):
	if _gm:
		_gm.set_speed(speed_idx)
		_update_speed_highlight(speed_idx)

func _on_save_pressed():
	if _gm:
		_gm.save_game()

func _update_speed_highlight(active_idx: int):
	for i in range(3):
		if _speed_buttons[i]:
			_speed_buttons[i].add_theme_color_override("button_normal",
				Color(0.3, 0.3, 0.4) if i == active_idx else Color(0.2, 0.2, 0.3))

## 更新人口显示
func update_population(pop: int):
	if _pop_label:
		_pop_label.text = str(pop)

func _format_money(amount: float) -> String:
	if amount >= 10000:
		return "%d" % int(amount)
	elif amount >= 1000:
		return "%.1fK" % (amount / 1000.0)
	return "%d" % int(amount)

func _process(delta):
	if not _gm:
		_gm = get_node("/root/Main/GameManager")
		if _gm:
			_ready_after_gm()

	# 更新时间系统
	_update_time(delta)

## 更新游戏内时间
func _update_time(delta):
	if _gm and _gm.current_speed != _gm.Speed.PAUSED:
		var speed_mult = 2.0 if _gm.current_speed == _gm.Speed.FAST else 1.0
		_game_hour += delta * speed_mult * (24.0 / _day_length)
		if _game_hour >= 24.0:
			_game_hour -= 24.0

	# 更新图标：白天 ☀️，晚上 🌙
	if _world_map_btn:
		if _game_hour >= 6.0 and _game_hour < 18.0:
			_world_map_btn.text = "☀️"
			_world_map_btn.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
		else:
			_world_map_btn.text = "🌙"
			_world_map_btn.add_theme_color_override("font_color", Color(0.6, 0.7, 1.0))

## 点击世界地图按钮 → 返回超级大地图
func _on_world_map_pressed():
	var global_game = get_node("/root/Main/GlobalGame")
	if global_game and global_game.has_method("exit_to_world_map"):
		print("通过时间按钮返回世界地图")
		global_game.exit_to_world_map()
