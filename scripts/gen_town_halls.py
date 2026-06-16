"""
生成大本营纹理：10 级 × 6 文明 = 60 个等距建筑贴图
使用模板 + 柔和颜色调整（避免硬性亮度映射导致的色块伪影）
"""
from PIL import Image, ImageDraw, ImageFilter, ImageOps
import os, math, random

BASE = "C:/Users/WIN11/WorkBuddy/2026-06-01-16-27-34/city-builder/assets/textures/buildings"
TEMPLATE = os.path.join(BASE, "town_hall_template.png")

CIV_NAMES = ["chinese", "roman", "british", "egyptian", "japanese", "viking"]

# 每个文明的色调配置
# roof_hue: 屋顶色相偏移(度), wall_hue: 墙壁色相偏移, base_hue: 基座偏移
# saturation: 饱和度倍率, lightness_shift: 亮度偏移
CIV_TINTS = {
    "chinese":  {"roof_hue": 0,  "wall_hue": 0,    "base_hue": 0,  "sat": 1.0, "lum": 0},
    "roman":    {"roof_hue": 0,  "wall_hue": 3,    "base_hue": 5,  "sat": 1.1, "lum": 8},
    "british":  {"roof_hue": 0,  "wall_hue": -3,   "base_hue": -3, "sat": 0.8, "lum": -5},
    "egyptian": {"roof_hue": 0,  "wall_hue": 8,    "base_hue": 10, "sat": 1.2, "lum": 12},
    "japanese": {"roof_hue": 0,  "wall_hue": -2,   "base_hue": -2, "sat": 0.7, "lum": -8},
    "viking":   {"roof_hue": 0,  "wall_hue": 2,    "base_hue": 5,  "sat": 0.9, "lum": -10},
}

def apply_tint(img, roof_hue, wall_hue, base_hue, sat_scale, lum_shift):
    """根据不同建筑部位（屋顶/墙壁/基座）应用独立色调偏移"""
    pixels = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a < 10:
                continue
            
            # RGB归一化
            rn, gn, bn = r/255.0, g/255.0, b/255.0
            mx, mn = max(rn, gn, bn), min(rn, gn, bn)
            l = (mx + mn) / 2.0
            
            # 判断亮度区域
            lum = l * 255
            if lum > 140:
                h_shift = wall_hue
            elif lum > 60:
                h_shift = roof_hue
            else:
                h_shift = base_hue
            
            if mx == mn:
                h_val = 0.0
                s = 0.0
            else:
                d = mx - mn
                s = d / (2.0 - mx - mn) if l > 0.5 else d / (mx + mn)
                if mx == rn:
                    h_val = ((gn - bn) / d + (6 if gn < bn else 0)) / 6.0
                elif mx == gn:
                    h_val = ((bn - rn) / d + 2) / 6.0
                else:
                    h_val = ((rn - gn) / d + 4) / 6.0
            
            # 应用偏移
            h_val = (h_val + h_shift / 360.0) % 1.0
            s = max(0, min(1, s * sat_scale))
            l = max(0, min(1, l + lum_shift / 255.0))
            
            # HSL → RGB
            if s == 0:
                nr = ng = nb = int(l * 255)
            else:
                def hue_to_rgb(p, q, t):
                    if t < 0: t += 1
                    if t > 1: t -= 1
                    if t < 1/6: return p + (q - p) * 6 * t
                    if t < 1/2: return q
                    if t < 2/3: return p + (q - p) * (2/3 - t) * 6
                    return p
                q = l * (1 + s) if l < 0.5 else l + s - l * s
                p = 2 * l - q
                nr = int(hue_to_rgb(p, q, h_val + 1/3) * 255)
                ng = int(hue_to_rgb(p, q, h_val) * 255)
                nb = int(hue_to_rgb(p, q, h_val - 1/3) * 255)
            
            pixels[x, y] = (max(0, min(255, nr)), max(0, min(255, ng)), 
                           max(0, min(255, nb)), a)
    return img

