#!/usr/bin/env python3
"""Aggressive background removal for troop sprites using edge flood fill."""
import sys, os, glob
from PIL import Image
from collections import deque

def is_colorful(r, g, b):
    """Check if pixel is actual content (not gray background)."""
    max_val = max(r, g, b)
    min_val = min(r, g, b)
    # If it's very dark, keep it (could be part of sprite)
    if max_val < 30:
        return True
    # If it's very light, it's likely background
    if min_val > 200:
        return False
    # Check saturation: colorful if max-min > threshold
    saturation = max_val - min_val
    return saturation > 25

def remove_bg(input_path, output_path):
    img = Image.open(input_path).convert('RGBA')
    w, h = img.size
    pixels = img.load()
    
    # Step 1: Flood fill from all edges to find background-connected area
    visited = set()
    queue = deque()
    
    # Add all edge pixels
    for x in range(w):
        queue.append((x, 0))
        queue.append((x, h-1))
        visited.add((x, 0))
        visited.add((x, h-1))
    for y in range(1, h-1):
        queue.append((0, y))
        queue.append((w-1, y))
        visited.add((0, y))
        visited.add((w-1, y))
    
    while queue:
        x, y = queue.popleft()
        if x < 0 or x >= w or y < 0 or y >= h:
            continue
        c = pixels[x, y]
        # If already transparent, skip
        if c[3] == 0:
            continue
        
        r, g, b, a = c
        
        # If this pixel looks like background (low saturation OR very light), make transparent
        if not is_colorful(r, g, b):
            pixels[x, y] = (0, 0, 0, 0)
            # Spread to neighbors
            for dx, dy in [(0,1),(0,-1),(1,0),(-1,0)]:
                nx, ny = x+dx, y+dy
                if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                    visited.add((nx, ny))
                    queue.append((nx, ny))
    
    # Step 2: Crop to remaining content
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    
    # Step 3: Center on 64x64 canvas with transparency
    final = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    cw, ch = img.size
    x_offset = (64 - cw) // 2
    y_offset = (64 - ch) // 2
    final.paste(img, (x_offset, y_offset), img)
    
    final.save(output_path)
    # Verify transparency
    opaque = sum(1 for y in range(64) for x in range(64) if final.getpixel((x,y))[3] > 0)
    print(f"  {input_path}: {opaque}/{4096} opaque pixels -> {output_path}")

if __name__ == '__main__':
    for path in sorted(glob.glob("assets/textures/troops/troop_*.png")):
        if path.endswith('.png') and not '_v2' in path:
            out = path  # overwrite original
            print(f"Processing: {path}")
            remove_bg(path, out)
    print("Done!")
