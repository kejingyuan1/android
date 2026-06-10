#!/usr/bin/env python3
"""
Post-process creature sprites: remove solid background, crop, resize.
"""
import sys
from PIL import Image

def remove_bg_and_crop(img_path, out_path, target_size=128):
    """Remove background, crop, resize to target_size."""
    img = Image.open(img_path).convert('RGBA')
    pixels = img.load()
    w, h = img.size

    # --- Strategy 1: If edges are already transparent, just crop ---
    edge_transparent = 0
    for x in range(w):
        for y in [0, h-1]:
            if x < w and y < h and pixels[x, y][3] == 0:
                edge_transparent += 1
    for y in range(h):
        for x in [0, w-1]:
            if x < w and y < h and pixels[x, y][3] == 0:
                edge_transparent += 1

    if edge_transparent > 10:
        # Already has transparency - just crop
        bbox = img.getbbox()
        if bbox:
            img = img.crop(bbox)
    else:
        # --- Strategy 2: Remove solid background color ---
        # Sample edge pixels to find background color
        edge_colors = {}
        for x in range(w):
            for y in [0, h-1]:
                c = pixels[x, y]
                if c[3] > 0:
                    rgb = (c[0] // 10, c[1] // 10, c[2] // 10)  # quantize
                    edge_colors[rgb] = edge_colors.get(rgb, 0) + 1
        for y in range(h):
            for x in [0, w-1]:
                c = pixels[x, y]
                if c[3] > 0:
                    rgb = (c[0] // 10, c[1] // 10, c[2] // 10)
                    edge_colors[rgb] = edge_colors.get(rgb, 0) + 1

        if not edge_colors:
            bg_rgb = (0, 0, 0)
        else:
            # Get most common edge color
            bg_quantized = max(edge_colors, key=edge_colors.get)
            bg_rgb = (bg_quantized[0] * 10 + 5, bg_quantized[1] * 10 + 5, bg_quantized[2] * 10 + 5)

        # Make all pixels close to bg color transparent
        for y in range(h):
            for x in range(w):
                c = pixels[x, y]
                if c[3] > 0:
                    dist = abs(int(c[0]) - bg_rgb[0]) + abs(int(c[1]) - bg_rgb[1]) + abs(int(c[2]) - bg_rgb[2])
                    if dist < 60:
                        pixels[x, y] = (0, 0, 0, 0)

        bbox = img.getbbox()
        if bbox:
            img = img.crop(bbox)

    # --- Resize to target size preserving aspect ratio ---
    img = img.resize((target_size, target_size), Image.NEAREST)

    # Save
    img.save(out_path)
    print(f"Processed: {img_path} -> {out_path} ({img.size[0]}x{img.size[1]})")

if __name__ == '__main__':
    for path in sys.argv[1:]:
        if path.endswith('.png'):
            out = path.replace('.png', '_c.png')
            remove_bg_and_crop(path, out)
