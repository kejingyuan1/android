from PIL import Image
import os

# Load the sprite sheet
sheet = Image.open(r'C:\Users\WIN11\WorkBuddy\2026-06-01-16-27-34\city-builder\assets\textures\A_sprite_sheet_of_8_buildings__2026-06-03T00-30-18.png')

# The image is 1024x1024 with 3 columns and 3 rows of buildings
# Each building is approximately 341x341
building_names = [
    'house1', 'house2', 'apartment',
    'shop', 'office', 'factory',
    'fire_station', 'police', 'hospital'
]

width, height = sheet.size
cols = 3
rows = 3
cell_w = width // cols
cell_h = height // rows

output_dir = r'C:\Users\WIN11\WorkBuddy\2026-06-01-16-27-34\city-builder\assets\textures\buildings'
os.makedirs(output_dir, exist_ok=True)

# Extract each building
for row in range(rows):
    for col in range(cols):
        idx = row * cols + col
        if idx >= len(building_names):
            break
        
        # Calculate crop box
        left = col * cell_w
        upper = row * cell_h
        right = left + cell_w
        lower = upper + cell_h
        
        # Crop and save
        building = sheet.crop((left, upper, right, lower))
        
        # Resize to 64x64 for game use
        building = building.resize((64, 64), Image.LANCZOS)
        
        output_path = os.path.join(output_dir, f'{building_names[idx]}.png')
        building.save(output_path)
        print(f'Saved: {output_path}')

print('Done!')
