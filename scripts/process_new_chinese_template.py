"""
处理新生成的中国风建筑模板：
1. 去除灰色背景
2. 去除右下角水印
3. 裁剪到内容
4. 手动镂空三处透明区域
"""
from PIL import Image
from collections import deque
import os

INPUT_PATH = "C:/Users/WIN11/WorkBuddy/2026-06-01-16-27-34/city-builder/assets/textures/buildings/isometric_pixel_art_Chinese_te_2026-06-17T00-24-50.png"
OUTPUT_PATH = "C:/Users/WIN11/WorkBuddy/2026-06-01-16-27-34/city-builder/assets/textures/buildings/town_hall_template_v2.png"

def remove_background_and_watermark(img):
    """去除灰色背景和右下角水印"""
    pixels = img.load()
    w, h = img.size
    
    # 从四角BFS去除背景
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
        # 判断是否是背景（灰色系或接近灰色）
        # 背景色大约在 RGB(140, 140, 130) 左右
        is_bg = False
        if r > 120 and g > 120 and b > 110:  # 亮度较高
            max_diff = max(r,g,b) - min(r,g,b)
            if max_diff < 40:  # 低色差（灰色）
                is_bg = True
        
        if is_bg:
            pixels[x, y] = (0, 0, 0, 0)
            removed += 1
            for nx, ny in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
                if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                    visited.add((nx, ny))
                    q.append((nx, ny))
    
    print(f"  背景移除: {removed} 像素")
    return img

def remove_watermark_zone(img):
    """直接清除右下角水印区域"""
    pixels = img.load()
    w, h = img.size
    # 右下角 150x80 区域
    for y in range(h-80, h):
        for x in range(w-150, w):
            pixels[x, y] = (0, 0, 0, 0)
    print(f"  水印区域清除: 150x80")
    return img

def manual_cutout_three_areas(img):
    """手动镂空三处区域"""
    pixels = img.load()
    w, h = img.size
    
    # 分析图片结构，找出三处需要镂空的位置
    # 左飞檐下方、门洞、右飞檐下方
    
    # 策略：根据亮度/颜色识别门洞区域（通常较暗或有间隙）
    # 飞檐下方的镂空通常在建筑两侧的中上部
    
    # 扫描 y=50%-65% 高度，找到 x 方向的透明间隙
    door_gap = None
    for y_frac in [0.55, 0.58, 0.60, 0.62, 0.64, 0.66]:
        y = int(h * y_frac)
        cols = [x for x in range(w) if pixels[x, y][3] > 10]
        if len(cols) < 10:
            continue
        # 找间隙
        gaps = []
        prev = cols[0]
        for c in cols[1:]:
            if c - prev > 15:
                gaps.append((prev+1, c-1, c-prev))
            prev = c
        # 找最宽的间隙（门洞）
        for gs, ge, gw in gaps:
            if gw > 30 and 0.35 < gs/w < 0.50:  # 在建筑中间区域
                door_gap = (gs, ge, y)
                break
        if door_gap:
            break
    
    if door_gap:
        gs, ge, best_y = door_gap
        # 门洞区域
        door_center = (gs + ge) // 2
        door_left = max(door_center - 25, gs + 5)
        door_right = min(door_center + 25, ge - 5)
        door_top = int(h * 0.50)
        door_bottom = int(h * 0.72)
        
        count = 0
        for y in range(door_top, door_bottom):
            for x in range(door_left, door_right):
                if pixels[x, y][3] > 10:
                    pixels[x, y] = (0, 0, 0, 0)
                    count += 1
        print(f"  门洞镂空: x={door_left}-{door_right} y={door_top}-{door_bottom} ({count}像素)")
        
        # 左飞檐下（门洞左侧，y=45%-55%）
        left_x_end = door_left - 10
        left_x_start = max(0, left_x_end - 60)
        left_y_start = int(h * 0.42)
        left_y_end = int(h * 0.58)
        
        count2 = 0
        for y in range(left_y_start, left_y_end):
            for x in range(left_x_start, left_x_end):
                if pixels[x, y][3] > 10:
                    # 只清除非屋顶部分（避免切掉屋檐）
                    r, g, b, a = pixels[x, y]
                    # 屋顶通常是黄色/金色，墙体是红色
                    if not (r > 200 and g > 150 and b < 100):  # 不是金色
                        pixels[x, y] = (0, 0, 0, 0)
                        count2 += 1
        print(f"  左飞檐下镂空: x={left_x_start}-{left_x_end} y={left_y_start}-{left_y_end} ({count2}像素)")
        
        # 右飞檐下（门洞右侧，y=45%-55%）
        right_x_start = door_right + 10
        right_x_end = min(w, right_x_start + 60)
        
        count3 = 0
        for y in range(left_y_start, left_y_end):
            for x in range(right_x_start, right_x_end):
                if pixels[x, y][3] > 10:
                    r, g, b, a = pixels[x, y]
                    if not (r > 200 and g > 150 and b < 100):  # 不是金色
                        pixels[x, y] = (0, 0, 0, 0)
                        count3 += 1
        print(f"  右飞檐下镂空: x={right_x_start}-{right_x_end} y={left_y_start}-{left_y_end} ({count3}像素)")
    
    return img

