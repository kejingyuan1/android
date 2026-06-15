"""
生成大本营纹理：10 级 × 6 文明 = 60 个等距建筑贴图
使用模板 + 程序化升级变体
"""
from PIL import Image, ImageDraw, ImageFilter, ImageOps
import os, math, random

BASE = "C:/Users/WIN11/WorkBuddy/2026-06-01-16-27-34/city-builder/assets/textures/buildings"
TEMPLATE = os.path.join(BASE, "town_hall_template.png")

# 文明名称（用于文件名）
CIV_NAMES = ["chinese", "roman", "british", "egyptian", "japanese", "viking"]

# 每个文明的配色方案（用于纹理着色）
CIV_PALETTES = {
    "chinese": {
        "roof": (180, 50, 40),      # 中国红
        "wall": (210, 190, 150),     # 米黄墙
        "trim": (200, 170, 50),      # 金色装饰
        "base": (140, 130, 110),     # 灰色石基
        "accent": (50, 120, 60),     # 绿色（青铜）
    },
    "roman": {
        "roof": (180, 100, 60),      # 红陶瓦
        "wall": (220, 200, 180),     # 白色大理石
        "trim": (180, 140, 100),     # 砂岩色
        "base": (150, 140, 130),     # 灰石基
        "accent": (180, 50, 50),     # 罗马红
    },
    "british": {
        "roof": (80, 80, 100),       # 石板灰
        "wall": (200, 190, 175),     # 米色石灰石
        "trim": (120, 100, 90),      # 深木色
        "base": (160, 150, 140),     # 石材基
        "accent": (60, 80, 160),     # 皇家蓝
    },
    "egyptian": {
        "roof": (200, 180, 120),     # 金色砂岩顶
        "wall": (210, 190, 150),     # 米黄砂岩
        "trim": (180, 160, 80),      # 金色饰边
        "base": (160, 140, 110),     # 沙石基
        "accent": (50, 100, 180),    # 青金石蓝
    },
    "japanese": {
        "roof": (120, 120, 130),     # 灰色瓦片
        "wall": (190, 180, 170),     # 白墙
        "trim": (160, 80, 60),       # 红木
        "base": (150, 140, 130),     # 石基
        "accent": (60, 60, 60),      # 黑漆
    },
    "viking": {
        "roof": (100, 130, 80),      # 草皮绿顶
        "wall": (160, 130, 100),     # 原木色
        "trim": (180, 100, 50),      # 红赭石
        "base": (140, 130, 120),     # 毛石基
        "accent": (180, 160, 60),    # 金色
    },
}

def create_civ_variant(template, palette):
    """对模板应用文明配色着色"""
    img = template.copy().convert("RGBA")
    pixels = img.load()
    w, h = img.size
    
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a < 10:
                continue
            # 根据像素亮度映射到不同建筑部位
            lum = (r * 0.299 + g * 0.587 + b * 0.114)
            if lum > 200:  # 亮色 → 墙壁
                ratio = (lum - 200) / 55.0
                nr = int(palette["wall"][0] * (0.8 + 0.2 * ratio))
                ng = int(palette["wall"][1] * (0.8 + 0.2 * ratio))
                nb = int(palette["wall"][2] * (0.8 + 0.2 * ratio))
            elif lum > 130:  # 中亮 → 屋顶
                nr = int(palette["roof"][0] * (1.0 + (lum - 130) / 70.0))
                ng = int(palette["roof"][1] * (1.0 + (lum - 130) / 70.0))
                nb = int(palette["roof"][2] * (1.0 + (lum - 130) / 70.0))
            elif lum > 80:  # 中暗 → 基座
                nr = int(palette["base"][0] * (0.8 + 0.2 * (lum - 80) / 50.0))
                ng = int(palette["base"][1] * (0.8 + 0.2 * (lum - 80) / 50.0))
                nb = int(palette["base"][2] * (0.8 + 0.2 * (lum - 80) / 50.0))
            else:  # 暗色 → 装饰
                nr = int(palette["trim"][0] * (0.7 + 0.3 * lum / 80.0))
                ng = int(palette["trim"][1] * (0.7 + 0.3 * lum / 80.0))
                nb = int(palette["trim"][2] * (0.7 + 0.3 * lum / 80.0))
            
            pixels[x, y] = (max(0, min(255, nr)), max(0, min(255, ng)), 
                           max(0, min(255, nb)), a)
    return img

