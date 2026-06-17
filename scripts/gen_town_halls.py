"""
生成大本营纹理：10级 × 6文明
透明处理：动态检测柱子间隙 → 清除中间门洞区域
输出: textures/buildings/{civ}/l{level}_v2.png
"""
from PIL import Image, ImageDraw
import os, random
from collections import deque

BASE = "C:/Users/WIN11/WorkBuddy/2026-06-01-16-27-34/city-builder/assets/textures/buildings"
TEMPLATE = os.path.join(BASE, "town_hall_template_v2.png")

CIV_NAMES = ["chinese", "roman", "british", "egyptian", "japanese", "viking"]

CIV_TINTS = {
    "chinese":  {"roof_hue": 0,  "wall_hue": 0,    "base_hue": 0,  "sat": 1.0, "lum": 0},
    "roman":    {"roof_hue": 0,  "wall_hue": 3,    "base_hue": 5,  "sat": 1.1, "lum": 8},
    "british":  {"roof_hue": 0,  "wall_hue": -3,   "base_hue": -3, "sat": 0.8, "lum": -5},
    "egyptian": {"roof_hue": 0,  "wall_hue": 8,    "base_hue": 10, "sat": 1.2, "lum": 12},
    "japanese": {"roof_hue": 0,  "wall_hue": -2,   "base_hue": -2, "sat": 0.7, "lum": -8},
    "viking":   {"roof_hue": 0,  "wall_hue": 2,    "base_hue": 5,  "sat": 0.9, "lum": -10},
}


def remove_watermark(img):
    pixels = img.load()
    w, h = img.size
    removed = 0
    for y in range(max(0, h-80), h):
        for x in range(max(0, w-150), w):
            r, g, b, a = pixels[x, y]
            if a > 10:
                if max(r,g,b)-min(r,g,b) < 40 and (r+g+b)//3 > 130:
                    pixels[x, y] = (0, 0, 0, 0)
                    removed += 1
    return img, removed


