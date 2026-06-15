# RangeIndicator.gd — 防御塔攻击范围预览
extends Node2D

var _circle = null

func show_range(center_pos, radius):
    position = center_pos
    # 画一个半透明圆
    var img = Image.create(int(radius * 2), int(radius * 2), false, Image.FORMAT_RGBA8)
    var cx = radius
    var cy = radius
    for y in range(int(radius * 2)):
        for x in range(int(radius * 2)):
            var dist = Vector2(x - cx, y - cy).length()
            if dist < radius:
                var alpha = 0.0
                if dist > radius * 0.85:
                    alpha = 0.3  # 边缘线
                elif dist < radius * 0.7:
                    alpha = 0.08  # 内部淡色
                img.set_pixel(x, y, Color(1, 0.3, 0.1, alpha))
            else:
                img.set_pixel(x, y, Color(0, 0, 0, 0))
    var tex = ImageTexture.create_from_image(img)
    _circle = Sprite2D.new()
    _circle.texture = tex
    _circle.centered = true
    _circle.z_index = 60
    add_child(_circle)

func hide_range():
    if _circle:
        _circle.queue_free()
        _circle = null
