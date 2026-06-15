"""
生成COC风格等距道路纹理（三级升级系统）
L1: 碎石子路 (Gravel) - 土褐色 + 碎石纹理 + 虚线
L2: 水泥路 (Concrete) - 灰色 + 混凝土纹理 + 黄实线
L3: 柏油路 (Asphalt) - 深黑 + 沥青颗粒 + 双黄线 + 白边线

Spritesheet: 128x64
子图块: 64x32 等距菱形
索引: 0=水平, 1=垂直, 2=十字, 3=孤岛
"""
from PIL import Image, ImageDraw, ImageFilter
import random
import os

TILE_W = 64
TILE_H = 32
CX = TILE_W // 2
CY = TILE_H // 2

def is_in_diamond(x, y):
    dx = abs(x - CX) / CX
    dy = abs(y - CY) / CY
    return dx + dy <= 1.0

def noise_color(base, amt=15):
    r = max(0, min(255, base[0] + random.randint(-amt, amt)))
    g = max(0, min(255, base[1] + random.randint(-amt, amt)))
    b = max(0, min(255, base[2] + random.randint(-amt, amt)))
    return (r, g, b)

# ============ L1: 碎石子路 ============
# 特点：土褐色底色，随机白点碎石，淡黄色中心虚线
ROAD_L1 = {
    "name": "gravel",
    "surface": (165, 145, 115),      # 土褐色
    "curb": (190, 175, 150),          # 浅色路缘
    "line": (230, 220, 180),          # 淡黄色虚线
    "gravel_dots": True,
}

# ============ L2: 水泥路 ============
# 特点：灰色混凝土，噪点纹理，黄色实线
ROAD_L2 = {
    "name": "concrete",
    "surface": (140, 140, 145),       # 水泥灰
    "curb": (180, 180, 185),          # 混凝土路缘
    "line": (240, 200, 50),           # 黄色实线
    "concrete_noise": True,
}

# ============ L3: 柏油路 ============
# 特点：深黑色沥青，颗粒感，双黄线，白色边线
ROAD_L3 = {
    "name": "asphalt",
    "surface": (45, 45, 48),          # 深沥青色
    "curb": (200, 200, 195),          # 白色路缘
    "line": (255, 220, 0),            # 亮黄双线
    "edge_line": (240, 240, 240),     # 白色边线
    "asphalt_grain": True,
}

def draw_gravel_road(draw, tile_x, tile_y):
    """碎石子路 - 中间车道实心，边缘透明"""
    img = draw._image
    pixels = img.load()
    
    for y in range(TILE_H):
        for x in range(TILE_W):
            px = tile_x + x
            py = tile_y + y
            
            # 归一化坐标
            rx = (x - CX) / CX
            ry = (y - CY) / CY
            
            # 只绘制中间车道区域（宽度约70%）
            road_width = 0.70
            if abs(ry) > road_width:
                # 路外区域保持透明
                pixels[px, py] = (0, 0, 0, 0)
                continue
            
            # 路缘（车道边缘）
            curb_w = 0.62
            if abs(ry) > curb_w:
                c = ROAD_L1["curb"]
                pixels[px, py] = noise_color(c, 8) + (255,)
                continue
            
            # 路面底色
            base = ROAD_L1["surface"]
            # 添加碎石点
            if random.random() < 0.06:
                base = (min(base[0]+30,255), min(base[1]+25,255), min(base[2]+20,255))
            c = noise_color(base, 10)
            
            # 中心虚线
            dash_spacing = 14
            if int(x * 0.5 + y * 0.3) % dash_spacing < 5:
                if abs(ry) < 0.06:
                    c = ROAD_L1["line"]
            
            pixels[px, py] = c + (255,)

def draw_concrete_road(draw, tile_x, tile_y):
    """水泥路 - 中间车道实心，边缘透明"""
    img = draw._image
    pixels = img.load()
    
    for y in range(TILE_H):
        for x in range(TILE_W):
            px = tile_x + x
            py = tile_y + y
            
            rx = (x - CX) / CX
            ry = (y - CY) / CY
            
            # 只绘制中间车道
            if abs(ry) > 0.65:
                pixels[px, py] = (0, 0, 0, 0)
                continue
            
            # 路缘
            if abs(ry) > 0.58:
                c = ROAD_L2["curb"]
                pixels[px, py] = noise_color(c, 5) + (255,)
                continue
            
            # 混凝土纹理
            base = ROAD_L2["surface"]
            n = random.randint(-10, 10)
            c = (max(0, min(255, base[0]+n)), max(0, min(255, base[1]+n)), max(0, min(255, base[2]+n)))
            
            # 中心黄实线
            if abs(ry) < 0.05:
                c = ROAD_L2["line"]
            
            pixels[px, py] = c + (255,)

def draw_asphalt_road(draw, tile_x, tile_y):
    """柏油路 - 中间车道实心，边缘透明"""
    img = draw._image
    pixels = img.load()
    
    for y in range(TILE_H):
        for x in range(TILE_W):
            px = tile_x + x
            py = tile_y + y
            
            rx = (x - CX) / CX
            ry = (y - CY) / CY
            
            # 只绘制中间车道
            if abs(ry) > 0.60:
                pixels[px, py] = (0, 0, 0, 0)
                continue
            
            # 白色边线（车道边缘虚线）
            edge_pos = 0.55
            edge_w = 0.03
            if abs(abs(ry) - edge_pos) < edge_w:
                if (int(x * 0.6) % 6) < 4:
                    pixels[px, py] = ROAD_L3["edge_line"] + (255,)
                    continue
            
            # 沥青底色
            base = ROAD_L3["surface"]
            grain = random.randint(-5, 8)
            c = (max(0, min(80, base[0]+grain)), max(0, min(80, base[1]+grain)), max(0, min(85, base[2]+grain)))
            
            # 双黄线中心线
            if abs(abs(ry) - 0.08) < 0.025:
                c = ROAD_L3["line"]
            
            pixels[px, py] = c + (255,)

def generate_road_sheet(road_config, output_path, draw_func):
    """生成128x64 spritesheet"""
    img = Image.new('RGBA', (TILE_W*2, TILE_H*2), (0,0,0,0))
    draw = ImageDraw.Draw(img)
    
    # 4个子图块：水平、垂直、十字、孤岛
    positions = [(0,0), (64,0), (0,32), (64,32)]
    for tx, ty in positions:
        draw_func(draw, tx, ty)
    
    img.save(output_path)
    print(f"  Generated: {output_path}")

def main():
    base = "C:/Users/WIN11/WorkBuddy/2026-06-01-16-27-34/city-builder/assets/textures/roads"
    
    print("Generating road textures...")
    random.seed(42)
    
    # L1: 碎石子路
    generate_road_sheet(ROAD_L1, os.path.join(base, "road_gravel.png"), draw_gravel_road)
    
    # L2: 水泥路  
    generate_road_sheet(ROAD_L2, os.path.join(base, "road_concrete.png"), draw_concrete_road)
    
    # L3: 柏油路
    generate_road_sheet(ROAD_L3, os.path.join(base, "road_asphalt.png"), draw_asphalt_road)
    
    print("\nAll road textures generated!")

if __name__ == "__main__":
    main()
