"""
生成大本营纹理：10 级 × 6 文明 = 60 个等距建筑贴图
流程：
  1. 清理模板：去除水印 + 去除背景残留 + 柱子间门洞镂空透明
  2. HSL 色调偏移生成各文明变体
  3. 门洞镂空透明（HSL之后再做一次，防止 HSL 改变了门洞像素）
  4. 精确去除水印文字（HSL之后再做一次）
  5. 裁剪到内容
  6. 升级装饰
"""
from PIL import Image, ImageDraw
import os, math, random
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
    """
    精确去除右下角水印文字。
    策略：找到底部区域的近白色小色差孤立像素。
    """
    pixels = img.load()
    w, h = img.size

    # 扫描底部区域中非建筑结构的孤立亮像素
    removed = 0
    for y in range(max(0, h-80), h):
        for x in range(max(0, w-150), w):
            r, g, b, a = pixels[x, y]
            if a > 10:
                max_diff = max(r, g, b) - min(r, g, b)
                lum = (r + g + b) // 3
                # 水印特征：高亮度、低色差（近灰色）
                if lum > 130 and max_diff < 40:
                    pixels[x, y] = (0, 0, 0, 0)
                    removed += 1
    return img, removed


def flood_fill_remove_bg(img):
    """从四角 BFS 去除背景残留"""
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
        if r > 230 and g > 230 and b > 230:
            pixels[x, y] = (0, 0, 0, 0)
            removed += 1
            for nx, ny in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
                if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                    visited.add((nx, ny))
                    q.append((nx, ny))
    return img, removed


