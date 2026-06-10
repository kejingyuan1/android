from PIL import Image
import sys, os, glob
from collections import Counter

for path in glob.glob("assets/textures/troops/troop_*.png"):
    img = Image.open(path).convert('RGBA')
    w, h = img.size
    pixels = img.load()
    
    # Find bg color from corners
    corner = []
    for x in range(min(30,w)):
        for y in range(min(30,h)):
            c = pixels[x,y]
            if c[3] > 0: corner.append(c[:3])
    for x in range(max(0,w-30),w):
        for y in range(max(0,h-30),h):
            c = pixels[x,y]
            if c[3] > 0: corner.append(c[:3])
    
    if corner:
        bg = Counter(corner).most_common(1)[0][0]
        for y in range(h):
            for x in range(w):
                c = pixels[x,y]
                if c[3] == 0: continue
                d = abs(int(c[0])-bg[0]) + abs(int(c[1])-bg[1]) + abs(int(c[2])-bg[2])
                if d < 80: pixels[x,y] = (0,0,0,0)
    
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    
    # Resize to 64x64
    img = img.resize((64, 64), Image.NEAREST)
    img.save(path)
    print(f"Processed: {path} -> {img.size}")

print("Done!")