def add_level_upgrades(img, level):
    """根据等级添加升级细节"""
    if level <= 1:
        return img
    
    w, h = img.size
    canvas = Image.new('RGBA', (w + 40, h + 40), (0, 0, 0, 0))
    # 将原图居中到底部
    scale = 0.8 + (level - 1) * 0.04  # L1=0.8, L10=1.16
    new_w = int(w * scale)
    new_h = int(h * scale)
    scaled = img.resize((new_w, new_h), Image.NEAREST)
    
    x_offset = (canvas.width - new_w) // 2
    y_offset = canvas.height - new_h  # 底部对齐
    canvas.paste(scaled, (x_offset, y_offset), scaled)
    draw = ImageDraw.Draw(canvas)
    
    # 根据等级添加装饰物
    if level >= 2:
        # 小旗子（顶部）
        flag_x = canvas.width // 2
        flag_y = y_offset - 10
        draw.polygon([(flag_x, flag_y), (flag_x, flag_y - 25), (flag_x + 15, flag_y - 12)], 
                     fill=(200, 50, 50, 255))
        draw.line([(flag_x, flag_y), (flag_x, flag_y - 25)], fill=(120, 60, 30, 255), width=2)
    
    if level >= 3:
        # 两面旗子
        draw.polygon([(flag_x - 20, flag_y - 5), (flag_x - 20, flag_y - 25), 
                     (flag_x - 5, flag_y - 15)], fill=(200, 50, 50, 255))
        draw.line([(flag_x - 20, flag_y - 5), (flag_x - 20, flag_y - 25)], 
                 fill=(120, 60, 30, 255), width=2)
    
    if level >= 4:
        # 金色饰边（底部）
        for i in range(0, canvas.width, 12):
            draw.rectangle([i, y_offset + new_h - 6, i + 6, y_offset + new_h], 
                          fill=(220, 180, 40, 200))
    
    if level >= 5:
        # 塔楼/尖顶
        draw.polygon([(flag_x - 12, y_offset - 15), (flag_x, y_offset - 40), 
                     (flag_x + 12, y_offset - 15)], fill=(200, 180, 100, 220))
        draw.rectangle([flag_x - 4, y_offset - 15, flag_x + 4, y_offset], 
                      fill=(200, 180, 100, 220))
    
    if level >= 6:
        # 柱子装饰（两侧）
        for side_x in [x_offset + 5, x_offset + new_w - 10]:
            for py in range(y_offset + int(new_h * 0.3), y_offset + new_h - 5, 8):
                draw.rectangle([side_x, py, side_x + 4, py + 5], fill=(220, 200, 150, 200))
    
    if level >= 7:
        # 城墙/围栏
        wall_y = y_offset + new_h + 2
        for wx in range(x_offset, x_offset + new_w, 8):
            draw.rectangle([wx, wall_y, wx + 6, wall_y + 8], fill=(160, 150, 130, 200))
    
    if level >= 8:
        # 四角塔楼
        for tx, ty in [(x_offset - 10, y_offset), (x_offset + new_w - 5, y_offset),
                       (x_offset - 10, y_offset + new_h - 20), 
                       (x_offset + new_w - 5, y_offset + new_h - 20)]:
            draw.polygon([(tx, ty + 25), (tx + 8, ty), (tx + 16, ty + 25)], 
                        fill=(180, 160, 100, 200))
    
    if level >= 9:
        # 大旗 + 金色圆顶
        draw.ellipse([flag_x - 15, y_offset - 50, flag_x + 15, y_offset - 20], 
                    fill=(255, 215, 0, 220))
        draw.polygon([(flag_x, y_offset - 55), (flag_x - 10, y_offset - 35), 
                     (flag_x + 10, y_offset - 35)], fill=(255, 50, 50, 255))
    
    if level >= 10:
        # 最终形态：宏伟城堡
        # 更大的旗帜
        draw.polygon([(flag_x - 15, y_offset - 60), (flag_x - 15, y_offset - 90), 
                     (flag_x + 10, y_offset - 75)], fill=(255, 215, 0, 255))
        draw.line([(flag_x - 15, y_offset - 60), (flag_x - 15, y_offset - 90)], 
                 fill=(150, 75, 0, 255), width=3)
        # 发光效果
        glow = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
        glow_draw = ImageDraw.Draw(glow)
        glow_draw.ellipse([flag_x - 30, y_offset - 80, flag_x + 30, y_offset - 20], 
                         fill=(255, 215, 0, 60))
        canvas = Image.alpha_composite(canvas, glow)
    
    # 重新裁剪到内容区域
    canvas = canvas.crop(canvas.getbbox() or (0, 0, canvas.width, canvas.height))
    return canvas

def remove_watermark(img):
    """去除右下角'AI生成'水印 — 将亮白色水印像素设为透明"""
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    pixels = img.load()
    w, h = img.size
    # 水印通常在右下角 200x60 范围，为近白色像素
    removed = 0
    for y in range(max(0, h - 60), h):
        for x in range(max(0, w - 200), w):
            r, g, b, a = pixels[x, y]
            if a > 10 and r > 180 and g > 180 and b > 180:
                pixels[x, y] = (0, 0, 0, 0)
                removed += 1
    return img, removed

def main():
    print("=" * 60)
    print("生成大本营纹理：10级 × 6文明")
    print("=" * 60)
    
    if not os.path.exists(TEMPLATE):
        print(f"[ERROR] 模板文件不存在: {TEMPLATE}")
        return
    
    template = Image.open(TEMPLATE).convert("RGBA")
    print(f"模板尺寸: {template.size}")
    
    out_dir = BASE
    random.seed(42)
    
    for civ in CIV_NAMES:
        palette = CIV_PALETTES[civ]
        print(f"\n--- {civ.upper()} ---")
        
        # 创建文明变体（L1 = 基础配色）
        civ_base = create_civ_variant(template, palette)
        
        for level in range(1, 11):
            if level == 1:
                img = civ_base
            else:
                img = add_level_upgrades(civ_base, level)
            
            # 后处理：强制清除右下角水印区域
            cleared = 0
            w, h = img.size
            pixels = img.load()
            for y in range(max(0, h - 60), h):
                for x in range(max(0, w - 200), w):
                    if pixels[x, y][3] > 10:
                        pixels[x, y] = (0, 0, 0, 0)
                        cleared += 1
            
            filename = f"town_hall_{civ}_l{level}.png"
            out_path = os.path.join(out_dir, filename)
            img.save(out_path)
            detail = f" (清{cleared}px)" if cleared > 0 else ""
            print(f"  L{level}: {filename} -> {img.size}{detail}")

if __name__ == "__main__":
    main()
