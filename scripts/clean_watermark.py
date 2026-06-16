"""
精确去除大本营纹理右下角'AI生成'水印
方案：仅对水印文字区域做局部像素修复，不裁剪建筑
"""
from PIL import Image, ImageDraw
from collections import deque
import os

BASE = "C:/Users/WIN11/WorkBuddy/2026-06-01-16-27-34/city-builder/assets/textures/buildings"

def remove_watermark_precise(img):
    """
    定位水印文字区域并用周围像素颜色填充
    水印在原始 ImageGen 输出中位于右下角约 200x60 区域
    文字为浅色/白色像素
    """
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    pixels = img.load()
    w, h = img.size
    
    # 1. 找到水印文字的实际边界框（浅色连续像素区域）
    watermark_pixels = []
    for y in range(max(0, h-70), h):
        for x in range(max(0, w-220), w):
            r, g, b, a = pixels[x, y]
            # 水印文字：近白色或亮色像素
            if a > 10 and (r > 200 or g > 200 or b > 200):
                watermark_pixels.append((x, y))
    
    if not watermark_pixels:
        # 尝试找任何非透明像素（可能水印被着色了）
        for y in range(max(0, h-70), h):
            for x in range(max(0, w-220), w):
                r, g, b, a = pixels[x, y]
                if a > 10:
                    watermark_pixels.append((x, y))
    
    if not watermark_pixels:
        return img, 0
    
    # 2. 计算水印区域的边界
    xs = [p[0] for p in watermark_pixels]
    ys = [p[1] for p in watermark_pixels]
    x0, x1 = max(0, min(xs)-5), min(w, max(xs)+5)
    y0, y1 = max(0, min(ys)-5), min(h, max(ys)+5)
    
    # 3. 用水印区域上方的像素颜色填充水印区域
    for y in range(y0, y1):
        for x in range(x0, x1):
            if pixels[x, y] in watermark_pixels or (pixels[x, y][3] > 10 and 
                (x, y) in watermark_pixels):
                # 从上方采样颜色
                if y > 10:
                    sample_y = max(0, y0 - (y1 - y))
                    # 采样多个像素取平均
                    colors = []
                    for sx in range(max(0, x-5), min(w, x+5)):
                        if sx < w:
                            c = pixels[sx, sample_y]
                            if c[3] > 10:
                                colors.append(c[:3])
                    if colors:
                        avg_r = sum(c[0] for c in colors) // len(colors)
                        avg_g = sum(c[1] for c in colors) // len(colors)
                        avg_b = sum(c[2] for c in colors) // len(colors)
                        pixels[x, y] = (avg_r, avg_g, avg_b, 255)
                    else:
                        pixels[x, y] = (0, 0, 0, 0)
                else:
                    pixels[x, y] = (0, 0, 0, 0)
    
    return img, len(watermark_pixels)

def main():
    template = os.path.join(BASE, "town_hall_template.png")
    if not os.path.exists(template):
        print(f"[ERROR] 模板不存在: {template}")
        return
    
    img = Image.open(template).convert("RGBA")
    print(f"原始尺寸: {img.size}")
    
    img, removed = remove_watermark_precise(img)
    print(f"去除水印: {removed} 像素")
    
    img.save(template)
    print(f"已保存: {template}")
    
    # 验证
    verify = Image.open(template).convert("RGBA")
    w, h = verify.size
    # 检查右下角
    remnant = sum(1 for y in range(max(0, h-60), h) for x in range(max(0, w-200), w) 
                  if verify.getpixel((x, y))[3] > 10)
    print(f"验证-右下角剩余非透明像素: {remnant}")
    
    # 同时处理埃及模板
    egypt = os.path.join(BASE, "town_hall_egyptian_template.png")
    if os.path.exists(egypt):
        eimg = Image.open(egypt).convert("RGBA")
        eimg, eremoved = remove_watermark_precise(eimg)
        print(f"埃及模板: 去除水印 {eremoved} 像素")
        eimg.save(egypt)

if __name__ == "__main__":
    main()
