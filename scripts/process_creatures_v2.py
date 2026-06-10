#!/usr/bin/env python3
"""
Strict background removal for creature sprites.
Uses multiple strategies to ensure clean transparent background.
"""
import sys
from PIL import Image

def strict_remove_bg(img_path, out_path, target_size=64):
    """Remove background aggressively, resize to small sprite."""
    img = Image.open(img_path).convert('RGBA')
    w, h = img.size
    pixels = img.load()

    # Step 1: Find the dominant background color from corners
    corner_pixels = []
    for x in range(min(20, w)):
        for y in range(min(20, h)):
            c = pixels[x, y]
            if c[3] > 0:
                corner_pixels.append(c[:3])
    for x in range(max(0, w-20), w):
        for y in range(min(20, h)):
            c = pixels[x, y]
            if c[3] > 0:
                corner_pixels.append(c[:3])
    for x in range(min(20, w)):
        for y in range(max(0, h-20), h):
            c = pixels[x, y]
            if c[3] > 0:
                corner_pixels.append(c[:3])
    for x in range(max(0, w-20), w):
        for y in range(max(0, h-20), h):
            c = pixels[x, y]
            if c[3] > 0:
                corner_pixels.append(c[:3])

    if not corner_pixels:
        bg_color = (255, 255, 255)
    else:
        # Most common color in corners
        from collections import Counter
        bg_color = Counter(corner_pixels).most_common(1)[0][0]

    # Step 2: Make all pixels similar to bg_color transparent
    # Also check for gray-ish colors that might be residual background
    for y in range(h):
        for x in range(w):
            c = pixels[x, y]
            if c[3] == 0:
                continue
            
            # Distance from detected background
            dist_bg = abs(int(c[0]) - bg_color[0]) + abs(int(c[1]) - bg_color[1]) + abs(int(c[2]) - bg_color[2])
            
            # Check if it's a gray color (residual background)
            is_gray = abs(int(c[0]) - int(c[1])) < 15 and abs(int(c[1]) - int(c[2])) < 15
            gray_dist = abs(int(c[0]) - 128) if is_gray else 999
            
            if dist_bg < 80 or (is_gray and gray_dist < 60):
                pixels[x, y] = (0, 0, 0, 0)

    # Step 3: Find content bounding box
    bbox = img.getbbox()
    if not bbox:
        print(f"Warning: No content found in {img_path}")
        return
    
    # Step 4: Crop with small padding
    left, top, right, bottom = bbox
    pad = 4
    left = max(0, left - pad)
    top = max(0, top - pad)
    right = min(w, right + pad)
    bottom = min(h, bottom + pad)
    
    img = img.crop((left, top, right, bottom))
    
    # Step 5: Resize to target (small sprite)
    img = img.resize((target_size, target_size), Image.NEAREST)
    
    # Save
    img.save(out_path)
    print(f"Processed: {img_path} -> {out_path} ({img.size[0]}x{img.size[1]})")

if __name__ == '__main__':
    for path in sys.argv[1:]:
        if path.endswith('.png'):
            out = path.replace('.png', '_v2.png')
            strict_remove_bg(path, out, target_size=64)
