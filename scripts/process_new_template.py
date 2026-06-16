"""
处理新生成的ImageGen大本营贴图：
1. 去背景（四角泛洪）
2. 精确去除右下角水印文字
3. 裁剪到内容+边距（不裁剪建筑本身）
"""
from PIL import Image
from collections import deque
import os

def flood_fill_bg(img, threshold=30):
    """从四角泛洪去除背景"""
    w, h = img.size
    pixels = img.load()
    visited = set()
    q = deque()
    for sx, sy in [(0,0),(w-1,0),(0,h-1),(w-1,h-1),(w//2,0),(0,h//2),(w-1,h//2),(w//2,h-1)]:
        q.append((sx, sy))
        visited.add((sx, sy))
    removed = 0
    while q:
        x, y = q.popleft()
        r, g, b, a = pixels[x, y]
        # 找背景：透明或非常亮/纯色区域
        is_bg = False
        if a < 5:
            is_bg = True
        elif r > 250 and g > 250 and b > 250:
            is_bg = True
        elif a > 0 and r > 200 and g > 200 and b > 200:
            is_bg = True
        if is_bg:
            if a > 0:
                pixels[x, y] = (0, 0, 0, 0)
                removed += 1
            for nx, ny in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
                if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                    visited.add((nx, ny))
                    q.append((nx, ny))
    return removed

def remove_watermark(img):
    """精确去除右下角水印文字"""
    pixels = img.load()
    w, h = img.size
    
    # 在右下角 250x80 区域找水印文字像素（浅色、高亮、或白色像素）
    watermark_zone = []
    for y in range(max(0, h-80), h):
        for x in range(max(0, w-250), w):
            r, g, b, a = pixels[x, y]
            if a > 10:
                watermark_zone.append((x, y))
    
    if not watermark_zone:
        return 0
    
    # 计算水印边界
    xs = [p[0] for p in watermark_zone]
    ys = [p[1] for p in watermark_zone]
    x0, x1 = max(0, min(xs)-3), min(w, max(xs)+3)
    y0, y1 = max(0, min(ys)-3), min(h, max(ys)+3)
    
    # 用水印上方/周围的颜色填充
    removed = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            if pixels[x, y][3] > 10:
                # 从上方像素采样颜色
                if y > 15:
                    sample = []
                    for sx in range(max(0, x-8), min(w, x+8)):
                        c = pixels[sx, y-15]
                        if c[3] > 10:
                            sample.append(c[:3])
                    if sample:
                        avg = tuple(sum(c[i] for c in sample) // len(sample) for i in range(3))
                        pixels[x, y] = avg + (255,)
                        removed += 1
                    else:
                        pixels[x, y] = (0, 0, 0, 0)
                else:
                    pixels[x, y] = (0, 0, 0, 0)
    return removed

def crop_to_content(img, margin=6):
    """裁剪到建筑实际区域（不裁掉建筑边缘）"""
    bbox = img.getbbox()
    if bbox:
        x0, y0, x1, y1 = bbox
        crop = img.crop((max(0, x0-margin), max(0, y0-margin), 
                        min(img.width, x1+margin), min(img.height, y1+margin)))
        return crop
    return img

def main():
    base = "C:/Users/WIN11/WorkBuddy/2026-06-01-16-27-34/city-builder/assets/textures/buildings"
    
    # 找到最新生成的 ImageGen 输出
    import glob
    files = sorted(glob.glob(os.path.join(base, "Isometric_pixel_art_COC*")))
    if not files:
        print("[ERROR] 未找到新生成的模板")
        return
    
    src = files[-1]
    print(f"源文件: {os.path.basename(src)}")
    
    img = Image.open(src).convert("RGBA")
    print(f"原始尺寸: {img.size}, 模式: {img.mode}")
    
    # 1. 去背景
    bg_removed = flood_fill_bg(img)
    print(f"去背景: {bg_removed} 像素")
    
    # 2. 去水印
    wm_removed = remove_watermark(img)
    print(f"去水印: {wm_removed} 像素")
    
    # 3. 裁剪到内容
    img = crop_to_content(img, margin=8)
    print(f"裁剪后: {img.size}")
    
    # 验证
    w, h = img.size
    remnant = sum(1 for y in range(max(0, h-60), h) for x in range(max(0, w-200), w) 
                  if img.getpixel((x, y))[3] > 10)
    print(f"右下角 200x60 非透明像素: {remnant}")
    
    # 保存为模板
    template_path = os.path.join(base, "town_hall_template.png")
    img.save(template_path)
    print(f"模板已保存: {template_path}")
    
    # 重新生成所有纹理
    print("\n=== 重新生成所有大本营纹理 ===")
    import subprocess
    subprocess.run(["python", "scripts/gen_town_halls.py"], cwd="C:/Users/WIN11/WorkBuddy/2026-06-01-16-27-34/city-builder")

if __name__ == "__main__":
    main()