def crop_to_content(img, margin=10):
    """裁剪到内容区域"""
    bbox = img.getbbox()
    if bbox:
        x0, y0, x1, y1 = bbox
        return img.crop((max(0, x0-margin), max(0, y0-margin),
                        min(img.width, x1+margin), min(img.height, y1+margin)))
    return img

def main():
    print("=" * 60)
    print("处理新生成的中国风建筑模板")
    print("=" * 60)
    
    img = Image.open(INPUT_PATH).convert("RGBA")
    print(f"原始尺寸: {img.size}")
    
    # 1. 去除背景
    img = remove_background_and_watermark(img)
    
    # 2. 去除水印区域
    img = remove_watermark_zone(img)
    
    # 3. 手动镂空三处
    img = manual_cutout_three_areas(img)
    
    # 4. 裁剪
    img = crop_to_content(img, margin=8)
    print(f"裁剪后尺寸: {img.size}")
    
    # 保存
    img.save(OUTPUT_PATH)
    print(f"\n已保存: {OUTPUT_PATH}")
    
    # 验证
    pixels = img.load()
    w, h = img.size
    
    # 检查三处区域的透明度
    print("\n镂空验证:")
    
    # 门洞区域（大致在中间下部）
    dx1, dx2 = int(w*0.45), int(w*0.60)
    dy1, dy2 = int(h*0.55), int(h*0.70)
    door_opaque = sum(1 for y in range(dy1, dy2) for x in range(dx1, dx2) if pixels[x,y][3]>10)
    door_total = (dx2-dx1)*(dy2-dy1)
    print(f"  门洞区域({dx1}-{dx2},{dy1}-{dy2}): 不透明{door_opaque}/{door_total} ({100-door_opaque/door_total*100:.0f}%透明)")
    
    # 左飞檐下
    lx1, lx2 = int(w*0.15), int(w*0.35)
    ly1, ly2 = int(h*0.40), int(h*0.55)
    left_opaque = sum(1 for y in range(ly1, ly2) for x in range(lx1, lx2) if pixels[x,y][3]>10)
    left_total = (lx2-lx1)*(ly2-ly1)
    print(f"  左飞檐下({lx1}-{lx2},{ly1}-{ly2}): 不透明{left_opaque}/{left_total} ({100-left_opaque/left_total*100:.0f}%透明)")
    
    # 右飞檐下
    rx1, rx2 = int(w*0.65), int(w*0.85)
    ry1, ry2 = int(h*0.40), int(h*0.55)
    right_opaque = sum(1 for y in range(ry1, ry2) for x in range(rx1, rx2) if pixels[x,y][3]>10)
    right_total = (rx2-rx1)*(ry2-ry1)
    print(f"  右飞檐下({rx1}-{rx2},{ry1}-{ry2}): 不透明{right_opaque}/{right_total} ({100-right_opaque/right_total*100:.0f}%透明)")
    
    print("=" * 60)

if __name__ == "__main__":
    main()
