# WallBuilding.gd — 城墙（连接式）
extends Node2D

var cell_x = 0
var cell_y = 0
var hp = 1000
var max_hp = 1000
var _sprite = null
var _grid_map = null  # 由外部设置

func setup(gx, gy, grid_map_ref):
    cell_x = gx
    cell_y = gy
    _grid_map = grid_map_ref
    _sprite = Sprite2D.new()
    # 使用浅色矩形表示城墙（后续可替换为纹理）
    var img = Image.create(64, 32, false, Image.FORMAT_RGBA8)
    # 画一个浅灰色的菱形
    var cx = 32
    var cy = 16
    for y in range(32):
        for x in range(64):
            var dx = abs(x-cx)/float(cx)
            var dy = abs(y-cy)/float(cy)
            if dx + dy <= 1.0:
                img.set_pixel(x, y, Color(0.5, 0.4, 0.3, 1.0))
            else:
                img.set_pixel(x, y, Color(0,0,0,0))
    _sprite.texture = ImageTexture.create_from_image(img)
    _sprite.centered = true
    _sprite.z_index = 4
    add_child(_sprite)
    _update_connection()

func _update_connection():
    # 检查邻居
    var u = _is_wall(cell_x, cell_y - 1)
    var d = _is_wall(cell_x, cell_y + 1)
    var l = _is_wall(cell_x - 1, cell_y)
    var r = _is_wall(cell_x + 1, cell_y)
    # 连接越多颜色越暗（示意）
    var count = [u,d,l,r].count(true)
    var shade = 0.5 + count * 0.1
    if _sprite and _sprite.texture:
        var img = _sprite.texture.get_image()
        if img:
            for y in range(32):
                for x in range(64):
                    var dx = abs(x-32)/32.0
                    var dy = abs(y-16)/16.0
                    if dx + dy <= 1.0:
                        var px = img.get_pixel(x, y)
                        var c = Color(min(px.r * shade, 1.0), min(px.g * shade, 1.0), min(px.b * shade, 1.0))
                        img.set_pixel(x, y, c)
            _sprite.texture = ImageTexture.create_from_image(img)

func _is_wall(gx, gy):
    if _grid_map == null: return false
    var cell = _grid_map.get_cell(gx, gy)
    return cell != null and cell.has_building

func take_damage(dmg):
    hp -= dmg
    if hp <= 0:
        queue_free()

func _get_wall_key():
    return str(cell_x) + "_" + str(cell_y)
