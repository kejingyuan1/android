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


    return (door_left, door_right, door_top, door_bottom)
    """
    清除三处镂空区域（无颜色过滤，直接硬编码坐标）：
    ① 中间门洞 → 两柱之间
    ② 左飞檐下方 → 屋檐与主体间的三角间隙
    ③ 右飞檐下方 → 屋檐与主体间的三角间隙
    """
    pixels = img.load()
    w, h = img.size

    # ===== ① 中间门洞 =====
    # 间隙实际在 x=365-435(70px), y=527-638
    # 使用动态检测确认精确边界
    door_left, door_right = 366, 434
    door_top, door_bottom = 527, 638
    c1 = 0
    for y in range(door_top, door_bottom):
        for x in range(door_left, door_right):
            if pixels[x, y][3] > 10:
                pixels[x, y] = (0, 0, 0, 0)
                c1 += 1
    print(f"  ①门洞: ({door_left}-{door_right},{door_top}-{door_bottom}) {c1}px")

    # ===== ② 左飞檐下方 =====
    # 飞檐尖端 x=6-36 → 间隙 x=37-84(透明) → 建筑主体 x=85+
    # 创建可见挑檐效果：从间隙内缘(x=37)切到建筑主体(x=110)
    lx1, lx2 = 37, 110
    ly1, ly2 = 357, 443
    c2 = 0
    for y in range(ly1, ly2):
        for x in range(lx1, lx2):
            if pixels[x, y][3] > 10:
                pixels[x, y] = (0, 0, 0, 0)
                c2 += 1
    print(f"  ②左飞檐: ({lx1}-{lx2},{ly1}-{ly2}) {c2}px")

    # ===== ③ 右飞檐下方 =====
    # 建筑主体 x=532 → 间隙 x=533-580(透明) → 飞檐尖端 x=581-609
    rx1, rx2 = 506, 579
    ry1, ry2 = 357, 443
    c3 = 0
    for y in range(ry1, ry2):
        for x in range(rx1, rx2):
            if pixels[x, y][3] > 10:
                pixels[x, y] = (0, 0, 0, 0)
                c3 += 1
    print(f"  ③右飞檐: ({rx1}-{rx2},{ry1}-{ry2}) {c3}px")

    total = c1 + c2 + c3
    print(f"  三处合计: {total}px")
    return img, total
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
