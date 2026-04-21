#!/usr/bin/env python3
"""Generate professional Veltrix TV app icon."""
from PIL import Image, ImageDraw, ImageFont
import math

def create_icon(size, is_foreground=False):
    """Create a clean, modern IPTV app icon."""
    # For adaptive icon foreground, use 432x432 with safe zone
    if is_foreground:
        canvas_size = size
        # Safe zone is inner 66% - but we draw centered so it works
        padding = int(size * 0.17)  # ~17% padding on each side
    else:
        canvas_size = size
        padding = int(size * 0.1)

    img = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    if not is_foreground:
        # Draw rounded rectangle background
        # Dark gradient-like background
        for y in range(canvas_size):
            ratio = y / canvas_size
            r = int(15 + ratio * 10)
            g = int(5 + ratio * 5)
            b = int(25 + ratio * 15)
            draw.line([(0, y), (canvas_size, y)], fill=(r, g, b, 255))

    cx, cy = canvas_size // 2, canvas_size // 2

    # Draw a stylish "V" with a TV/play accent
    v_width = canvas_size - 2 * padding
    v_height = int(v_width * 0.75)
    v_top = cy - v_height // 2 - int(size * 0.02)
    v_bottom = v_top + v_height

    # Thickness of the V strokes
    thickness = max(int(v_width * 0.14), 4)

    # Left stroke of V - gradient from red to white
    left_top = (cx - v_width // 2, v_top)
    bottom_point = (cx, v_bottom)
    right_top = (cx + v_width // 2, v_top)

    # Draw V with anti-aliased thick lines using polygon
    # Left stroke
    half_t = thickness // 2
    left_poly = [
        (left_top[0] - half_t, left_top[1]),
        (left_top[0] + half_t + 2, left_top[1]),
        (bottom_point[0] + half_t, bottom_point[1]),
        (bottom_point[0] - half_t, bottom_point[1]),
    ]
    # Right stroke
    right_poly = [
        (right_top[0] + half_t, right_top[1]),
        (right_top[0] - half_t - 2, right_top[1]),
        (bottom_point[0] - half_t, bottom_point[1]),
        (bottom_point[0] + half_t, bottom_point[1]),
    ]

    # Red accent color (Veltrix brand red)
    red = (220, 40, 40)
    white = (255, 255, 255)

    # Draw the V in red with gradient effect
    # Left stroke - red
    draw.polygon(left_poly, fill=red)
    # Right stroke - slightly lighter red/white
    draw.polygon(right_poly, fill=(240, 60, 60))

    # Add a subtle glow/highlight on inner edges
    inner_left = [
        (left_top[0] + half_t, left_top[1]),
        (left_top[0] + half_t + int(thickness * 0.4), left_top[1]),
        (bottom_point[0] + int(thickness * 0.2), bottom_point[1]),
        (bottom_point[0], bottom_point[1]),
    ]
    draw.polygon(inner_left, fill=(255, 100, 100, 180))

    inner_right = [
        (right_top[0] - half_t, right_top[1]),
        (right_top[0] - half_t - int(thickness * 0.4), right_top[1]),
        (bottom_point[0] - int(thickness * 0.2), bottom_point[1]),
        (bottom_point[0], bottom_point[1]),
    ]
    draw.polygon(inner_right, fill=(255, 120, 120, 180))

    # Add a small play triangle inside the V
    play_size = int(v_width * 0.15)
    play_cx = cx
    play_cy = v_top + int(v_height * 0.45)
    play_tri = [
        (play_cx - int(play_size * 0.4), play_cy - play_size // 2),
        (play_cx - int(play_size * 0.4), play_cy + play_size // 2),
        (play_cx + int(play_size * 0.6), play_cy),
    ]
    draw.polygon(play_tri, fill=white)

    # Add "TV" text below the V
    tv_y = v_bottom + int(size * 0.02)
    try:
        font_size = max(int(size * 0.12), 10)
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", font_size)
    except:
        font = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), "TV", font=font)
    tw = bbox[2] - bbox[0]
    draw.text((cx - tw // 2, tv_y), "TV", fill=(180, 180, 190), font=font)

    return img


def create_background(size):
    """Create the adaptive icon background - solid dark."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Dark background with subtle gradient
    for y in range(size):
        ratio = y / size
        r = int(12 + ratio * 8)
        g = int(4 + ratio * 4)
        b = int(20 + ratio * 12)
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))
    return img


# Generate all icon sizes
res_dir = '/var/lib/freelancer/projects/40373506/iptv_pro/android/app/src/main/res'

# Standard launcher icon sizes
icon_sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

# Adaptive icon foreground sizes (1.5x the standard)
foreground_sizes = {
    'mipmap-mdpi': 108,
    'mipmap-hdpi': 162,
    'mipmap-xhdpi': 216,
    'mipmap-xxhdpi': 324,
    'mipmap-xxxhdpi': 432,
}

# Generate standard icons
for folder, size in icon_sizes.items():
    icon = create_icon(size)
    # Add dark background for non-adaptive
    bg = create_background(size)
    final = Image.alpha_composite(bg, icon)
    final = final.convert('RGB')
    final.save(f'{res_dir}/{folder}/ic_launcher.png', 'PNG')
    print(f'Created {folder}/ic_launcher.png ({size}x{size})')

# Generate adaptive foreground icons
for folder, size in foreground_sizes.items():
    fg = create_icon(size, is_foreground=True)
    fg.save(f'{res_dir}/{folder}/ic_launcher_foreground.png', 'PNG')
    print(f'Created {folder}/ic_launcher_foreground.png ({size}x{size})')

# Check if there's a background color resource
print('\nDone! Icons generated.')
