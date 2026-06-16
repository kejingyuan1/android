"""
清理世界地图主城纹理（capital_*.png）：
1. 去除右下角AI水印文字
2. BFS去除亮色背景残留
3. 裁剪到内容区域
"""
from PIL import Image
import os
from collections import deque

WORLD_MAP_DIR = "C:/Users/WIN11/WorkBuddy/2026-06-01-16-27-34/city-builder/assets/textures/world_map"

CIV_NAMES = ["china", "rome", "britain", "egypt", "japan", "viking"]


def remove_watermark_generic(img):
    """通用水印去除"""
    pixels = img.load()
    w, h = img.size
    removed = 0
    for y in range(max(0, h-80), h):
        for x in range(max(0, w-200), w):
            r, g, b, a = pixels[x, y]
            if a > 10:
                max_diff = max(r, g, b) - min(r, g, b)
                lum = (r + g + b) // 3
                if lum > 130 and max_diff < 40:
                    pixels[x, y] = (0, 0, 0, 0)
                    removed += 1
    return img, removed


def flood_fill_remove_bg(img):
    """从四角BFS去除背景残留"""
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


def crop_to_content(img, margin=6):
    bbox = img.getbbox()
    if bbox:
        x0, y0, x1, y1 = bbox
        return img.crop((max(0, x0-margin), max(0, y0-margin),
                        min(img.width, x1+margin), min(img.height, y1+margin)))
    return img


def main():
    print("=" * 60)
    print("清理世界地图主城纹理（6个文明）")
    print("=" * 60)

    total_wm = 0
    total_bg = 0

    for civ in CIV_NAMES:
        path = os.path.join(WORLD_MAP_DIR, f"capital_{civ}_v2.png")
        if not os.path.exists(path):
            print(f"[SKIP] {civ}: 文件不存在")
            continue

        img = Image.open(path).convert("RGBA")
        print(f"\n--- {civ.upper()} ({img.size}) ---")

        # 去水印
        img, wm = remove_watermark_generic(img)
        total_wm += wm

        # 去背景
        img, bg = flood_fill_remove_bg(img)
        total_bg += bg

        # 裁剪
        img = crop_to_content(img, margin=6)
        print(f"  水印:{wm} 背景:{bg} → {img.size}")

        # 保存覆盖
        img.save(path)
        print(f"  已保存: capital_{civ}_v2.png")

        # 验证
        pixels = img.load()
        w2, h2 = img.size
        wm_left = 0
        for y in range(max(0, h2-80), h2):
            for x in range(max(0, w2-200), w2):
                r, g, b, a = pixels[x, y]
                if a > 10:
                    max_diff = max(r,g,b)-min(r,g,b)
                    if max_diff < 40 and (r+g+b)//3 > 130:
                        wm_left += 1
        if wm_left > 0:
            print(f"  ⚠ 仍有 {wm_left} 水印像素残留")
        else:
            print(f"  ✓ 水印已清除")

    print(f"\n✅ 总计: 水印{total_wm} + 背景{total_bg} 像素已清理")
    print("=" * 60)


if __name__ == "__main__":
    main()
