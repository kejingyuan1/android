"""
生成大本营纹理：10 级 × 6 文明 = 60 个等距建筑贴图
流程：
  1. 清理模板：去除水印 + 去除背景残留 + 柱子间门洞镂空透明
  2. HSL 色调偏移生成各文明变体
  3. 门洞镂空透明（HSL之后再做一次，防止 HSL 改变了门洞像素）
  4. 升级装饰
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


def remove_watermark(img):
    """精确去除右下角 '图片1' 水印文字（近白色像素集群）"""
    pixels = img.load()
    w, h = img.size
    
    # 水印区域：右下角 250x100 范围内的近白色像素
    # 从数据来看水印在 x=499-598, y=865-914，松一点
    wm_x0, wm_y0 = max(0, w - 250), max(0, h - 100)
    
    # 先标记出水印区域中的非透明像素
    wm_pixels = []
    for y in range(wm_y0, h):
        for x in range(wm_x0, w):
            r, g, b, a = pixels[x, y]
            if a > 10:
                wm_pixels.append((x, y, r, g, b))
    
    if not wm_pixels:
        return img, 0
    
    # 计算水印边界框
    xs = [p[0] for p in wm_pixels]
    ys = [p[1] for p in wm_pixels]
    x0, x1 = max(wm_x0, min(xs) - 5), min(w, max(xs) + 5)
    y0, y1 = max(wm_y0, min(ys) - 3), min(h, max(ys) + 3)
    
    removed = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, a = pixels[x, y]
            if a < 10:
                continue
            # 水印像素特征是亮度极高（近白色）
            # 检查是否应该被移除：像素亮度高 且 在背景区域
            lum = (r + g + b) // 3
            if lum > 200:
                # 设为完全透明
                pixels[x, y] = (0, 0, 0, 0)
                removed += 1
            elif lum > 170 and (r > 200 and g > 200 and b > 200):
                pixels[x, y] = (0, 0, 0, 0)
                removed += 1
    
    return img, removed


def remove_background_remnants(img):
    """去除建筑边缘的背景残留像素（泛洪填充 + 四角检测 + 小孤立像素群）"""
    pixels = img.load()
    w, h = img.size
    
    # 从四角开始 BFS 去除白色/透明背景残留
    from collections import deque
    visited = set()
    q = deque()
    for sx, sy in [(0,0), (w-1,0), (0,h-1), (w-1,h-1), (w//2,0), (0,h//2), (w-1,h//2), (w//2,h-1)]:
        q.append((sx, sy))
        visited.add((sx, sy))
    
    removed_bg = 0
    while q:
        x, y = q.popleft()
        r, g, b, a = pixels[x, y]
        # 背景判断：透明 或 非常亮 或 非常接近白色
        if a < 5:
            continue  # 已经透明
        is_bg = False
        if r > 230 and g > 230 and b > 230:
            is_bg = True  # 白色/亮背景
        elif a < 20:
            is_bg = True  # 半透明背景
        if is_bg:
            pixels[x, y] = (0, 0, 0, 0)
            removed_bg += 1
            for nx, ny in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
                if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                    visited.add((nx, ny))
                    q.append((nx, ny))
    
    return img, removed_bg


def make_door_transparent(img):
    """
    使柱子之间的门洞区域镂空透明以露出草地
    门洞区域：x=365-435, y=515-640（以 799x921 模板为基准）
    策略：将门洞区域内所有非建筑结构像素设为透明
    注意：仅去除门洞内部像素，保留门框、柱子边界
    """
    pixels = img.load()
    w, h = img.size
    
    removed = 0
    # 门洞区域
    door_x0, door_x1 = 365, 435
    door_y0, door_y1 = 515, 640
    
    for y in range(door_y0, min(door_y1, h)):
        for x in range(door_x0, min(door_x1, w)):
            r, g, b, a = pixels[x, y]
            if a < 10:
                continue
            
            # 分析该像素是否属于建筑结构（门框、柱子边缘）还是门洞内部
            lum = (r + g + b) // 3
            
            # 门洞内部特征：暗色（门洞空间）或 纯色背景残留
            # 建筑结构（应保留）特征：暖色调（金色/红色）且饱和度高
            is_structure = False
            
            # 门框/柱子边缘：暖色（红/金）且有一定饱和度
            if r > g + 20 or (r > 180 and g > 100 and b < 100):
                is_structure = True  # 红色/金色建筑结构
            elif r > 150 and g > 80 and b < 60:
                is_structure = True  # 深红色柱子
            elif r > 200 and g > 150 and b < 80:
                is_structure = True  # 金色装饰
            
            # 明亮像素 > 190 → 可能是背景或水印残留
            if lum > 190:
                is_structure = False
            
            # 中间区域（x=388-421, y=530-615）—— 门洞中部，应完全透明
            if x >= 388 and x <= 421 and y >= 530 and y <= 615:
                is_structure = False
            
            if not is_structure:
                pixels[x, y] = (0, 0, 0, 0)
                removed += 1
    
    return img, removed


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
    print("生成大本营纹理：10级 × 6文明")
    print("=" * 60)
    
    if not os.path.exists(TEMPLATE):
        print(f"[ERROR] 模板不存在: {TEMPLATE}")
        return
    
    template = Image.open(TEMPLATE).convert("RGBA")
    print(f"模板尺寸: {template.size}")
    
    # === 第一步：清理模板 ===
    print("\n--- 第1步：清理模板 ---")
    template, wm = remove_watermark(template)
    print(f"  去除水印: {wm} 像素")
    template, bg = remove_background_remnants(template)
    print(f"  去除背景残留: {bg} 像素")
    template, dr = make_door_transparent(template)
    print(f"  门洞镂空: {dr} 像素")
    
    # 保存清理后的模板（便于验证）
    template.save(TEMPLATE)
    print(f"  已保存清理版模板")
    
    out_dir = BASE
    random.seed(42)
    
    for civ in CIV_NAMES:
        tint = CIV_TINTS[civ]
        print(f"\n--- {civ.upper()} ---")
        
        # 第2步：分区HSL色调偏移
        civ_base = apply_tint(template.copy(), 
            tint["roof_hue"], tint["wall_hue"], tint["base_hue"],
            tint["sat"], tint["lum"])
        
        # 第3步：HSL之后再次确保门洞镂空（防止HSL改变了门洞像素颜色）
        civ_base, dr2 = make_door_transparent(civ_base)
        if dr2 > 0:
            print(f"  HSL后额外镂空门洞: {dr2} 像素")
        
        # 第4步：再次确保水印被清除（HSL可能生成新的亮像素）
        civ_base, wm2 = remove_watermark(civ_base)
        if wm2 > 0:
            print(f"  HSL后额外去水印: {wm2} 像素")
        
        for level in range(1, 11):
            if level == 1:
                img = civ_base
            else:
                img = add_level_upgrades(civ_base, level)
            
            filename = f"town_hall_{civ}_l{level}.png"
            out_path = os.path.join(out_dir, filename)
            img.save(out_path)
            print(f"  L{level}: {filename} -> {img.size}")
    
    # === 验证 ===
    print("\n" + "=" * 60)
    print("验证所有输出纹理...")
    total_wm = 0
    total_door = 0
    for civ in CIV_NAMES:
        for level in [1, 5, 10]:
            path = os.path.join(out_dir, f"town_hall_{civ}_l{level}.png")
            if not os.path.exists(path):
                continue
            img = Image.open(path).convert("RGBA")
            w, h = img.size
            
            # 验证水印
            wm_count = sum(1 for y in range(max(0, h-100), h) for x in range(max(0, w-250), w)
                          if img.getpixel((x, y))[3] > 10 and sum(img.getpixel((x, y))[:3])//3 > 200)
            if wm_count > 0:
                print(f"  ⚠ {civ}_l{level}.png: 右下角残留 {wm_count} 个亮像素")
                total_wm += wm_count
            else:
                print(f"  ✓ {civ}_l{level}.png: 水印已清除")
            
            # 验证门洞
            door_count = sum(1 for y in range(515, min(640, h)) for x in range(388, 421)
                           if x < w and y < h and img.getpixel((x, y))[3] > 10)
            if door_count > 0:
                print(f"  ⚠ {civ}_l{level}.png: 门洞中部残留 {door_count} 像素")
                total_door += door_count
    
    if total_wm == 0:
        print("\n✅ 所有纹理水印彻底清除！")
    else:
        print(f"\n⚠ 总计残留 {total_wm} 个水印像素")
    if total_door == 0:
        print("✅ 所有纹理门洞镂空正确！")
    else:
        print(f"⚠ 总计残留 {total_door} 个门洞像素")
    print("=" * 60)


if __name__ == "__main__":
    main()
