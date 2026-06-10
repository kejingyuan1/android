#!/usr/bin/env python3
"""Force full transparency on all edges of troop/critter sprites."""
import glob
from PIL import Image

for path in glob.glob("assets/textures/**/*.png", recursive=True):
    if '_v2' in path or '.import' in path:
        continue
    img = Image.open(path).convert('RGBA')
    w, h = img.size
    pixels = img.load()
    
    changed = 0
    
    # For 64x64 images: make ALL pixels with low alpha or gray-ish fully transparent
    if w <= 128 and h <= 128:
        for y in range(h):
            for x in range(w):
                r, g, b, a = pixels[x, y]
                if a == 0:
                    continue
                
                # If alpha is very low, force transparent
                if a < 30:
                    pixels[x, y] = (0, 0, 0, 0)
                    changed += 1
                    continue
                
                # If all channels are very close (gray-ish) AND not very bright AND not very dark
                max_c = max(r, g, b)
                min_c = min(r, g, b)
                diff = max_c - min_c
                
                # Remove near-white pixels
                if min_c > 200:
                    pixels[x, y] = (0, 0, 0, 0)
                    changed += 1
                    continue
                
                # Remove low-saturation gray pixels
                if diff < 20 and max_c > 60 and max_c < 220:
                    pixels[x, y] = (0, 0, 0, 0)
                    changed += 1
                    continue
    
    if changed > 0:
        img.save(path)
        print(f"{path}: removed {changed} pixels")

print("Done!")
