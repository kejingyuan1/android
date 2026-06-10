#!/usr/bin/env python3
"""Process new building sprites: remove bg, crop, resize to 64x64."""
import glob
from PIL import Image
from collections import deque

for path in glob.glob("assets/textures/buildings/*_raw.png"):
    img = Image.open(path).convert('RGBA')
    w, h = img.size
    pixels = img.load()
    
    # Flood fill from edges to remove background
    visited = set()
    queue = deque()
    for x in range(w):
        queue.append((x,0)); queue.append((x,h-1))
        visited.add((x,0)); visited.add((x,h-1))
    for y in range(1,h-1):
        queue.append((0,y)); queue.append((w-1,y))
        visited.add((0,y)); visited.add((w-1,y))
    
    while queue:
        x,y = queue.popleft()
        if x<0 or x>=w or y<0 or y>=h: continue
        c = pixels[x,y]
        if c[3]==0: continue
        r,g,b,a = c
        max_c, min_c = max(r,g,b), min(r,g,b)
        sat = max_c - min_c
        if sat < 30 or min_c > 200:
            pixels[x,y] = (0,0,0,0)
            for dx,dy in [(0,1),(0,-1),(1,0),(-1,0)]:
                nx,ny = x+dx,y+dy
                if 0<=nx<w and 0<=ny<h and (nx,ny) not in visited:
                    visited.add((nx,ny))
                    queue.append((nx,ny))
    
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    else:
        print(f"  WARNING: {path} has no content!")
        continue
    
    # Center on 64x64
    final = Image.new('RGBA', (64,64), (0,0,0,0))
    cw,ch = img.size
    xo,yo = (64-cw)//2, (64-ch)//2
    final.paste(img, (xo,yo), img)
    
    out_path = path.replace('_raw.png', '.png')
    final.save(out_path)
    opaque = sum(1 for y in range(64) for x in range(64) if final.getpixel((x,y))[3]>0)
    print(f"  {out_path}: {opaque}/{4096} opaque pixels")
    import os
    os.remove(path)

print("Done!")
