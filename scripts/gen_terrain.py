#!/usr/bin/env python3
"""Generate colorful pixel-art terrain tiles + detailed road + isometric building shadows."""
import os
from PIL import Image, ImageDraw

OUT = "assets/textures/city/"
os.makedirs(OUT, exist_ok=True)

def make_terrain_tiles():
    """Create 32x32 terrain tiles with colorful pixel-art detail."""
    tiles = {
        "grass": {
            "base": [(80, 160, 50), (70, 150, 45), (90, 170, 55)],
            "detail": [(120, 190, 60), (60, 130, 35), (100, 180, 50)],
        },
        "forest": {
            "base": [(50, 120, 35), (40, 100, 30), (60, 140, 40)],
            "detail": [(30, 90, 25), (70, 150, 45), (80, 160, 50)],
        },
        "sand": {
            "base": [(210, 195, 140), (200, 185, 130), (220, 200, 150)],
            "detail": [(190, 175, 120), (230, 215, 160), (180, 165, 110)],
        },
        "water": {
            "base": [(50, 100, 180), (40, 90, 170), (60, 110, 190)],
            "detail": [(70, 120, 200), (30, 80, 160), (55, 105, 185)],
        },
        "mountain": {
            "base": [(130, 120, 110), (120, 110, 100), (140, 130, 120)],
            "detail": [(100, 90, 80), (150, 140, 130), (160, 150, 140)],
        },
    }
    
    for name, colors in tiles.items():
        sheet = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
        for idx in range(4):
            ax, ay = idx % 2, idx // 2
            tile = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
            draw = ImageDraw.Draw(tile)
            base = colors["base"][idx % len(colors["base"])]
            detail = colors["detail"][idx % len(colors["detail"])]
            
            # Base fill with tiny variation
            for y in range(32):
                for x in range(32):
                    v = ((x * 7 + y * 13 + idx * 5) % 5 - 2) * 6
                    r = max(0, min(255, base[0] + v))
                    g = max(0, min(255, base[1] + v))
                    b = max(0, min(255, base[2] + v))
                    tile.putpixel((x, y), (r, g, b, 255))
            
            # Detail dots (flowers, stones, grass tufts)
            import random
            random.seed(idx * 12345)
            for _ in range(12):
                rx, ry = random.randint(2, 29), random.randint(2, 29)
                dc = random.choice(detail)
                tile.putpixel((rx, ry), dc)
                if random.random() > 0.6:
                    for dx, dy in [(0,1),(1,0),(-1,0),(0,-1)]:
                        nx, ny = rx+dx, ry+dy
                        if 0 <= nx < 32 and 0 <= ny < 32:
                            tile.putpixel((nx, ny), (dc[0]-10, dc[1]-10, dc[2]-10, 255))
            
            # Edge darkening for depth
            for y in range(32):
                for x in range(32):
                    edge = min(x, 31-x, y, 31-y)
                    if edge < 3:
                        f = (3 - edge) * 0.04
                        r, g, b, a = tile.getpixel((x, y))
                        tile.putpixel((x, y), (int(r*(1-f)), int(g*(1-f)), int(b*(1-f)), 255))
            
            sheet.paste(tile, (ax*32, ay*32))
        
        sheet.save(f"{OUT}{name}_sheet.png")
        print(f"{name}_sheet.png")

make_terrain_tiles()
print("\nAll terrain tiles created!")
