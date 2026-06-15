"""
生成更好的等距地形纹理
每个纹理是 64x32 的菱形像素风格贴图
"""
from PIL import Image, ImageDraw
import random
import os

TILE_W = 64
TILE_H = 32
CENTER_X = TILE_W // 2
CENTER_Y = TILE_H // 2

def create_diamond_mask():
    """创建等距菱形遮罩 (64x32)"""
    mask = Image.new('L', (TILE_W, TILE_H), 0)
    draw = ImageDraw.Draw(mask)
    # 菱形四个角
    top = (CENTER_X, 0)
    right = (TILE_W - 1, CENTER_Y)
    bottom = (CENTER_X, TILE_H - 1)
    left = (0, CENTER_Y)
    draw.polygon([top, right, bottom, left], fill=255)
    return mask

def is_in_diamond(x, y):
    """检查点是否在菱形内"""
    dx = abs(x - CENTER_X)
    dy = abs(y - CENTER_Y)
    return dx / CENTER_X + dy / CENTER_Y <= 1.0

def noise_pixel(base_color, noise_amount=15):
    """添加噪点颜色变化"""
    r = max(0, min(255, base_color[0] + random.randint(-noise_amount, noise_amount)))
    g = max(0, min(255, base_color[1] + random.randint(-noise_amount, noise_amount)))
    b = max(0, min(255, base_color[2] + random.randint(-noise_amount, noise_amount)))
    return (r, g, b)

def create_grass_texture(seed=0, variant=0):
    """生成草地纹理 - 绿色底色带黄色点缀"""
    random.seed(seed + variant)
    img = Image.new('RGBA', (TILE_W, TILE_H), (0, 0, 0, 0))
    pixels = img.load()

    base_colors = [(58, 140, 40), (65, 150, 45), (55, 130, 35)]
    base = base_colors[variant]

    for y in range(TILE_H):
        for x in range(TILE_W):
            if is_in_diamond(x, y):
                # 基础草色 + 噪点
                color = noise_pixel(base, 20)
                # 添加随机小花/草点缀
                if random.random() < 0.03:
                    if random.random() < 0.5:
                        color = (220, 220, 80)  # 黄色小花
                    else:
                        color = (180, 220, 100)  # 淡绿点缀
                pixels[x, y] = (color[0], color[1], color[2], 255)

    return img

def create_water_texture(seed=0, variant=0):
    """生成水域纹理 - 蓝色底色带波浪纹理"""
    random.seed(seed + variant)
    img = Image.new('RGBA', (TILE_W, TILE_H), (0, 0, 0, 0))
    pixels = img.load()

    base_colors = [(45, 100, 180), (50, 110, 190), (40, 95, 175)]
    base = base_colors[variant]

    for y in range(TILE_H):
        for x in range(TILE_W):
            if is_in_diamond(x, y):
                # 波浪效果 - 根据x位置添加亮度变化
                wave = int((x / TILE_W) * 20)
                color = noise_pixel((base[0] + wave, base[1] + wave, base[2] + wave), 10)
                # 随机高光
                if random.random() < 0.05:
                    color = (color[0] + 40, color[1] + 50, color[2] + 60)
                pixels[x, y] = (color[0], color[1], color[2], 255)

    return img

def create_sand_texture(seed=0):
    """生成沙滩纹理 - 米黄色带颗粒感"""
    random.seed(seed)
    img = Image.new('RGBA', (TILE_W, TILE_H), (0, 0, 0, 0))
    pixels = img.load()

    base = (210, 190, 130)

    for y in range(TILE_H):
        for x in range(TILE_W):
            if is_in_diamond(x, y):
                color = noise_pixel(base, 25)
                # 沙粒效果
                if random.random() < 0.02:
                    color = (color[0] - 20, color[1] - 20, color[2] - 10)
                pixels[x, y] = (color[0], color[1], color[2], 255)

    return img

def create_forest_texture(seed=0):
    """生成森林纹理 - 深绿色带树木纹理"""
    random.seed(seed)
    img = Image.new('RGBA', (TILE_W, TILE_H), (0, 0, 0, 0))
    pixels = img.load()

    base = (35, 100, 35)

    for y in range(TILE_H):
        for x in range(TILE_W):
            if is_in_diamond(x, y):
                color = noise_pixel(base, 15)
                # 树木阴影/高光
                if random.random() < 0.1:
                    color = (color[0] - 15, color[1] - 10, color[2] - 15)
                elif random.random() < 0.05:
                    color = (color[0] + 20, color[1] + 30, color[2] + 10)
                pixels[x, y] = (color[0], color[1], color[2], 255)

    return img

