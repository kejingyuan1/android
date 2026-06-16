"""
生成COC风格等距道路纹理（三级升级系统 + 16种连接形态）
L1: 碎石路, L2: 水泥路, L3: 柏油路
Spritesheet: 256x128 → 4列×4行 = 16种子图块
"""
from PIL import Image, ImageDraw
import random, os, math

TILE_W = 64
TILE_H = 32
CX = TILE_W // 2
CY = TILE_H // 2
COLS = 4
ROWS = 4

def is_in_diamond(x, y):
    dx = abs(x - CX) / CX
    dy = abs(y - CY) / CY
    return dx + dy <= 1.0

def noise_color(base, amt=15):
    r = max(0, min(255, base[0] + random.randint(-amt, amt)))
    g = max(0, min(255, base[1] + random.randint(-amt, amt)))
    b = max(0, min(255, base[2] + random.randint(-amt, amt)))
    return (r, g, b)

# 道路配置
ROAD_CONFIGS = {
    "gravel": {
        "surface": (165, 145, 115), "curb": (190, 175, 150),
        "line": (230, 220, 180), "gravel_dots": True,
    },
    "concrete": {
        "surface": (140, 140, 145), "curb": (180, 180, 185),
        "line": (240, 200, 50), "concrete_noise": True,
    },
    "asphalt": {
        "surface": (45, 45, 48), "curb": (200, 200, 195),
        "line": (255, 220, 0), "edge_line": (240, 240, 240),
        "asphalt_grain": True,
    },
}

# 方向: bit0=上(gy-1), bit1=下(gy+1), bit2=左(gx-1), bit3=右(gx+1)
def draw_road_tile(draw, ox, oy, mask, cfg, is_asphalt=False):
    """根据邻居掩码绘制单个道路图块"""
    img = draw._image
    pixels = img.load()
    
    # 定义4个方向在菱形内的延伸区域
    # 每个方向对应一个三角形区域从中心到边缘
    arms = {
        1: {"label": "up", "range": lambda x, y: (y < CY and abs(x-CX)/CX + abs(y-CY)/CY <= 0.85)},    # bit0=up
        2: {"label": "down", "range": lambda x, y: (y > CY and abs(x-CX)/CX + abs(y-CY)/CY <= 0.85)},  # bit1=down
        4: {"label": "left", "range": lambda x, y: (x < CX and abs(x-CX)/CX + abs(y-CY)/CY <= 0.85)},  # bit2=left
        8: {"label": "right", "range": lambda x, y: (x > CX and abs(x-CX)/CX + abs(y-CY)/CY <= 0.85)}, # bit3=right
    }
    
    for y in range(TILE_H):
        for x in range(TILE_W):
            px = ox + x
            py = oy + y
            
            if not is_in_diamond(x, y):
                pixels[px, py] = (0, 0, 0, 0)
                continue
            
            rx = (x - CX) / CX
            ry = (y - CY) / CY
            
            # 决定这个像素是否在某个连接臂上
            in_arm = False
            arm_bits = 0
            
            # 检查每个方向
            if mask & 1 and y < CY and abs(rx) + abs(ry) <= 0.85:  # up
                in_arm = True
                arm_bits |= 1
            if mask & 2 and y > CY and abs(rx) + abs(ry) <= 0.85:  # down
                in_arm = True
                arm_bits |= 2
            if mask & 4 and x < CX and abs(rx) + abs(ry) <= 0.85:  # left
                in_arm = True
                arm_bits |= 4
            if mask & 8 and x > CX and abs(rx) + abs(ry) <= 0.85:  # right
                in_arm = True
                arm_bits |= 8
            
            # 中心区域
            is_center = (abs(rx) + abs(ry) <= 0.50)
            
            if not in_arm and not is_center:
                # 非连接方向：设为透明（露出草地）
                pixels[px, py] = (0, 0, 0, 0)
                continue
            
            # 车道宽度限制（垂直方向收窄）
            if abs(ry) > 0.65:
                pixels[px, py] = (0, 0, 0, 0)
                continue
            
            # 路面颜色
            base = cfg["surface"]
            if cfg.get("gravel_dots") and random.random() < 0.06:
                base = (min(base[0]+30,255), min(base[1]+25,255), min(base[2]+20,255))
            c = noise_color(base, 10)
            
            # 中心线（基于连接方向绘制）
            horiz = (mask & 12) != 0  # left or right connected
            vert = (mask & 3) != 0    # up or down connected
            
            # 水平连接 → 水平横穿中心黄线
            if horiz and abs(ry) < 0.05:
                if not vert or abs(rx) < 0.3 or (mask & 3) == 0:
                    if not is_asphalt:
                        c = cfg["line"]
            
            # 垂直连接 → 垂直中心线（在菱形中表现为右上-左下方向）
            if vert and abs(rx) < 0.05:
                if not horiz or abs(ry) < 0.3 or (mask & 12) == 0:
                    c = cfg["line"]
            
            # L3 沥青路特殊标记
            if is_asphalt:
                edge_pos = 0.50
                edge_w = 0.025
                if abs(abs(ry) - edge_pos) < edge_w:
                    if (int(x * 0.6) % 6) < 4:
                        c = cfg["edge_line"]
                if abs(abs(ry) - 0.04) < 0.015 and horiz:
                    if (int(x * 0.5) % 8) < 4:
                        c = cfg["line"]
                if abs(abs(rx) - 0.04) < 0.015 and vert:
                    if (int(y * 0.5) % 8) < 4:
                        c = cfg["line"]
            
            pixels[px, py] = c + (255,)

def generate_road_sheet(cfg, output_path, is_asphalt=False):
    """生成256x128 spritesheet (4x4 tiles)"""
    img = Image.new('RGBA', (TILE_W*COLS, TILE_H*ROWS), (0,0,0,0))
    draw = ImageDraw.Draw(img)
    
    # 为每种掩码值(0-15)生成图块
    # 布局: 4列×4行, tile位置 = (mask%4, mask//4)
    for mask in range(16):
        col = mask % COLS
        row = mask // COLS
        tx = col * TILE_W
        ty = row * TILE_H
        draw_road_tile(draw, tx, ty, mask, cfg, is_asphalt)
    
    img.save(output_path)
    print(f"  Generated: {output_path} ({16} tiles)")

def main():
    base = "C:/Users/WIN11/WorkBuddy/2026-06-01-16-27-34/city-builder/assets/textures/roads"
    print("Generating road textures (v3 - 16 connections)...")
    random.seed(42)
    
    configs = [
        (ROAD_CONFIGS["gravel"], False, "iso_dirt", "road_gravel"),
        (ROAD_CONFIGS["concrete"], False, "iso_asphalt", "road_concrete"),
        (ROAD_CONFIGS["asphalt"], True, "iso_highway", "road_asphalt"),
    ]
    
    for cfg, is_asph, name1, name2 in configs:
        generate_road_sheet(cfg, os.path.join(base, f"{name1}.png"), is_asph)
        generate_road_sheet(cfg, os.path.join(base, f"{name2}.png"), is_asph)
    
    print("\nDone!")

if __name__ == "__main__":
    main()
