# BuildingInfoPanel.gd — 点击建筑显示信息
extends CanvasLayer

var _panel = null
var _name_label = null
var _info_label = null
var _close_btn = null

func _ready():
    # 信息浮窗
    _panel = ColorRect.new()
    _panel.color = Color(0.1, 0.1, 0.15, 0.95)
    _panel.size = Vector2(200, 160)
    _panel.position = Vector2(540, 260)
    _panel.z_index = 100
    _panel.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_panel)
    _panel.visible = false
    
    _name_label = Label.new()
    _name_label.position = Vector2(10, 10)
    _name_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
    _name_label.add_theme_font_size_override("font_size", 16)
    _panel.add_child(_name_label)
    
    _info_label = Label.new()
    _info_label.position = Vector2(10, 36)
    _info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
    _info_label.add_theme_font_size_override("font_size", 12)
    _panel.add_child(_info_label)

func show_building_info(cell):
    if not cell or not cell.has_building:
        hide_panel()
        return
    _panel.visible = true
    _name_label.text = "建筑信息"
    var info_text = ""
    info_text += "等级: " + str(cell.building_level) + "\n"
    info_text += "占地: " + str(cell.building_size_x) + "x" + str(cell.building_size_y) + "\n"
    # 如果是防御建筑显示攻击属性
    if cell.building_ref and cell.building_ref.has_method("is_in_group"):
        info_text += "类型: 防御建筑\n"
    # 显示资源信息
    if cell.building_ref and cell.building_ref.has_method("get_collectable_amount"):
        var stored = cell.building_ref.get_collectable_amount()
        var capacity = cell.building_ref.get_capacity() if cell.building_ref.has_method("get_capacity") else 0
        info_text += "存储: " + str(stored) + "/" + str(capacity) + "\n"
        # 如果有可收集资源，显示收集按钮
        if stored > 0:
            info_text += "\n[点击收集]"
    _info_label.text = info_text

func hide_panel():
    if _panel:
        _panel.visible = false