def create_mountain_texture(seed=0):
    """生成山脉纹理 - 连续岩石山体，灰色调带自然条纹"""
    random.seed(seed)
    img = Image.new('RGBA', (TILE_W, TILE_H), (0, 0, 0, 0))
    pixels = img.load()

    for y in range(TILE_H):
        for x in range(TILE_W):
            if is_in_diamond(x, y):
                # 基于坐标生成岩石纹理
                rel_y = y / TILE_H
                rel_x = abs(x - CENTER_X) / CENTER_X

                # 岩石底色 - 山脉灰，底部偏暖
                base_r = 130 + int(rel_x * 15) + int(rel_y * 20)
                base_g = 120 + int(rel_x * 10) + int(rel_y * 15)
                base_b = 110 + int(rel_y * 10)

                # 水平岩层条纹 (让相邻格子的纹理在接缝处更连续)
                stripe = int(y * 0.7 + x * 0.3)
                if stripe % 5 < 1:
                    base_r -= 20
                    base_g -= 20
                    base_b -= 18
                elif stripe % 5 > 3:
                    base_r += 10
                    base_g += 8
                    base_b += 6

                # 边缘加阴影，让菱形更有立体感
                edge_factor = 1.0 - (rel_x * rel_x + rel_y * rel_y) * 0.3
                base_r = int(base_r * (0.85 + edge_factor * 0.15))
                base_g = int(base_g * (0.85 + edge_factor * 0.15))
                base_b = int(base_b * (0.85 + edge_factor * 0.15))

                # 噪点
                color = noise_pixel((base_r, base_g, base_b), 12)

                pixels[x, y] = (color[0], color[1], color[2], 255)

    return img

def create_dirt_texture(seed=0):
    """生成泥土纹理 - 棕色带纹理"""
    random.seed(seed)
    img = Image.new('RGBA', (TILE_W, TILE_H), (0, 0, 0, 0))
    pixels = img.load()

    base = (140, 100, 60)

    for y in range(TILE_H):
        for x in range(TILE_W):
            if is_in_diamond(x, y):
                color = noise_pixel(base, 20)
                # 泥土纹理
                if random.random() < 0.03:
                    color = (color[0] + 10, color[1] + 5, color[2] - 5)
                pixels[x, y] = (color[0], color[1], color[2], 255)

    return img

def create_highlight_texture():
    """生成高亮边框纹理"""
    img = Image.new('RGBA', (TILE_W, TILE_H), (0, 0, 0, 0))
    pixels = img.load()

    # 菱形边框
    for y in range(TILE_H):
        for x in range(TILE_W):
            if is_in_diamond(x, y):
                # 检查是否是边缘像素
                edge_thickness = 2
                is_edge = False
                for dy in range(-edge_thickness, edge_thickness+1):
                    for dx in range(-edge_thickness, edge_thickness+1):
                        nx, ny = x + dx, y + dy
                        if nx < 0 or nx >= TILE_W or ny < 0 or ny >= TILE_H:
                            is_edge = True
                        elif not is_in_diamond(nx, ny):
                            is_edge = True

                if is_edge:
                    pixels[x, y] = (255, 220, 80, 200)  # 黄色边缘
                else:
                    pixels[x, y] = (255, 255, 200, 40)  # 淡黄填充

    return img

def create_ghost_texture():
    """生成虚影纹理 - 半透明白色菱形"""
    img = Image.new('RGBA', (TILE_W, TILE_H), (0, 0, 0, 0))
    pixels = img.load()

    for y in range(TILE_H):
        for x in range(TILE_W):
            if is_in_diamond(x, y):
                pixels[x, y] = (255, 255, 255, 100)  # 半透明白

    return img

def create_shadow_texture():
    """生成建筑阴影纹理 - 深色菱形"""
    img = Image.new('RGBA', (TILE_W, TILE_H), (0, 0, 0, 0))
    pixels = img.load()

    for y in range(TILE_H):
        for x in range(TILE_W):
            if is_in_diamond(x, y):
                pixels[x, y] = (0, 0, 0, 80)  # 半透明黑

    return img

def main():
    base_path = "C:/Users/WIN11/WorkBuddy/2026-06-01-16-27-34/city-builder/assets/textures/isometric"
    seed = 42

    # 生成草地纹理 (3种变体)
    for i in range(3):
        img = create_grass_texture(seed, i)
        img.save(os.path.join(base_path, f"grass_{i}.png"))
        print(f"Generated grass_{i}.png")

    # 生成水域纹理 (3种变体)
    for i in range(3):
        img = create_water_texture(seed, i)
        img.save(os.path.join(base_path, f"water_{i}.png"))
        print(f"Generated water_{i}.png")

    # 生成沙滩纹理
    img = create_sand_texture(seed)
    img.save(os.path.join(base_path, "sand.png"))
    print("Generated sand.png")

    # 生成森林纹理
    img = create_forest_texture(seed)
    img.save(os.path.join(base_path, "forest.png"))
    print("Generated forest.png")

    # 生成山脉纹理 (改善版)
    img = create_mountain_texture(seed)
    img.save(os.path.join(base_path, "mountain.png"))
    print("Generated mountain.png")

    # 生成泥土纹理
    img = create_dirt_texture(seed)
    img.save(os.path.join(base_path, "dirt.png"))
    print("Generated dirt.png")

    # 生成高亮纹理
    img = create_highlight_texture()
    img.save(os.path.join(base_path, "highlight.png"))
    print("Generated highlight.png")

    # 生成虚影纹理
    img = create_ghost_texture()
    img.save(os.path.join(base_path, "ghost.png"))
    print("Generated ghost.png")

    # 生成阴影纹理
    img = create_shadow_texture()
    img.save(os.path.join(base_path, "shadow.png"))
    print("Generated shadow.png")

    print("\n所有纹理生成完成!")

if __name__ == "__main__":
    main()
