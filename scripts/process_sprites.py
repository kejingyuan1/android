"""Process sprites: flood-fill bg removal + anti-alias edge blending."""
from PIL import Image
import os

sheet_path = r"C:\Users\WIN11\WorkBuddy\2026-06-01-16-27-34\city-builder\assets\textures\A_sprite_sheet_of_8_buildings__2026-06-03T00-30-18.png"
out_dir = r"C:\Users\WIN11\WorkBuddy\2026-06-01-16-27-34\city-builder\assets\textures\buildings"
os.makedirs(out_dir, exist_ok=True)

img = Image.open(sheet_path).convert("RGBA")
w, h = img.size
cols, rows = 3, 3
cw, ch = w // cols, h // rows

names = [
    "house1", "house2", "apartment",
    "shop", "office", "factory",
    "fire_station", "police", "hospital"
]

def get_bg_color(cell, margin=8):
    """Sample background color from corners."""
    pixels = cell.load()
    cw, ch = cell.size
    samples = []
    for sx in [margin, cw - margin - 1]:
        for sy in [margin, ch - margin - 1]:
            for dx in range(6):
                for dy in range(6):
                    px, py = sx + dx, sy + dy
                    if 0 <= px < cw and 0 <= py < ch:
                        r, g, b, a = pixels[px, py]
                        samples.append((r, g, b))
    ar = sum(s[0] for s in samples) / len(samples)
    ag = sum(s[1] for s in samples) / len(samples)
    ab = sum(s[2] for s in samples) / len(samples)
    return (ar, ag, ab)

for row in range(rows):
    for col in range(cols):
        idx = row * cols + col
        if idx >= len(names):
            break
        cell = img.crop((col*cw, row*ch, (col+1)*cw, (row+1)*ch)).copy()
        pixels = cell.load()
        cw, ch = cell.size

        bg = get_bg_color(cell)

        # Step 1: Flood-fill remove background (threshold=35 to catch all bg)
        visited = [[False]*ch for _ in range(cw)]
        stack = [(x, y) for x in range(cw) for y in [0, ch-1]] + \
                [(x, y) for y in range(ch) for x in [0, cw-1]]
        while stack:
            x, y = stack.pop()
            if not (0 <= x < cw and 0 <= y < ch) or visited[x][y]:
                continue
            visited[x][y] = True
            r, g, b, a = pixels[x, y]
            d = ((r-bg[0])**2 + (g-bg[1])**2 + (b-bg[2])**2)**0.5
            if d < 35:
                pixels[x, y] = (r, g, b, 0)
                for dx, dy in [(1,0),(-1,0),(0,1),(0,-1)]:
                    nx, ny = x+dx, y+dy
                    if 0 <= nx < cw and 0 <= ny < ch and not visited[nx][ny]:
                        stack.append((nx, ny))

        # Step 2: Gentle anti-alias fix - only pixels very close to bg get reduced alpha
        for y in range(ch):
            for x in range(cw):
                r, g, b, a = pixels[x, y]
                if a == 0:
                    continue
                d = ((r-bg[0])**2 + (g-bg[1])**2 + (b-bg[2])**2)**0.5
                # Only pixels that were anti-aliased to bg (d < 50) get blended
                # But keep building edges strong (d > 40 stays at full opacity)
                if d < 40:
                    # Very close to bg: blend more
                    t = d / 40.0  # 0 to 1
                    new_a = int(255 * t * t)  # Quadratic falloff
                    pixels[x, y] = (r, g, b, new_a)
                # d >= 40: keep original alpha (building is solid)

        # Step 3: Find bounding box
        min_x, min_y = cw, ch
        max_x, max_y = -1, -1
        for y in range(ch):
            for x in range(cw):
                if pixels[x, y][3] > 0:
                    min_x = min(min_x, x)
                    min_y = min(min_y, y)
                    max_x = max(max_x, x)
                    max_y = max(max_y, y)

        if max_x < min_x:
            continue

        # Step 4: Crop tight
        pad = 1
        bx1, by1 = max(0, min_x-pad), max(0, min_y-pad)
        bx2, by2 = min(cw, max_x+1+pad), min(ch, max_y+1+pad)
        tight = cell.crop((bx1, by1, bx2, by2))
        tw, th = tight.size

        # Step 5: Scale to 64x64
        scale = 64.0 / max(tw, th) * 0.88
        nw, nh = max(1, int(tw*scale)), max(1, int(th*scale))
        resized = tight.resize((nw, nh), Image.LANCZOS)

        canvas = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        cx, cy = (64-nw)//2, (64-nh)//2
        canvas.paste(resized, (cx, cy), resized)
        canvas.save(os.path.join(out_dir, f"{names[idx]}.png"))

        p = canvas.load()
        semi = sum(1 for y in range(64) for x in range(64) if 0 < p[x,y][3] < 255)
        print(f"{names[idx]}: {tw}x{th}->{nw}x{nh} | anti-alias pixels={semi}")

print("\nDone!")