def make_door_transparent(img):
    """
    使柱子之间的门洞区域镂空透明。
    动态检测：在图像底部区域自动找到两列柱子之间的间隙，清空间隙像素。
    """
    pixels = img.load()
    w, h = img.size
    removed = 0

    # 在 y=50%~75% 高度范围内，找到 x 方向的透明间隙（柱子之间的门洞）
    mid_y_start = int(h * 0.55)
    mid_y_end = int(h * 0.72)

    # 扫描每行的透明间隙，聚合出门的左右边界
    door_left = w
    door_right = 0
    door_top = h
    door_bottom = 0

    for y in range(mid_y_start, mid_y_end):
        # 找到这一行中所有不透明像素的x范围
        opaque_x = [x for x in range(w) if pixels[x, y][3] > 10]
        if len(opaque_x) < 5:
            continue

        # 找到最大的连续不透明区间之间的间隙
        gaps = []
        prev = opaque_x[0]
        for cx in opaque_x[1:]:
            if cx - prev > 8:  # >8px的间隙
                gaps.append((prev + 1, cx - 1))
            prev = cx

        # 找到最宽的间隙（应该就是门洞）
        for gs, ge in gaps:
            gw = ge - gs
            if gw > 20:  # 门洞至少20px宽
                if gs < door_left:
                    door_left = gs
                if ge > door_right:
                    door_right = ge
                if y < door_top:
                    door_top = y
                if y > door_bottom:
                    door_bottom = y

    # 如果没有找到门洞，使用默认坐标
    if door_right <= door_left:
        door_left = max(0, w // 2 - 30)
        door_right = min(w, w // 2 + 30)
        door_top = mid_y_start
        door_bottom = mid_y_end

    # 加一点内边距（不要清掉柱子本身）
    door_center = (door_left + door_right) // 2
    door_left = max(0, door_center - 18)
    door_right = min(w, door_center + 18)

    # 扩大垂直范围，确保门楣也被清掉
    clear_top = max(0, door_top - 5)
    clear_bottom = min(h, door_bottom + 5)

    # 执行清除
    for y in range(clear_top, clear_bottom):
        for x in range(door_left, door_right):
            if pixels[x, y][3] > 10:
                pixels[x, y] = (0, 0, 0, 0)
                removed += 1

    if removed > 0:
        print(f"  [门洞] 动态检测: x={door_left}-{door_right} y={clear_top}-{clear_bottom} 清除{removed}像素")
    else:
        print(f"  [门洞] 未找到门洞间隙, 跳过")
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
            rn, gn, bn = r/255.0, g/255.0, b/255.0
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
        draw.ellipse([flag_x - 6, flag_y - 6, flag_x + 6, flag_y + 6], fill=(255, 100, 100, 255))
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


def crop_to_content(img, margin=6):
    """裁剪到建筑实际区域"""
    bbox = img.getbbox()
    if bbox:
        x0, y0, x1, y1 = bbox
        return img.crop((max(0, x0-margin), max(0, y0-margin),
                        min(img.width, x1+margin), min(img.height, y1+margin)))
    return img


def main():
    print("=" * 60)
    print("生成大本营纹理：10级 × 6文明")
    print("=" * 60)

    if not os.path.exists(TEMPLATE):
        print(f"[ERROR] 模板不存在: {TEMPLATE}")
        return

    # 加载原始模板（保持不裁剪！）
    template = Image.open(TEMPLATE).convert("RGBA")
    print(f"模板尺寸: {template.size}")

    # 对模板做永久性清理（操作在原尺寸上进行）
    print("\n--- 清理模板 ---")
    template, wm = remove_watermark(template)
    print(f"  去除水印: {wm} 像素")
    template, bg = flood_fill_remove_bg(template)
    print(f"  去除背景残留: {bg} 像素")
    template, dr = make_door_transparent(template)
    print(f"  门洞镂空: {dr} 像素")
    print(f"  清理后尺寸: {template.size}")

    # ===== 关键修改：只保存清理版模板，不裁剪！ =====
    # 裁剪操作在每个文明生成时单独执行
    # 这样门洞坐标始终在原始图像空间中是准确的

    out_dir = BASE
    random.seed(42)

    for civ in CIV_NAMES:
        tint = CIV_TINTS[civ]
        print(f"\n--- {civ.upper()} ---")

        # 复制已清理的全尺寸模板
        civ_img = template.copy()

        # 第2步：分区HSL色调偏移（全尺寸）
        civ_img = apply_tint(civ_img,
            tint["roof_hue"], tint["wall_hue"], tint["base_hue"],
            tint["sat"], tint["lum"])

        # 第3步：HSL之后再次确保门洞镂空（全尺寸，坐标正确）
        civ_img, dr2 = make_door_transparent(civ_img)
        if dr2 > 0:
            print(f"  HSL后额外镂空门洞: {dr2} 像素")

        # 第4步：再次去除水印（全尺寸）
        civ_img, wm2 = remove_watermark(civ_img)
        if wm2 > 0:
            print(f"  HSL后额外去水印: {wm2} 像素")

        # 第5步：裁剪到内容（每个文明独立裁剪）
        civ_img = crop_to_content(civ_img, margin=6)
        print(f"  裁剪后: {civ_img.size}")

        for level in range(1, 11):
            if level == 1:
                img = civ_img.copy()
            else:
                img = add_level_upgrades(civ_img, level)

            # 使用 _v2 后缀
            filename = f"town_hall_{civ}_l{level}_v2.png"
            out_path = os.path.join(out_dir, filename)
            img.save(out_path)
            print(f"  L{level}: {filename} -> {img.size}")

    # === 验证 ===
    print("\n" + "=" * 60)
    print("验证所有输出纹理...")
    all_clean = True
    for civ in CIV_NAMES:
        for level in [1, 5, 10]:
            path = os.path.join(out_dir, f"town_hall_{civ}_l{level}_v2.png")
            if not os.path.exists(path):
                continue
            img = Image.open(path).convert("RGBA")
            w2, h2 = img.size

            # 验证1：右下角找水印
            wm_count = 0
            for y in range(max(0, h2-80), h2):
                for x in range(max(0, w2-150), w2):
                    px = img.getpixel((x, y))
                    r, g, b, a = px
                    if a > 10:
                        max_diff = max(r,g,b) - min(r,g,b)
                        lum = (r+g+b)//3
                        if lum > 130 and max_diff < 40:
                            wm_count += 1

            # 验证2：门洞区域（中间50%宽度、55%-72%高度范围）的透明占比
            dx1 = int(w2 * 0.50)
            dx2 = int(w2 * 0.80)
            dy1 = int(h2 * 0.55)
            dy2 = int(h2 * 0.72)
            opaque_door = 0
            total_door = 0
            for y in range(dy1, dy2):
                for x in range(dx1, dx2):
                    if img.getpixel((x, y))[3] > 10:
                        opaque_door += 1
                    total_door += 1
            door_transparent_pct = (total_door - opaque_door) / total_door * 100 if total_door > 0 else 0

            if wm_count > 0:
                print(f"  ⚠ {civ}_l{level}: 右下角残留 {wm_count} 个疑似水印像素")
                all_clean = False
            else:
                print(f"  ✓ {civ}_l{level}: 水印已清除, 门洞透明显{door_transparent_pct:.0f}%")

    if all_clean:
        print("\n✅ 所有纹理水印彻底清除！")
    else:
        print("\n⚠ 部分纹理仍有水印残留")
    print("=" * 60)


if __name__ == "__main__":
    main()