def add_level_upgrades(img, level):
    """根据等级添加升级细节"""
    if level <= 1:
        return img
    w, h = img.size
    canvas = Image.new('RGBA', (w + 60, h + 60), (0, 0, 0, 0))
    scale = 0.8 + (level - 1) * 0.04
    new_w = int(w * scale)
    new_h = int(h * scale)
    scaled = img.resize((new_w, new_h), Image.LANCZOS)
    x_offset = (canvas.width - new_w) // 2
    y_offset = canvas.height - new_h
    canvas.paste(scaled, (x_offset, y_offset), scaled)
    draw = ImageDraw.Draw(canvas)
    
    flag_x = canvas.width // 2
    if level >= 2:
        flag_y = y_offset - 10
        draw.polygon([(flag_x, flag_y), (flag_x, flag_y - 25), (flag_x + 15, flag_y - 12)], fill=(200, 50, 50, 255))
        draw.line([(flag_x, flag_y), (flag_x, flag_y - 25)], fill=(120, 60, 30, 255), width=2)
    if level >= 3:
        draw.polygon([(flag_x - 20, y_offset - 15), (flag_x - 20, y_offset - 35), (flag_x - 5, y_offset - 25)], fill=(200, 50, 50, 255))
        draw.line([(flag_x - 20, y_offset - 15), (flag_x - 20, y_offset - 35)], fill=(120, 60, 30, 255), width=2)
    if level >= 4:
        for i in range(0, canvas.width, 14):
            draw.rectangle([i, y_offset + new_h - 8, i + 8, y_offset + new_h], fill=(220, 180, 40, 200))
    if level >= 5:
        draw.polygon([(flag_x - 15, y_offset - 25), (flag_x, y_offset - 50), (flag_x + 15, y_offset - 25)], fill=(200, 180, 100, 220))
        draw.rectangle([flag_x - 5, y_offset - 25, flag_x + 5, y_offset - 10], fill=(200, 180, 100, 220))
    if level >= 6:
        for side_x in [x_offset + 8, x_offset + new_w - 14]:
            for py in range(y_offset + int(new_h * 0.3), y_offset + new_h - 8, 10):
                draw.rectangle([side_x, py, side_x + 5, py + 6], fill=(220, 200, 150, 200))
    if level >= 7:
        wall_y = y_offset + new_h + 2
        for wx in range(x_offset, x_offset + new_w, 8):
            draw.rectangle([wx, wall_y, wx + 6, wall_y + 10], fill=(160, 150, 130, 200))
    if level >= 8:
        for tx, ty in [(x_offset - 12, y_offset), (x_offset + new_w - 4, y_offset),
                       (x_offset - 12, y_offset + new_h - 25), (x_offset + new_w - 4, y_offset + new_h - 25)]:
            draw.polygon([(tx, ty + 30), (tx + 10, ty), (tx + 20, ty + 30)], fill=(180, 160, 100, 200))
    if level >= 9:
        draw.ellipse([flag_x - 18, y_offset - 55, flag_x + 18, y_offset - 20], fill=(255, 215, 0, 220))
        draw.polygon([(flag_x, y_offset - 65), (flag_x - 12, y_offset - 40), (flag_x + 12, y_offset - 40)], fill=(255, 50, 50, 255))
    if level >= 10:
        draw.polygon([(flag_x - 18, y_offset - 70), (flag_x - 18, y_offset - 100), (flag_x + 12, y_offset - 85)], fill=(255, 215, 0, 255))
        draw.line([(flag_x - 18, y_offset - 70), (flag_x - 18, y_offset - 100)], fill=(150, 75, 0, 255), width=3)
        glow = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
        glow_draw = ImageDraw.Draw(glow)
        glow_draw.ellipse([flag_x - 35, y_offset - 90, flag_x + 35, y_offset - 20], fill=(255, 215, 0, 60))
        canvas = Image.alpha_composite(canvas, glow)
    
    canvas = canvas.crop(canvas.getbbox() or (0, 0, canvas.width, canvas.height))
    return canvas

def main():
    print("=" * 60)
    print("生成大本营纹理：10级 × 6文明（HSL色调偏移方案）")
    print("=" * 60)
    
    if not os.path.exists(TEMPLATE):
        print(f"[ERROR] 模板不存在: {TEMPLATE}")
        return
    
    template = Image.open(TEMPLATE).convert("RGBA")
    print(f"模板尺寸: {template.size}")
    
    out_dir = BASE
    random.seed(42)
    
    for civ in CIV_NAMES:
        tint = CIV_TINTS[civ]
        print(f"\n--- {civ.upper()} ---")
        
        # 分区HSL色调偏移（屋顶/墙壁/基座不同色相）
        civ_base = apply_tint(template.copy(), 
            tint["roof_hue"], tint["wall_hue"], tint["base_hue"],
            tint["sat"], tint["lum"])
        
        for level in range(1, 11):
            if level == 1:
                img = civ_base
            else:
                img = add_level_upgrades(civ_base, level)
            
            filename = f"town_hall_{civ}_l{level}.png"
            out_path = os.path.join(out_dir, filename)
            img.save(out_path)
            print(f"  L{level}: {filename} -> {img.size}")

if __name__ == "__main__":
    main()
