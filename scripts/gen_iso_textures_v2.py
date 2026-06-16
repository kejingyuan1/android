"""
生成高质量的等距地形纹理 v2
每个纹理 64x32 菱形，大幅提升细节
使用分层噪点、微纹理和自然色彩变化
"""
from PIL import Image, ImageDraw
import random, math, os

TILE_W = 64
TILE_H = 32
CX = TILE_W // 2
CY = TILE_H // 2

def is_in_diamond(x, y):
    dx = abs(x - CX) / CX
    dy = abs(y - CY) / CY
    return dx + dy <= 1.0

def noise_color(base, amt=15):
    r = max(0, min(255, base[0] + random.randint(-amt, amt)))
    g = max(0, min(255, base[1] + random.randint(-amt, amt)))
    b = max(0, min(255, base[2] + random.randint(-amt, amt)))
    return (r, g, b)

def simple_noise(x, y, seed=0):
    """简单的值噪声"""
    n = hash((x + seed * 1000, y + seed * 2000)) & 0xFFFF
    return n / 65535.0

def draw_tile_pixels(draw_fn, *args):
    """通用图块绘制"""
    img = draw_fn.__self__._image if hasattr(draw_fn, '__self__') else None
    draw_fn(*args)

# ============ 草地纹理 ============
def create_grass(img, ox, oy, variant=0):
    pixels = img.load()
    base_green = [(58, 145, 38), (62, 152, 42), (52, 135, 32)][variant]
    
    for y in range(TILE_H):
        for x in range(TILE_W):
            if not is_in_diamond(x, y):
                pixels[ox+x, oy+y] = (0, 0, 0, 0)
                continue
            
            px, py = ox+x, oy+y
            ry = (y - CY) / CY
            
            # 基础草色：沿y轴渐变色增加立体感
            depth_factor = 1.0 - abs(ry) * 0.3  # 中心亮，边缘暗
            base = (
                int(base_green[0] * depth_factor),
                int(base_green[1] * depth_factor),
                int(base_green[2] * depth_factor)
            )
            c = noise_color(base, 12)
            
            # 自然色斑块（大的浅色/深色区域）
            patch = simple_noise(x//8, y//4, variant*100)
            if patch < 0.15:
                c = (min(c[0]+15,255), min(c[1]+20,255), min(c[2]+10,255))
            elif patch > 0.85:
                c = (max(c[0]-10,0), max(c[1]-12,0), max(c[2]-8,0))
            
            # 草丛细节（细长的草叶线条）
            grass_seed = hash((x, y, variant*99)) & 0xFFFF
            if grass_seed < 600:  # 约3.6%
                # 画一根草叶
                blade_angle = (grass_seed % 5) - 2  # -2 to 2
                for bx in range(max(0, x-1), min(TILE_W, x+2)):
                    for by in range(max(0, y-2), min(TILE_H, y+3)):
                        if abs(bx-x) <= 1 and abs(by-y) <= 2:
                            bdx = abs(bx-CX)/CX
                            bdy = abs(by-CY)/CY
                            if bdx + bdy <= 1.0:
                                pixels[ox+bx, oy+by] = (55 + blade_angle*5, 150 + blade_angle*3, 25)
            
            # 小黄花（约1.5%概率）
            if hash((x, y, variant*77+33)) % 256 < 4:
                for dx in range(-1, 2):
                    for dy in range(-1, 2):
                        nx, ny = x+dx, y+dy
                        if 0 <= nx < TILE_W and 0 <= ny < TILE_H and is_in_diamond(nx, ny):
                            pixels[ox+nx, oy+ny] = (240, 230, 60)
                            break
            
            pixels[px, py] = c

# ============ 水域纹理 ============
def create_water(img, ox, oy, variant=0):
    pixels = img.load()
    base_blue = [(40, 95, 180), (45, 105, 190), (35, 90, 170)][variant]
    
    for y in range(TILE_H):
        for x in range(TILE_W):
            if not is_in_diamond(x, y):
                pixels[ox+x, oy+y] = (0, 0, 0, 0)
                continue
            
            px, py = ox+x, oy+y
            
            # 波浪：不同频率的sin波叠加
            wave1 = math.sin(x * 0.2 + y * 0.1 + variant) * 8
            wave2 = math.sin(x * 0.15 - y * 0.12 + variant * 2) * 5
            wave_intensity = wave1 + wave2
            
            base = (
                int(base_blue[0] + wave_intensity * 0.5),
                int(base_blue[1] + wave_intensity * 0.8),
                int(base_blue[2] + wave_intensity * 1.2)
            )
            c = noise_color(base, 6)
            
            # 高光
            highlight = simple_noise(x, y, variant*50)
            if highlight > 0.92:
                c = (min(c[0]+50,255), min(c[1]+60,255), min(c[2]+70,255))
            
            # 水波纹短线
            if hash((x//3, y//2, variant*55)) % 10 == 0:
                c = (c[0]+15, c[1]+20, c[2]+25)
            
            pixels[px, py] = c

# ============ 沙滩纹理 ============
def create_sand(img, ox, oy):
    pixels = img.load()
    base_sand = (195, 180, 140)
    
    for y in range(TILE_H):
        for x in range(TILE_W):
            if not is_in_diamond(x, y):
                pixels[ox+x, oy+y] = (0, 0, 0, 0)
                continue
            
            c = noise_color(base_sand, 10)
            
            # 沙粒颗粒感
            grain = hash((x, y, 999)) % 20
            if grain < 3:
                c = (c[0]+8, c[1]+6, c[2]-3)
            elif grain > 16:
                c = (c[0]-5, c[1]-4, c[2]+5)
            
            # 小贝壳/亮点
            if hash((x, y, 888)) % 80 < 2:
                c = (240, 235, 210)
            
            pixels[ox+x, oy+y] = c

# ============ 森林纹理 ============
def create_forest(img, ox, oy):
    pixels = img.load()
    base_green = (40, 100, 35)
    
    for y in range(TILE_H):
        for x in range(TILE_W):
            if not is_in_diamond(x, y):
                pixels[ox+x, oy+y] = (0, 0, 0, 0)
                continue
            
            # 树冠效果：暗绿色斑块
            tree = simple_noise(x//4, y//3, 777)
            shade = int(tree * 20)
            base = (base_green[0] - shade, base_green[1] - shade + 10, base_green[2] - shade)
            c = noise_color(base, 10)
            
            # 树冠高光
            if tree < 0.2:
                c = (c[0]+10, c[1]+25, c[2]+8)
            
            # 透光点
            if hash((x, y, 666)) % 30 < 2:
                c = (c[0]+40, c[1]+50, c[2]+20)
            
            pixels[ox+x, oy+y] = c

# ============ 山脉纹理 ============
def create_mountain(img, ox, oy):
    pixels = img.load()
    
    for y in range(TILE_H):
        for x in range(TILE_W):
            if not is_in_diamond(x, y):
                pixels[ox+x, oy+y] = (0, 0, 0, 0)
                continue
            
            ry = (y - CY) / CY
            
            # 岩石灰（底部亮，顶部暗）
            height = 1.0 - abs(ry)
            base_gray = (100 + int(height * 50), 95 + int(height * 45), 90 + int(height * 40))
            
            # 岩石纹理条纹
            stripe = simple_noise(x//3, y, 555)
            c = (
                int(base_gray[0] + stripe * 20 - 10),
                int(base_gray[1] + stripe * 15 - 8),
                int(base_gray[2] + stripe * 12 - 6)
            )
            c = noise_color(c, 8)
            
            # 山顶雪（顶部区域）
            if abs(ry) < 0.25:
                snow = (1.0 - abs(ry) * 4) * 0.4
                if simple_noise(x, y, 444) < snow:
                    c = (240, 245, 250)
            
            pixels[ox+x, oy+y] = c

# ============ 泥土地纹理 ============
def create_dirt(img, ox, oy):
    pixels = img.load()
    base_brown = (140, 115, 75)
    
    for y in range(TILE_H):
        for x in range(TILE_W):
            if not is_in_diamond(x, y):
                pixels[ox+x, oy+y] = (0, 0, 0, 0)
                continue
            
            c = noise_color(base_brown, 12)
            
            # 碎石颗粒
            gravel = hash((x, y, 333)) % 15
            if gravel < 2:
                c = (c[0]+15, c[1]+10, c[2]-5)
            elif gravel > 12:
                c = (c[0]-10, c[1]-8, c[2]+10)
            
            # 小石子
            if hash((x//2, y//2, 222)) % 40 < 2:
                c = (160, 150, 130)
            
            pixels[ox+x, oy+y] = c

# ============ 高亮/虚影/阴影 ============
def create_overlay_textures(out_dir):
    # 高亮（半透明黄）
    hl = Image.new('RGBA', (TILE_W, TILE_H), (0,0,0,0))
    for y in range(TILE_H):
        for x in range(TILE_W):
            if is_in_diamond(x, y):
                hl.putpixel((x, y), (255, 255, 0, 60))
    hl.save(os.path.join(out_dir, "highlight.png"))
    
    # 虚影（半透明白）
    gh = Image.new('RGBA', (TILE_W, TILE_H), (0,0,0,0))
    for y in range(TILE_H):
        for x in range(TILE_W):
            if is_in_diamond(x, y):
                gh.putpixel((x, y), (255, 255, 255, 80))
    gh.save(os.path.join(out_dir, "ghost.png"))
    
    # 阴影
    sh = Image.new('RGBA', (TILE_W, TILE_H), (0,0,0,0))
    for y in range(TILE_H):
        for x in range(TILE_W):
            if is_in_diamond(x, y):
                dx = abs(x-CX)/CX
                dy = abs(y-CY)/CY
                alpha = int((1.0 - dx * 0.8 - dy * 0.2) * 60)
                sh.putpixel((x, y), (0, 0, 0, max(0, min(255, alpha))))
    sh.save(os.path.join(out_dir, "shadow.png"))

def main():
    out_dir = "C:/Users/WIN11/WorkBuddy/2026-06-01-16-27-34/city-builder/assets/textures/isometric"
    
    print("Generating high-quality isometric terrain textures v2...")
    random.seed(42)
    
    tiles = {
        "grass_0": lambda img,ox,oy: create_grass(img, ox, oy, 0),
        "grass_1": lambda img,ox,oy: create_grass(img, ox, oy, 1),
        "grass_2": lambda img,ox,oy: create_grass(img, ox, oy, 2),
        "water_0": lambda img,ox,oy: create_water(img, ox, oy, 0),
        "water_1": lambda img,ox,oy: create_water(img, ox, oy, 1),
        "water_2": lambda img,ox,oy: create_water(img, ox, oy, 2),
        "sand":    lambda img,ox,oy: create_sand(img, ox, oy),
        "forest":  lambda img,ox,oy: create_forest(img, ox, oy),
        "mountain":lambda img,ox,oy: create_mountain(img, ox, oy),
        "dirt":    lambda img,ox,oy: create_dirt(img, ox, oy),
    }
    
    for name, draw_fn in tiles.items():
        img = Image.new('RGBA', (TILE_W, TILE_H), (0, 0, 0, 0))
        draw_fn(img, 0, 0)
        path = os.path.join(out_dir, f"{name}.png")
        img.save(path)
        # Count non-transparent pixels
        w, h = img.size
        content = sum(1 for y in range(h) for x in range(w) if img.getpixel((x,y))[3] > 10)
        print(f"  {name}: {w}x{h}, {content} content pixels")
    
    # 生成覆盖层
    create_overlay_textures(out_dir)
    print("  overlay textures (highlight, ghost, shadow) generated")
    
    print("\\nDone!")

if __name__ == "__main__":
    main()