def flood_fill_remove_bg(img):
    """从四角BFS去除白色/浅色背景残留（更宽松阈值）"""
    pixels = img.load()
    w, h = img.size
    visited = set()
    q = deque()
    for sx, sy in [(0,0),(w-1,0),(0,h-1),(w-1,h-1),(w//2,0),(0,h//2),(w-1,h//2),(w//2,h-1)]:
        q.append((sx, sy))
        visited.add((sx, sy))
    removed = 0
    while q:
        x, y = q.popleft()
        r, g, b, a = pixels[x, y]
        if a < 5:
            continue
        if r > 220 and g > 220 and b > 220:
            pixels[x, y] = (0, 0, 0, 0)
            removed += 1
            for nx, ny in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
                if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                    visited.add((nx, ny))
                    q.append((nx, ny))
    return img, removed


def detect_door_gap(img):
    """检测柱子间门洞并清除三处镂空：中间门洞 + 左右飞檐下方"""
    pixels = img.load()
    w, h = img.size

    # ===== 中间门洞 (基于616x851模板) =====
    # 门洞在 x=364-436(72px), y=527-640
    door_left = int(w * 0.59)
    door_right = int(w * 0.71)
    door_top = int(h * 0.62)
    door_bottom = int(h * 0.75)

    # 在目标区域内确认间隙
    actual_left = door_right
    actual_right = door_left
    for y in range(door_top, door_bottom):
        cols = [x for x in range(w) if pixels[x, y][3] > 10]
        if len(cols) < 5: continue
        gaps = []
        prev = cols[0]
        for c in cols[1:]:
            if c - prev > 15:
                gaps.append((prev+1, c-1, c-prev))
            prev = c
        for gs, ge, gw in gaps:
            if gw > 40 and door_left < gs and ge < door_right:
                actual_left = min(actual_left, gs)
                actual_right = max(actual_right, ge)

    if actual_left < actual_right:
        door_left = actual_left + 2
        door_right = actual_right - 2
    else:
        door_left = door_left + 5
        door_right = door_right - 5

    # 清除门洞
    door_cleared = 0
    for y in range(door_top, door_bottom):
        for x in range(door_left, door_right):
            if pixels[x, y][3] > 10:
                pixels[x, y] = (0, 0, 0, 0)
                door_cleared += 1
    print(f"  门洞: x={door_left}-{door_right} y={door_top}-{door_bottom} 清除{door_cleared}像素")

    # ===== 左飞檐下方 =====
    # 在建筑上部左侧，屋檐下方的空间
    # 位置：门洞偏上偏左的区域，在屋顶和立柱之间
    left_x1 = int(w * 0.12)
    left_x2 = int(w * 0.35)
    left_y1 = int(h * 0.38)
    left_y2 = int(h * 0.55)
    left_cleared = 0
    for y in range(left_y1, left_y2):
        for x in range(left_x1, left_x2):
            if pixels[x, y][3] > 10:
                # 只清除非屋顶颜色的像素（避免切掉飞檐）
                r, g, b, a = pixels[x, y]
                # 屋顶颜色：金色/黄色 (R>150, G>100, R/G接近)
                is_roof = (r > 150 and g > 100 and abs(r - g) < 60)
                # 暗色装饰/门框保留
                is_dark_deco = (r < 60 and g < 50 and b < 50)
                if not is_roof and not is_dark_deco:
                    pixels[x, y] = (0, 0, 0, 0)
                    left_cleared += 1
    if left_cleared < 200:
        # 稳健补清
        for y in range(left_y1, left_y2):
            for x in range(left_x1, left_x2):
                if pixels[x, y][3] > 10:
                    pixels[x, y] = (0, 0, 0, 0)
                    left_cleared += 1
    print(f"  左飞檐下: x={left_x1}-{left_x2} y={left_y1}-{left_y2} 清除{left_cleared}像素")

    # ===== 右飞檐下方 =====
    right_x1 = int(w * 0.62)
    right_x2 = int(w * 0.88)
    right_y1 = int(h * 0.38)
    right_y2 = int(h * 0.55)
    right_cleared = 0
    for y in range(right_y1, right_y2):
        for x in range(right_x1, right_x2):
            if pixels[x, y][3] > 10:
                r, g, b, a = pixels[x, y]
                is_roof = (r > 150 and g > 100 and abs(r - g) < 60)
                is_dark_deco = (r < 60 and g < 50 and b < 50)
                # 避开门洞区域(door_left-door_right, door_top-door_bottom)的像素
                if door_left < x < door_right and door_top < y < door_bottom:
                    continue
                if not is_roof and not is_dark_deco:
                    pixels[x, y] = (0, 0, 0, 0)
                    right_cleared += 1
    if right_cleared < 200:
        for y in range(right_y1, right_y2):
            for x in range(right_x1, right_x2):
                if pixels[x, y][3] > 10:
                    if door_left < x < door_right and door_top < y < door_bottom:
                        continue
                    pixels[x, y] = (0, 0, 0, 0)
                    right_cleared += 1
    print(f"  右飞檐下: x={right_x1}-{right_x2} y={right_y1}-{right_y2} 清除{right_cleared}像素")

    total = door_cleared + left_cleared + right_cleared
    print(f"  三处合计: {total}像素")
    return (door_left, door_right, door_top, door_bottom)


def _find_gaps(cols, w, gap_min):
    if len(cols) < 5: return []
    gaps = []
    prev = cols[0]
    for c in cols[1:]:
        if c - prev > gap_min:
            gaps.append((prev+1, c-1, c-prev))
        prev = c
    return gaps


def make_door_transparent(img):
    """
    清除三处镂空：
    1. 左飞檐下方 → 屋檐翘角与建筑主体之间的狭长三角区
    2. 中间门洞 → 两柱之间的开敞空间
    3. 右飞檐下方 → 屋檐翘角与建筑主体之间的狭长三角区
    """
    pixels = img.load()
    w, h = img.size
    total_before = sum(1 for y in range(h) for x in range(w) if pixels[x, y][3] > 10)

    # ===== 门洞 (x=59%-71%宽, y=62%-75%高) =====
    door_left = int(w * 0.59)
    door_right = int(w * 0.71)
    door_top = int(h * 0.62)
    door_bottom = int(h * 0.75)

    # 在目标区域内确认实际间隙边界
    actual_left = door_right
    actual_right = door_left
    for y in range(door_top, door_bottom):
        cols = [x for x in range(w) if pixels[x, y][3] > 10]
        if len(cols) < 5: continue
        for prev, curr, _gw in [(cols[i], cols[i+1], cols[i+1]-cols[i]) for i in range(len(cols)-1) if cols[i+1]-cols[i] > 15]:
            if curr - prev > 40 and door_left < prev and curr < door_right:
                actual_left = min(actual_left, prev+2)
                actual_right = max(actual_right, curr-2)

    dl = actual_left if actual_left < actual_right else (door_left + 5)
    dr = actual_right if actual_left < actual_right else (door_right - 5)
    door_cleared = 0
    for y in range(door_top, door_bottom):
        for x in range(dl, dr):
            if pixels[x, y][3] > 10:
                pixels[x, y] = (0, 0, 0, 0)
                door_cleared += 1
    print(f"  ①门洞: x={dl}-{dr} y={door_top}-{door_bottom} ({door_cleared}px)")

    # ===== 左右飞檐下 (精准小三角区域) =====
    # 左飞檐：建筑左侧 x=10%-20%宽, y=42%-52%高
    # 右飞檐：建筑右侧 x=80%-90%宽, y=42%-52%高
    for side, (x_s, x_e) in [("左", (int(w*0.10), int(w*0.22))), ("右", (int(w*0.78), int(w*0.90)))]:
        y_s = int(h * 0.42)
        y_e = int(h * 0.52)
        cleared = 0
        for y in range(y_s, y_e):
            for x in range(x_s, x_e):
                if pixels[x, y][3] > 10:
                    r, g, b, a = pixels[x, y]
                    # 颜色比值检测：黄金屋顶保留，其他移除
                    is_gold_roof = (r > g * 0.85 and g > b * 0.65)  # 金色特征
                    is_dark_detailing = (r + g + b < 120)  # 深色细节（柱子/阴影）
                    if not is_gold_roof and not is_dark_detailing:
                        pixels[x, y] = (0, 0, 0, 0)
                        cleared += 1
        print(f"  {'③' if side=='右' else '②'}{side}飞檐: x={x_s}-{x_e} y={y_s}-{y_e} ({cleared}px)")

    total_after = sum(1 for y in range(h) for x in range(w) if pixels[x, y][3] > 10)
    removed = total_before - total_after
    print(f"  三处合计: {removed}px")
    return img, removed


def apply_tint(img, roof_hue, wall_hue, base_hue, sat_scale, lum_shift):
    pixels = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a < 10:
                continue
            rn, gn, bn = r / 255.0, g / 255.0, b / 255.0
            mx, mn = max(rn, gn, bn), min(rn, gn, bn)
            l = (mx + mn) / 2.0
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
            h_val = (h_val + h_shift / 360.0) % 1.0
            s = max(0, min(1, s * sat_scale))
            l = max(0, min(1, l + lum_shift / 255.0))
            if s == 0:
                nr = ng = nb = int(l * 255)
            else:
                def hue_to_rgb(p, q, t):
                    if t < 0:
                        t += 1
                    if t > 1:
                        t -= 1
                    if t < 1/6:
                        return p + (q - p) * 6 * t
                    if t < 1/2:
                        return q
                    if t < 2/3:
                        return p + (q - p) * (2/3 - t) * 6
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
    if level<=1: return img
    w,h=img.size
    canvas=Image.new('RGBA',(w+60,h+60),(0,0,0,0))
    scale=0.8+(level-1)*0.04
    nw,nh=int(w*scale),int(h*scale)
    scaled=img.resize((nw,nh),Image.LANCZOS)
    xo=(canvas.width-nw)//2; yo=canvas.height-nh
    canvas.paste(scaled,(xo,yo),scaled)
    draw=ImageDraw.Draw(canvas); fx=canvas.width//2
    if level>=2: draw.ellipse([fx-6,yo-10,fx+6,yo+2],fill=(255,100,100,255))
    if level>=3: draw.polygon([(fx-20,yo-15),(fx-20,yo-35),(fx-5,yo-25)],fill=(200,50,50,255))
    if level>=4:
        for i in range(0,canvas.width,14): draw.rectangle([i,yo+nh-8,i+8,yo+nh],fill=(220,180,40,200))
    if level>=5:
        draw.polygon([(fx-15,yo-25),(fx,yo-50),(fx+15,yo-25)],fill=(200,180,100,220))
        draw.rectangle([fx-5,yo-25,fx+5,yo-10],fill=(200,180,100,220))
    if level>=6:
        for sx in [xo+8,xo+nw-14]:
            for py in range(yo+int(nh*.3),yo+nh-8,10): draw.rectangle([sx,py,sx+5,py+6],fill=(220,200,150,200))
    if level>=7:
        for wx in range(xo,xo+nw,8): draw.rectangle([wx,yo+nh+2,wx+6,yo+nh+12],fill=(160,150,130,200))
    if level>=8:
        for tx,ty in [(xo-12,yo),(xo+nw-4,yo)]:
            draw.polygon([(tx,ty+30),(tx+10,ty),(tx+20,ty+30)],fill=(180,160,100,200))
    if level>=9:
        draw.ellipse([fx-18,yo-55,fx+18,yo-20],fill=(255,215,0,220))
        draw.polygon([(fx,yo-65),(fx-12,yo-40),(fx+12,yo-40)],fill=(255,50,50,255))
    if level>=10:
        draw.polygon([(fx-18,yo-70),(fx-18,yo-100),(fx+12,yo-85)],fill=(255,215,0,255))
        glow=Image.new('RGBA',canvas.size,(0,0,0,0));gd=ImageDraw.Draw(glow)
        gd.ellipse([fx-35,yo-90,fx+35,yo-20],fill=(255,215,0,60))
        canvas=Image.alpha_composite(canvas,glow)
    return canvas.crop(canvas.getbbox() or (0,0,canvas.width,canvas.height))


def crop_to_content(img, margin=6):
    bbox=img.getbbox()
    if bbox:
        x0,y0,x1,y1=bbox
        return img.crop((max(0,x0-margin),max(0,y0-margin),min(img.width,x1+margin),min(img.height,y1+margin)))
    return img


def main():
    print("="*60)
    print("生成大本营纹理：10级×6文明 → civ/l{level}_v2.png")
    print("="*60)

    if not os.path.exists(TEMPLATE):
        print(f"[ERROR] 模板不存在: {TEMPLATE}"); return

    template = Image.open(TEMPLATE).convert("RGBA")
    print(f"模板尺寸: {template.size}")

    print("\n--- 清理模板 ---")
    template, wm = remove_watermark(template)
    print(f"  水印: {wm}像素")
    template, bg = flood_fill_remove_bg(template)
    print(f"  背景: {bg}像素")

    random.seed(42)

    for civ in CIV_NAMES:
        tint = CIV_TINTS[civ]
        print(f"\n--- {civ.upper()} ---")

        civ_dir = os.path.join(BASE, civ)
        os.makedirs(civ_dir, exist_ok=True)

        civ_img = template.copy()
        civ_img = apply_tint(civ_img, tint["roof_hue"], tint["wall_hue"],
                            tint["base_hue"], tint["sat"], tint["lum"])

        # 动态检测门洞并镂空
        civ_img, dr = make_door_transparent(civ_img)

        # 去水印
        civ_img, wm2 = remove_watermark(civ_img)
        if wm2: print(f"  水印: {wm2}像素")

        # 裁剪
        civ_img = crop_to_content(civ_img, margin=6)
        print(f"  裁剪: {civ_img.size}")

        for level in range(1, 11):
            img = civ_img.copy() if level==1 else add_level_upgrades(civ_img.copy(), level)
            out_path = os.path.join(civ_dir, f"l{level}_v2.png")
            img.save(out_path)
            if level==1: print(f"  L{level}: {img.size} → {civ}/l{level}_v2.png")

    # 验证
    print(f"\n{'='*60}\n验证")
    for civ in CIV_NAMES:
        civ_dir = os.path.join(BASE, civ)
        for level in [1,5,10]:
            path = os.path.join(civ_dir, f"l{level}_v2.png")
            if not os.path.exists(path):
                print(f"  ✗ 缺失: {civ}/l{level}_v2.png"); continue
            img = Image.open(path).convert("RGBA")
            w2,h2=img.size
            # 门洞透明
            dx1,dx2=int(w2*.55),int(w2*.75)
            dy1,dy2=int(h2*.62),int(h2*.72)
            opaque = sum(1 for y in range(dy1,dy2) for x in range(dx1,dx2) if img.getpixel((x,y))[3]>10)
            total = (dx2-dx1)*(dy2-dy1)
            pct = (total-opaque)/total*100 if total>0 else 0
            print(f"  {'✓' if pct>20 else '⚠'} {civ}/l{level}_v2.png: {w2}x{h2} 门洞透明{pct:.0f}%")
    print("="*60)


if __name__ == "__main__":
    main()
