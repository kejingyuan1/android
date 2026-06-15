"""
生成带3D质感的等距道路纹理 (128x64 spritesheet, 4个子图块)
每个子图块 64x32 菱形
子图索引: 0=(0,0)=水平, 1=(1,0)=垂直, 2=(0,1)=十字, 3=(1,1)=孤岛
"""
from PIL import Image, ImageDraw, ImageFilter
import os
import random

TILE_W = 64
TILE_H = 32
CX = TILE_W // 2   # 32
CY = TILE_H // 2   # 16

def is_in_diamond(x, y, cx=CX, cy=CY):
    dx = abs(x - cx) / cx
    dy = abs(y - cy) / cy
    return dx + dy <= 1.0

def noise(base, amount=8):
    r = max(0, min(255, base[0] + random.randint(-amount, amount)))
    g = max(0, min(255, base[1] + random.randint(-amount, amount)))
    b = max(0, min(255, base[2] + random.randint(-amount, amount)))
    return (r, g, b)

# ===== 道路样式定义 =====

ROAD_STYLES = {
    "dirt": {
        "surface": (160, 130, 85),     # 土路色
        "curb": (190, 170, 120),       # 浅土色路缘
        "line": (220, 210, 160),       # 浅黄中心线
        "noise": 15,
    },
    "asphalt": {
        "surface": (65, 65, 70),       # 深沥青色1
        "surface2": (75, 75, 80),      # 浅沥青色2（交替）
        "curb": (180, 180, 185),       # 灰色路缘
        "line": (240, 230, 100),       # 黄色中心线
        "noise": 6,
    },
    "highway": {
        "surface": (55, 55, 58),       # 更深的路面色
        "surface2": (50, 50, 53),
        "curb": (200, 200, 190),       # 浅色护栏
        "line": (245, 235, 80),        # 亮黄线
        "noise": 4,
    },
}

def create_diamond_mask(w, h):
    """创建等距菱形遮罩"""
    mask = Image.new('L', (w, h), 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon([(w//2, 0), (w-1, h//2), (w//2, h-1), (0, h//2)], fill=255)
    return mask

def draw_road_tile(draw, tile_x, tile_y, style, sub_type):
    """
    在 (tile_x, tile_y) 位置绘制一个道路子图块
    sub_type: "h"(水平), "v"(垂直), "cross"(十字), "plain"(孤岛)
    """
    surface = style["surface"]
    curb_color = style["curb"]
    line_color = style["line"]
    noise_amt = style["noise"]

    # 每个子图块是 64x32 的区域内绘制菱形道路
    cx = tile_x + CX
    cy = tile_y + CY

    # 先填充菱形区域
    img = draw._image
    pixels = img.load()

    # 菱形内的每个像素
    for y in range(CY * 2):
        for x in range(CX * 2):
            px = tile_x + x
            py = tile_y + y
            if not is_in_diamond(x, y, CX, CY):
                continue

            # 计算在菱形内的归一化坐标
            rel_x = (x - CX) / CX  # -1~1
            rel_y = (y - CY) / CY  # -1~1

            # === 判断是否在路缘区域 ===
            # 路缘宽度约 2-3 像素
            curb_w = 2.5 / CX  # 归一化宽度

            is_curb = False
            # 不同方向道路的路缘在不同位置
            if sub_type in ("h", "cross"):
                # 水平方向：路缘在顶部和底部 (rel_y 接近 -1 或 1)
                if abs(rel_y - (-1.0)) < curb_w * 2.2:
                    is_curb = True
                    curb_pos = "top"
                if abs(rel_y - 1.0) < curb_w * 2.2:
                    is_curb = True
                    curb_pos = "bottom"
            if sub_type in ("v", "cross"):
                # 垂直方向：路缘在左侧和右侧 (rel_x 接近 -1 或 1)
                if abs(rel_x - (-1.0)) < curb_w * 2.2:
                    is_curb = True
                    curb_pos = "left"
                if abs(rel_x - 1.0) < curb_w * 2.2:
                    is_curb = True
                    curb_pos = "right"

            if is_curb:
                # 路缘颜色 - 带3D高光：顶部亮，底部暗
                if abs(rel_y - (-1.0)) < curb_w * 2.2:
                    c = (min(curb_color[0]+25, 255), min(curb_color[1]+25, 255), min(curb_color[2]+25, 255))
                elif abs(rel_y - 1.0) < curb_w * 2.2:
                    c = (max(curb_color[0]-20, 0), max(curb_color[1]-20, 0), max(curb_color[2]-20, 0))
                else:
                    c = curb_color
                pixels[px, py] = noise(c, noise_amt) + (255,)
                continue

            # === 路面区域 ===
            # 3D质感：菱形中间亮、边缘暗
            dist_factor = 1.0 - (rel_x*rel_x + rel_y*rel_y) * 0.4  # 0.6~1.0
            r = int(surface[0] * (0.7 + dist_factor * 0.3))
            g = int(surface[1] * (0.7 + dist_factor * 0.3))
            b = int(surface[2] * (0.7 + dist_factor * 0.3))
            c = noise((r, g, b), noise_amt)

            # === 道路标线 ===
            is_line = False
            if sub_type == "h" or sub_type == "cross":
                # 水平方向有横线
                if abs(rel_y) < 0.08:
                    if sub_type == "cross":
                        # 十字：只在中心区域画线
                        if abs(rel_x) < 0.8:
                            is_line = True
                    else:
                        is_line = True
            if sub_type == "v" or sub_type == "cross":
                # 垂直方向有竖线
                if abs(rel_x) < 0.08:
                    if sub_type == "cross":
                        if abs(rel_y) < 0.8:
                            is_line = True
                    else:
                        is_line = True

            if is_line:
                c = line_color

            # === 十字路口特殊处理 ===
            if sub_type == "cross":
                # 交叉口中心加一个交叉阴影
                if abs(rel_x) < 0.2 and abs(rel_y) < 0.2:
                    c = (c[0]-10, c[1]-10, c[2]-10)

            pixels[px, py] = c + (255,)

def generate_road_sheet(road_type, output_path):
    """生成 128x64 的等距道路 spritesheet"""
    style = ROAD_STYLES[road_type]
    img = Image.new('RGBA', (TILE_W * 2, TILE_H * 2), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 4个子图块
    sub_types = ["h", "v", "cross", "plain"]
    for i, sub_type in enumerate(sub_types):
        tx = (i % 2) * TILE_W
        ty = (i // 2) * TILE_H
        # 先用背景色绘制菱形
        draw_road_tile(draw, tx, ty, style, sub_type)

    img.save(output_path)
    print(f"  -> {output_path} ({img.size})")

def main():
    base = "C:/Users/WIN11/WorkBuddy/2026-06-01-16-27-34/city-builder/assets/textures/roads"
    for rtype in ["dirt", "asphalt", "highway"]:
        path = os.path.join(base, f"iso_{rtype}.png")
        generate_road_sheet(rtype, path)
    print("\n所有道路纹理重新生成完成！")

if __name__ == "__main__":
    random.seed(42)
    main()
