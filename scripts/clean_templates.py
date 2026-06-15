"""清理大本营模板（去背景+去水印+裁剪）"""
from PIL import Image
from collections import deque
import os

BASE = "C:/Users/WIN11/WorkBuddy/2026-06-01-16-27-34/city-builder/assets/textures/buildings"

def flood_fill_remove_bg(img, threshold=40):
    w, h = img.size
    pixels = img.load()
    visited = set()
    q = deque()
    # Seed from corners and edges
    seeds = [(0,0),(w-1,0),(0,h-1),(w-1,h-1),(w//2,0),(0,h//2),(w-1,h//2),(w//2,h-1)]
    for sx, sy in seeds:
        q.append((sx, sy))
        visited.add((sx, sy))
    removed = 0
    while q:
        x, y = q.popleft()
        r, g, b, a = pixels[x, y]
        # Background: transparent already, or very light/white
        if a < 10 or (r > 220 and g > 220 and b > 220):
            if a > 0:
                removed += 1
            pixels[x, y] = (0, 0, 0, 0)
            for nx, ny in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
                if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                    visited.add((nx, ny))
                    q.append((nx, ny))
    return removed

def crop_and_clean(img, margin=6):
    w, h = img.size
    bbox = img.getbbox()
    if not bbox:
        return img
    x0, y0, x1, y1 = bbox
    # Crop with margin
    crop = img.crop((max(0, x0-margin), max(0, y0-margin),
                     min(w, x1+margin), min(h, y1+margin)))
    # Remove right 210px to ensure watermark is gone
    cw, ch = crop.size
    if cw > 210:
        crop = crop.crop((0, 0, cw-210, ch))
    return crop

def main():
    for fname in ["town_hall_template.png", "town_hall_egyptian_template.png"]:
        path = os.path.join(BASE, fname)
        if not os.path.exists(path):
            print(f"  [SKIP] {fname} - not found")
            continue
        img = Image.open(path).convert("RGBA")
        print(f"  {fname}: {img.size}")
        removed = flood_fill_remove_bg(img)
        print(f"    Removed {removed} bg pixels")
        img = crop_and_clean(img)
        print(f"    Cropped to {img.size}")
        img.save(path)
        # Verify: check watermark zone
        w, h = img.size
        zone_px = sum(1 for y in range(max(0,h-60),h) for x in range(max(0,w-200),w)
                     if img.getpixel((x,y))[3] > 10)
        print(f"    Watermark zone content: {zone_px} pixels")

if __name__ == "__main__":
    main()
