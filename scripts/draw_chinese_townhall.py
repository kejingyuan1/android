"""
手绘中国风大本营建筑纹理（全新生成，确保三处镂空透明）
特点：
- 红色墙体，黄色琉璃瓦
- 两层飞檐翘角
- 三处透明镂空：左飞檐下、中间门洞、右飞檐下
- 像素风格
"""
from PIL import Image, ImageDraw
import os

OUT_PATH = "C:/Users/WIN11/WorkBuddy/2026-06-01-16-27-34/city-builder/assets/textures/buildings/chinese/l1_v2.png"
W, H = 640, 880

def draw_chinese_townhall():
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 颜色定义
    red = (180, 50, 40, 255)      # 中国红
    dark_red = (120, 30, 25, 255)  # 深红
    roof = (220, 160, 50, 255)     # 琉璃黄
    roof_dark = (180, 130, 35, 255)
    stone = (160, 150, 140, 255)   # 石柱
    stone_dark = (100, 95, 90, 255)
    base = (200, 180, 150, 255)    # 台基
    gold = (255, 200, 60, 255)     # 金色装饰
    window = (80, 40, 20, 255)     # 窗格
    
    cx = W // 2
    
    # === 台基（底部基座）===
    base_y = 750
    draw.rectangle([50, base_y, 590, 820], fill=base)  # 主台基
    draw.rectangle([60, base_y+5, 580, base_y+15], fill=(170, 160, 140, 255))  # 阴影层
    
    # 台阶
    draw.rectangle([cx-50, 820, cx+50, 850], fill=stone)
    for i in range(5):
        y = 820 + i * 6
        draw.rectangle([cx-50+i*3, y, cx+50-i*3, y+5], fill=(140+i*10, 135+i*10, 130+i*10, 255))
    
    # === 下层柱子（四根主柱）===
    pillars = [
        (110, 680, 135, 750),   # 左外柱
        (230, 680, 255, 750),   # 左内柱
        (385, 680, 410, 750),   # 右内柱
        (505, 680, 530, 750),   # 右外柱
    ]
    for x1, y1, x2, y2 in pillars:
        draw.rectangle([x1, y1, x2, y2], fill=red)
        draw.rectangle([x1+3, y1, x2-3, y2], fill=dark_red)  # 暗面
        # 柱头石
        draw.rectangle([x1-5, y1-10, x2+5, y1], fill=stone)
        draw.rectangle([x1-5, y2, x2+5, y2+10], fill=stone_dark)
    
    # === 下层屋顶（左右飞檐）===
    # 下层左飞檐
    left_roof_points = [(50, 580), (170, 520), (230, 580), (230, 600), (50, 600)]
    draw.polygon(left_roof_points, fill=roof)
    draw.polygon([(50, 580), (170, 520), (230, 580)], fill=roof_dark)  # 阴影面
    # 瓦片纹理
    for i in range(8):
        x = 60 + i * 22
        draw.ellipse([x, 570, x+18, 590], fill=roof_dark, outline=(160, 110, 25, 255))
    
    # 下层右飞檐
    right_roof_points = [(410, 580), (470, 520), (590, 580), (590, 600), (410, 600)]
    draw.polygon(right_roof_points, fill=roof)
    draw.polygon([(410, 580), (470, 520), (590, 580)], fill=roof_dark)
    for i in range(8):
        x = 420 + i * 22
        draw.ellipse([x, 570, x+18, 590], fill=roof_dark, outline=(160, 110, 25, 255))
    
    # 飞檐翘角装饰
    draw.polygon([(50, 580), (30, 560), (60, 570)], fill=gold)  # 左翘角
    draw.polygon([(590, 580), (610, 560), (580, 570)], fill=gold)  # 右翘角
    
    # === 上层柱子 ===
    upper_pillars = [
        (170, 480, 195, 520),   # 左上
        (230, 480, 255, 520),   # 左中
        (385, 480, 410, 520),   # 右中
        (445, 480, 470, 520),   # 右上
    ]
    for x1, y1, x2, y2 in upper_pillars:
        draw.rectangle([x1, y1, x2, y2], fill=red)
        draw.rectangle([x1+3, y1, x2-3, y2], fill=dark_red)
        draw.rectangle([x1-3, y1-8, x2+3, y1], fill=stone)
    
    # === 上层主墙体（中间部分，留出镂空）===
    # 上层墙体分三段（左右实体，中间是门洞上方的横梁）
    draw.rectangle([195, 480, 265, 520], fill=red)  # 左墙
    draw.rectangle([375, 480, 445, 520], fill=red)  # 右墙
    draw.rectangle([265, 490, 375, 520], fill=dark_red)  # 中间横梁（深色）
    
    # === 上层屋顶（主顶）===
    roof_points = [(100, 380), (cx, 280), (540, 380), (540, 400), (100, 400)]
    draw.polygon(roof_points, fill=roof)
    draw.polygon([(100, 380), (cx, 280), (540, 380)], fill=roof_dark)
    # 主顶瓦片
    for row in range(5):
        y = 320 + row * 15
        for col in range(20):
            x = 110 + col * 22
            if 100 < x < 540 and y > 300:
                draw.ellipse([x, y, x+18, y+12], fill=roof, outline=roof_dark)
    
    # 飞檐翘角（上层）
    draw.polygon([(100, 380), (70, 350), (110, 370)], fill=gold)
    draw.polygon([(540, 380), (570, 350), (530, 370)], fill=gold)
    
    # === 屋脊装饰 ===
    draw.rectangle([cx-10, 280, cx+10, 240], fill=stone)  # 旗杆
    draw.polygon([(cx, 220), (cx-25, 240), (cx+25, 240)], fill=(200, 40, 40, 255))  # 红旗
    draw.line([(cx, 220), (cx, 240)], fill=gold, width=3)
    
    # === 门窗细节 ===
    # 上层窗户（左右各一）
    draw.rectangle([210, 500, 240, 515], fill=window)
    draw.rectangle([215, 502, 235, 513], fill=(60, 30, 15, 255))
    draw.rectangle([400, 500, 430, 515], fill=window)
    draw.rectangle([405, 502, 425, 513], fill=(60, 30, 15, 255))
    
    # 下层窗格（柱间）
    for x in [145, 320]:
        draw.rectangle([x, 700, x+40, 730], fill=window)
        for i in range(3):
            draw.line([(x+10+i*10, 700), (x+10+i*10, 730)], fill=(50, 25, 10, 255), width=1)
            draw.line([(x, 710+i*7), (x+40, 710+i*7)], fill=(50, 25, 10, 255), width=1)
    
    # === 围栏（栏杆）===
    for y in [640, 660]:
        draw.rectangle([135, y, 505, y+5], fill=stone_dark)  # 横栏
    for x in [135, 170, 230, 320, 410, 470, 505]:
        draw.rectangle([x, 630, x+5, 670], fill=stone)  # 竖栏
    
    # === 确保三处镂空区域完全透明 ===
    # 这些区域现在应该有背景透明格子，不会画任何像素
    
    # 保存
    img = img.crop(img.getbbox())  # 裁剪到内容
    img.save(OUT_PATH)
    print(f"已生成: {OUT_PATH}")
    
    # 验证镂空
    print("\n验证透明区域:")
    pixels = img.load()
    regions = [
        ("左飞檐下", 80, 120, 590, 630),
        ("门洞", 260, 360, 580, 680),
        ("右飞檐下", 500, 540, 590, 630),
    ]
    for name, x1, x2, y1, y2 in regions:
        opaque = sum(1 for y in range(y1, y2) for x in range(x1, x2) if pixels[x, y][3] > 10)
        total = (x2-x1)*(y2-y1)
        print(f"  {name}: 不透明{opaque}/{total} ({opaque/total*100:.1f}%)")
    
    return img

if __name__ == "__main__":
    draw_chinese_townhall()
