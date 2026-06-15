"""
生成带3D质感的等距道路纹理 (128x64 spritesheet, 4个子图块)
每个子图块 64x32 菱形
子图索引: 0=(0,0)=水平, 1=(1,0)=垂直, 2=(0,1)=十字, 3=(1,1)=孤岛
"""
from PIL import Image, ImageDraw
import os
import random

TILE_W = 64
TILE_H = 32
CX = TILE_W // 2   # 32
CY = TILE_H // 2   # 16
LINE_W = 3  # 中心线宽度(像素)

def is_in_diamond(x, y, cx=CX, cy=CY):
    dx = abs(x - cx) / cx
    dy = abs(y - cy) / cy
    return dx + dy <= 1.0

def noise(base, amount=8):
    r = max(0, min(255, base[0] + random.randint(-amount, amount)))
    g = max(0, min(255, base[1] + random.randint(-amount, amount)))
    b = max(0, min(255, base[2] + random.randint(-amount, amount)))
    return (r, g, b)

ROAD_STYLES = {
    "dirt": {
        "surface": (160, 130, 85),
        "curb": (190, 170, 120),
        "line": (220, 210, 160),
        "noise": 15,
    },
    "asphalt": {
        "surface": (65, 65, 70),
        "curb": (180, 180, 185),
        "line": (240, 230, 100),
        "edge_line": True,
        "edge_line_color": (220, 220, 220),
        "noise": 6,
    },
    "highway": {
        "surface": (45, 45, 48),
        "curb": (200, 200, 190),
        "line": (255, 240, 60),
        "edge_line": True,
        "edge_line_color": (230, 230, 230),
        "noise": 4,
    },
}

def draw_road_tile(pixels, tx, ty, style, sub_type):
    surf = style["surface"]
    curb_col = style["curb"]
    line_col = style["line"]
    nz = style["noise"]
    edge = style.get("edge_line", False)
    edge_col = style.get("edge_line_color", (255,255,255))

    for y in range(TILE_H):
        for x in range(TILE_W):
            if not is_in_diamond(x, y, CX, CY):
                continue
            px = tx + x
            py = ty + y
            rx = (x - CX) / CX
            ry = (y - CY) / CY

            # === 路缘(4px宽) ===
            is_curb = False
            is_top = None
            if sub_type in ("h","cross"):
                if abs(ry + 1) < 0.12:
                    is_curb = True; is_top = True
                if abs(ry - 1) < 0.12:
                    is_curb = True; is_top = False
            if sub_type in ("v","cross"):
                if abs(rx + 1) < 0.12:
                    is_curb = True; is_top = None
                if abs(rx - 1) < 0.12:
                    is_curb = True; is_top = None

            if is_curb:
                if is_top == True:
                    c = (min(curb_col[0]+35,255), min(curb_col[1]+35,255), min(curb_col[2]+35,255))
                elif is_top == False:
                    c = (max(curb_col[0]-25,0), max(curb_col[1]-25,0), max(curb_col[2]-25,0))
                else:
                    c = curb_col
                pixels[px, py] = noise(c, nz) + (255,)
                continue

            # === 路面 ===
            dist = 1.0 - (rx*rx + ry*ry) * 0.3
            r = int(surf[0] * (0.6 + dist * 0.4))
            g = int(surf[1] * (0.6 + dist * 0.4))
            b = int(surf[2] * (0.6 + dist * 0.4))
            c = noise((r, g, b), nz)

            # === 车道边缘白线(虚线) ===
            if edge:
                ew = 0.06
                is_el = False
                if sub_type in ("h","cross"):
                    for ey in [-0.55, 0.55]:
                        if abs(ry - ey) < ew:
                            dash = int(x * 0.6 + y * 0.3) % 4 < 3
                            if dash and (abs(rx) < 0.85 if sub_type == "cross" else True):
                                is_el = True
                if sub_type in ("v","cross"):
                    for ex in [-0.55, 0.55]:
                        if abs(rx - ex) < ew:
                            dash = int(x * 0.3 + y * 0.6) % 4 < 3
                            if dash and (abs(ry) < 0.85 if sub_type == "cross" else True):
                                is_el = True
                if is_el:
                    c = edge_col

            # === 中心线 ===
            lw = LINE_W / CX * 0.45
            is_line = False
            if sub_type == "h":
                if abs(ry) < lw:
                    is_line = True
            elif sub_type == "v":
                if abs(rx) < lw:
                    is_line = True
            elif sub_type == "cross":
                if abs(ry) < lw and abs(rx) < 0.85:
                    is_line = True
                if abs(rx) < lw and abs(ry) < 0.85:
                    is_line = True

            if is_line:
                c = line_col

            pixels[px, py] = c + (255,)

def generate_road_sheet(road_type, output_path):
    style = ROAD_STYLES[road_type]
    img = Image.new('RGBA', (TILE_W*2, TILE_H*2), (0,0,0,0))
    pixels = img.load()
    sub_types = ["h","v","cross","plain"]
    for i, st in enumerate(sub_types):
        tx = (i % 2) * TILE_W
        ty = (i // 2) * TILE_H
        draw_road_tile(pixels, tx, ty, style, st)
    img.save(output_path)
    print(f"  -> {output_path} ({img.size})")

def main():
    base = "C:/Users/WIN11/WorkBuddy/2026-06-01-16-27-34/city-builder/assets/textures/roads"
    for rtype in ["dirt","asphalt","highway"]:
        path = os.path.join(base, f"iso_{rtype}.png")
        generate_road_sheet(rtype, path)
    print("\n所有道路纹理重新生成完成！")

if __name__ == "__main__":
    random.seed(42)
    main()
